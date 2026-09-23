const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { getPartnerId } = require('./utils/lovegirl_rewards');

// 年度恋爱报告：纯 SQL 聚合既有业务表（Wrapped 式总结页）

async function rows(sql, params) {
  const [r] = await pool.query(sql, params);
  return r;
}

router.get('/', authRequired, async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    if (year < 2000 || year > 2100) {
      return res.status(400).json({ code: 400, message: '年份不合法' });
    }
    const partnerId = await getPartnerId(req.user.id);
    const userIds = partnerId != null ? [req.user.id, partnerId] : [req.user.id];
    const inPh = userIds.map(() => '?').join(',');
    const yStart = `${year}-01-01`;
    const yEnd = `${year + 1}-01-01`;

    // 旅行：今年去过的地点 / 城市
    const travelRows = await rows(
      `SELECT COUNT(DISTINCT name) AS spots,
              COUNT(DISTINCT CASE WHEN city IS NOT NULL AND city != '' THEN city END) AS cities
       FROM travel_spots
       WHERE user_id IN (${inPh}) AND status='visited'
         AND visited_date >= ? AND visited_date < ?`,
      [...userIds, yStart, yEnd]
    );

    // 厨房：今年订单 / 完成 / ta 做给我的
    const kitchenRows = await rows(
      `SELECT COUNT(*) AS total,
              COALESCE(SUM(status='done'),0) AS done,
              COALESCE(SUM(orderer_id = ? AND status='done'),0) AS fedMe
       FROM kitchen_orders
       WHERE (orderer_id IN (${inPh}) OR cook_id IN (${inPh}))
         AND created_at >= ? AND created_at < ?`,
      [req.user.id, ...userIds, ...userIds, yStart, yEnd]
    );

    // 最常点的菜（订单首个菜近似）
    let topDish = null;
    try {
      const t = await rows(
        `SELECT d.name AS name, COUNT(*) AS n
         FROM kitchen_orders o
         JOIN kitchen_dishes d
           ON JSON_UNQUOTE(JSON_EXTRACT(o.items, '$[0].dish_id')) = CAST(d.id AS CHAR)
         WHERE o.created_at >= ? AND o.created_at < ?
         GROUP BY d.name ORDER BY n DESC LIMIT 1`,
        [yStart, yEnd]
      );
      topDish = t.length > 0 ? t[0].name : null;
    } catch (_) {}

    // 每日一问：今年双方都答的天数
    const dailyRows = await rows(
      `SELECT COUNT(*) AS days FROM (
         SELECT question_date FROM daily_answers
         WHERE user_id IN (${inPh}) AND question_date >= ? AND question_date < ?
         GROUP BY question_date HAVING COUNT(DISTINCT user_id) = ?
       ) t`,
      [...userIds, yStart, yEnd, userIds.length]
    );

    // 爱心豆：今年两人总获得
    const beanRows = await rows(
      `SELECT COALESCE(SUM(amount),0) AS earned
       FROM bean_transactions
       WHERE user_id IN (${inPh}) AND amount > 0
         AND created_at >= ? AND created_at < ?`,
      [...userIds, yStart, yEnd]
    );

    // 相册照片 / 时光轴 / 慢信
    const photoRows = await rows(
      `SELECT COUNT(*) AS n FROM photos
       WHERE user_id IN (${inPh}) AND created_at >= ? AND created_at < ?`,
      [...userIds, yStart, yEnd]
    );
    const timelineRows = await rows(
      `SELECT COUNT(*) AS n FROM love_timeline
       WHERE user_id IN (${inPh}) AND event_date >= ? AND event_date < ?`,
      [...userIds, yStart, yEnd]
    );
    const letterRows = await rows(
      `SELECT COUNT(*) AS n FROM slow_letters
       WHERE (sender_id IN (${inPh}) OR receiver_id IN (${inPh}))
         AND created_at >= ? AND created_at < ?`,
      [...userIds, ...userIds, yStart, yEnd]
    );

    // 最活跃月份（厨房订单 + 旅行打卡 + 时光轴）
    let busiestMonth = null;
    try {
      const m = await rows(
        `SELECT month, SUM(c) AS total FROM (
           SELECT MONTH(created_at) AS month, COUNT(*) AS c FROM kitchen_orders
           WHERE created_at >= ? AND created_at < ? GROUP BY month
           UNION ALL
           SELECT MONTH(visited_date), COUNT(*) FROM travel_spots
           WHERE status='visited' AND visited_date >= ? AND visited_date < ? GROUP BY MONTH(visited_date)
           UNION ALL
           SELECT MONTH(event_date), COUNT(*) FROM love_timeline
           WHERE event_date >= ? AND event_date < ? GROUP BY MONTH(event_date)
         ) s GROUP BY month ORDER BY total DESC LIMIT 1`,
        [yStart, yEnd, yStart, yEnd, yStart, yEnd]
      );
      if (m.length > 0) {
        const names = ['', '一月', '二月', '三月', '四月', '五月', '六月',
          '七月', '八月', '九月', '十月', '十一月', '十二月'];
        busiestMonth = names[m[0].month] || null;
      }
    } catch (_) {}

    res.json({
      code: 200,
      data: {
        year,
        hasPartner: partnerId != null,
        travel: {
          spots: travelRows[0]?.spots || 0,
          cities: travelRows[0]?.cities || 0,
        },
        kitchen: {
          orders: kitchenRows[0]?.total || 0,
          done: Number(kitchenRows[0]?.done || 0),
          fedMe: Number(kitchenRows[0]?.fedMe || 0),
          topDish,
        },
        dailyDays: dailyRows[0]?.days || 0,
        beansEarned: Number(beanRows[0]?.earned || 0),
        photos: photoRows[0]?.n || 0,
        timelineEvents: timelineRows[0]?.n || 0,
        letters: letterRows[0]?.n || 0,
        busiestMonth,
      },
    });
  } catch (err) {
    console.error('[Report] failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
