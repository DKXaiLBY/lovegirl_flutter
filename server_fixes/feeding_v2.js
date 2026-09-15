const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  addBeanTransaction,
  createFinanceRecord,
  createTimelineEvent,
  checkAchievements,
  isUserInPeriod,
  todayString,
} = require('./utils/lovegirl_rewards');

function isAdmin(user) {
  return user?.isAdmin || user?.is_admin || user?.role === 'admin';
}

function defaultShops() {
  return [
    { id: 1, name: '暖胃小馆', icon: 'shop', description: '正餐和小吃', category: 'food', banner_color: '#E9856B', sort_order: 1 },
    { id: 2, name: '饮品站', icon: 'drink', description: '热饮和冷饮', category: 'drink', banner_color: '#6B9DE9', sort_order: 2 },
    { id: 3, name: '花礼角', icon: 'flower', description: '鲜花和小礼物', category: 'flower', banner_color: '#E96B9D', sort_order: 3 },
  ];
}

function defaultProducts(shopId) {
  const data = {
    1: [
      { id: 1001, shop_id: 1, name: '热汤面', description: '暖胃主食', price: 18, image: null, sort_order: 1 },
      { id: 1002, shop_id: 1, name: '盖浇饭', description: '简单又顶饱', price: 22, image: null, sort_order: 2 },
    ],
    2: [
      { id: 2001, shop_id: 2, name: '热红糖姜茶', description: '经期友好', price: 12, image: null, sort_order: 1 },
      { id: 2002, shop_id: 2, name: '冰柠檬茶', description: '清爽冷饮', price: 10, image: null, sort_order: 2 },
    ],
    3: [
      { id: 3001, shop_id: 3, name: '小花束', description: '一份小惊喜', price: 30, image: null, sort_order: 1 },
    ],
  };
  return data[shopId] || [];
}

function statusLabel(status) {
  return {
    pending: 'pending',
    accepted: 'accepted',
    preparing: 'preparing',
    delivering: 'delivering',
    completed: 'completed',
    cancelled: 'cancelled',
  }[status] || status;
}

async function createNotification(userId, type, title, content, payload = {}) {
  if (!userId) return;
  try {
    await pool.query(
      'INSERT INTO notifications (user_id, type, title, content, payload, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [userId, type, title, content, JSON.stringify(payload)]
    );
  } catch (err) {
    if (!['ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR'].includes(err.code)) {
      console.error('[Feeding] notification failed:', err.message);
    }
  }
  try {
    await pool.query(
      'INSERT INTO push_messages (user_id, type, title, content) VALUES (?, ?, ?, ?)',
      [userId, type, title, content]
    );
  } catch (err) {
    if (!['ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR'].includes(err.code)) {
      console.error('[Feeding] push failed:', err.message);
    }
  }
}

async function getPartnerId(user) {
  const userId = user.id;
  try {
    const [couples] = await pool.query(
      `SELECT CASE WHEN user1_id = ? THEN user2_id ELSE user1_id END AS partner_id
       FROM couples
       WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'
       LIMIT 1`,
      [userId, userId, userId]
    );
    if (couples.length > 0) return couples[0].partner_id;
  } catch (_) {}

  try {
    const partnerRole = user.role === 'boy' ? 'girl' : 'boy';
    const [partners] = await pool.query(
      'SELECT id FROM users WHERE role = ? AND id != ? ORDER BY id ASC LIMIT 1',
      [partnerRole, userId]
    );
    return partners[0]?.id || null;
  } catch (_) {
    return null;
  }
}

async function getGirlUserIdForPeriod(user) {
  if (user.role === 'girl') return user.id;
  const partnerId = await getPartnerId(user);
  if (!partnerId) return null;
  try {
    const [rows] = await pool.query("SELECT id FROM users WHERE id = ? AND role = 'girl'", [partnerId]);
    return rows[0]?.id || null;
  } catch (_) {
    return null;
  }
}

