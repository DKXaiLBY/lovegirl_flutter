/**
 * 投喂站 v2 — 外卖风格的情侣送礼系统
 *
 * 数据表设计：
 *
 * CREATE TABLE IF NOT EXISTS feeding_shops (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   name VARCHAR(50) NOT NULL,
 *   icon VARCHAR(10) DEFAULT '🏪',
 *   description VARCHAR(200) DEFAULT '',
 *   category VARCHAR(20) DEFAULT 'food' COMMENT 'food/drink/flower/gift',
 *   banner_color VARCHAR(20) DEFAULT '#FF6B8A',
 *   sort_order INT DEFAULT 0,
 *   is_active TINYINT(1) DEFAULT 1,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 *
 * CREATE TABLE IF NOT EXISTS feeding_products (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   shop_id INT NOT NULL,
 *   name VARCHAR(100) NOT NULL,
 *   description TEXT,
 *   price INT NOT NULL DEFAULT 10 COMMENT '爱心豆价格',
 *   image VARCHAR(255),
 *   is_active TINYINT(1) DEFAULT 1,
 *   sort_order INT DEFAULT 0,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   FOREIGN KEY (shop_id) REFERENCES feeding_shops(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 *
 * CREATE TABLE IF NOT EXISTS feeding_orders (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   sender_id INT NOT NULL,
 *   receiver_id INT DEFAULT NULL,
 *   shop_id INT DEFAULT NULL,
 *   product_id INT NOT NULL,
 *   product_name VARCHAR(100) NOT NULL,
 *   product_price INT NOT NULL DEFAULT 0,
 *   quantity INT NOT NULL DEFAULT 1,
 *   total_price INT NOT NULL DEFAULT 0,
 *   message TEXT,
 *   status VARCHAR(20) DEFAULT 'pending' COMMENT 'pending/accepted/preparing/delivering/completed',
 *   urge_count INT DEFAULT 0,
 *   last_urge_at DATETIME DEFAULT NULL,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 *   FOREIGN KEY (sender_id) REFERENCES users(id),
 *   FOREIGN KEY (product_id) REFERENCES feeding_products(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 */

const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

// ==================== 店铺 ====================

