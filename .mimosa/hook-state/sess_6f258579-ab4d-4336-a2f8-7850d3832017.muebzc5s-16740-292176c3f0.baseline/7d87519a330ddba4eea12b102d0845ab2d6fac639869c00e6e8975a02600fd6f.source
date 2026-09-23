const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { ensureAchievementsSeeded, checkAchievements } = require('./utils/lovegirl_rewards');

function progressFor(row) {
  if (row.code && row.code.startsWith('travel_city_')) return Number(row.travel_city_progress || 0);
  return Number(row.category_progress || 0);
}

router.get('/', authRequired, async (req, res) => {
  try {
    await ensureAchievementsSeeded(pool);
    await checkAchievements(req.user.id);
    const [rows] = await pool.query(
      `SELECT a.id, a.code, a.category, a.title, a.description, a.target_value, a.reward_beans,
              ua.progress, ua.unlocked_at,
              CASE
                WHEN a.category = 'travel' THEN (
                  SELECT COUNT(*) FROM travel_spots
                  WHERE COALESCE(created_by, user_id) = ? AND status = 'visited'
                )
                WHEN a.category = 'feeding' THEN (
                  SELECT COUNT(*) FROM feeding_orders
                  WHERE receiver_id = ? AND status = 'completed'
                )
                WHEN a.category = 'mood' THEN (
                  SELECT COUNT(*) FROM mood_diary WHERE user_id = ?
                )
                WHEN a.category = 'checkin' THEN (
                  SELECT COUNT(DISTINCT DATE(created_at)) FROM bean_transactions
                  WHERE user_id = ? AND type = 'daily_check_in'
                )
                ELSE 0
              END AS category_progress,
              (
                SELECT COUNT(DISTINCT NULLIF(city, '')) FROM travel_spots
                WHERE COALESCE(created_by, user_id) = ? AND status = 'visited'
              ) AS travel_city_progress
       FROM achievements a
       LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ?
       WHERE a.is_active = 1
       ORDER BY a.category ASC, a.target_value ASC, a.id ASC`,
      [req.user.id, req.user.id, req.user.id, req.user.id, req.user.id, req.user.id]
    );
    const list = rows.map((row) => {
      const progress = Math.max(Number(row.progress || 0), progressFor(row));
      return {
        id: row.id,
        code: row.code,
        category: row.category,
        title: row.title,
        description: row.description,
        target: Number(row.target_value || 0),
        progress,
        rewardBeans: Number(row.reward_beans || 0),
        unlocked: !!row.unlocked_at,
        unlockedAt: row.unlocked_at || null,
      };
    });
    res.json({
      code: 200,
      data: {
        list,
        unlocked: list.filter((item) => item.unlocked).length,
        total: list.length,
      },
    });
  } catch (err) {
    console.error('[Achievements] list failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/check', authRequired, async (req, res) => {
  try {
    const unlocked = await checkAchievements(req.user.id, req.body?.category || req.query.category || null);
    res.json({ code: 200, data: { unlocked } });
  } catch (err) {
    console.error('[Achievements] check failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

module.exports = router;
