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
              brand, price, status, wear_count, created_at
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
              i.color, i.brand, i.price, i.status, i.wear_count, i.created_at,
              (SELECT COUNT(*) FROM wardrobe_outfits o
                WHERE o.user_id = i.user_id AND o.item_ids IS NOT NULL
                  AND JSON_CONTAINS(o.item_ids, CAST(i.id AS JSON))) AS outfit_refs_count
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
      'SELECT id, image_url, thumbnail_url FROM wardrobe_items WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
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
    if (req.file) {
      imageUrl = `/uploads/wardrobe/${req.file.filename}`;
      try { thumbnailUrl = await makeThumbnail(req.file.path); } catch (e) { console.error('[Wardrobe] thumb failed:', e.message); }
      oldUrls = [rows[0].image_url, rows[0].thumbnail_url];
    }

    await pool.query(
      `UPDATE wardrobe_items SET image_url = ?, thumbnail_url = ?, category = ?, temperature = ?,
              occasions = ?, styles = ?, color = ?, brand = ?, price = ? WHERE id = ? AND user_id = ?`,
      [imageUrl, thumbnailUrl, category, temperature,
       JSON.stringify(occasions), JSON.stringify(styles), color, brand, price, id, req.user.id]
    );
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
      'SELECT image_url, thumbnail_url FROM wardrobe_items WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE',
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
    removeFilesQuiet([rows[0].image_url, rows[0].thumbnail_url]); // 事务提交后清理文件
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
    if (!['实拍', '组合'].includes(source)) {
      conn.release();
      return res.status(400).json({ code: 400, message: '来源不对' });
    }
    const wornDate = cleanText(req.body.wornDate, 10);
    const today = bjToday();
    const maxDate = source === '组合' ? addDays(today, 90) : today;
    if (!isValidDate(wornDate) || wornDate < '2000-01-01' || wornDate > maxDate) {
      conn.release();
      return res.status(400).json({ code: 400, message: source === '组合' ? '日期要在 2000-01-01 ~ 今天+90 天内' : '实拍日期不能是未来' });
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
      if (!req.file) {
        conn.release();
        return res.status(400).json({ code: 400, message: '先拍一张今天的穿搭吧' });
      }
      photoUrl = `/uploads/wardrobe/${req.file.filename}`;
      itemIds = parseItemIds(req.body.itemIds, 0, 8);
      if (itemIds == null) {
        conn.release();
        return res.status(400).json({ code: 400, message: '关联单品不对' });
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
    const maxDate = row.source === '组合' ? addDays(bjToday(), 90) : bjToday();
    if (!isValidDate(wornDate) || wornDate < '2000-01-01' || wornDate > maxDate) {
      await conn.rollback();
      conn.release();
      return res.status(400).json({ code: 400, message: '日期越界了' });
    }
    const note = req.body.note === undefined ? row.note : (cleanText(req.body.note, 200) || null);

    let itemIds = oldItems;
    if (req.body.itemIds !== undefined) {
      const parsed = parseItemIds(req.body.itemIds, row.source === '组合' ? 2 : 0, 8);
      if (parsed == null) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({ code: 400, message: row.source === '组合' ? '搭配要 2-8 件单品' : '关联单品不对' });
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

// ---------- 抠图（S3，默认关） ----------
router.get('/bg-status', authRequired, (req, res) => {
  res.json({ code: 200, data: { enabled: process.env.WARDROBE_BG_ON === '1' } });
});

router.post('/bg-remove', authRequired, wrapUpload('image'), (req, res) => {
  // 开启前必须过 G2 三段闸（容器 musl 加载 / 样图 benchmark / 主接口 P95），见 M1 方案
  if (process.env.WARDROBE_BG_ON !== '1') {
    return res.status(503).json({ code: 503, message: '抠图服务未开启' });
  }
  return res.status(503).json({ code: 503, message: '抠图服务暂不可用' });
});

module.exports = router;
