const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { addBeanTransaction, awardBeans, checkAchievements, getCheckinStreak } = require('./utils/lovegirl_rewards');

router.get('/balance', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT bean_balance FROM users WHERE id = ?', [req.user.id]);
    res.json({ code: 200, data: { balance: rows[0]?.bean_balance || 0 } });
  } catch (err) {
    if (err.code === 'ER_BAD_FIELD_ERROR') {
      return res.json({ code: 200, data: { balance: 0 } });
    }
    console.error('[Beans] balance failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.get('/transactions', authRequired, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const size = Math.min(50, Math.max(1, parseInt(req.query.size) || 20));
    const offset = (page - 1) * size;
    const [rows] = await pool.query(
      `SELECT id, amount, balance_after, type, title, source_module, source_id,
              reference_id, description, created_at
       FROM bean_transactions
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [req.user.id, size, offset]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: [] });
    }
    console.error('[Beans] transactions failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

async function handleCheckIn(req, res) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await addBeanTransaction(conn, {
      userId: req.user.id,
      amount: 5,
      type: 'daily_check_in',
      title: '每日签到',
      sourceModule: 'home',
      description: '每日签到奖励',
      oncePerDay: true,
    });
    if (!result) {
      await conn.rollback();
      return res.status(400).json({ code: 400, message: '今天已经签到过啦' });
    }
    await conn.commit();
    const streak = await getCheckinStreak(req.user.id);
    let bonus = null;
    if (streak >= 7 && streak % 7 === 0) {
      bonus = await awardBeans({
        userId: req.user.id,
        amount: 15,
        type: 'daily_check_in_7_bonus',
        title: 'Seven-day check-in bonus',
        sourceModule: 'home',
        description: `check-in streak ${streak}`,
        oncePerDay: true,
      });
    }
    const unlocked = await checkAchievements(req.user.id, 'checkin');
    return res.json({ code: 200, message: 'check-in success, beans +5', data: { ...result, streak, bonus, unlocked } });
    res.json({ code: 200, message: '签到成功，爱心豆 +5', data: result });
  } catch (err) {
    await conn.rollback();
    console.error('[Beans] checkin failed:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '服务器错误' });
  } finally {
    conn.release();
  }
}

router.post('/checkin', authRequired, handleCheckIn);
router.post('/check-in', authRequired, handleCheckIn);

router.get('/checkin/status', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id FROM bean_transactions
       WHERE user_id = ? AND type = 'daily_check_in' AND DATE(created_at) = CURDATE()
       LIMIT 1`,
      [req.user.id]
    );
    const streak = await getCheckinStreak(req.user.id);
    const nextBonusIn = streak > 0 && streak % 7 === 0 ? 7 : 7 - (streak % 7);
    res.json({ code: 200, data: { checkedIn: rows.length > 0, reward: 5, streak, nextBonusIn } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { checkedIn: false, reward: 5 } });
    }
    console.error('[Beans] checkin status failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
