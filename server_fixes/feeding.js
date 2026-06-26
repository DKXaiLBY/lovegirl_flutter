/**
 * 投喂站路由 — 情侣虚拟送礼系统
 *
 * 数据表设计（需在MySQL中创建）：
 *
 * CREATE TABLE IF NOT EXISTS feeding_categories (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   name VARCHAR(50) NOT NULL,
 *   icon VARCHAR(10) DEFAULT '🎁',
 *   sort_order INT DEFAULT 0,
 *   is_active TINYINT(1) DEFAULT 1,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 *
 * CREATE TABLE IF NOT EXISTS feeding_products (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   category_id INT NOT NULL,
 *   name VARCHAR(100) NOT NULL,
 *   description TEXT,
 *   price INT NOT NULL DEFAULT 10 COMMENT '爱心豆价格',
 *   image VARCHAR(255),
 *   is_active TINYINT(1) DEFAULT 1,
 *   sort_order INT DEFAULT 0,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   FOREIGN KEY (category_id) REFERENCES feeding_categories(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 *
 * CREATE TABLE IF NOT EXISTS feeding_orders (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   sender_id INT NOT NULL,
 *   receiver_id INT DEFAULT NULL,
 *   product_id INT NOT NULL,
 *   product_name VARCHAR(100) NOT NULL,
 *   product_price INT NOT NULL DEFAULT 0,
 *   quantity INT NOT NULL DEFAULT 1,
 *   message TEXT,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   FOREIGN KEY (sender_id) REFERENCES users(id),
 *   FOREIGN KEY (product_id) REFERENCES feeding_products(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 */

const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

// ==================== 分类 ====================

// GET /api/feeding/categories
router.get('/categories', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, icon, sort_order FROM feeding_categories WHERE is_active = 1 ORDER BY sort_order ASC'
    );
    // 如果表不存在或无数据，返回默认分类
    if (rows.length === 0) {
      return res.json({
        code: 200,
        data: [
          { id: 1, name: '甜品', icon: '🍰', sort_order: 0 },
          { id: 2, name: '饮品', icon: '🧋', sort_order: 1 },
          { id: 3, name: '鲜花', icon: '🌹', sort_order: 2 },
          { id: 4, name: '零食', icon: '🍿', sort_order: 3 },
          { id: 5, name: '礼物', icon: '🎀', sort_order: 4 },
        ]
      });
    }
    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Feeding] 获取分类失败:', err.message);
    // 表不存在时返回默认数据
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({
        code: 200,
        data: [
          { id: 1, name: '甜品', icon: '🍰' },
          { id: 2, name: '饮品', icon: '🧋' },
          { id: 3, name: '鲜花', icon: '🌹' },
          { id: 4, name: '零食', icon: '🍿' },
          { id: 5, name: '礼物', icon: '🎀' },
        ]
      });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 商品 ====================

