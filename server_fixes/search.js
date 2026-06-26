/**
 * 全站搜索路由
 *
 * 支持搜索：旅行足迹、待办事项、记账记录、心情日记、聊天记录、时光轴事件
 * 参数：keyword (必填)
 * 返回：按类型分组的搜索结果列表
 */

const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

// GET /api/search?keyword=xxx
router.get('/', authRequired, async (req, res) => {
  try {
    const keyword = (req.query.keyword || '').trim();
    if (!keyword || keyword.length < 2) {
      return res.status(400).json({ code: 400, message: '请输入至少2个字符的关键词' });
    }

    const userId = req.user.id;
    const like = `%${keyword}%`;
    const results = [];

    // 并行搜索所有模块
    const searches = [
      // 1. 旅行足迹
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, name AS title, city AS subtitle, 'travel' AS type, status
             FROM travel_spots WHERE (name LIKE ? OR city LIKE ? OR diary LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 2. 待办事项
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, title, description AS subtitle, 'todo' AS type, status
             FROM todos WHERE (title LIKE ? OR description LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 3. 记账记录
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, CONCAT(category, ' - ', note) AS title, CONCAT('¥', amount) AS subtitle, 'finance' AS type
             FROM finance_records WHERE (note LIKE ? OR category LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 4. 心情日记
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, label AS title, note AS subtitle, 'mood' AS type
             FROM moods WHERE (label LIKE ? OR note LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 5. 聊天记录
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, content AS title, '' AS subtitle, 'chat' AS type
             FROM chat_messages WHERE content LIKE ? AND (sender_id = ? OR receiver_id = ?)
             ORDER BY created_at DESC LIMIT 10`,
            [like, userId, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 6. 时光轴
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, title, description AS subtitle, 'timeline' AS type
             FROM timeline_events WHERE (title LIKE ? OR description LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 7. 投喂记录
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT o.id, o.product_name AS title, o.message AS subtitle, 'feeding' AS type
             FROM feeding_orders o WHERE (o.product_name LIKE ? OR o.message LIKE ?)
             AND (o.sender_id = ? OR o.receiver_id = ?)
             LIMIT 10`,
            [like, like, userId, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),

      // 8. 课程表
      (async () => {
        try {
          const [rows] = await pool.query(
            `SELECT id, name AS title, CONCAT(day_of_week, ' ', time_slot) AS subtitle, 'course' AS type
             FROM courses WHERE (name LIKE ? OR teacher LIKE ?) AND user_id = ?
             LIMIT 10`,
            [like, like, userId]
          );
          return rows;
        } catch (_) { return []; }
      })(),
    ];

    const allResults = await Promise.all(searches);

    // 合并结果
    allResults.forEach(rows => {
      if (rows && rows.length > 0) {
        results.push(...rows);
      }
    });

    console.log(`[Search] 用户${userId} 搜索"${keyword}" → ${results.length}条结果`);

    res.json({
      code: 200,
      data: results,
      meta: {
        keyword,
        total: results.length,
        types: [...new Set(results.map(r => r.type))],
      }
    });
  } catch (err) {
    console.error('[Search] 搜索失败:', err);
    res.status(500).json({ code: 500, message: '搜索失败，请稍后重试' });
  }
});

module.exports = router;
