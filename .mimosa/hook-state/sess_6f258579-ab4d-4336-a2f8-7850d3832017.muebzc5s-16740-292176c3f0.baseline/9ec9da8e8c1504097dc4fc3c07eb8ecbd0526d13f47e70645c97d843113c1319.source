/**
 * 情侣厨房（Kitchen）— v3.20 投喂站重构
 * 菜单是"我会为你做的事"：双方挂自家菜单，对方以外卖交互下单，
 * 厨师接单→买菜做菜→拍成品照完成，完成 +5 爱心豆，订单沉淀为投喂记录。
 * 依赖表：kitchen_dishes / kitchen_orders（见 server_fixes/kitchen_tables.sql）
 * 复用：couples（绑定关系）、users.bean_balance + bean_transactions（爱心豆）、
 *       notifications（站内通知）、/uploads 静态目录（成品照/菜品照）
 */
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { addBeanTransaction } = require('./utils/lovegirl_rewards');

const KITCHEN_BEAN_REWARD = 5;

// ---------- 图片上传（菜品照 / 成品照） ----------
const uploadDir = path.join(__dirname, '..', 'uploads', 'kitchen');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = (path.extname(file.originalname) || '.jpg').toLowerCase();
    cb(null, `${Date.now()}_${crypto.randomBytes(4).toString('hex')}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (/^image\//.test(file.mimetype)) return cb(null, true);
    cb(new Error('only image allowed'));
  },
});

router.post('/upload', authRequired, (req, res) => {
  upload.single('photo')(req, res, (err) => {
    if (err) return res.status(400).json({ code: 400, message: '图片上传失败：' + err.message });
    if (!req.file) return res.status(400).json({ code: 400, message: '缺少图片文件' });
    res.json({ code: 200, data: { url: `/uploads/kitchen/${req.file.filename}` } });
  });
});

// ---------- 工具 ----------
async function getPartnerId(userId) {
  const [rows] = await pool.query(
    "SELECT user1_id, user2_id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'",
    [userId, userId]
  );
  if (!rows.length) return null;
  return rows[0].user1_id === userId ? rows[0].user2_id : rows[0].user1_id;
}

function parseItems(raw) {
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    try { return JSON.parse(raw); } catch (_) { return []; }
  }
  return [];
}

async function loadDish(dishId) {
  const [rows] = await pool.query('SELECT * FROM kitchen_dishes WHERE id = ? AND is_active = 1', [dishId]);
  return rows[0] || null;
}

function dishToJson(r) {
  return {
    id: r.id, user_id: r.user_id, name: r.name, category: r.category || '家常菜',
    emoji: r.emoji || '🍳', photo_url: r.photo_url || null, price: r.price || 0,
    description: r.description || null, is_active: !!r.is_active,
  };
}

async function notify(userId, type, title, content, payload) {
  try {
    await pool.query(
      'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
      [userId, type, title, content, JSON.stringify(payload || {})]
    );
  } catch (err) {
    console.error('[Kitchen] notify failed:', err.message);
  }
}

// ---------- 菜单 ----------
router.get('/menu', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const partnerId = await getPartnerId(userId);
    const [mineRows] = await pool.query(
      'SELECT * FROM kitchen_dishes WHERE user_id = ? AND is_active = 1 ORDER BY sort_order ASC, id DESC', [userId]
    );
    let partnerRows = [];
    let partnerInfo = null;
    if (partnerId != null) {
      [partnerRows] = await pool.query(
        'SELECT * FROM kitchen_dishes WHERE user_id = ? AND is_active = 1 ORDER BY sort_order ASC, id DESC', [partnerId]
      );
      const [uRows] = await pool.query('SELECT id, nickname, avatar_url FROM users WHERE id = ?', [partnerId]);
      partnerInfo = uRows[0] ? { id: uRows[0].id, nickname: uRows[0].nickname, avatar: uRows[0].avatar_url } : null;
    }
    res.json({
      code: 200,
      data: {
        bound: partnerId != null,
        partner: partnerInfo,
        mine: mineRows.map(dishToJson),
        partner_dishes: partnerRows.map(dishToJson),
      },
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { bound: false, partner: null, mine: [], partner_dishes: [] } });
    }
    console.error('[Kitchen] menu failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/dishes', authRequired, async (req, res) => {
  try {
    const { name, category, emoji, price, description, photo_url, sort_order } = req.body || {};
    if (!name || !String(name).trim()) return res.status(400).json({ code: 400, message: '菜名不能为空' });
    const [result] = await pool.query(
      `INSERT INTO kitchen_dishes (user_id, name, category, emoji, photo_url, price, description, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, String(name).trim().slice(0, 100),
       String(category || '家常菜').slice(0, 30),
       String(emoji || '🍳').slice(0, 16),
       photo_url ? String(photo_url).slice(0, 500) : null,
       Number.isFinite(Number(price)) ? Math.max(0, Math.round(Number(price))) : 0,
       description ? String(description).slice(0, 300) : null,
       Number.isFinite(Number(sort_order)) ? Number(sort_order) : 0]
    );
    const dish = await loadDish(result.insertId);
    res.json({ code: 200, data: dish ? dishToJson(dish) : null });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.status(500).json({ code: 500, message: '厨房表未初始化' });
    console.error('[Kitchen] create dish failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/dishes/:id', authRequired, async (req, res) => {
  try {
    const dish = await loadDish(Number(req.params.id));
    if (!dish) return res.status(404).json({ code: 404, message: '菜品不存在' });
    if (dish.user_id !== req.user.id) return res.status(403).json({ code: 403, message: '只能编辑自己的菜品' });
    const b = req.body || {};
    await pool.query(
      `UPDATE kitchen_dishes SET name = ?, category = ?, emoji = ?, photo_url = ?, price = ?, description = ?
       WHERE id = ?`,
      [String(b.name ?? dish.name).trim().slice(0, 100),
       String(b.category ?? dish.category).slice(0, 30),
       String(b.emoji ?? dish.emoji).slice(0, 16),
       b.photo_url !== undefined ? (b.photo_url ? String(b.photo_url).slice(0, 500) : null) : dish.photo_url,
       Number.isFinite(Number(b.price)) ? Math.max(0, Math.round(Number(b.price))) : dish.price,
       b.description !== undefined ? (b.description ? String(b.description).slice(0, 300) : null) : dish.description,
       dish.id]
    );
    const updated = await loadDish(dish.id);
    res.json({ code: 200, data: updated ? dishToJson(updated) : null });
  } catch (err) {
    console.error('[Kitchen] update dish failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.delete('/dishes/:id', authRequired, async (req, res) => {
  try {
    const dish = await loadDish(Number(req.params.id));
    if (!dish) return res.status(404).json({ code: 404, message: '菜品不存在' });
    if (dish.user_id !== req.user.id) return res.status(403).json({ code: 403, message: '只能删除自己的菜品' });
    // 软删除：历史订单里存的是快照，不受影响
    await pool.query('UPDATE kitchen_dishes SET is_active = 0 WHERE id = ?', [dish.id]);
    res.json({ code: 200, message: '菜品已下架' });
  } catch (err) {
    console.error('[Kitchen] delete dish failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ---------- 订单 ----------
router.get('/orders', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      `SELECT * FROM kitchen_orders WHERE cook_id = ? OR orderer_id = ? ORDER BY id DESC LIMIT 100`,
      [userId, userId]
    );
    const incoming = [];
    const outgoing = [];
    for (const r of rows) {
      const o = {
        id: r.id, orderer_id: r.orderer_id, cook_id: r.cook_id,
        items: parseItems(r.items), total_price: r.total_price || 0,
        note: r.note || null, status: r.status || 'placed',
        photo_url: r.photo_url || null, reply: r.reply || null,
        beans_awarded: !!r.beans_awarded,
        created_at: r.created_at, accepted_at: r.accepted_at, done_at: r.done_at,
      };
      if (r.cook_id === userId) incoming.push(o); else outgoing.push(o);
    }
    res.json({ code: 200, data: { incoming, outgoing } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json({ code: 200, data: { incoming: [], outgoing: [] } });
    console.error('[Kitchen] orders failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/orders', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const partnerId = await getPartnerId(userId);
    if (partnerId == null) return res.status(400).json({ code: 400, message: '还没绑定伴侣，先去绑定吧' });
    const rawItems = Array.isArray(req.body?.items) ? req.body.items : [];
    if (!rawItems.length) return res.status(400).json({ code: 400, message: '购物车是空的' });
    const items = [];
    for (const it of rawItems.slice(0, 20)) {
      const dish = await loadDish(Number(it.dish_id));
      if (!dish) return res.status(400).json({ code: 400, message: '有菜品刚被下架了，刷新一下菜单' });
      if (dish.user_id !== partnerId) return res.status(400).json({ code: 400, message: '只能下单对方的菜品' });
      const qty = Math.min(9, Math.max(1, Math.round(Number(it.quantity) || 1)));
      items.push({ dish_id: dish.id, name: dish.name, emoji: dish.emoji || '🍳', price: dish.price || 0, quantity: qty });
    }
    const total = items.reduce((s, it) => s + (it.price || 0) * it.quantity, 0);
    const note = req.body?.note ? String(req.body.note).slice(0, 300) : null;
    const [result] = await pool.query(
      `INSERT INTO kitchen_orders (orderer_id, cook_id, items, total_price, note, status) VALUES (?, ?, ?, ?, ?, 'placed')`,
      [userId, partnerId, JSON.stringify(items), total, note]
    );
    await notify(partnerId, 'kitchen_order', '收到新订单', 'TA 点了你的菜，去看看想吃什么吧', { order_id: result.insertId });
    res.json({ code: 200, data: { id: result.insertId, status: 'placed', items, total_price: total } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.status(500).json({ code: 500, message: '厨房表未初始化' });
    console.error('[Kitchen] create order failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/orders/:id/status', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const userId = req.user.id;
    const [rows] = await conn.query('SELECT * FROM kitchen_orders WHERE id = ?', [Number(req.params.id)]);
    if (!rows.length) { conn.release(); return res.status(404).json({ code: 404, message: '订单不存在' }); }
    const order = rows[0];
    const isCook = order.cook_id === userId;
    const isOrderer = order.orderer_id === userId;
    if (!isCook && !isOrderer) { conn.release(); return res.status(403).json({ code: 403, message: '这不是你的订单' }); }
    const target = String(req.body?.status || '');
    const now = new Date();
    let beans = 0;

    if (target === 'accepted') {
      if (!isCook || order.status !== 'placed') { conn.release(); return res.status(400).json({ code: 400, message: '当前状态不能接单' }); }
      await conn.query("UPDATE kitchen_orders SET status = 'accepted', accepted_at = ? WHERE id = ?", [now, order.id]);
      await notify(order.orderer_id, 'kitchen_order', '订单已被接下', 'TA 接单啦，准备为你下厨', { order_id: order.id });
    } else if (target === 'done') {
      if (!isCook || order.status !== 'accepted') { conn.release(); return res.status(400).json({ code: 400, message: '请先接单再做完成' }); }
      const photo = req.body?.photo_url ? String(req.body.photo_url).slice(0, 500) : null;
      if (!photo) { conn.release(); return res.status(400).json({ code: 400, message: '拍一张成品照才能完成这单' }); }
      await conn.beginTransaction();
      if (!order.beans_awarded) {
        const beanResult = await addBeanTransaction(conn, {
          userId, amount: KITCHEN_BEAN_REWARD, type: 'kitchen_order_done',
          title: '情侣厨房开火', sourceModule: 'kitchen',
          description: `完成订单 #${order.id}`,
        });
        if (beanResult) beans = KITCHEN_BEAN_REWARD;
        await conn.query('UPDATE kitchen_orders SET beans_awarded = 1 WHERE id = ?', [order.id]);
      }
      await conn.query(
        "UPDATE kitchen_orders SET status = 'done', photo_url = ?, done_at = ? WHERE id = ?",
        [photo, now, order.id]
      );
      await conn.commit();
      await notify(order.orderer_id, 'kitchen_order', '菜做好啦', 'TA 完成了你的订单，快去尝尝', { order_id: order.id });
    } else if (target === 'cancelled') {
      if (!isOrderer || !['placed', 'accepted'].includes(order.status)) {
        conn.release(); return res.status(400).json({ code: 400, message: '当前状态不能取消' });
      }
      const reason = req.body?.reason ? String(req.body.reason).slice(0, 255) : null;
      await conn.query("UPDATE kitchen_orders SET status = 'cancelled', cancel_reason = ? WHERE id = ?", [reason, order.id]);
      await notify(order.cook_id, 'kitchen_order', '订单取消了', reason ? `理由：${reason}` : 'TA 取消了订单', { order_id: order.id });
    } else {
      conn.release();
      return res.status(400).json({ code: 400, message: '不支持的状态' });
    }
    const [updated] = await conn.query('SELECT * FROM kitchen_orders WHERE id = ?', [order.id]);
    conn.release();
    const r = updated[0];
    res.json({
      code: 200,
      data: {
        id: r.id, status: r.status, items: parseItems(r.items), total_price: r.total_price,
        photo_url: r.photo_url, beans_awarded: !!r.beans_awarded,
        beans_earned: beans, created_at: r.created_at, done_at: r.done_at,
      },
    });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    conn.release();
    console.error('[Kitchen] update order status failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ---------- 汇总（红点 + 首页提示条） ----------
router.get('/summary', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const partnerId = await getPartnerId(userId);
    if (partnerId == null) return res.json({ code: 200, data: { bound: false, incoming_new: 0, outgoing_active: 0 } });
    const [inRows] = await pool.query(
      "SELECT COUNT(*) AS c FROM kitchen_orders WHERE cook_id = ? AND status = 'placed'", [userId]
    );
    const [outRows] = await pool.query(
      "SELECT COUNT(*) AS c FROM kitchen_orders WHERE orderer_id = ? AND status IN ('placed','accepted')", [userId]
    );
    res.json({
      code: 200,
      data: { bound: true, incoming_new: inRows[0].c || 0, outgoing_active: outRows[0].c || 0 },
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json({ code: 200, data: { bound: false, incoming_new: 0, outgoing_active: 0 } });
    console.error('[Kitchen] summary failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
