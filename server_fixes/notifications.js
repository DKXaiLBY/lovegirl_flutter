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

router.get('/unread-count', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT COUNT(*) AS count FROM notifications WHERE user_id = ? AND read_at IS NULL',
      [req.user.id]
    );
    res.json({ code: 200, data: { count: rows[0].count } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { count: 0 } });
    }
    console.error('[Notifications] 未读数查询失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/read-all', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'UPDATE notifications SET read_at = NOW() WHERE user_id = ? AND read_at IS NULL',
      [req.user.id]
    );
    res.json({ code: 200, message: '全部已读', data: { updated: result.affectedRows } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, message: '全部已读', data: { updated: 0 } });
    }
    console.error('[Notifications] 全部已读失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.put('/:id/read', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ code: 400, message: '无效的通知 ID' });
    }
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
