const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { todayString, getPartnerId } = require('./utils/lovegirl_rewards');

// 慢信：写给对方的信，指定日期才解锁（时间胶囊）

function addDays(dateStr, delta) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}

function dateToStr(v) {
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).slice(0, 10);
}

async function partnerNameOf(partnerId) {
  const [u] = await pool.query('SELECT nickname FROM users WHERE id = ?', [partnerId]);
  return u.length > 0 ? u[0].nickname : null;
}

function isValidDate(s) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(s)) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
}

// 收件箱 + 寄出箱
router.get('/list', authRequired, async (req, res) => {
  try {
    const today = todayString();
    const [inbox] = await pool.query(
      `SELECT id, sender_id, title, unlock_date, read_at, created_at
       FROM slow_letters WHERE receiver_id = ?
       ORDER BY unlock_date ASC LIMIT 60`,
      [req.user.id]
    );
    const [outbox] = await pool.query(
      `SELECT id, receiver_id, title, unlock_date, read_at, created_at
       FROM slow_letters WHERE sender_id = ?
       ORDER BY created_at DESC LIMIT 60`,
      [req.user.id]
    );

    const mapLetter = (r, isSender) => {
      const unlock = dateToStr(r.unlock_date);
      const unlocked = unlock <= today;
      return {
        id: r.id,
        title: r.title,
        unlockDate: unlock,
        unlocked,
        // 收件方：已解锁未读才算未读；寄出方：看对方是否已读
        unread: isSender ? false : unlocked && r.read_at == null,
        readByPartner: isSender ? r.read_at != null : null,
        createdAt: dateToStr(r.created_at),
      };
    };

    res.json({
      code: 200,
      data: {
        inbox: inbox.map((r) => mapLetter(r, false)),
        outbox: outbox.map((r) => mapLetter(r, true)),
        today,
      },
    });
  } catch (err) {
    console.error('[Letter] list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 读信（到期才可读；读即标已读）
router.get('/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const [rows] = await pool.query(
      'SELECT * FROM slow_letters WHERE id = ? AND (receiver_id = ? OR sender_id = ?)',
      [id, req.user.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: '信不存在' });
    }
    const letter = rows[0];
    const isReceiver = letter.receiver_id === req.user.id;
    const unlock = dateToStr(letter.unlock_date);
    const unlocked = unlock <= todayString();

    // 寄出人可以看自己写的内容（寄出的信在到期前对寄件人可见——自己写的当然能看）
    if (isReceiver && !unlocked) {
      return res.status(403).json({
        code: 403,
        message: '还没到解锁的日子',
        data: { unlockDate: unlock },
      });
    }

    if (isReceiver && letter.read_at == null) {
      await pool.query('UPDATE slow_letters SET read_at = NOW() WHERE id = ?', [id]);
    }

    const senderName = await partnerNameOf(letter.sender_id);
    res.json({
      code: 200,
      data: {
        id: letter.id,
        title: letter.title,
        content: letter.content,
        unlockDate: unlock,
        unlocked,
        senderName,
        isReceiver,
        readAt: isReceiver ? (letter.read_at || new Date().toISOString()) : letter.read_at,
        createdAt: dateToStr(letter.created_at),
      },
    });
  } catch (err) {
    console.error('[Letter] read failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 写信（解锁日必须 >= 明天）
router.post('/', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.status(400).json({ code: 400, message: '先绑定伴侣，把信寄给 TA' });
    }
    const title = String(req.body.title ?? '').trim() || '一封慢信';
    const content = String(req.body.content ?? '').trim();
    const unlockDate = String(req.body.unlockDate ?? '');

    if (!content) return res.status(400).json({ code: 400, message: '信的内容不能为空' });
    if (content.length > 5000) return res.status(400).json({ code: 400, message: '信太长了（5000字以内）' });
    if (title.length > 100) return res.status(400).json({ code: 400, message: '标题太长了' });
    if (!isValidDate(unlockDate)) return res.status(400).json({ code: 400, message: '解锁日期格式不对' });

    const tomorrow = addDays(todayString(), 1);
    if (unlockDate < tomorrow) {
      return res.status(400).json({ code: 400, message: '慢信至少要等到明天才解锁哦' });
    }

    const [result] = await pool.query(
      `INSERT INTO slow_letters (sender_id, receiver_id, title, content, unlock_date)
       VALUES (?, ?, ?, ?, ?)`,
      [req.user.id, partnerId, title, content, unlockDate]
    );

    try {
      await pool.query(
        'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
        [partnerId, 'slow_letter', '收到一封慢信', `要等到 ${unlockDate} 才能拆开`, JSON.stringify({ letter_id: result.insertId })]
      );
    } catch (err) {
      console.error('[Letter] notify failed:', err.message);
    }

    res.json({ code: 200, data: { id: result.insertId } });
  } catch (err) {
    console.error('[Letter] create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
