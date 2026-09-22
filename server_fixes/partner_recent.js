const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { todayString, getPartnerId } = require('./utils/lovegirl_rewards');

// TA 的近况：聚合对方最近的动作（做饭/打卡/今日一问），首页展示"对方的存在感"
// 只读、轻量；心情等内容性隐私数据不进入此接口

router.get('/recent', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.json({ code: 200, data: { hasPartner: false, items: [] } });
    }

    const events = [];

    // 1. 最近一次下厨记录
    try {
      const [cooking] = await pool.query(
        'SELECT id, title, is_new, cooked_at, created_at FROM cooking_logs WHERE chef_id = ? ORDER BY id DESC LIMIT 1',
        [partnerId]
      );
      if (cooking.length > 0) {
        const r = cooking[0];
        events.push({
          type: 'cooking',
          icon: 'restaurant',
          text: `${r.is_new === 1 ? '尝试了新菜' : '下厨做了'}「${r.title}」`,
          at: r.cooked_at instanceof Date ? r.cooked_at.toISOString().slice(0, 10) : String(r.cooked_at).slice(0, 10),
          rank: r.created_at,
        });
      }
    } catch (_) {}

    // 2. 最近一次旅行打卡
    try {
      const [travel] = await pool.query(
        `SELECT id, name, visited_date FROM travel_spots
         WHERE COALESCE(created_by, user_id) = ? AND status = 'visited'
         ORDER BY COALESCE(visited_date, date(created_at)) DESC LIMIT 1`,
        [partnerId]
      );
      if (travel.length > 0) {
        const r = travel[0];
        events.push({
          type: 'travel',
          icon: 'map',
          text: `打卡了「${r.name}」`,
          at: r.visited_date instanceof Date ? r.visited_date.toISOString().slice(0, 10) : String(r.visited_date || '').slice(0, 10),
          rank: r.visited_date,
        });
      }
    } catch (_) {}

    // 3. 今日一问是否已答（只有"今天答了"才算动态）
    try {
      const today = todayString();
      const [daily] = await pool.query(
        'SELECT id, created_at FROM daily_answers WHERE user_id = ? AND question_date = ?',
        [partnerId, today]
      );
      if (daily.length > 0) {
        events.push({
          type: 'daily',
          icon: 'quiz',
          text: '已经交了今日一问的答卷',
          at: today,
          rank: daily[0].created_at,
        });
      }
    } catch (_) {}

    // 按时间倒序取 3 条
    events.sort((a, b) => new Date(b.rank || 0) - new Date(a.rank || 0));
    res.json({
      code: 200,
      data: { hasPartner: true, items: events.slice(0, 3) },
    });
  } catch (err) {
    console.error('[Partner] recent failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