// GET /api/feeding/shops — 获取所有店铺
router.get('/shops', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, description, category, banner_color, sort_order FROM feeding_shops WHERE is_active = 1 ORDER BY sort_order ASC'
    );
    if (rows.length === 0) {
      return res.json({ code: 200, data: getDefaultShops() });
    }
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Feeding] 获取店铺失败:', err.message);
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: getDefaultShops() });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/feeding/shops/:id — 获取店铺详情
router.get('/shops/:id', authRequired, async (req, res) => {
  try {
    const shopId = parseInt(req.params.id);
    const [rows] = await pool.query(
      'SELECT id, name, icon, description, category, banner_color FROM feeding_shops WHERE id = ? AND is_active = 1',
      [shopId]
    );
    if (rows.length === 0) {
      const defaults = getDefaultShops();
      const shop = defaults.find(s => s.id === shopId);
      if (shop) return res.json({ code: 200, data: shop });
      return res.status(404).json({ code: 404, message: '店铺不存在' });
    }
    res.json({ code: 200, data: rows[0] });
  } catch (err) {
    console.error('[Feeding] 获取店铺详情失败:', err.message);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 商品 ====================

// GET /api/feeding/shops/:id/products — 获取店铺商品
router.get('/shops/:id/products', authRequired, async (req, res) => {
  try {
    const shopId = parseInt(req.params.id);
    const [rows] = await pool.query(
      'SELECT id, shop_id, name, description, price, image FROM feeding_products WHERE shop_id = ? AND is_active = 1 ORDER BY sort_order ASC',
      [shopId]
    );
    if (rows.length === 0) {
      const defaults = getDefaultProducts(shopId);
      return res.json({ code: 200, data: defaults });
    }
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Feeding] 获取商品失败:', err.message);
    if (err.code === 'ER_NO_SUCH_TABLE') {
      const defaults = getDefaultProducts(parseInt(req.params.id));
      return res.json({ code: 200, data: defaults });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/feeding/products?shop_id=1 — 兼容旧接口
router.get('/products', authRequired, async (req, res) => {
  try {
    const shopId = parseInt(req.query.shop_id || req.query.category_id) || 0;
    if (!shopId) {
      return res.status(400).json({ code: 400, message: '请提供shop_id' });
    }
    const [rows] = await pool.query(
      'SELECT id, shop_id, name, description, price, image FROM feeding_products WHERE shop_id = ? AND is_active = 1 ORDER BY sort_order ASC',
      [shopId]
    );
    if (rows.length === 0) {
      const defaults = getDefaultProducts(shopId);
      return res.json({ code: 200, data: defaults });
    }
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Feeding] 获取商品失败:', err.message);
    if (err.code === 'ER_NO_SUCH_TABLE') {
      const defaults = getDefaultProducts(parseInt(req.query.shop_id || req.query.category_id) || 0);
      return res.json({ code: 200, data: defaults });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 兼容旧接口：GET /api/feeding/categories
router.get('/categories', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, sort_order FROM feeding_shops WHERE is_active = 1 ORDER BY sort_order ASC'
    );
    if (rows.length === 0) {
      return res.json({ code: 200, data: getDefaultShops().map(s => ({ id: s.id, name: s.name, icon: s.icon, sort_order: s.sort_order })) });
    }
    res.json({ code: 200, data: rows.map(r => ({ id: r.id, name: r.name, icon: r.icon, sort_order: r.sort_order })) });
  } catch (err) {
    console.error('[Feeding] 获取分类失败:', err.message);
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: getDefaultShops().map(s => ({ id: s.id, name: s.name, icon: s.icon, sort_order: s.sort_order })) });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 订单 ====================

// POST /api/feeding/orders — 创建投喂订单
router.post('/orders', authRequired, async (req, res) => {
  try {
    const senderId = req.user.id;
    const { product_id, shop_id, quantity, message } = req.body;

    if (!product_id) {
      return res.status(400).json({ code: 400, message: '请选择要送出的商品' });
    }
    const qty = Math.max(1, Math.min(99, parseInt(quantity) || 1));

    // 查找商品信息
    let productName = '礼物';
    let productPrice = 10;
    let shopId = shop_id || null;
    try {
      const [products] = await pool.query(
        'SELECT p.name, p.price, p.shop_id FROM feeding_products p WHERE p.id = ?',
        [product_id]
      );
      if (products.length > 0) {
        productName = products[0].name;
        productPrice = products[0].price;
        shopId = shopId || products[0].shop_id;
      }
    } catch (_) {
      // 表不存在时用默认数据
      const allShops = getDefaultShops();
      for (const shop of allShops) {
        const prods = getDefaultProducts(shop.id);
        const found = prods.find(p => p.id == product_id);
        if (found) {
          productName = found.name;
          productPrice = found.price;
          shopId = shop.id;
          break;
        }
      }
    }

    const totalPrice = productPrice * qty;

    // 查找伴侣作为接收者
    // TODO: 引入 couple/binding 表记录伴侣关系，当前假设只有2个用户（boy+girl）
    const partnerRole = req.user.role === 'boy' ? 'girl' : 'boy';
    let receiverId = null;
    try {
      const [partners] = await pool.query(
        'SELECT id FROM users WHERE role = ? AND id != ? ORDER BY last_login DESC LIMIT 1',
        [partnerRole, senderId]
      );
      if (partners.length > 0) receiverId = partners[0].id;
    } catch (_) {
      receiverId = null;
    }

    // 插入订单
    let orderId = Date.now();
    try {
      const [result] = await pool.query(
        `INSERT INTO feeding_orders
         (sender_id, receiver_id, shop_id, product_id, product_name, product_price, quantity, total_price, message, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
        [senderId, receiverId, shopId, product_id, productName, productPrice, qty, totalPrice, message || '']
      );
      orderId = result.insertId;
    } catch (err) {
      if (err.code === 'ER_NO_SUCH_TABLE') {
        console.log('[Feeding] feeding_orders 表尚未创建，订单仅记录日志');
      } else {
        throw err;
      }
    }

    console.log(`[Feeding] 订单#${orderId}: 用户${senderId} 送出 ${productName} x${qty} (${totalPrice}豆)`);

    res.json({
      code: 200,
      message: `已送出${productName}! TA会收到通知哦~`,
      data: {
        id: orderId,
        product_name: productName,
        product_price: productPrice,
        quantity: qty,
        total_price: totalPrice,
        status: 'pending',
      }
    });
  } catch (err) {
    console.error('[Feeding] 创建订单失败:', err);
    res.status(500).json({ code: 500, message: '送出失败，请稍后重试' });
  }
});

// GET /api/feeding/orders — 获取投喂记录
router.get('/orders', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const size = Math.min(parseInt(req.query.size) || 20, 50);
    const offset = (page - 1) * size;

    let rows = [];
    try {
      [rows] = await pool.query(
        `SELECT o.id, o.product_id, o.product_name, o.product_price, o.quantity, o.total_price,
                o.message, o.status, o.urge_count, o.last_urge_at, o.created_at, o.updated_at,
                s.nickname AS sender_name, s.avatar AS sender_avatar,
                r.nickname AS receiver_name, r.avatar AS receiver_avatar,
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
    } catch (err) {
      if (err.code === 'ER_NO_SUCH_TABLE') {
        return res.json({ code: 200, data: { list: [], total: 0 } });
      }
      throw err;
    }

    // 标记是否是自己发出的
    const list = rows.map(row => ({
      ...row,
      is_mine: row.sender_id === userId,
      is_received: row.receiver_id === userId,
    }));

    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    console.error('[Feeding] 获取订单失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/feeding/orders/:id/status — 更新订单状态
router.put('/orders/:id/status', authRequired, async (req, res) => {
  try {
    const orderId = parseInt(req.params.id);
    const { status } = req.body;
    const validStatuses = ['pending', 'accepted', 'preparing', 'delivering', 'completed', 'cancelled'];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ code: 400, message: '无效的订单状态' });
    }

    // 验证订单归属
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, status AS current_status FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ code: 404, message: '订单不存在' });
    }

    const order = orders[0];
    const userId = req.user.id;

    // 权限检查：接收者可以更新状态，发送者可以取消
    if (status === 'cancelled') {
      if (order.sender_id !== userId) {
        return res.status(403).json({ code: 403, message: '只有发送者可以取消订单' });
      }
    } else {
      if (order.receiver_id !== userId) {
        return res.status(403).json({ code: 403, message: '只有接收者可以更新订单状态' });
      }
    }

    // 状态流转验证
    const statusFlow = {
      'pending': ['accepted', 'cancelled'],
      'accepted': ['preparing', 'cancelled'],
      'preparing': ['delivering'],
      'delivering': ['completed'],
      'completed': [],
      'cancelled': [],
    };

    if (!statusFlow[order.current_status]?.includes(status)) {
      return res.status(400).json({ code: 400, message: `无法从 ${order.current_status} 变更为 ${status}` });
    }

    await pool.query(
      'UPDATE feeding_orders SET status = ?, updated_at = NOW() WHERE id = ?',
      [status, orderId]
    );

    res.json({ code: 200, message: '订单状态已更新', data: { id: orderId, status } });
  } catch (err) {
    console.error('[Feeding] 更新订单状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/feeding/orders/:id/urge — 催单
router.post('/orders/:id/urge', authRequired, async (req, res) => {
  try {
    const orderId = parseInt(req.params.id);
    const userId = req.user.id;

    // 验证订单归属
    const [orders] = await pool.query(
      'SELECT id, sender_id, receiver_id, status, urge_count FROM feeding_orders WHERE id = ?',
      [orderId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ code: 404, message: '订单不存在' });
    }

    const order = orders[0];

    // 只有发送者可以催单
    if (order.sender_id !== userId) {
      return res.status(403).json({ code: 403, message: '只有发送者可以催单' });
    }

    // 只有待处理/已接单/准备中的订单可以催单
    if (!['pending', 'accepted', 'preparing'].includes(order.status)) {
      return res.status(400).json({ code: 400, message: '当前订单状态不支持催单' });
    }

    // 更新催单次数和时间
    await pool.query(
      'UPDATE feeding_orders SET urge_count = urge_count + 1, last_urge_at = NOW() WHERE id = ?',
      [orderId]
    );

    console.log(`[Feeding] 催单: 订单#${orderId} 被用户${userId} 催单 (第${(order.urge_count || 0) + 1}次)`);

    res.json({
      code: 200,
      message: '已催单! TA会收到提醒哦~',
      data: { id: orderId, urge_count: (order.urge_count || 0) + 1 }
    });
  } catch (err) {
    console.error('[Feeding] 催单失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 统计 ====================

// GET /api/feeding/stats
router.get('/stats', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    let totalSent = 0, totalReceived = 0, lastFeedingTime = '';
    let pendingOrders = 0;

    try {
      const [sentRows] = await pool.query(
        'SELECT COUNT(*) AS cnt FROM feeding_orders WHERE sender_id = ?', [userId]
      );
      totalSent = sentRows[0]?.cnt || 0;

      const [recvRows] = await pool.query(
        'SELECT COUNT(*) AS cnt FROM feeding_orders WHERE receiver_id = ?', [userId]
      );
      totalReceived = recvRows[0]?.cnt || 0;

      const [lastRows] = await pool.query(
        'SELECT created_at FROM feeding_orders WHERE sender_id = ? OR receiver_id = ? ORDER BY created_at DESC LIMIT 1',
        [userId, userId]
      );
      if (lastRows.length > 0 && lastRows[0].created_at) {
        const d = new Date(lastRows[0].created_at);
        lastFeedingTime = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      }

      // 待处理订单数（我收到的未完成订单）
      const [pendingRows] = await pool.query(
        "SELECT COUNT(*) AS cnt FROM feeding_orders WHERE receiver_id = ? AND status IN ('pending', 'accepted', 'preparing', 'delivering')",
        [userId]
      );
      pendingOrders = pendingRows[0]?.cnt || 0;
    } catch (err) {
      if (err.code !== 'ER_NO_SUCH_TABLE') throw err;
    }

    res.json({
      code: 200,
      data: {
        total_sent: totalSent,
        total_received: totalReceived,
        last_feeding_time: lastFeedingTime,
        pending_orders: pendingOrders,
      }
    });
  } catch (err) {
    console.error('[Feeding] 获取统计失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 默认数据 ====================

function getDefaultShops() {
  return [
    { id: 1, name: '喜茶', icon: '🧋', description: '灵感之茶，一杯喜茶遇见你', category: 'drink', banner_color: '#4CAF50', sort_order: 0 },
    { id: 2, name: '瑞幸咖啡', icon: '☕', description: '每一杯都是浪漫的开始', category: 'drink', banner_color: '#2196F3', sort_order: 1 },
    { id: 3, name: '好利来', icon: '🎂', description: '甜蜜的蛋糕给甜蜜的你', category: 'food', banner_color: '#FF6B8A', sort_order: 2 },
    { id: 4, name: '鸡柳大人', icon: '🍗', description: '酥脆鸡柳，追剧必备', category: 'food', banner_color: '#FF9800', sort_order: 3 },
    { id: 5, name: '浪漫花店', icon: '🌹', description: '用花语表达爱意', category: 'flower', banner_color: '#E040FB', sort_order: 4 },
    { id: 6, name: '甜蜜零食铺', icon: '🍫', description: '甜蜜零食，甜蜜恋爱', category: 'food', banner_color: '#7B8CFF', sort_order: 5 },
    { id: 7, name: '心意礼物坊', icon: '🎁', description: '用心挑选，送给最爱的TA', category: 'gift', banner_color: '#FFB347', sort_order: 6 },
  ];
}

function getDefaultProducts(shopId) {
  const products = {
    1: [ // 喜茶
      { id: 10001, shop_id: 1, name: '多肉葡萄', description: '新鲜葡萄果肉+芝士奶盖', price: 28, image: '' },
      { id: 10002, shop_id: 1, name: '芝芝莓莓', description: '草莓+蓝莓+芝士', price: 32, image: '' },
      { id: 10003, shop_id: 1, name: '烤黑糖波波', description: '黑糖珍珠+鲜奶', price: 25, image: '' },
      { id: 10004, shop_id: 1, name: '多肉芒芒', description: '芒果果肉+椰奶', price: 30, image: '' },
      { id: 10005, shop_id: 1, name: '芝芝桃桃', description: '水蜜桃+芝士奶盖', price: 28, image: '' },
    ],
    2: [ // 瑞幸咖啡
      { id: 10101, shop_id: 2, name: '生椰拿铁', description: '椰浆+浓缩咖啡', price: 18, image: '' },
      { id: 10102, shop_id: 2, name: '厚乳拿铁', description: '厚牛乳+浓缩咖啡', price: 20, image: '' },
      { id: 10103, shop_id: 2, name: '丝绒拿铁', description: '丝滑口感，回味无穷', price: 22, image: '' },
      { id: 10104, shop_id: 2, name: '橙C美式', description: '鲜橙汁+美式咖啡', price: 16, image: '' },
      { id: 10105, shop_id: 2, name: '冰吸生椰', description: '清凉解暑，夏日必备', price: 19, image: '' },
    ],
    3: [ // 好利来
      { id: 10201, shop_id: 3, name: '半熟芝士', description: '入口即化的芝士蛋糕', price: 38, image: '' },
      { id: 10202, shop_id: 3, name: '草莓蛋糕', description: '新鲜草莓+奶油蛋糕', price: 45, image: '' },
      { id: 10203, shop_id: 3, name: '巧克力慕斯', description: '浓郁巧克力，丝滑口感', price: 42, image: '' },
      { id: 10204, shop_id: 3, name: '提拉米苏', description: '经典意式甜品', price: 35, image: '' },
      { id: 10205, shop_id: 3, name: '马卡龙礼盒', description: '6枚精致法式马卡龙', price: 58, image: '' },
    ],
    4: [ // 鸡柳大人
      { id: 10301, shop_id: 4, name: '招牌鸡柳', description: '酥脆多汁，追剧必备', price: 18, image: '' },
      { id: 10302, shop_id: 4, name: '黄金鸡块', description: '外酥里嫩，一口一个', price: 22, image: '' },
      { id: 10303, shop_id: 4, name: '芝士热狗', description: '拉丝芝士+脆皮热狗', price: 15, image: '' },
      { id: 10304, shop_id: 4, name: '薯条大份', description: '金黄酥脆，停不下来', price: 12, image: '' },
      { id: 10305, shop_id: 4, name: '鸡米花', description: '小巧可爱，一口一个', price: 16, image: '' },
    ],
    5: [ // 浪漫花店
      { id: 10401, shop_id: 5, name: '红玫瑰花束', description: '11朵红玫瑰，一心一意', price: 99, image: '' },
      { id: 10402, shop_id: 5, name: '粉色康乃馨', description: '温馨浪漫，表达爱意', price: 68, image: '' },
      { id: 10403, shop_id: 5, name: '向日葵花束', description: '你是我的太阳', price: 58, image: '' },
      { id: 10404, shop_id: 5, name: '满天星花束', description: '星星点点的浪漫', price: 48, image: '' },
      { id: 10405, shop_id: 5, name: '混搭花束', description: '精心搭配，独一无二', price: 88, image: '' },
    ],
    6: [ // 甜蜜零食铺
      { id: 10501, shop_id: 6, name: '巧克力礼盒', description: '进口巧克力，甜蜜满分', price: 45, image: '' },
      { id: 10502, shop_id: 6, name: '坚果大礼包', description: '每日坚果，健康美味', price: 38, image: '' },
      { id: 10503, shop_id: 6, name: '果冻布丁', description: 'Q弹爽滑，甜蜜诱惑', price: 22, image: '' },
      { id: 10504, shop_id: 6, name: '薯片大礼包', description: '追剧必备，多种口味', price: 28, image: '' },
      { id: 10505, shop_id: 6, name: '小熊饼干', description: '可爱造型，酥脆可口', price: 18, image: '' },
    ],
    7: [ // 心意礼物坊
      { id: 10601, shop_id: 7, name: '情侣手链', description: '刻上你们的名字', price: 88, image: '' },
      { id: 10602, shop_id: 7, name: '泰迪熊', description: '软软的陪伴，温暖的拥抱', price: 58, image: '' },
      { id: 10603, shop_id: 7, name: '情侣戒指', description: '爱的承诺，永恒的约定', price: 128, image: '' },
      { id: 10604, shop_id: 7, name: '音乐盒', description: '播放你们的主题曲', price: 68, image: '' },
      { id: 10605, shop_id: 7, name: '星空投影灯', description: '每晚一起看星星', price: 48, image: '' },
    ],
  };
  return products[shopId] || [];
}

module.exports = router;
