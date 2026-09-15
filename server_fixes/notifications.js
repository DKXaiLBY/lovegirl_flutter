const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

router.get('/', authRequired, async (req, res) => {
  try {
    const size = Math.min(50, Math.max(1, parseInt(req.query.size) || 20));
    const [rows] = await pool.query(
      `SELECT id, type, title, content, payload, read_at, created_at
       FROM notifications
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT ?`,
      [req.user.id, size]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: [] });
    }
    console.error('[Notifications] 查询失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/:id/read', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const [result] = await pool.query(
      'UPDATE notifications SET read_at = NOW() WHERE id = ? AND user_id = ?',
      [id, req.user.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '通知不存在' });
    }
    res.json({ code: 200, message: '已读' });
  } catch (err) {
    console.error('[Notifications] 标记已读失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
