/**
 * 电子衣柜路由（M1）— 口径见 docs/wardrobe-interaction.md v1.0
 * 实拍保存即已通过；组合 待确认⇄已通过；软删 deleted_at；
 * wear_count 条件更新（进入已通过+1/离开-1）；M1 不开 TA 授权。
 * SQL 全部内联字面量 + 参数数组；可变 IN 用固定 8 占位符补位（单品上限 8）。
 */
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');

// ---------- 上传 ----------
const uploadDir = path.join(__dirname, '..', 'uploads', 'wardrobe');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${Date.now()}_${Math.random().toString(36).slice(2, 8)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    cb(null, allowed.includes(path.extname(file.originalname).toLowerCase()));
  },
});

// multer 拒绝一律 400（不复现现网 fileFilter 返 500 的旧病）
const wrapUpload = (field) => (req, res, next) => {
  upload.single(field)(req, res, (err) => {
    if (err) return res.status(400).json({ code: 400, message: '图片不合格（≤10MB，jpg/png/webp）' });
    next();
  });
};

// ---------- 枚举白名单 ----------
const CATEGORIES = ['上装', '裤装', '裙装', '外套', '鞋子', '包袋', '配饰', '连体装'];
const TEMPERATURES = ['炎热', '温暖', '凉爽', '寒冷'];
const COLORS = ['红', '橙', '黄', '绿', '蓝', '紫', '粉', '黑白灰', '棕', '杂色'];
const OCCASIONS = ['日常', '上班', '约会', '运动', '正式', '居家', '旅行'];
const STYLES = ['休闲', '甜美', '简约', '运动', '复古', '正式', '潮酷'];
const ITEM_STATUSES = ['在柜', '退役'];
const OUTFIT_STATUSES = ['待确认', '已通过'];

// ---------- 工具 ----------
function cleanText(v, max) {
  return String(v ?? '').trim().slice(0, max);
}

function bjToday() {
  return new Date(Date.now() + 8 * 3600 * 1000).toISOString().slice(0, 10);
}

function addDays(dateStr, n) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function isValidDate(s) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
}

function sqlDateStr(v) {
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v ?? '').slice(0, 10);
}

// FormData 里的多选字段是 JSON 字符串；数组直传（dio JSON body）也兼容
function parseJsonArray(v, allowed, maxLen) {
  let arr = v;
  if (typeof arr === 'string') {
    try { arr = JSON.parse(arr); } catch { return null; }
  }
  if (arr == null) return [];
  if (!Array.isArray(arr)) return null;
  const out = [...new Set(arr.map((x) => String(x).trim()).filter((x) => allowed.includes(x)))];
  return out.length <= maxLen ? out : null;
}

function parsePrice(v) {
  if (v == null || String(v).trim() === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0 || n > 9999999) return undefined;
  return Math.round(n * 100) / 100;
}

function parseItemIds(v, min, max) {
  let arr = v;
  if (typeof arr === 'string') {
    try { arr = JSON.parse(arr); } catch { return null; }
  }
  if (arr == null) arr = [];
  if (!Array.isArray(arr)) return null;
  const ids = [...new Set(arr.map((x) => parseInt(x, 10)).filter((x) => Number.isInteger(x) && x > 0))];
  return ids.length >= min && ids.length <= max ? ids : null;
}

// 固定 8 占位符补位（IN 上限 8，见 M1 方案）
function padIds(ids) {
  const arr = [...ids];
  while (arr.length < 8) arr.push(arr.length > 0 ? arr[0] : 0);
  return arr;
}

async function makeThumbnail(absPath) {
  const thumbPath = absPath.replace(/(\.[a-z0-9]+)$/i, '') + '_thumb.webp';
  await sharp(absPath).rotate().resize(400, 400, { fit: 'inside', withoutEnlargement: true })
    .webp({ quality: 80 }).toFile(thumbPath);
  return `/uploads/wardrobe/${path.basename(thumbPath)}`;
}

function removeFilesQuiet(urls) {
  for (const url of urls) {
    if (!url) continue;
    try { fs.unlinkSync(path.join(__dirname, '..', url)); } catch (_) { /* 文件可能已不存在 */ }
  }
}

// 校验 items 归属且"在柜"，返回去重后的实际命中 id
async function ownedOnCabIds(conn, userId, ids) {
  if (ids.length === 0) return [];
  const [rows] = await conn.query(
    "SELECT id FROM wardrobe_items WHERE user_id = ? AND deleted_at IS NULL AND status = '在柜' AND id IN (?, ?, ?, ?, ?, ?, ?, ?)",
    [userId, ...padIds(ids)]
  );
  return [...new Set(rows.map((r) => r.id))];
}

function itemsOf(row) {
  const raw = row.item_ids;
  const arr = raw == null ? [] : (Array.isArray(raw) ? raw : []);
  return [...new Set(arr.map((x) => parseInt(x, 10)).filter((x) => Number.isInteger(x) && x > 0))];
}