async function annotatePeriodProducts(products, user) {
  const girlUserId = await getGirlUserIdForPeriod(user);
  const inPeriod = await isUserInPeriod(girlUserId);
  const coldWords = ['ice', 'iced', 'cold', '冰', '冷', '雪糕', '冰淇淋', '冻', '冷饮'];
  const warmWords = ['hot', 'warm', 'ginger', 'brown sugar', '热', '温', '姜', '红糖', '暖'];
  return products
    .map((product) => {
      const text = `${product.name || ''} ${product.description || ''}`.toLowerCase();
      const cold = coldWords.some((word) => text.includes(word.toLowerCase()));
      const warm = warmWords.some((word) => text.includes(word.toLowerCase()));
      return { ...product, period_recommended: inPeriod ? (warm ? 1 : cold ? -1 : 0) : 0 };
    })
    .sort((a, b) => (b.period_recommended || 0) - (a.period_recommended || 0) || (a.sort_order || 0) - (b.sort_order || 0));
}

async function completeOrderLinkage(order, actualAmount = null) {
  const amount = actualAmount || order.actual_amount || order.total_price || 0;
  const platformText = [order.platform, order.platform_order_id || order.platform_order_no]
    .filter(Boolean)
    .join(' ');
  await createFinanceRecord({
    userId: order.receiver_id,
    type: 'expense',
    category: 'feeding',
    amount,
    description: `feeding-${order.product_name} ${amount}${platformText ? ` ${platformText}` : ''}`,
    sourceModule: 'feeding',
    sourceId: order.id,
  });
  await createTimelineEvent({
    userId: order.sender_id,
    title: `投喂已完成：${order.product_name}`,
    description: platformText ? `这份投喂已经送达：${platformText}` : '这份投喂已经送达',
    eventDate: todayString(),
    icon: 'restaurant',
    sourceModule: 'feeding',
    sourceId: order.id,
  });
  try {
    await addBeanTransaction(pool, {
      userId: order.receiver_id,
      amount: 1,
      type: 'feeding_received',
      title: '收到投喂',
      sourceModule: 'feeding',
      sourceId: order.id,
      description: order.product_name,
    });
  } catch (err) {
    console.error('[Feeding] completion bean award failed:', err.message);
  }
  await checkAchievements(order.receiver_id, 'feeding');
}

