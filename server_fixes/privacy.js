// 隐私设置路由
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

// GET /api/privacy — 获取当前隐私设置
router.get('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      'SELECT * FROM user_privacy WHERE user_id = ?', [userId]
    );
    const settings = rows[0] || {
      photo_visible: true,
      mood_visible: true,
      travel_visible: true,
      chat_visible: true
    };
    res.json({ code: 200, data: settings });
  } catch (err) {
    console.error('获取隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/privacy — 更新隐私设置
router.put('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const { photo_visible, mood_visible, travel_visible, chat_visible } = req.body;

    const [existing] = await pool.query('SELECT id FROM user_privacy WHERE user_id = ?', [userId]);
    if (existing.length > 0) {
      await pool.query(
        `UPDATE user_privacy SET
         photo_visible = COALESCE(?, photo_visible),
         mood_visible = COALESCE(?, mood_visible),
         travel_visible = COALESCE(?, travel_visible),
         chat_visible = COALESCE(?, chat_visible)
         WHERE user_id = ?`,
        [photo_visible, mood_visible, travel_visible, chat_visible, userId]
      );
    } else {
      await pool.query(
        `INSERT INTO user_privacy (user_id, photo_visible, mood_visible, travel_visible, chat_visible)
         VALUES (?, ?, ?, ?, ?)`,
        [userId, photo_visible ?? true, mood_visible ?? true, travel_visible ?? true, chat_visible ?? true]
      );
    }

    const [updated] = await pool.query('SELECT * FROM user_privacy WHERE user_id = ?', [userId]);
    res.json({ code: 200, data: updated[0], message: '隐私设置已更新' });
  } catch (err) {
    console.error('更新隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/privacy/check?type=photo|mood|travel|chat&partner_id=xxx
// 检查对方是否允许访问某类数据（需验证伴侣关系）
router.get('/check', authRequired, async (req, res) => {
  try {
    const { type, partner_id } = req.query;
    if (!type || !partner_id) {
      return res.status(400).json({ code: 400, message: '缺少参数' });
    }

    // 验证伴侣关系
    const userId = req.user.id;
    const [coupleRows] = await pool.query(
      "SELECT id FROM couples WHERE ((user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)) AND status = 'active'",
      [userId, partner_id, partner_id, userId]
    );
    if (coupleRows.length === 0) {
      return res.status(403).json({ code: 403, message: '无权访问对方隐私设置' });
    }

    const [rows] = await pool.query('SELECT * FROM user_privacy WHERE user_id = ?', [partner_id]);
    const setting = rows[0] || {};
    const fieldMap = { photo: 'photo_visible', mood: 'mood_visible', travel: 'travel_visible', chat: 'chat_visible' };
    const field = fieldMap[type];
    if (!field) return res.status(400).json({ code: 400, message: '无效的类型' });
    res.json({ code: 200, data: { visible: setting[field] !== false } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      // couples 表不存在时放行（向后兼容）
      const { partner_id, type } = req.query;
      const [rows] = await pool.query('SELECT * FROM user_privacy WHERE user_id = ?', [partner_id]);
      const setting = rows[0] || {};
      const fieldMap = { photo: 'photo_visible', mood: 'mood_visible', travel: 'travel_visible', chat: 'chat_visible' };
      const field = fieldMap[type];
      return res.json({ code: 200, data: { visible: setting[field] !== false } });
    }
    console.error('检查隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
