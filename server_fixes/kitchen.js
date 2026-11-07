/**
 * 情侣厨房（Kitchen）— v3.20 投喂站重构
 * 菜单是"我会为你做的事"：双方挂自家菜单，对方以外卖交互下单，
 * 厨师接单→买菜做菜→开饭（可选成品照），订单沉淀为投喂记录。
 * 依赖表：kitchen_dishes / kitchen_orders（见 server_fixes/kitchen_tables.sql）
 * 复用：couples（绑定关系）、notifications（站内通知）、/uploads 静态目录（成品照/菜品照）
 */
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { todayString } = require('./utils/lovegirl_rewards');

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
async function getPartnerId(userId, db = pool) {
  const [rows] = await db.query(
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

async function loadDish(dishId, db = pool) {
  const [rows] = await db.query('SELECT * FROM kitchen_dishes WHERE id = ? AND is_active = 1', [dishId]);
  return rows[0] || null;
}

function dishToJson(r) {
  return {
    id: r.id, user_id: r.user_id, name: r.name, category: r.category || '家常菜',
    emoji: r.emoji || '🍳', photo_url: r.photo_url || null, price: r.price || 0,
    description: r.description || null, is_active: !!r.is_active,
    ingredients: r.ingredients || null, recipe: r.recipe || null,
  };
}

function failure(status, message) { return Object.assign(new Error(message), { status }); }

function text(value, max, label) {
  if (value == null) return null;
  if (typeof value !== 'string' || value.trim().length > max) throw failure(400, `${label}格式不正确或过长`);
  return value.trim() || null;
}

function mealPayload(body, cookId, partnerId) {
  if (!Array.isArray(body.items) || !body.items.length) throw failure(400, '购物车是空的');
  if (body.items.length > 20) throw failure(400, '一餐最多选择20道菜，请分餐安排');
  const seen = new Set();
  const items = body.items.map(item => {
    const id = Number(item?.dish_id), quantity = Number(item?.quantity ?? 1);
    if (!Number.isSafeInteger(id) || id <= 0 || seen.has(id) || !Number.isInteger(quantity) || quantity < 1 || quantity > 9) {
      throw failure(400, '菜品或数量不正确，每道菜可选1至9份');
    }
    seen.add(id); return { dish_id: id, quantity };
  });
  const date = body.meal_date || null;
  if (date && (typeof date !== 'string' || !/^20\d{2}-\d{2}-\d{2}$/.test(date) ||
      Number.isNaN(Date.parse(date + 'T00:00:00Z')) || new Date(date + 'T00:00:00Z').toISOString().slice(0, 10) !== date)) {
    throw failure(400, '用餐日期不正确');
  }
  const slot = body.meal_slot || null;
  if (slot && !['breakfast', 'lunch', 'dinner', 'snack'].includes(slot)) throw failure(400, '用餐时段不正确');
  if (!Number.isSafeInteger(cookId) || cookId <= 0) throw failure(400, '请选择这一餐的主厨');
  const note = text(body.note, 300, '口味备注');
  const hash = crypto.createHash('sha256').update(JSON.stringify({
    items: [...items].sort((a, b) => a.dish_id - b.dish_id), cookId, partnerId, note, date, slot,
  })).digest('hex');
  return { items, cookId, partnerId, note, date, slot, hash };
}

async function snapshotItems(db, payload, previous = null) {
  const items = [];
  const original = new Map(previous?.cook_id === payload.cookId
    ? parseItems(previous.items).map(item => [item.dish_id, item]) : []);
  for (const item of payload.items) {
    const old = original.get(item.dish_id);
    if (old && old.quantity === item.quantity) { items.push(old); continue; }
    const dish = await loadDish(item.dish_id, db);
    if (!dish) throw failure(400, '有菜品刚被下架了，请刷新菜单');
    if (dish.user_id !== payload.cookId) throw failure(400, '所选菜品不属于这一餐的主厨');
    items.push(old ? { ...old, quantity: item.quantity } : { dish_id: dish.id, name: dish.name, emoji: dish.emoji || '🍳',
      price: Number(dish.price || 0), quantity: item.quantity, photo_url: dish.photo_url || null,
      ingredients: dish.ingredients || null, recipe: dish.recipe || null });
  }
  return items;
}

function participants(order) { return [...new Set([order.orderer_id, order.partner_id || order.cook_id])]; }
function requireParticipant(order, userId) {
  if (!participants(order).includes(userId)) throw failure(403, '这不是你的餐次');
}
async function requireActivePair(db, order, userId) {
  const other = participants(order).find(id => id !== userId);
  if (!other || await getPartnerId(userId, db) !== other) throw failure(409, '绑定关系已变化，请刷新厨房核对餐次');
}
function requireRevision(order, value, required = false) {
  if (value == null && !required) return;
  if (!Number.isSafeInteger(value) || value <= 0) throw failure(400, '请携带餐次版本后重试');
  if (value !== Number(order.revision || 1)) throw failure(409, '这一餐已被更新，请刷新后再操作');
}
function orderToJson(row, full = true) {
  const items = parseItems(row.items).map(item => full ? item : {
    dish_id: item.dish_id, name: item.name, emoji: item.emoji, price: item.price,
    quantity: item.quantity, photo_url: item.photo_url || null,
  });
  return { id: row.id, orderer_id: row.orderer_id, partner_id: row.partner_id || null, cook_id: row.cook_id,
    items, total_price: Number(row.total_price || 0), note: row.note || null, status: row.status || 'placed',
    photo_url: row.photo_url || null, reply: row.reply || null, beans_awarded: !!row.beans_awarded,
    beans_earned: 0, revision: Number(row.revision || 1), meal_date: row.meal_date ? String(row.meal_date).slice(0, 10) : null,
    meal_slot: row.meal_slot || null, cooking_log_id: row.cooking_log_id || null,
    created_at: row.created_at, accepted_at: row.accepted_at, done_at: row.done_at };
}
async function orderWithLog(db, id) {
  const [rows] = await db.query(
    'SELECT o.*, c.id AS cooking_log_id FROM kitchen_orders o LEFT JOIN cooking_logs c ON c.kitchen_order_id = o.id WHERE o.id = ?', [id]);
  return rows[0] || null;
}
async function transaction(run) {
  let conn;
  try { conn = await pool.getConnection(); await conn.beginTransaction(); const result = await run(conn); await conn.commit(); return result; }
  catch (error) { if (conn) { try { await conn.rollback(); } catch (_) {} } throw error; }
  finally { if (conn) conn.release(); }
}
function respondError(res, error) {
  if (!error.status) console.error('[Kitchen] request failed:', error.code || error.message);
  res.status(error.status || 500).json({ code: error.status || 500, message: error.status ? error.message : '服务器错误，请稍后重试' });
}

async function createMealMemory(db, order, photo, date) {
  const items = parseItems(order.items);
  const title = items.map(item => item.name).join('、').slice(0, 100) || '一起开饭';
  const recipes = items.filter(item => item.recipe).map(item => `【${item.name}】\n${item.recipe}`).join('\n\n');
  const recipe = recipes.length <= 3000 ? recipes || null : null;
  const story = order.note || null;
  const [saved] = await db.query(
    `INSERT INTO cooking_logs (chef_id, title, emoji, photo_url, recipe, story, is_new, cooked_at, dish_id, kitchen_order_id)
     VALUES (?, ?, ?, ?, ?, ?, 0, ?, NULL, ?)`,
    [order.cook_id, title, '🍳', photo, recipe, story, date, order.id]);
  for (const userId of participants(order)) {
    await db.query(
      `INSERT INTO love_timeline (user_id, title, description, event_date, image_url, icon, source_module, source_id)
       VALUES (?, ?, ?, ?, ?, 'restaurant', 'cooking', ?)`,
      [userId, `一起开饭：${title}`, order.note || '', date, photo, saved.insertId]);
  }
  return saved.insertId;
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
    const dishName = text(name, 100, '菜名');
    if (!dishName) throw failure(400, '菜名不能为空');
    const ingredients = text(req.body.ingredients, 2000, '食材');
    const recipe = text(req.body.recipe, 3000, '做法');
    const [result] = await pool.query(
      `INSERT INTO kitchen_dishes (user_id, name, category, emoji, photo_url, price, description, sort_order, ingredients, recipe)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, dishName,
       String(category || '家常菜').slice(0, 30),
       String(emoji || '🍳').slice(0, 16),
       photo_url ? String(photo_url).slice(0, 500) : null,
       Number.isFinite(Number(price)) ? Math.max(0, Math.round(Number(price))) : 0,
       description ? String(description).slice(0, 300) : null,
       Number.isFinite(Number(sort_order)) ? Number(sort_order) : 0, ingredients, recipe]
    );
    const dish = await loadDish(result.insertId);
    res.json({ code: 200, data: dish ? dishToJson(dish) : null });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.status(500).json({ code: 500, message: '厨房表未初始化' });
    respondError(res, err);
  }
});

router.put('/dishes/:id', authRequired, async (req, res) => {
  try {
    const dish = await loadDish(Number(req.params.id));
    if (!dish) return res.status(404).json({ code: 404, message: '菜品不存在' });
    if (dish.user_id !== req.user.id) return res.status(403).json({ code: 403, message: '只能编辑自己的菜品' });
    const b = req.body || {};
    const dishName = text(b.name === undefined ? dish.name : b.name, 100, '菜名');
    if (!dishName) throw failure(400, '菜名不能为空');
    const ingredients = b.ingredients === undefined ? dish.ingredients : text(b.ingredients, 2000, '食材');
    const recipe = b.recipe === undefined ? dish.recipe : text(b.recipe, 3000, '做法');
    await pool.query(
      `UPDATE kitchen_dishes SET name = ?, category = ?, emoji = ?, photo_url = ?, price = ?, description = ?, ingredients = ?, recipe = ?
       WHERE id = ?`,
      [dishName,
       String(b.category ?? dish.category).slice(0, 30),
       String(b.emoji ?? dish.emoji).slice(0, 16),
       b.photo_url !== undefined ? (b.photo_url ? String(b.photo_url).slice(0, 500) : null) : dish.photo_url,
       Number.isFinite(Number(b.price)) ? Math.max(0, Math.round(Number(b.price))) : dish.price,
       b.description !== undefined ? (b.description ? String(b.description).slice(0, 300) : null) : dish.description,
       ingredients || null, recipe || null, dish.id]
    );
    const updated = await loadDish(dish.id);
    res.json({ code: 200, data: updated ? dishToJson(updated) : null });
  } catch (err) {
    respondError(res, err);
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

// ---------- 餐次 ----------
function requestedOrderId(req) {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) throw failure(400, '餐次编号不正确');
  return id;
}
async function replayOrder(db, userId, key, hash) {
  if (!key) return null;
  const [rows] = await db.query(
    'SELECT id, request_hash FROM kitchen_orders WHERE orderer_id = ? AND request_key = ?', [userId, key]);
  if (!rows.length) return null;
  if (rows[0].request_hash !== hash) throw failure(409, '提交内容已改变，请重新确认这一餐');
  return orderWithLog(db, rows[0].id);
}

router.get('/orders', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      `SELECT o.*, c.id AS cooking_log_id FROM kitchen_orders o
       LEFT JOIN cooking_logs c ON c.kitchen_order_id = o.id
       WHERE o.cook_id = ? OR o.orderer_id = ? OR o.partner_id = ? ORDER BY o.id DESC LIMIT 100`,
      [userId, userId, userId]);
    const incoming = [], outgoing = [];
    for (const row of rows) {
      (row.cook_id === userId ? incoming : outgoing).push(orderToJson(row, false));
    }
    res.json({ code: 200, data: { incoming, outgoing } });
  } catch (error) { respondError(res, error); }
});

router.get('/orders/:id', authRequired, async (req, res) => {
  try {
    const order = await orderWithLog(pool, requestedOrderId(req));
    if (!order) throw failure(404, '餐次不存在');
    requireParticipant(order, req.user.id);
    res.json({ code: 200, data: orderToJson(order) });
  } catch (error) { respondError(res, error); }
});

router.post('/orders', authRequired, async (req, res) => {
  let key, payload;
  try {
    const body = req.body || {};
    key = body.request_key == null ? null : text(body.request_key, 64, '提交标识');
    if (body.request_key != null && (!key || !/^[A-Za-z0-9_-]{8,64}$/.test(key))) throw failure(400, '提交标识不正确');
    const result = await transaction(async conn => {
      const userId = req.user.id;
      const partnerId = await getPartnerId(userId, conn);
      const intendedPartner = body.partner_id == null ? partnerId : Number(body.partner_id);
      const cookId = body.cook_id == null ? partnerId : Number(body.cook_id);
      payload = mealPayload(body, cookId, intendedPartner);
      const replay = await replayOrder(conn, userId, key, payload.hash);
      if (replay) return { order: replay };
      if (!partnerId) throw failure(400, '还没绑定伴侣，先去绑定吧');
      if (intendedPartner !== partnerId) throw failure(409, '绑定关系已变化，请重新确认这一餐');
      if (![userId, partnerId].includes(cookId)) throw failure(403, '只能由你或当前伴侣掌勺');
      const items = await snapshotItems(conn, payload);
      const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
      const [saved] = await conn.query(
        `INSERT INTO kitchen_orders (orderer_id, partner_id, cook_id, items, total_price, note, meal_date, meal_slot, request_key, request_hash, status, revision)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'placed', 1)`,
        [userId, partnerId, cookId, JSON.stringify(items), total, payload.note, payload.date, payload.slot, key, key ? payload.hash : null]);
      return { order: await orderWithLog(conn, saved.insertId), partnerId };
    });
    if (result.partnerId) await notify(result.partnerId, 'kitchen_order', '这一餐安排好了',
      result.order.cook_id === req.user.id ? 'TA 来掌勺，看看这餐吃什么' : 'TA 点了你的菜，去确认一下吧', { order_id: result.order.id });
    res.json({ code: 200, data: orderToJson(result.order) });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY' && key && payload) {
      try {
        const replay = await replayOrder(pool, req.user.id, key, payload.hash);
        if (replay) return res.json({ code: 200, data: orderToJson(replay) });
      } catch (replayError) { error = replayError; }
    }
    respondError(res, error);
  }
});

router.put('/orders/:id', authRequired, async (req, res) => {
  try {
    const body = req.body || {};
    const result = await transaction(async conn => {
      const id = requestedOrderId(req);
      const [rows] = await conn.query('SELECT * FROM kitchen_orders WHERE id = ? FOR UPDATE', [id]);
      if (!rows.length) throw failure(404, '餐次不存在');
      const order = rows[0], userId = req.user.id;
      requireParticipant(order, userId);
      requireRevision(order, body.revision, true);
      if (!['placed', 'accepted'].includes(order.status)) throw failure(409, '这一餐已经结束，不能再调整');
      await requireActivePair(conn, order, userId);
      const cookId = body.cook_id == null ? order.cook_id : Number(body.cook_id);
      if (!participants(order).includes(cookId)) throw failure(403, '只能由这一餐的双方掌勺');
      const partnerId = order.partner_id || participants(order).find(uid => uid !== order.orderer_id);
      const payload = mealPayload({ note: order.note, meal_date: order.meal_date, meal_slot: order.meal_slot, ...body }, cookId, partnerId);
      const items = await snapshotItems(conn, payload, order);
      const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
      await conn.query(
        `UPDATE kitchen_orders SET partner_id = ?, cook_id = ?, items = ?, total_price = ?, note = ?, meal_date = ?, meal_slot = ?,
         status = 'placed', accepted_at = NULL, revision = revision + 1 WHERE id = ?`,
        [partnerId, cookId, JSON.stringify(items), total, payload.note, payload.date, payload.slot, id]);
      return { order: await orderWithLog(conn, id), other: participants(order).find(uid => uid !== userId) };
    });
    if (result.other) await notify(result.other, 'kitchen_order', '这一餐有了调整', '菜品或安排有变化，请主厨重新确认', { order_id: result.order.id });
    res.json({ code: 200, data: orderToJson(result.order) });
  } catch (error) { respondError(res, error); }
});

router.put('/orders/:id/status', authRequired, async (req, res) => {
  try {
    const result = await transaction(async conn => {
      const id = requestedOrderId(req);
      const [rows] = await conn.query('SELECT * FROM kitchen_orders WHERE id = ? FOR UPDATE', [id]);
      if (!rows.length) throw failure(404, '餐次不存在');
      const order = rows[0], userId = req.user.id;
      requireParticipant(order, userId);
      const isCook = order.cook_id === userId;
      const target = String(req.body?.status || '');
      if (target === 'done' && order.status === 'done' && isCook) return { order: await orderWithLog(conn, id) };
      requireRevision(order, req.body?.revision);
      if (req.body?.expected_status && req.body.expected_status !== order.status) throw failure(409, '这一餐已被更新，请刷新后再操作');
      if (target !== 'cancelled') await requireActivePair(conn, order, userId);
      const now = new Date();
      let title, content;
      if (target === 'accepted') {
        if (!isCook) throw failure(403, '只有主厨可以接单');
        if (order.status !== 'placed') throw failure(400, '当前状态不能接单');
        await conn.query("UPDATE kitchen_orders SET status = 'accepted', accepted_at = ?, revision = revision + 1 WHERE id = ?", [now, id]);
        title = '订单已被接下'; content = 'TA 接单啦，准备为你下厨';
      } else if (target === 'placed') {
        if (!isCook) throw failure(403, '只有主厨可以撤销接单');
        if (order.status !== 'accepted') throw failure(400, '当前状态不能撤销接单');
        await conn.query("UPDATE kitchen_orders SET status = 'placed', accepted_at = NULL, revision = revision + 1 WHERE id = ?", [id]);
        title = '接单已撤销'; content = '这一餐回到待确认状态，可以再商量一下';
      } else if (target === 'done') {
        if (!isCook) throw failure(403, '只有主厨可以完成这一餐');
        if (order.status !== 'accepted') throw failure(400, '请先接单再做完成');
        const photo = text(req.body?.photo_url, 500, '照片地址');
        await createMealMemory(conn, order, photo, todayString());
        await conn.query("UPDATE kitchen_orders SET status = 'done', photo_url = ?, done_at = ?, revision = revision + 1 WHERE id = ?", [photo, now, id]);
        title = '菜做好啦'; content = '这一餐完成了，快去尝尝';
      } else if (target === 'cancelled') {
        if (order.orderer_id !== userId || !['placed', 'accepted'].includes(order.status)) throw failure(400, '只有安排者可以取消未结束的餐次');
        const reason = text(req.body?.reason, 255, '取消原因');
        await conn.query("UPDATE kitchen_orders SET status = 'cancelled', cancel_reason = ?, revision = revision + 1 WHERE id = ?", [reason, id]);
        title = '订单取消了'; content = reason || 'TA 取消了这一餐';
      } else throw failure(400, '不支持的状态');
      return { order: await orderWithLog(conn, id), other: participants(order).find(uid => uid !== userId), title, content };
    });
    if (result.other) await notify(result.other, 'kitchen_order', result.title, result.content, { order_id: result.order.id });
    res.json({ code: 200, data: orderToJson(result.order) });
  } catch (error) { respondError(res, error); }
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