// GET /api/feeding/products?category_id=1
router.get('/products', authRequired, async (req, res) => {
  try {
    const categoryId = parseInt(req.query.category_id) || 0;
    if (!categoryId) {
      return res.status(400).json({ code: 400, message: '请提供category_id' });
    }

    const [rows] = await pool.query(
      'SELECT id, category_id, name, description, price, image FROM feeding_products WHERE category_id = ? AND is_active = 1 ORDER BY sort_order ASC',
      [categoryId]
    );

    if (rows.length === 0) {
      // 表不存在或无数据时返回默认商品
      const defaults = getDefaultProducts(categoryId);
      return res.json({ code: 200, data: defaults.length > 0 ? defaults : [] });
    }

    res.json({ code: 200, data: rows });
  } catch (err) {
    console.error('[Feeding] 获取商品失败:', err.message);
    if (err.code === 'ER_NO_SUCH_TABLE') {
      const defaults = getDefaultProducts(parseInt(req.query.category_id) || 0);
      return res.json({ code: 200, data: defaults });
    }
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 默认商品数据（表未创建时的回退）
function getDefaultProducts(categoryId) {
  const products = {
    1: [ // 甜品
      { id: 10001, category_id: 1, name: '草莓蛋糕', description: '新鲜草莓配上奶油蛋糕', price: 20, image: '' },
      { id: 10002, category_id: 1, name: '巧克力慕斯', description: '浓郁巧克力，入口即化', price: 25, image: '' },
      { id: 10003, category_id: 1, name: '马卡龙礼盒', description: '6枚精致法式马卡龙', price: 30, image: '' },
      { id: 10004, category_id: 1, name: '冰淇淋球', description: '双球哈根达斯', price: 15, image: '' },
      { id: 10005, category_id: 1, name: '甜甜圈', description: '彩色糖霜甜甜圈', price: 12, image: '' },
      { id: 10006, category_id: 1, name: '提拉米苏', description: '经典意式提拉米苏', price: 28, image: '' },
    ],
    2: [ // 饮品
      { id: 10101, category_id: 2, name: '珍珠奶茶', description: 'Q弹珍珠，甜蜜满分', price: 15, image: '' },
      { id: 10102, category_id: 2, name: '拿铁咖啡', description: '香浓拿铁，温暖TA的心', price: 18, image: '' },
      { id: 10103, category_id: 2, name: '水果茶', description: '满满维C，清爽一夏', price: 16, image: '' },
      { id: 10104, category_id: 2, name: '热可可', description: '冬日里的温暖拥抱', price: 14, image: '' },
      { id: 10105, category_id: 2, name: '星冰乐', description: '冰爽甜蜜，快乐加倍', price: 22, image: '' },
      { id: 10106, category_id: 2, name: '蜂蜜柚子茶', description: '养生又甜蜜', price: 12, image: '' },
    ],
    3: [ // 鲜花
      { id: 10201, category_id: 3, name: '红玫瑰花束', description: '99朵代表长长久久', price: 99, image: '' },
      { id: 10202, category_id: 3, name: '粉色康乃馨', description: '温馨浪漫，表达爱意', price: 50, image: '' },
      { id: 10203, category_id: 3, name: '向日葵', description: '你是我的太阳', price: 30, image: '' },
      { id: 10204, category_id: 3, name: '满天星', description: '星星点点的浪漫', price: 35, image: '' },
      { id: 10205, category_id: 3, name: '郁金香', description: '优雅的爱', price: 45, image: '' },
      { id: 10206, category_id: 3, name: '薰衣草', description: '等待爱情', price: 28, image: '' },
    ],
    4: [ // 零食
      { id: 10301, category_id: 4, name: '薯片大礼包', description: '追剧必备零食', price: 20, image: '' },
      { id: 10302, category_id: 4, name: '坚果混合装', description: '健康美味每一天', price: 25, image: '' },
      { id: 10303, category_id: 4, name: '巧克力棒', description: '能量满满的甜蜜', price: 10, image: '' },
      { id: 10304, category_id: 4, name: '果冻布丁', description: 'Q弹爽滑的甜蜜', price: 15, image: '' },
      { id: 10305, category_id: 4, name: '牛肉干', description: '咸香可口的零食', price: 28, image: '' },
      { id: 10306, category_id: 4, name: '小熊饼干', description: '可爱又美味', price: 12, image: '' },
    ],
    5: [ // 礼物
      { id: 10401, category_id: 5, name: '情侣手链', description: '刻上你们的名字', price: 88, image: '' },
      { id: 10402, category_id: 5, name: '泰迪熊', description: '软软的陪伴', price: 50, image: '' },
      { id: 10403, category_id: 5, name: '情侣戒指', description: '爱的承诺', price: 99, image: '' },
      { id: 10404, category_id: 5, name: '音乐盒', description: '播放你们的主题曲', price: 60, image: '' },
      { id: 10405, category_id: 5, name: '相册本', description: '珍藏美好回忆', price: 35, image: '' },
      { id: 10406, category_id: 5, name: '星空投影灯', description: '每晚一起看星星', price: 45, image: '' },
    ],
  };
  return products[categoryId] || [];
}

// ==================== 订单 ====================

// POST /api/feeding/orders — 创建投喂订单
router.post('/orders', authRequired, async (req, res) => {
  try {
    const senderId = req.user.id;
    const { product_id, quantity, message } = req.body;

    if (!product_id) {
      return res.status(400).json({ code: 400, message: '请选择要送出的商品' });
    }
    const qty = Math.max(1, Math.min(99, parseInt(quantity) || 1));

    // 查找商品信息
    let productName = '礼物';
    let productPrice = 10;
    try {
      const [products] = await pool.query('SELECT name, price FROM feeding_products WHERE id = ?', [product_id]);
      if (products.length > 0) {
        productName = products[0].name;
        productPrice = products[0].price;
      }
    } catch (_) {
      // 表不存在时用默认数据
      const allProducts = Object.values(getDefaultProducts(1))
        .concat(Object.values(getDefaultProducts(2)))
        .concat(Object.values(getDefaultProducts(3)))
        .concat(Object.values(getDefaultProducts(4)))
        .concat(Object.values(getDefaultProducts(5)));
      const found = allProducts.find(p => p.id == product_id);
      if (found) { productName = found.name; productPrice = found.price; }
    }

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
        'INSERT INTO feeding_orders (sender_id, receiver_id, product_id, product_name, product_price, quantity, message) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [senderId, receiverId, product_id, productName, productPrice, qty, message || '']
      );
      orderId = result.insertId;
    } catch (err) {
      if (err.code === 'ER_NO_SUCH_TABLE') {
        // 表不存在时仍返回成功（后续建表即可）
        console.log('[Feeding] feeding_orders 表尚未创建，订单仅记录日志');
      } else {
        throw err;
      }
    }

    console.log(`[Feeding] 订单#${orderId}: 用户${senderId} 送出 ${productName} x${qty} (${productPrice * qty}豆)`);

    res.json({
      code: 200,
      message: `已送出${productName}! TA会收到通知哦~`,
      data: {
        id: orderId,
        product_name: productName,
        product_price: productPrice,
        quantity: qty,
        total: productPrice * qty,
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
        `SELECT o.id, o.sender_id, o.receiver_id, o.product_id, o.product_name, o.product_price, o.quantity, o.message, o.created_at,
                s.nickname AS sender_name, s.avatar AS sender_avatar,
                r.nickname AS receiver_name
         FROM feeding_orders o
         LEFT JOIN users s ON o.sender_id = s.id
         LEFT JOIN users r ON o.receiver_id = r.id
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
    }));

    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    console.error('[Feeding] 获取订单失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== 统计 ====================

// GET /api/feeding/stats
router.get('/stats', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    let totalSent = 0, totalReceived = 0, lastFeedingTime = '';

    try {
      // 已送出（我发出的）
      const [sentRows] = await pool.query(
        'SELECT COUNT(*) AS cnt FROM feeding_orders WHERE sender_id = ?', [userId]
      );
      totalSent = sentRows[0]?.cnt || 0;

      // 收到的（伴侣发给我的）
      const [recvRows] = await pool.query(
        'SELECT COUNT(*) AS cnt FROM feeding_orders WHERE receiver_id = ?', [userId]
      );
      totalReceived = recvRows[0]?.cnt || 0;

      // 最近一次投喂时间
      const [lastRows] = await pool.query(
        'SELECT created_at FROM feeding_orders WHERE sender_id = ? OR receiver_id = ? ORDER BY created_at DESC LIMIT 1',
        [userId, userId]
      );
      if (lastRows.length > 0 && lastRows[0].created_at) {
        const d = new Date(lastRows[0].created_at);
        lastFeedingTime = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      }
    } catch (err) {
      if (err.code !== 'ER_NO_SUCH_TABLE') throw err;
    }

    res.json({
      code: 200,
      data: {
        total_sent: totalSent,
        total_received: totalReceived,
        last_feeding_time: lastFeedingTime,
      }
    });
  } catch (err) {
    console.error('[Feeding] 获取统计失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