// item_ids → 条目摘要（软删行保留所以拿得到 category，P7/P9 灰占位数据来源）
async function resolveItemSummaries(itemIds) {
  if (itemIds.length === 0) return [];
  const [rows] = await pool.query(
    'SELECT id, category, brand, thumbnail_url, deleted_at FROM wardrobe_items WHERE id IN (?, ?, ?, ?, ?, ?, ?, ?)',
    padIds(itemIds)
  );
  const map = new Map(rows.map((r) => [r.id, r]));
  return itemIds.map((id) => {
    const r = map.get(id);
    if (!r) return { id, deleted: true, category: null, brand: null, thumbnailUrl: null };
    return {
      id,
      deleted: r.deleted_at != null,
      category: r.category,
      brand: r.brand,
      thumbnailUrl: r.thumbnail_url,
    };
  });
}

async function adjustWearCount(conn, userId, ids, delta) {
  for (const id of ids) {
    await conn.query(
      'UPDATE wardrobe_items SET wear_count = GREATEST(wear_count + ?, 0) WHERE id = ? AND user_id = ?',
      [delta, id, userId]
    );
  }
}

// ---------- 单品 ----------
router.get('/items', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, image_url, thumbnail_url, category, temperature, occasions, styles, color,
              brand, price, status, wear_count, bg_removed, cutout_url, item_layout, created_at
       FROM wardrobe_items WHERE user_id = ? AND deleted_at IS NULL
       ORDER BY created_at DESC, id DESC`,
      [req.user.id]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Wardrobe] items list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/items/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ code: 400, message: '参数不对' });
    const [rows] = await pool.query(
      `SELECT i.id, i.image_url, i.thumbnail_url, i.category, i.temperature, i.occasions, i.styles,
              i.color, i.brand, i.price, i.status, i.wear_count, i.bg_removed, i.cutout_url,
              i.item_layout, i.created_at,
              (SELECT COUNT(*) FROM wardrobe_outfits o
                WHERE o.user_id = i.user_id AND i.id MEMBER OF (o.item_ids)) AS outfit_refs_count
       FROM wardrobe_items i
       WHERE i.id = ? AND i.user_id = ? AND i.deleted_at IS NULL`,
      [id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: '单品不存在' });
    res.json({ code: 200, data: rows[0] });
  } catch (err) {
    console.error('[Wardrobe] item detail failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/items', authRequired, wrapUpload('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ code: 400, message: '先给衣服拍张照吧' });
    const category = cleanText(req.body.category, 20);
    if (!CATEGORIES.includes(category)) return res.status(400).json({ code: 400, message: '类型不对' });
    const temperature = cleanText(req.body.temperature, 10) || null;
    if (temperature && !TEMPERATURES.includes(temperature)) return res.status(400).json({ code: 400, message: '温度档不对' });
    const occasions = parseJsonArray(req.body.occasions, OCCASIONS, 7);
    const styles = parseJsonArray(req.body.styles, STYLES, 7);
    if (occasions == null || styles == null) return res.status(400).json({ code: 400, message: '标签不对' });
    const color = cleanText(req.body.color, 20) || null;
    if (color && !COLORS.includes(color)) return res.status(400).json({ code: 400, message: '颜色不对' });
    const brand = cleanText(req.body.brand, 20) || null;
    const price = parsePrice(req.body.price);
    if (price === undefined) return res.status(400).json({ code: 400, message: '价格要是非负数' });

    const imageUrl = `/uploads/wardrobe/${req.file.filename}`;
    let thumbnailUrl = null;
    try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }

    const [result] = await pool.query(
      `INSERT INTO wardrobe_items (user_id, image_url, thumbnail_url, category, temperature, occasions, styles, color, brand, price)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, imageUrl, thumbnailUrl, category, temperature,
       JSON.stringify(occasions), JSON.stringify(styles), color, brand, price]
    );
    res.json({ code: 200, message: '已放入衣橱', data: { id: result.insertId, imageUrl, thumbnailUrl } });
  } catch (err) {
    console.error('[Wardrobe] item create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/items/:id', authRequired, wrapUpload('image'), async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ code: 400, message: '参数不对' });
    const [rows] = await pool.query(
      'SELECT id, image_url, thumbnail_url, cutout_url FROM wardrobe_items WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: '单品不存在' });

    const category = cleanText(req.body.category, 20);
    if (!CATEGORIES.includes(category)) return res.status(400).json({ code: 400, message: '类型不对' });
    const temperature = cleanText(req.body.temperature, 10) || null;
    if (temperature && !TEMPERATURES.includes(temperature)) return res.status(400).json({ code: 400, message: '温度档不对' });
    const occasions = parseJsonArray(req.body.occasions, OCCASIONS, 7);
    const styles = parseJsonArray(req.body.styles, STYLES, 7);
    if (occasions == null || styles == null) return res.status(400).json({ code: 400, message: '标签不对' });
    const color = cleanText(req.body.color, 20) || null;
    if (color && !COLORS.includes(color)) return res.status(400).json({ code: 400, message: '颜色不对' });
    const brand = cleanText(req.body.brand, 20) || null;
    const price = parsePrice(req.body.price);
    if (price === undefined) return res.status(400).json({ code: 400, message: '价格要是非负数' });

    let imageUrl = rows[0].image_url;
    let thumbnailUrl = rows[0].thumbnail_url;
    let oldUrls = null;
    let cutoutInvalidated = false;
    if (req.file) {
      imageUrl = `/uploads/wardrobe/${req.file.filename}`;
      try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }
      // 换图后旧抠图与位置记忆一并失效（审查 P1-3）
      oldUrls = [rows[0].image_url, rows[0].thumbnail_url, rows[0].cutout_url];
      cutoutInvalidated = true;
    }

    // 两条完整内联字面量（Mimosa 红线：禁止变量拼 SET 子句）
    if (cutoutInvalidated) {
      await pool.query(
        'UPDATE wardrobe_items SET image_url = ?, thumbnail_url = ?, category = ?, temperature = ?, occasions = ?, styles = ?, color = ?, brand = ?, price = ?, bg_removed = 0, cutout_url = NULL, item_layout = NULL WHERE id = ? AND user_id = ?',
        [imageUrl, thumbnailUrl, category, temperature,
         JSON.stringify(occasions), JSON.stringify(styles), color, brand, price, id, req.user.id]
      );
    } else {
      await pool.query(
        'UPDATE wardrobe_items SET image_url = ?, thumbnail_url = ?, category = ?, temperature = ?, occasions = ?, styles = ?, color = ?, brand = ?, price = ? WHERE id = ? AND user_id = ?',
        [imageUrl, thumbnailUrl, category, temperature,
         JSON.stringify(occasions), JSON.stringify(styles), color, brand, price, id, req.user.id]
      );
    }
    if (oldUrls) removeFilesQuiet(oldUrls); // 换图旧文件：提交后清理
    res.json({ code: 200, message: '已保存', data: { id, imageUrl, thumbnailUrl } });
  } catch (err) {
    console.error('[Wardrobe] item update failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.patch('/items/:id/status', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const status = cleanText(req.body.status, 10);
    if (!Number.isInteger(id) || !ITEM_STATUSES.includes(status)) {
      return res.status(400).json({ code: 400, message: '状态不对' });
    }
    const [r] = await pool.query(
      'UPDATE wardrobe_items SET status = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [status, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '单品不存在' });
    res.json({ code: 200, message: status === '退役' ? '已退役' : '已放回在柜' });
  } catch (err) {
    console.error('[Wardrobe] item status failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.delete('/items/:id', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '参数不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT image_url, thumbnail_url, cutout_url FROM wardrobe_items WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '单品不存在' });
    }
    await conn.query(
      'UPDATE wardrobe_items SET deleted_at = NOW() WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [id, req.user.id]
    );
    await conn.commit();
    conn.release();
    removeFilesQuiet([rows[0].image_url, rows[0].thumbnail_url, rows[0].cutout_url]); // 事务提交后清理文件
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] item delete failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ---------- 穿搭 ----------
router.get('/outfits', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, worn_date, source, photo_url, item_ids, status, note, created_at
       FROM wardrobe_outfits WHERE user_id = ?
       ORDER BY worn_date DESC, created_at DESC, id DESC`,
      [req.user.id]
    );
    const data = [];
    for (const row of rows) {
      const itemIds = itemsOf(row);
      data.push({
        ...row,
        worn_date: sqlDateStr(row.worn_date),
        itemIds,
        items: await resolveItemSummaries(itemIds),
      });
    }
    res.json({ code: 200, data });
  } catch (err) {
    console.error('[Wardrobe] outfits list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/outfits', authRequired, wrapUpload('photo'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const source = cleanText(req.body.source, 10);
    if (!['实拍', '组合', '换装'].includes(source)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '来源不对' });
    }
    const wornDate = cleanText(req.body.wornDate, 10);
    const today = bjToday();
    const maxDate = source === '实拍' ? today : addDays(today, 90);
    if (!isValidDate(wornDate) || wornDate < '2000-01-01' || wornDate > maxDate) {
      conn.release();
      return res.status(400).json({ code: 400, message: source === '实拍' ? '实拍日期不能是未来' : '日期要在 2000-01-01 ~ 今天+90 天内' });
    }
    const note = cleanText(req.body.note, 200) || null;

    let itemIds = [];
    let photoUrl = null;
    let thumbnailUrl = null;
    if (source === '组合') {
      itemIds = parseItemIds(req.body.itemIds, 2, 8);
      if (itemIds == null) {
        conn.release();
        return res.status(400).json({ code: 400, message: '搭配要 2-8 件单品' });
      }
    } else {
      // 实拍与换装都需要照片（换装 photo_url=合成图）；关联件数：换装 1-8、实拍 0-8
      if (!req.file) {
        conn.release();
        return res.status(400).json({ code: 400, message: source === '换装' ? '缺少合成图，请重新保存穿搭' : '先拍一张今天的穿搭吧' });
      }
      photoUrl = `/uploads/wardrobe/${req.file.filename}`;
      itemIds = parseItemIds(req.body.itemIds, source === '换装' ? 1 : 0, 8);
      if (itemIds == null) {
        conn.release();
        return res.status(400).json({ code: 400, message: source === '换装' ? '穿搭至少要 1 件单品' : '关联单品不对' });
      }
    }

    await conn.beginTransaction();
    if (itemIds.length > 0) {
      const owned = await ownedOnCabIds(conn, req.user.id, itemIds);
      if (owned.length !== itemIds.length) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({ code: 400, message: '有的单品已不在柜，刷新后再试' });
      }
    }
    if (req.file) {
      try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }
    }
    const status = source === '实拍' ? '已通过' : '待确认';
    const [ins] = await conn.query(
      'INSERT INTO wardrobe_outfits (user_id, worn_date, source, photo_url, item_ids, status, note) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [req.user.id, wornDate, source, photoUrl, itemIds.length > 0 ? JSON.stringify(itemIds) : null, status, note]
    );
    if (status === '已通过' && itemIds.length > 0) {
      await adjustWearCount(conn, req.user.id, itemIds, 1);
    }
    await conn.commit();
    conn.release();
    res.json({ code: 200, message: '已记录', data: { id: ins.insertId } });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] outfit create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/outfits/:id', authRequired, wrapUpload('photo'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '参数不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT id, worn_date, source, photo_url, thumbnail_url, item_ids, status FROM wardrobe_outfits WHERE id = ? AND user_id = ? FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '穿搭不存在' });
    }
    const row = rows[0];
    const oldItems = itemsOf(row);

    const wornDate = cleanText(req.body.wornDate, 10) || sqlDateStr(row.worn_date);
    const maxDate = row.source === '实拍' ? bjToday() : addDays(bjToday(), 90);
    if (!isValidDate(wornDate) || wornDate < '2000-01-01' || wornDate > maxDate) {
      await conn.rollback();
      conn.release();
      return res.status(400).json({ code: 400, message: '日期越界了' });
    }
    const note = req.body.note === undefined ? row.note : (cleanText(req.body.note, 200) || null);

    let itemIds = oldItems;
    if (req.body.itemIds !== undefined) {
      const minIds = row.source === '组合' ? 2 : row.source === '换装' ? 1 : 0;
      const parsed = parseItemIds(req.body.itemIds, minIds, 8);
      if (parsed == null) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({ code: 400, message: row.source === '组合' ? '搭配要 2-8 件单品' : row.source === '换装' ? '穿搭至少要 1 件单品' : '关联单品不对' });
      }
      if (parsed.length > 0) {
        const owned = await ownedOnCabIds(conn, req.user.id, parsed);
        if (owned.length !== parsed.length) {
          await conn.rollback();
          conn.release();
          return res.status(400).json({ code: 400, message: '有的单品已不在柜，刷新后再试' });
        }
      }
      itemIds = parsed;
    }

    let photoUrl = row.photo_url;
    let thumbnailUrl = row.thumbnail_url;
    let oldFiles = null;
    if (req.file) {
      if (row.source !== '实拍') {
        await conn.rollback();
        conn.release();
        return res.status(400).json({ code: 400, message: '组合搭配没有照片可换' });
      }
      photoUrl = `/uploads/wardrobe/${req.file.filename}`;
      try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }
      oldFiles = [row.photo_url, row.thumbnail_url];
    }

    if (row.status === '已通过') {
      const removed = oldItems.filter((x) => !itemIds.includes(x));
      const added = itemIds.filter((x) => !oldItems.includes(x));
      if (removed.length > 0) await adjustWearCount(conn, req.user.id, removed, -1);
      if (added.length > 0) await adjustWearCount(conn, req.user.id, added, 1);
    }

    await conn.query(
      'UPDATE wardrobe_outfits SET worn_date = ?, note = ?, item_ids = ?, photo_url = ?, thumbnail_url = ? WHERE id = ? AND user_id = ?',
      [wornDate, note, itemIds.length > 0 ? JSON.stringify(itemIds) : null, photoUrl, thumbnailUrl, id, req.user.id]
    );
    await conn.commit();
    conn.release();
    if (oldFiles) removeFilesQuiet(oldFiles);
    res.json({ code: 200, message: '已保存' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] outfit update failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.patch('/outfits/:id/status', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    const target = cleanText(req.body.status, 10);
    if (!Number.isInteger(id) || !OUTFIT_STATUSES.includes(target)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '状态不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT status, item_ids FROM wardrobe_outfits WHERE id = ? AND user_id = ? FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '穿搭不存在' });
    }
    const old = rows[0].status;
    const items = itemsOf(rows[0]);
    if (old !== target) {
      // 条件更新防双端并发重复计数
      const [r] = await conn.query(
        'UPDATE wardrobe_outfits SET status = ? WHERE id = ? AND user_id = ? AND status = ?',
        [target, id, req.user.id, old]
      );
      if (r.affectedRows === 0) {
        await conn.rollback();
        conn.release();
        return res.status(409).json({ code: 409, message: '状态刚有变化，刷新后再试' });
      }
      if (items.length > 0) {
        await adjustWearCount(conn, req.user.id, items, target === '已通过' ? 1 : -1);
      }
    }
    await conn.commit();
    conn.release();
    res.json({ code: 200, message: target === '已通过' ? '已通过' : '已改回待确认' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] outfit status failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.delete('/outfits/:id', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '参数不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT status, item_ids, photo_url, thumbnail_url FROM wardrobe_outfits WHERE id = ? AND user_id = ? FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '穿搭不存在' });
    }
    const items = itemsOf(rows[0]);
    if (rows[0].status === '已通过' && items.length > 0) {
      await adjustWearCount(conn, req.user.id, items, -1);
    }
    await conn.query('DELETE FROM wardrobe_outfits WHERE id = ? AND user_id = ?', [id, req.user.id]);
    await conn.commit();
    conn.release();
    removeFilesQuiet([rows[0].photo_url, rows[0].thumbnail_url]);
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] outfit delete failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ---------- 抠图（M2a 人像=bda；M2-S0 衣服=数据万象 CI GoodsMatting+AIPicMatting 兜底） ----------
const cutoutDir = path.join(uploadDir, 'cutout');
if (!fs.existsSync(cutoutDir)) fs.mkdirSync(cutoutDir, { recursive: true });

// 单飞队列：同一时间仅 1 个云 API 调用（防限流拖垮主接口）
let cutoutChain = Promise.resolve();
let dailyCount = { date: new Date().toISOString().slice(0, 10), map: new Map() };

function cutoutQuotaLeft(userId) {
  const today = new Date().toISOString().slice(0, 10);
  if (dailyCount.date !== today) {
    dailyCount = { date: today, map: new Map() };
  }
  const used = dailyCount.map.get(userId) || 0;
  return Math.max(0, 50 - used);
}

function cutoutConsume(userId) {
  dailyCount.map.set(userId, (dailyCount.map.get(userId) || 0) + 1);
}

function cutoutEnabled() {
  return process.env.WARDROBE_CUTOUT_ON === '1' &&
    !!process.env.TENCENT_SECRET_ID &&
    !!process.env.TENCENT_SECRET_KEY;
}

// 人像分割：输入原图路径 → 输出透明 PNG 落盘，返回 cutout url
async function runPortraitCutout(absPath) {
  const { bda } = require('tencentcloud-sdk-nodejs-bda');
  let input = await sharp(absPath).rotate().jpeg({ quality: 90 }).toBuffer();
  if (input.length > 5 * 1024 * 1024) {
    input = await sharp(absPath).rotate().resize(1600, 1600, { fit: 'inside' }).jpeg({ quality: 85 }).toBuffer();
  }
  const client = new bda.v20200324.Client({
    credential: {
      secretId: process.env.TENCENT_SECRET_ID,
      secretKey: process.env.TENCENT_SECRET_KEY,
    },
    region: 'ap-guangzhou',
    profile: { httpProfile: { endpoint: 'bda.tencentcloudapi.com', reqTimeout: 15 } },
  });
  const r = await client.SegmentPortraitPic({
    Image: input.toString('base64'), // 参数名=Image（bda 2020-03-24），探针实证
    RspImgType: 'base64',
  });
  if (r.HasForeground === false) {
    const e = new Error('no person detected');
    e.noPerson = true;
    throw e;
  }
  if (!r.ResultImage) throw new Error('empty result');
  // 文件名纯程序生成（时间戳+随机），无用户输入成分；输出路径校验边界
  const outName = `cut_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.png`;
  const outPath = path.resolve(cutoutDir, outName);
  if (!outPath.startsWith(cutoutDir + path.sep)) throw new Error('bad out path');
  fs.writeFileSync(outPath, Buffer.from(r.ResultImage, 'base64'));
  return `/uploads/wardrobe/cutout/${outName}`;
}

// 衣服抠图（M2-S0）：数据万象 CI。探针实证要点：
// - 该账号走 {bucket}.pic.{region} 域名（{bucket}.ci.{region} 新域名 404 InvalidUrl）
// - 无主体不报错：GoodsMatting 返回 200 全透明 PNG（alphaMax=0）→ 以 alpha 判空，
//   HTTP 状态映射不可靠（404=域名/签名/配置故障）；422 只认 AIPicMatting 自己确认全透明
// - 白底单品 1.6-1.7s / 4000×6000 大图 4.4s；输出 PNG 可达 16MB → 落盘前必须压缩
const CI_MATTING_BUCKET = 'lovegirl-ci-1496866501'; // 私有桶（tmp/ 前缀 1 天生命周期）
const CI_MATTING_REGION = 'ap-guangzhou';           // 与桶绑成一组常量，勿单改其一

// CI 处理 GET：COS 签名（Key 不含 query）+ pic 域名；单次尝试 7s（两次最坏 14s < App 15s
// 接收超时）；timeout/aborted 必 reject，保证单飞链 promise 永不挂死
function ciMattingGet(cos, key, proc) {
  const https = require('https');
  const host = `${CI_MATTING_BUCKET}.pic.${CI_MATTING_REGION}.myqcloud.com`;
  return new Promise((resolve, reject) => {
    const auth = cos.getAuth({ Method: 'get', Key: key, Expires: 900 });
    const req = https.request(
      { host, path: `/${key}?ci-process=${proc}`, method: 'GET', headers: { Authorization: auth, Host: host } },
      (res) => {
        const chunks = [];
        let total = 0;
        let done = false;
        res.on('data', (c) => {
          total += c.length;
          if (total > 40 * 1024 * 1024) { done = true; req.destroy(); reject(new Error('ci response > 40MB')); return; }
          chunks.push(c);
        });
        res.on('end', () => { if (!done) { done = true; resolve({ status: res.statusCode, type: res.headers['content-type'] || '', buf: Buffer.concat(chunks) }); } });
        res.on('aborted', () => { if (!done) { done = true; reject(new Error('ci response aborted')); } });
      }
    );
    req.setTimeout(7000, () => req.destroy(new Error('ci timeout 7s')));
    req.on('error', (e) => { if (!done) { done = true; reject(e); } });
    req.end();
  });
}

// 衣服抠图：原图规整 → 传私有桶 → GoodsMatting（空主体兜底 AIPicMatting）→ 压缩落盘
async function runItemCutout(absPath) {
  const COS = require('cos-nodejs-sdk-v5');
  const cos = new COS({
    SecretId: process.env.TENCENT_SECRET_ID,
    SecretKey: process.env.TENCENT_SECRET_KEY,
  });
  // 无条件缩 1600（低细节大图 JPEG 可 <5MB 穿透体积阈值，全尺寸送 CI 换回 16MB PNG + 解码尖峰）
  const input = await sharp(absPath).rotate().resize(1600, 1600, { fit: 'inside' }).jpeg({ quality: 85 }).toBuffer();
  const tmpKey = `tmp/${new Date().toISOString().slice(0, 10)}/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.jpg`;
  await new Promise((resolve, reject) => {
    cos.putObject({ Bucket: CI_MATTING_BUCKET, Region: CI_MATTING_REGION, Key: tmpKey, Body: input, ContentType: 'image/jpeg' }, (e) => e ? reject(new Error('cos put: ' + (e.code || e.message))) : resolve());
  });
  const fails = [];
  let aipicConfirmedEmpty = false;
  try {
    for (const proc of ['GoodsMatting', 'AIPicMatting']) {
      let r;
      try {
        r = await ciMattingGet(cos, tmpKey, proc);
      } catch (e) {
        fails.push(`${proc}:${String(e.message).slice(0, 80)}`);
        continue;
      }
      if (r.status !== 200 || !/^image\//.test(r.type)) {
        fails.push(`${proc}:http${r.status}:${r.buf.toString('utf8').slice(0, 100).replace(/\s+/g, ' ')}`);
        continue;
      }
      const st = await sharp(r.buf).stats();
      const alphaMax = st.channels.length > 3 ? st.channels[3].max : 255;
      if (alphaMax === 0) {
        // 全透明 = 无主体（GoodsMatting 无商品的标准形态；AIPicMatting 确认才是真没有）
        fails.push(`${proc}:empty-subject`);
        if (proc === 'AIPicMatting') aipicConfirmedEmpty = true;
        continue;
      }
      const outName = `cut_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.png`;
      const outPath = path.resolve(cutoutDir, outName);
      if (!outPath.startsWith(cutoutDir + path.sep)) throw new Error('bad out path');
      const out = await sharp(r.buf).resize(1200, 1200, { fit: 'inside', withoutEnlargement: true }).png({ compressionLevel: 9 }).toBuffer();
      fs.writeFileSync(outPath, out);
      return `/uploads/wardrobe/cutout/${outName}`;
    }
  } finally {
    // 临时对象 best-effort 删除（DeleteObject 幂等；生命周期 tmp/ 1 天兜底）
    cos.deleteObject({ Bucket: CI_MATTING_BUCKET, Region: CI_MATTING_REGION, Key: tmpKey }, (e) => { if (e) console.error('[Wardrobe] ci tmp del failed:', e.code || e.message); });
  }
  const err = new Error('ci matting failed: ' + fails.join(' | '));
  if (aipicConfirmedEmpty) err.noPerson = true; // 422；基础设施故障不带此标记 → 502
  throw err;
}

router.get('/bg-status', authRequired, (req, res) => {
  res.json({
    code: 200,
    data: {
      enabled: cutoutEnabled(),
      person: cutoutEnabled(),
      object: cutoutEnabled(), // M2-S0：数据万象 GoodsMatting+AIPicMatting 已接通
    },
  });
});

router.post('/bg-remove', authRequired, wrapUpload('image'), (req, res) => {
  if (!cutoutEnabled()) {
    return res.status(503).json({ code: 503, message: '抠图服务未开启' });
  }
  const kind = cleanText(req.body.kind, 10) === 'person' ? 'person' : 'object';
  // 两种输入：multipart image（新文件）或 avatarId/itemId（服务器已有原图，免 App 中转）
  const avatarId = parseInt(req.body.avatarId);
  const itemId = parseInt(req.body.itemId);
  let sourcePath = null;
  if (req.file) {
    sourcePath = req.file.path;
  } else if (Number.isInteger(avatarId) && kind === 'person') {
    // 文件名取自 DB 记录，非用户输入
  } else if (Number.isInteger(itemId) && kind === 'object') {
    // 同上
  } else {
    return res.status(400).json({ code: 400, message: '缺少图片' });
  }
  if (cutoutQuotaLeft(req.user.id) <= 0) {
    return res.status(429).json({ code: 429, message: '今天抠图次数用完了，明天再来吧' });
  }
  // 入队串行执行；闭包持有本次请求上下文与响应
  const theFile = req.file;
  cutoutChain = cutoutChain.then(async () => {
    let absPath = theFile ? theFile.path : null;
    let cutoutUrl = null;
    if (!absPath) {
      const table = kind === 'person' ? 'wardrobe_avatars' : 'wardrobe_items';
      const [rows] = await pool.query(
        `SELECT image_url FROM ${table} WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
        [kind === 'person' ? avatarId : itemId, req.user.id]
      );
      if (rows.length === 0) {
        return res.status(404).json({ code: 404, message: '记录不存在' });
      }
      // join（非 resolve）：image_url 以 / 开头，resolve 会丢弃前缀越出容器
      absPath = path.join(__dirname, '..', rows[0].image_url);
      // 边界校验：只允许 uploads 目录内的文件
      const upDir = path.resolve(__dirname, '..', 'uploads');
      if (!absPath.startsWith(upDir + path.sep)) {
        return res.status(400).json({ code: 400, message: '图片路径不对' });
      }
      if (!fs.existsSync(absPath)) {
        return res.status(404).json({ code: 404, message: '原图文件已不存在，请重新上传' });
      }
    }
    const t0 = Date.now();
    cutoutUrl = kind === 'person' ? await runPortraitCutout(absPath) : await runItemCutout(absPath);
    cutoutConsume(req.user.id);
    // 直取模式自动回写（App 的 cutoutItem 不调 PUT cutout，必须在这里落库）
    if (!theFile && Number.isInteger(avatarId) && kind === 'person') {
      await pool.query(
        'UPDATE wardrobe_avatars SET cutout_url = ? WHERE id = ? AND user_id = ?',
        [cutoutUrl, avatarId, req.user.id]
      );
    }
    if (!theFile && Number.isInteger(itemId) && kind === 'object') {
      await pool.query(
        'UPDATE wardrobe_items SET cutout_url = ?, bg_removed = 1 WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
        [cutoutUrl, itemId, req.user.id]
      );
    }
    console.log(`[Wardrobe] cutout ok ${Date.now() - t0}ms user=${req.user.id}`);
    res.json({ code: 200, data: { cutoutUrl } });
  }).catch((err) => {
    console.error('[Wardrobe] cutout failed:', err.code || '', String(err.message || err).slice(0, 120));
    if (!res.headersSent) {
      if (err.noPerson) {
        res.status(422).json({ code: 422, message: kind === 'person' ? '照片里没找到人，换一张试试吧' : '照片里没找到可抠的主体，换一张试试' });
      } else {
        res.status(502).json({ code: 502, message: '抠图失败了，稍后重试一次' });
      }
    }
  });
});

