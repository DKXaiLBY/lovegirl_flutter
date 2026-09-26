const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { addBeanTransaction, todayString } = require('./utils/lovegirl_rewards');

function isoDate(value) {
  if (!value) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return String(value).slice(0, 10);
}

function daysUntilNext(eventDateValue) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const eventDate = new Date(eventDateValue);
  if (Number.isNaN(eventDate.getTime())) return { daysUntil: 0, years: 0 };
  const next = new Date(today.getFullYear(), eventDate.getMonth(), eventDate.getDate());
  next.setHours(0, 0, 0, 0);
  if (next < today) next.setFullYear(today.getFullYear() + 1);
  let years = today.getFullYear() - eventDate.getFullYear();
  const thisYear = new Date(today.getFullYear(), eventDate.getMonth(), eventDate.getDate());
  if (thisYear > today) years -= 1;
  return {
    daysUntil: Math.floor((next - today) / 86400000),
    years: Math.max(years, 0),
  };
}

async function rewardAnniversaryToday(userId, anniversaryId, title, eventDate) {
  if (isoDate(eventDate) !== todayString()) return;
  try {
    await addBeanTransaction(pool, {
      userId,
      amount: 20,
      type: 'anniversary_day',
      title: 'Anniversary day',
      sourceModule: 'anniversary',
      sourceId: anniversaryId,
      description: title,
    });
  } catch (err) {
    console.error('Anniversary bean reward failed:', err.message);
  }
}

router.get('/', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM anniversaries WHERE user_id = ? ORDER BY event_date ASC',
      [req.user.id]
    );
    const data = rows
      .map((item) => {
        const calc = daysUntilNext(item.event_date);
        return {
          id: item.id,
          title: item.title,
          eventDate: isoDate(item.event_date),
          icon: item.icon,
          daysUntil: calc.daysUntil,
          years: calc.years,
          description: item.description || '',
          type: item.type || 'custom',
          isLunar: item.is_lunar === 1 || item.is_lunar === true,
          repeatType: item.repeat_type || 'yearly',
          createdAt: item.created_at,
        };
      })
      .sort((a, b) => a.daysUntil - b.daysUntil);
    res.json({ code: 200, data });
  } catch (err) {
    console.error('List anniversaries failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/', authRequired, async (req, res) => {
  try {
    const { title, eventDate, icon, type, description, isLunar, repeatType } = req.body;
    if (!title || !eventDate) {
      return res.status(400).json({ code: 400, message: 'title and eventDate are required' });
    }
    const [result] = await pool.query(
      'INSERT INTO anniversaries (user_id, title, event_date, icon, type, description, is_lunar, repeat_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        req.user.id,
        title,
        eventDate,
        icon || 'heart',
        type || 'custom',
        description || '',
        isLunar === true || isLunar === 1 ? 1 : 0,
        repeatType || 'yearly',
      ]
    );
    await rewardAnniversaryToday(req.user.id, result.insertId, title, eventDate);
    res.json({ code: 200, message: 'created', data: { id: result.insertId } });
  } catch (err) {
    console.error('Create anniversary failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/:id', authRequired, async (req, res) => {
  try {
    const { title, eventDate, icon, type, description, isLunar, repeatType } = req.body;
    if (!title || !eventDate) {
      return res.status(400).json({ code: 400, message: 'title and eventDate are required' });
    }
    const [result] = await pool.query(
      'UPDATE anniversaries SET title = ?, event_date = ?, icon = ?, type = ?, description = ?, is_lunar = ?, repeat_type = ? WHERE id = ? AND user_id = ?',
      [
        title,
        eventDate,
        icon || 'heart',
        type || 'custom',
        description || '',
        isLunar === true || isLunar === 1 ? 1 : 0,
        repeatType || 'yearly',
        req.params.id,
        req.user.id,
      ]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'anniversary not found' });
    await rewardAnniversaryToday(req.user.id, req.params.id, title, eventDate);
    res.json({ code: 200, message: 'updated' });
  } catch (err) {
    console.error('Update anniversary failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.delete('/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM anniversaries WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'anniversary not found' });
    res.json({ code: 200, message: 'deleted' });
  } catch (err) {
    console.error('Delete anniversary failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

module.exports = router;
