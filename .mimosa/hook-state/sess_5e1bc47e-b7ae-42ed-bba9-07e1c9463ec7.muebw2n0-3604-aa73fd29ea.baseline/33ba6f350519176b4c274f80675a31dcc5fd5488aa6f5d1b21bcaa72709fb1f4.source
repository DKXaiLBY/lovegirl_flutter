const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { safeDecrypt, todayString } = require('./utils/lovegirl_rewards');

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return String(value).slice(0, 10);
}

async function safeQuery(sql, params = [], fallback = []) {
  try {
    const [rows] = await pool.query(sql, params);
    return rows;
  } catch (err) {
    console.error('[Home] subquery failed:', err.message);
    return fallback;
  }
}

function sumEncryptedAmount(rows) {
  return rows.reduce((sum, row) => {
    const raw = safeDecrypt(row.amount_encrypted) || row.amount || '0';
    const value = Number(raw);
    return sum + (Number.isFinite(value) ? value : 0);
  }, 0);
}

router.get('/today', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const today = todayString();
    const weekday = new Date(`${today}T00:00:00`).getDay() || 7;

    const [users, todos, courses, moods, financeExpense, financeIncome, anniversaries, achievements] = await Promise.all([
      safeQuery('SELECT id, nickname, avatar_url, role, created_at, bean_balance FROM users WHERE id = ?', [userId], [{}]),
      safeQuery(
        `SELECT
           COUNT(*) AS total,
           SUM(completed = 0) AS active,
           SUM(completed = 0 AND due_date = ?) AS dueToday
         FROM todos WHERE user_id = ?`,
        [today, userId],
        [{ total: 0, active: 0, dueToday: 0 }]
      ),
      safeQuery(
        'SELECT * FROM courses WHERE user_id = ? AND day_of_week = ? ORDER BY start_time ASC',
        [userId, weekday],
        []
      ),
      safeQuery(
        'SELECT id, mood, note, record_date FROM mood_diary WHERE user_id = ? AND record_date = ? ORDER BY created_at DESC LIMIT 1',
        [userId, today],
        []
      ),
      safeQuery(
        "SELECT amount_encrypted FROM finance_records WHERE user_id = ? AND type = 'expense' AND record_date = ?",
        [userId, today],
        []
      ),
      safeQuery(
        "SELECT amount_encrypted FROM finance_records WHERE user_id = ? AND type = 'income' AND record_date = ?",
        [userId, today],
        []
      ),
      safeQuery('SELECT id, title, event_date, icon FROM anniversaries WHERE user_id = ?', [userId], []),
      safeQuery(
        `SELECT ua.unlocked_at, a.title, a.description, a.category, a.reward_beans
         FROM user_achievements ua
         JOIN achievements a ON a.id = ua.achievement_id
         WHERE ua.user_id = ?
         ORDER BY ua.unlocked_at DESC
         LIMIT 5`,
        [userId],
        []
      ),
    ]);

    const user = users[0] || {};
    const loveStart = user.created_at ? new Date(user.created_at) : new Date();
    const loveDays = Math.max(1, Math.floor((Date.now() - loveStart.getTime()) / 86400000) + 1);
    const anniversaryData = anniversaries
      .map((item) => {
        const eventDate = new Date(item.event_date);
        const now = new Date(`${today}T00:00:00`);
        const target = new Date(now.getFullYear(), eventDate.getMonth(), eventDate.getDate());
        target.setHours(0, 0, 0, 0);
        now.setHours(0, 0, 0, 0);
        if (target < now) target.setFullYear(target.getFullYear() + 1);
        return {
          id: item.id,
          title: item.title,
          eventDate: isoDate(item.event_date),
          icon: item.icon,
          daysUntil: Math.floor((target - now) / 86400000),
        };
      })
      .sort((a, b) => a.daysUntil - b.daysUntil);

    res.json({
      code: 200,
      data: {
        date: today,
        user: {
          id: user.id,
          nickname: user.nickname || '',
          avatarUrl: user.avatar_url || '',
          role: user.role || '',
        },
        loveDays,
        beanBalance: Number(user.bean_balance || 0),
        todo: {
          total: Number(todos[0]?.total || 0),
          active: Number(todos[0]?.active || 0),
          dueToday: Number(todos[0]?.dueToday || 0),
        },
        course: {
          count: courses.length,
          next: courses[0] || null,
          list: courses,
        },
        moodToday: moods[0] || null,
        financeToday: {
          expense: sumEncryptedAmount(financeExpense),
          income: sumEncryptedAmount(financeIncome),
        },
        anniversary: {
          today: anniversaryData.filter((item) => item.daysUntil === 0),
          upcoming: anniversaryData.filter((item) => item.daysUntil > 0 && item.daysUntil <= 30).slice(0, 3),
        },
        recentAchievements: achievements.map((a) => ({
          title: a.title,
          description: a.description,
          category: a.category,
          rewardBeans: Number(a.reward_beans || 0),
          unlockedAt: a.unlocked_at,
        })),
      },
    });
  } catch (err) {
    console.error('[Home] today failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/memory', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [timeline, travel, mood] = await Promise.all([
      safeQuery(
        'SELECT id, title, description, event_date, image_url, icon FROM love_timeline WHERE user_id = ? ORDER BY event_date DESC, id DESC LIMIT 20',
        [userId],
        []
      ),
      safeQuery(
        "SELECT id, name AS title, diary AS description, visited_date AS event_date, emoji AS icon FROM travel_spots WHERE user_id = ? AND status = 'visited' ORDER BY visited_date DESC, updated_at DESC LIMIT 20",
        [userId],
        []
      ),
      safeQuery(
        'SELECT id, mood AS title, note AS description, record_date AS event_date FROM mood_diary WHERE user_id = ? ORDER BY record_date DESC, id DESC LIMIT 20',
        [userId],
        []
      ),
    ]);

    const candidates = [...timeline, ...travel, ...mood].filter((item) => item && item.id);
    const item = candidates.length ? candidates[Math.floor(Math.random() * candidates.length)] : null;
    res.json({
      code: 200,
      data: item
        ? {
            id: item.id,
            title: item.title || '回忆票根',
            description: item.description || '',
            eventDate: isoDate(item.event_date),
            imageUrl: item.image_url || null,
            icon: item.icon || 'heart',
          }
        : null,
    });
  } catch (err) {
    console.error('[Home] memory failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