router.get('/shops', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, description, category, banner_color, sort_order FROM feeding_shops WHERE is_active = 1 ORDER BY sort_order ASC'
    );
    res.json({ code: 200, data: rows.length ? rows : defaultShops() });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json({ code: 200, data: defaultShops() });
    console.error('[Feeding] shops failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/shops/:id', authRequired, async (req, res) => {
  try {
    const shopId = Number(req.params.id);
    const [rows] = await pool.query(
      'SELECT id, name, icon, description, category, banner_color FROM feeding_shops WHERE id = ? AND is_active = 1',
      [shopId]
    );
    const shop = rows[0] || defaultShops().find((item) => item.id === shopId);
    if (!shop) return res.status(404).json({ code: 404, message: '店铺不存在' });
    res.json({ code: 200, data: shop });
  } catch (err) {
    console.error('[Feeding] shop detail failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

async function loadProducts(shopId, includeInactive = false) {
  const where = includeInactive ? 'shop_id = ?' : 'shop_id = ? AND is_active = 1';
  const [rows] = await pool.query(
    `SELECT id, shop_id, name, description, price, image, is_active, sort_order
     FROM feeding_products
     WHERE ${where}
     ORDER BY sort_order ASC, id ASC`,
    [shopId]
  );
  return rows;
}

router.get('/shops/:id/products', authRequired, async (req, res) => {
  try {
    const shopId = Number(req.params.id);
    const rows = await loadProducts(shopId);
    const products = rows.length ? rows : defaultProducts(shopId);
    res.json({ code: 200, data: await annotatePeriodProducts(products, req.user) });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      const products = defaultProducts(Number(req.params.id));
      return res.json({ code: 200, data: await annotatePeriodProducts(products, req.user) });
    }
    console.error('[Feeding] products failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/products', authRequired, async (req, res) => {
  try {
    const shopId = Number(req.query.shop_id || req.query.category_id || 0);
    if (!shopId) return res.status(400).json({ code: 400, message: '缺少店铺 ID' });
    const rows = await loadProducts(shopId, isAdmin(req.user) && req.query.include_inactive === '1');
    const products = rows.length ? rows : defaultProducts(shopId);
    res.json({ code: 200, data: await annotatePeriodProducts(products, req.user) });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      const products = defaultProducts(Number(req.query.shop_id || req.query.category_id || 0));
      return res.json({ code: 200, data: await annotatePeriodProducts(products, req.user) });
    }
    console.error('[Feeding] products compat failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/products', authRequired, async (req, res) => {
  if (!isAdmin(req.user)) return res.status(403).json({ code: 403, message: '仅管理员可操作' });
  try {
    const { shop_id, name, description, price, image, sort_order, is_active } = req.body;
    if (!shop_id || !name) return res.status(400).json({ code: 400, message: '店铺和商品名称不能为空' });
    const [result] = await pool.query(
      `INSERT INTO feeding_products
       (shop_id, name, description, price, image, sort_order, is_active, is_custom, created_by, category)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, 'custom')`,
      [shop_id, name, description || '', Number(price || 0), image || null, Number(sort_order || 0), is_active === false ? 0 : 1, req.user.id]
    );
    res.json({ code: 200, data: { id: result.insertId } });
  } catch (err) {
    console.error('[Feeding] create product failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/products/:id', authRequired, async (req, res) => {
  if (!isAdmin(req.user)) return res.status(403).json({ code: 403, message: '仅管理员可操作' });
  try {
    const updates = {};
    for (const key of ['shop_id', 'name', 'description', 'price', 'image', 'sort_order', 'is_active']) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }
    if (Object.keys(updates).length === 0) return res.status(400).json({ code: 400, message: '没有可更新的内容' });
    await pool.query('UPDATE feeding_products SET ? WHERE id = ?', [updates, req.params.id]);
    res.json({ code: 200, message: '商品更新成功' });
  } catch (err) {
    console.error('[Feeding] update product failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.delete('/products/:id', authRequired, async (req, res) => {
  if (!isAdmin(req.user)) return res.status(403).json({ code: 403, message: '仅管理员可操作' });
  try {
    await pool.query('UPDATE feeding_products SET is_active = 0 WHERE id = ?', [req.params.id]);
    res.json({ code: 200, message: 'disabled' });
  } catch (err) {
    console.error('[Feeding] delete product failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/categories', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, sort_order FROM feeding_shops WHERE is_active = 1 ORDER BY sort_order ASC'
    );
    res.json({ code: 200, data: (rows.length ? rows : defaultShops()).map((s) => ({ id: s.id, name: s.name, icon: s.icon, sort_order: s.sort_order })) });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: defaultShops().map((s) => ({ id: s.id, name: s.name, icon: s.icon, sort_order: s.sort_order })) });
    }
    console.error('[Feeding] categories failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/orders', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const senderId = req.user.id;
    const productId = Number(req.body.product_id);
    const qty = Math.max(1, Math.min(99, Number(req.body.quantity) || 1));
    if (!productId) return res.status(400).json({ code: 400, message: '缺少商品 ID' });

    let productName = '心意礼物';
    let productPrice = 10;
    let shopId = req.body.shop_id || null;
    try {
      const [products] = await pool.query(
        'SELECT id, name, price, shop_id FROM feeding_products WHERE id = ? LIMIT 1',
        [productId]
      );
      if (products.length) {
        productName = products[0].name;
        productPrice = Number(products[0].price || 0);
        shopId = shopId || products[0].shop_id;
      } else {
        for (const shop of defaultShops()) {
          const found = defaultProducts(shop.id).find((p) => p.id === productId);
          if (found) {
            productName = found.name;
            productPrice = Number(found.price || 0);
            shopId = shop.id;
            break;
          }
        }
      }
    } catch (_) {}

    const receiverId = await getPartnerId(req.user);
    if (!receiverId) return res.status(400).json({ code: 400, message: '请先绑定伴侣' });

    const totalPrice = productPrice * qty;
    const boyUserId = req.user.role === 'boy' ? senderId : receiverId;
    const girlUserId = req.user.role === 'girl' ? senderId : receiverId;

    await conn.beginTransaction();
    await addBeanTransaction(conn, {
      userId: senderId,
      amount: -totalPrice,
      type: 'feeding_order',
      title: `Feeding - ${productName}`,
      sourceModule: 'feeding',
      description: `${productName} x${qty}`,
    });
    const [result] = await conn.query(
      `INSERT INTO feeding_orders
       (sender_id, receiver_id, boy_user_id, girl_user_id, shop_id, product_id, product_name,
        product_price, quantity, total_price, message, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [senderId, receiverId, boyUserId, girlUserId, shopId, productId, productName, productPrice, qty, totalPrice, req.body.message || '']
    );
    const orderId = result.insertId;
    await conn.query(
      `UPDATE bean_transactions SET source_id = ?, reference_id = ?
       WHERE user_id = ? AND type = 'feeding_order' AND source_module = 'feeding'
       ORDER BY id DESC LIMIT 1`,
      [orderId, orderId, senderId]
    );
    await conn.commit();

    await createNotification(receiverId, 'feeding_order', '收到新的投喂订单', `${productName} x${qty}`, { order_id: orderId });
    res.json({
      code: 200,
      message: '订单创建成功',
      data: { id: orderId, product_name: productName, product_price: productPrice, quantity: qty, total_price: totalPrice, status: 'pending' },
    });
  } catch (err) {
    await conn.rollback();
    console.error('[Feeding] create order failed:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '服务器错误' });
  } finally {
    conn.release();
  }
});

router.get('/orders', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const page = Math.max(1, Number(req.query.page) || 1);
    const size = Math.min(50, Math.max(1, Number(req.query.size) || 20));
    const offset = (page - 1) * size;
    const [rows] = await pool.query(
      `SELECT o.id, o.sender_id, o.receiver_id, o.product_id, o.product_name, o.product_price,
              o.quantity, o.total_price, o.message, o.status, o.urge_count, o.last_urge_at,
              o.cancel_reason, o.created_at, o.updated_at,
              o.platform, o.actual_amount, o.platform_order_no,
              COALESCE(o.platform_order_id, o.platform_order_no) AS platform_order_id,
              o.delivery_status, o.delivery_eta, o.delivery_note, o.note,
              s.nickname AS sender_name, s.avatar_url AS sender_avatar,
              r.nickname AS receiver_name, r.avatar_url AS receiver_avatar,
              sh.name AS shop_name, sh.icon AS shop_icon
       FROM feeding_orders o
       LEFT JOIN users s ON o.sender_id = s.id
       LEFT JOIN users r ON o.receiver_id = r.id
       LEFT JOIN feeding_shops sh ON o.shop_id = sh.id
       WHERE o.sender_id = ? OR o.receiver_id = ?
       ORDER BY o.created_at DESC
       LIMIT ? OFFSET ?`,
      [userId, userId, size, offset]
    );
    const list = rows.map((row) => ({
      ...row,
      is_mine: row.sender_id === userId,
      is_received: row.receiver_id === userId,
      order_role: row.sender_id === userId ? 'sent' : 'received',
    }));
    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json({ code: 200, data: { list: [], total: 0 } });
    console.error('[Feeding] orders failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/orders/:id/status', authRequired, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    const status = req.body.status;
    const valid = ['pending', 'accepted', 'preparing', 'delivering', 'completed', 'cancelled'];
    if (!valid.includes(status)) return res.status(400).json({ code: 400, message: 'invalid status' });

    const [orders] = await pool.query(
      'SELECT * FROM feeding_orders WHERE id = ? LIMIT 1',
      [orderId]
    );
    if (orders.length === 0) return res.status(404).json({ code: 404, message: 'order not found' });
    const order = orders[0];
    const userId = req.user.id;
    if (order.sender_id !== userId && order.receiver_id !== userId) {
      return res.status(403).json({ code: 403, message: 'forbidden' });
    }

    const flow = {
      pending: ['accepted', 'cancelled'],
      accepted: ['preparing', 'cancelled'],
      preparing: ['delivering', 'cancelled'],
      delivering: ['completed', 'cancelled'],
      completed: [],
      cancelled: [],
    };
    if (!flow[order.status]?.includes(status)) {
      return res.status(400).json({ code: 400, message: `cannot change ${order.status} to ${status}` });
    }
    if (status === 'cancelled') {
      const pendingCancelAllowed = order.status === 'pending' && (order.sender_id === userId || order.receiver_id === userId);
      const afterAcceptCancelAllowed = order.status !== 'pending' && order.receiver_id === userId;
      if (!pendingCancelAllowed && !afterAcceptCancelAllowed) {
        return res.status(403).json({ code: 403, message: 'cancel not allowed' });
      }
    } else if (order.receiver_id !== userId) {
      return res.status(403).json({ code: 403, message: 'receiver only' });
    }

    const updates = ['status = ?', 'updated_at = NOW()'];
    const params = [status];
    if (status === 'accepted') updates.push('accepted_at = NOW()');
    if (status === 'completed') updates.push('delivered_at = NOW()');
    if (status === 'cancelled') {
      updates.push('cancel_reason = ?');
      params.push(req.body.reason || req.body.cancel_reason || null);
    }
    params.push(orderId, order.status);
    const [result] = await pool.query(
      `UPDATE feeding_orders SET ${updates.join(', ')} WHERE id = ? AND status = ?`,
      params
    );
    if (result.affectedRows === 0) return res.status(409).json({ code: 409, message: 'order changed, refresh first' });

    if (status === 'completed') {
      const amount = order.actual_amount || order.total_price || 0;
      await createFinanceRecord({
        userId: order.receiver_id,
        type: 'expense',
        category: '投喂',
        amount,
        description: `投喂-${order.product_name} ¥${amount}`,
        sourceModule: 'feeding',
        sourceId: orderId,
      });
      await createTimelineEvent({
        userId: order.sender_id,
        title: `投喂完成：${order.product_name}`,
        description: `一份投喂已经送达`,
        eventDate: todayString(),
        icon: 'restaurant',
        sourceModule: 'feeding',
        sourceId: orderId,
      });
      try {
        await addBeanTransaction(pool, {
          userId: order.receiver_id,
          amount: 1,
          type: 'feeding_received',
          title: '完成投喂',
          sourceModule: 'feeding',
          sourceId: orderId,
          description: order.product_name,
        });
      } catch (err) {
        console.error('[Feeding] completion bean award failed:', err.message);
      }
      await checkAchievements(order.receiver_id, 'feeding');
    }

    const notifyUserId = status === 'cancelled' ? (userId === order.sender_id ? order.receiver_id : order.sender_id) : order.sender_id;
    await createNotification(notifyUserId, 'feeding_status', '投喂订单状态更新', `${order.product_name} ${statusLabel(status)}`, { order_id: orderId, status });
    res.json({ code: 200, message: '订单状态已更新', data: { id: orderId, status } });
  } catch (err) {
    console.error('[Feeding] status failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/orders/:id/urge', authRequired, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    const userId = req.user.id;
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, status, urge_count, last_urge_at, product_name FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) return res.status(404).json({ code: 404, message: 'order not found' });
    const order = orders[0];
    if (order.sender_id !== userId) return res.status(403).json({ code: 403, message: 'sender only' });
    if (!['pending', 'accepted', 'preparing'].includes(order.status)) {
      return res.status(400).json({ code: 400, message: '当前状态不能催单' });
    }
    const [result] = await pool.query(
      `UPDATE feeding_orders
       SET urge_count = urge_count + 1, last_urge_at = NOW()
       WHERE id = ? AND (last_urge_at IS NULL OR last_urge_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE))`,
      [orderId]
    );
    if (result.affectedRows === 0) {
      return res.status(429).json({ code: 429, message: 'please wait 5 minutes before urging again' });
    }
    const urgeCount = Number(order.urge_count || 0) + 1;
    await createNotification(order.receiver_id, 'feeding_urge', 'Feeding urge', `${order.product_name} is waiting`, { order_id: orderId, urge_count: urgeCount });
    res.json({ code: 200, message: '已发送催单提醒', data: { id: orderId, urge_count: urgeCount } });
  } catch (err) {
    console.error('[Feeding] urge failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/feeding/orders/:id/fulfill — 一键履约（填写平台信息 + 标记完成）
router.post('/orders/:id/fulfill', authRequired, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    const userId = req.user.id;
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, product_name, total_price, status FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) return res.status(404).json({ code: 404, message: 'order not found' });
    const order = orders[0];
    if (order.receiver_id !== userId) return res.status(403).json({ code: 403, message: 'receiver only' });
    if (['completed', 'cancelled'].includes(order.status)) {
      return res.status(400).json({ code: 400, message: 'order already completed or cancelled' });
    }

    const platform = (req.body.platform || '').toString().trim().slice(0, 30) || null;
    const amount = req.body.actual_amount === undefined || req.body.actual_amount === null || req.body.actual_amount === ''
      ? null : Number(req.body.actual_amount);
    if (amount !== null && (!Number.isFinite(amount) || amount < 0)) {
      return res.status(400).json({ code: 400, message: 'invalid amount' });
    }
    const platformOrderId = (req.body.platform_order_id || '').toString().trim().slice(0, 100) || null;
    const note = (req.body.note || '').toString().trim().slice(0, 500) || null;

    await pool.query(
      `UPDATE feeding_orders
       SET platform = ?, actual_amount = ?, platform_order_id = ?, platform_order_no = ?,
           note = ?, status = 'completed', delivered_at = NOW(), updated_at = NOW()
       WHERE id = ?`,
      [platform, amount, platformOrderId, platformOrderId, note, orderId]
    );

    const financeAmount = amount || order.total_price || 0;
    await completeOrderLinkage({
      ...order,
      platform,
      platform_order_id: platformOrderId,
      actual_amount: amount,
    }, financeAmount);

    await createNotification(order.sender_id, 'feeding_status', 'Feeding fulfilled', `${order.product_name} has been purchased`, { order_id: orderId, status: 'completed' });
    res.json({
      code: 200,
      message: 'order fulfilled',
      data: { id: orderId, status: 'completed', platform, platform_order_id: platformOrderId, actual_amount: amount, note },
    });
  } catch (err) {
    console.error('[Feeding] fulfill failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/orders/:id', authRequired, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, status FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) return res.status(404).json({ code: 404, message: 'order not found' });
    const order = orders[0];
    if (order.receiver_id !== req.user.id) return res.status(403).json({ code: 403, message: 'receiver only' });
    if (['completed', 'cancelled'].includes(order.status)) {
      return res.status(400).json({ code: 400, message: 'completed or cancelled order cannot be edited' });
    }

    const amount = req.body.actual_amount === undefined || req.body.actual_amount === null || req.body.actual_amount === ''
      ? null
      : Number(req.body.actual_amount);
    if (amount !== null && (!Number.isFinite(amount) || amount < 0)) {
      return res.status(400).json({ code: 400, message: 'invalid amount' });
    }
    const platform = req.body.platform ? String(req.body.platform).trim().slice(0, 30) : null;
    const platformOrderId = req.body.platform_order_id || req.body.platform_order_no || order.platform_order_id || order.platform_order_no || null;

    await pool.query(
      `UPDATE feeding_orders
       SET platform = ?, actual_amount = ?, platform_order_no = ?, platform_order_id = ?, updated_at = NOW()
       WHERE id = ?`,
      [platform, amount, platformOrderId, platformOrderId, orderId]
    );
    res.json({ code: 200, message: '订单信息更新成功', data: { id: orderId, platform, platform_order_id: platformOrderId, platform_order_no: platformOrderId, actual_amount: amount } });
  } catch (err) {
    console.error('[Feeding] order edit failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/orders/:id/delivery', authRequired, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, product_name, status, total_price, platform, platform_order_no, platform_order_id FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) return res.status(404).json({ code: 404, message: 'order not found' });
    const order = orders[0];
    if (order.receiver_id !== req.user.id) return res.status(403).json({ code: 403, message: 'receiver only' });

    const amount = req.body.actual_amount === undefined || req.body.actual_amount === null || req.body.actual_amount === ''
      ? null
      : Number(req.body.actual_amount);
    if (amount !== null && (!Number.isFinite(amount) || amount < 0)) {
      return res.status(400).json({ code: 400, message: 'invalid amount' });
    }
    const nextStatus = req.body.delivery_status === 'completed' ? 'completed' : req.body.delivery_status ? 'delivering' : order.status;
    const platformOrderId = req.body.platform_order_id || req.body.platform_order_no || null;
    await pool.query(
      `UPDATE feeding_orders
       SET platform = ?, actual_amount = ?, platform_order_no = ?, platform_order_id = ?,
           delivery_status = ?, delivery_eta = ?, delivery_note = ?,
           status = ?, delivered_at = CASE WHEN ? = 'completed' THEN NOW() ELSE delivered_at END,
           updated_at = NOW()
       WHERE id = ?`,
      [
        req.body.platform || null,
        amount,
        platformOrderId,
        platformOrderId,
        req.body.delivery_status || null,
        req.body.delivery_eta || null,
        req.body.delivery_note || null,
        nextStatus,
        nextStatus,
        orderId,
      ]
    );
    if (nextStatus === 'completed') {
      const financeAmount = amount || order.total_price || 0;
      if (false) await createFinanceRecord({
        userId: order.receiver_id,
        type: 'expense',
        category: '投喂',
        amount: financeAmount,
        description: `投喂-${order.product_name} ¥${financeAmount}`,
        sourceModule: 'feeding',
        sourceId: orderId,
      });
      await completeOrderLinkage({ ...order, platform: req.body.platform || order.platform, platform_order_id: platformOrderId }, financeAmount);
    }
    await createNotification(order.sender_id, 'feeding_delivery', '配送状态更新', `${order.product_name} 状态已更新`, { order_id: orderId, status: nextStatus });
    res.json({ code: 200, message: '配送状态已更新', data: { id: orderId, status: nextStatus, delivery_status: req.body.delivery_status || null } });
  } catch (err) {
    console.error('[Feeding] delivery failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/stats', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [sentRows] = await pool.query('SELECT COUNT(*) AS cnt FROM feeding_orders WHERE sender_id = ?', [userId]);
    const [recvRows] = await pool.query('SELECT COUNT(*) AS cnt FROM feeding_orders WHERE receiver_id = ?', [userId]);
    const [pendingRows] = await pool.query(
      "SELECT COUNT(*) AS cnt FROM feeding_orders WHERE receiver_id = ? AND status IN ('pending', 'accepted', 'preparing', 'delivering')",
      [userId]
    );
    const [lastRows] = await pool.query(
      'SELECT created_at FROM feeding_orders WHERE sender_id = ? OR receiver_id = ? ORDER BY created_at DESC LIMIT 1',
      [userId, userId]
    );
    res.json({
      code: 200,
      data: {
        total_sent: sentRows[0]?.cnt || 0,
        total_received: recvRows[0]?.cnt || 0,
        pending_orders: pendingRows[0]?.cnt || 0,
        last_feeding_time: lastRows[0]?.created_at || '',
      },
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { total_sent: 0, total_received: 0, pending_orders: 0, last_feeding_time: '' } });
    }
    console.error('[Feeding] stats failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