// ---------- 形象（M2a P12） ----------
router.get('/avatars', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, image_url, thumbnail_url, cutout_url, is_default, created_at FROM wardrobe_avatars WHERE user_id = ? AND deleted_at IS NULL ORDER BY is_default DESC, created_at DESC, id DESC',
      [req.user.id]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Wardrobe] avatars list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/avatars', authRequired, wrapUpload('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ code: 400, message: '先上传一张全身照吧' });
    const imageUrl = `/uploads/wardrobe/${req.file.filename}`;
    let thumbnailUrl = null;
    try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }
    const [result] = await pool.query(
      'INSERT INTO wardrobe_avatars (user_id, image_url, thumbnail_url) VALUES (?, ?, ?)',
      [req.user.id, imageUrl, thumbnailUrl]
    );
    res.json({ code: 200, message: '形象已保存', data: { id: result.insertId, imageUrl, thumbnailUrl } });
  } catch (err) {
    console.error('[Wardrobe] avatar create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.patch('/avatars/:id/default', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '参数不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT id FROM wardrobe_avatars WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '形象不存在' });
    }
    await conn.query('UPDATE wardrobe_avatars SET is_default = 0 WHERE user_id = ? AND is_default = 1', [req.user.id]);
    await conn.query('UPDATE wardrobe_avatars SET is_default = 1 WHERE id = ? AND user_id = ?', [id, req.user.id]);
    await conn.commit();
    conn.release();
    res.json({ code: 200, message: '已设为默认形象' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] avatar default failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.delete('/avatars/:id', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '参数不对' });
    }
    await conn.beginTransaction();
    const [rows] = await conn.query(
      'SELECT image_url, thumbnail_url, cutout_url FROM wardrobe_avatars WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '形象不存在' });
    }
    await conn.query(
      'UPDATE wardrobe_avatars SET deleted_at = NOW(), is_default = 0 WHERE id = ? AND user_id = ?',
      [id, req.user.id]
    );
    await conn.commit();
    conn.release();
    removeFilesQuiet([rows[0].image_url, rows[0].thumbnail_url, rows[0].cutout_url]);
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Wardrobe] avatar delete failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/avatars/:id/cutout', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const cutoutUrl = cleanText(req.body.cutoutUrl, 500);
    if (!Number.isInteger(id) || !cutoutUrl) return res.status(400).json({ code: 400, message: '参数不对' });
    const [r] = await pool.query(
      'UPDATE wardrobe_avatars SET cutout_url = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [cutoutUrl, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '形象不存在' });
    res.json({ code: 200, message: '抠图已保存' });
  } catch (err) {
    console.error('[Wardrobe] avatar cutout failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ---------- 单品抠图回写（M2a） ----------
router.put('/items/:id/cutout', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const cutoutUrl = cleanText(req.body.cutoutUrl, 500);
    const layoutRaw = typeof req.body.itemLayout === 'string' ? req.body.itemLayout : '';
    let layout = null;
    if (layoutRaw) {
      try { layout = JSON.stringify(JSON.parse(layoutRaw)); } catch { layout = null; }
    }
    if (!Number.isInteger(id)) return res.status(400).json({ code: 400, message: '参数不对' });
    const [r] = await pool.query(
      'UPDATE wardrobe_items SET cutout_url = ?, bg_removed = 1, item_layout = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [cutoutUrl || null, layout, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '单品不存在' });
    res.json({ code: 200, message: '抠图已保存' });
  } catch (err) {
    console.error('[Wardrobe] item cutout failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 位置记忆（W1 白板）：item_layout = {avatarId: {nx, ny, scale}}，客户端合并后整体保存。
// 纯 JSON 不套 wrapUpload；8KB+键数 64 双闸；nx/ny/scale 必须 finite
router.put('/items/:id/layout', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ code: 400, message: '参数不对' });
    const layoutRaw = req.body.layout;
    if (typeof layoutRaw !== 'string' || layoutRaw.length > 8192) {
      return res.status(400).json({ code: 400, message: '布局数据不对' });
    }
    let parsed;
    try { parsed = JSON.parse(layoutRaw); } catch (_) { return res.status(400).json({ code: 400, message: '布局数据不对' }); }
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return res.status(400).json({ code: 400, message: '布局数据不对' });
    }
    const keys = Object.keys(parsed);
    if (keys.length > 64) return res.status(400).json({ code: 400, message: '布局数据不对' });
    for (const k of keys) {
      const v = parsed[k];
      if (!v || typeof v !== 'object') return res.status(400).json({ code: 400, message: '布局数据不对' });
      if (!Number.isFinite(Number(v.nx)) || !Number.isFinite(Number(v.ny)) || !Number.isFinite(Number(v.scale))) {
        return res.status(400).json({ code: 400, message: '布局数据不对' });
      }
    }
    const [r] = await pool.query(
      'UPDATE wardrobe_items SET item_layout = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [layoutRaw, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '单品不存在' });
    res.json({ code: 200, message: '已记住位置' });
  } catch (err) {
    console.error('[Wardrobe] item layout failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
