// 心情日记路由：记录每日心情，按月查看和统计
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { addBeanTransaction, checkAchievements, todayString } = require('./utils/lovegirl_rewards');

const moodLabels = ['开心', '幸福', '恋爱', '难过', '生气', '疲惫', '兴奋', '悠闲', '委屈', '烦躁'];

function formatDate(value) {
  if (!value) return '';
  if (value instanceof Date) return value.toISOString().split('T')[0];
  return String(value).split('T')[0];
}

function labelForMood(mood) {
  const index = Number.parseInt(mood, 10);
  if (Number.isInteger(index) && index >= 0 && index < moodLabels.length) {
    return moodLabels[index];
  }
  return String(mood || '');
}

function normalizeMoodPayload(body) {
  const mood = body.mood ?? body.moodEmoji ?? body.emoji;
  const note = body.note ?? body.content ?? '';
  const recordDate = body.recordDate ?? body.record_date ?? body.date;
  return {
    mood: mood === undefined || mood === null ? '' : String(mood),
    note,
    recordDate,
  };
}

// GET /api/mood?month=2024-06 - 获取当月心情
router.get('/', authRequired, async (req, res) => {
  try {
    const month = req.query.month || todayString().substring(0, 7);
    const [year, mon] = month.split('-');

    const [moods] = await pool.query(
      `SELECT * FROM mood_diary
       WHERE user_id = ? AND YEAR(record_date) = ? AND MONTH(record_date) = ?
       ORDER BY record_date DESC, created_at DESC`,
      [req.user.id, year, mon]
    );

    const data = moods.map(m => ({
      id: m.id,
      mood: m.mood,
      emoji: m.mood,
      label: labelForMood(m.mood),
      note: m.note,
      date: formatDate(m.record_date),
      recordDate: formatDate(m.record_date),
      createdAt: m.created_at
    }));

    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取心情记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/mood - 记录心情
router.post('/', authRequired, async (req, res) => {
  try {
    const { mood, note, recordDate } = normalizeMoodPayload(req.body);
    if (!mood) {
      return res.status(400).json({ code: 400, message: '请选择心情' });
    }

    const date = recordDate || todayString();

    // 同一天已存在心情则更新，否则新增（upsert 逻辑）
    const [existing] = await pool.query(
      'SELECT id FROM mood_diary WHERE user_id = ? AND record_date = ?',
      [req.user.id, date]
    );

    if (existing.length > 0) {
      await pool.query(
        'UPDATE mood_diary SET mood = ?, note = ? WHERE id = ?',
        [mood, note || '', existing[0].id]
      );
      res.json({ code: 200, message: '心情已更新', data: { id: existing[0].id } });
    } else {
      const [result] = await pool.query(
        'INSERT INTO mood_diary (user_id, mood, note, record_date) VALUES (?, ?, ?, ?)',
        [req.user.id, mood, note || '', date]
      );
      try {
        await addBeanTransaction(pool, {
          userId: req.user.id,
          amount: 2,
          type: 'mood_record',
          title: 'Mood recorded',
          sourceModule: 'mood',
          sourceId: result.insertId,
          description: date,
          oncePerDay: true,
        });
      } catch (err) {
        console.error('Mood bean reward failed:', err.message);
      }
      const unlocked = await checkAchievements(req.user.id, 'mood');
      return res.json({ code: 200, message: 'mood recorded', data: { id: result.insertId, unlocked } });
      res.json({ code: 200, message: '记录成功', data: { id: result.insertId } });
    }
  } catch (err) {
    console.error('记录心情失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/mood/stats - 心情统计（本月各 emoji 计数）
router.get('/stats', authRequired, async (req, res) => {
  try {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    const [rows] = await pool.query(
      `SELECT mood, COUNT(*) as count FROM mood_diary
       WHERE user_id = ? AND YEAR(record_date) = ? AND MONTH(record_date) = ?
       GROUP BY mood
       ORDER BY count DESC`,
      [req.user.id, year, month]
    );

    // 计算总记录天数
    const totalDays = rows.reduce((sum, r) => sum + r.count, 0);

    const stats = rows.map(r => ({
      mood: r.mood,
      count: r.count,
      percent: totalDays > 0 ? Math.round((r.count / totalDays) * 10000) / 100 : 0
    }));

    res.json({
      code: 200,
      data: {
        totalDays,
        stats
      }
    });
  } catch (err) {
    console.error('获取心情统计失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/mood/:id - 更新心情记录
router.put('/:id', authRequired, async (req, res) => {
  try {
    // 先验证 user_id 匹配
    const [records] = await pool.query(
      'SELECT id FROM mood_diary WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (records.length === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' });
    }

    const { mood, moodEmoji, content, weather, tags } = req.body;
    const updates = []; const params = [];
    // 兼容两种字段名：moodEmoji（新）或 mood（旧）
    if (moodEmoji !== undefined) { updates.push('mood=?'); params.push(moodEmoji); }
    else if (mood !== undefined) { updates.push('mood=?'); params.push(mood); }
    if (content !== undefined) { updates.push('note=?'); params.push(content); }
    if (weather !== undefined) { updates.push('weather=?'); params.push(weather); }
    if (tags !== undefined) { updates.push('tags=?'); params.push(JSON.stringify(tags)); }
    if (updates.length === 0) return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    params.push(req.params.id);
    await pool.query(`UPDATE mood_diary SET ${updates.join(',')} WHERE id=?`, params);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('更新心情失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// DELETE /api/mood/:id - 删除心情记录
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM mood_diary WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' });
    }
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除心情失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
