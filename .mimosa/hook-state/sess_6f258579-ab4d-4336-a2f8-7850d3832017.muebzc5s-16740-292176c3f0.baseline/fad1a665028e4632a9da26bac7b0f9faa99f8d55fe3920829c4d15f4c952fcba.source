const express = require('express');

const router = express.Router();
const pool = require('../config/database');
const { decrypt, encrypt } = require('../config/encrypt');
const { authRequired } = require('../middleware/auth');

function safeDecrypt(value) {
  try {
    return decrypt(value);
  } catch (_) {
    return typeof value === 'string' ? value : '';
  }
}

async function resolvePartnerId(user) {
  const userId = user.id;

  const [couples] = await pool.query(
    `SELECT user1_id, user2_id
     FROM couples
     WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'
     LIMIT 1`,
    [userId, userId]
  );
  if (couples.length > 0) {
    const couple = couples[0];
    return couple.user1_id === userId ? couple.user2_id : couple.user1_id;
  }

  if (user.role === 'boy' || user.role === 'girl') {
    const partnerRole = user.role === 'boy' ? 'girl' : 'boy';
    const [users] = await pool.query(
      'SELECT id FROM users WHERE role = ? AND id != ? ORDER BY id ASC LIMIT 1',
      [partnerRole, userId]
    );
    if (users.length > 0) return users[0].id;
  }

  return null;
}

router.get('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const partnerId = await resolvePartnerId(req.user);
    if (!partnerId) {
      return res.json({ code: 200, data: [] });
    }

    const page = Math.max(1, parseInt(req.query.page || '1', 10) || 1);
    const size = Math.min(50, Math.max(1, parseInt(req.query.size || '20', 10) || 20));
    const offset = (page - 1) * size;

    const [rows] = await pool.query(
      `SELECT id, sender_id, receiver_id, content_encrypted, message_type, media_url, is_read, created_at
       FROM chat_messages
       WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
       ORDER BY created_at DESC, id DESC
       LIMIT ? OFFSET ?`,
      [userId, partnerId, partnerId, userId, size, offset]
    );

    await pool.query(
      'UPDATE chat_messages SET is_read = 1 WHERE sender_id = ? AND receiver_id = ? AND is_read = 0',
      [partnerId, userId]
    );

    const data = rows.map((row) => ({
      id: row.id,
      content: safeDecrypt(row.content_encrypted),
      type: row.message_type || 'text',
      mediaUrl: row.media_url || null,
      is_mine: row.sender_id === userId,
      isMine: row.sender_id === userId,
      isRead: !!row.is_read,
      created_at: row.created_at,
      createdAt: row.created_at,
      senderId: row.sender_id,
      receiverId: row.receiver_id,
    }));

    res.json({ code: 200, data });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: [] });
    }
    console.error('[Chat] list failed:', err);
    res.status(500).json({ code: 500, message: '加载消息失败' });
  }
});

router.post('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const partnerId = await resolvePartnerId(req.user);
    const content = String(req.body.content || '').trim();

    if (!partnerId) {
      return res.status(400).json({ code: 400, message: '还没有可发送消息的伴侣' });
    }
    if (!content) {
      return res.status(400).json({ code: 400, message: '消息内容不能为空' });
    }

    const [result] = await pool.query(
      `INSERT INTO chat_messages
       (sender_id, receiver_id, content_encrypted, message_type, media_url, is_read)
       VALUES (?, ?, ?, 'text', NULL, 0)`,
      [userId, partnerId, encrypt(content)]
    );

    res.json({
      code: 200,
      message: '发送成功',
      data: {
        id: result.insertId,
        content,
        is_mine: true,
        isMine: true,
        created_at: new Date().toISOString(),
      },
    });
  } catch (err) {
    console.error('[Chat] send failed:', err);
    res.status(500).json({ code: 500, message: '发送失败，请稍后重试' });
  }
});

router.get('/unread', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      'SELECT COUNT(*) AS total FROM chat_messages WHERE receiver_id = ? AND is_read = 0',
      [userId]
    );
    res.json({
      code: 200,
      data: {
        unread: Number(rows[0]?.total || 0),
      },
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { unread: 0 } });
    }
    console.error('[Chat] unread failed:', err);
    res.status(500).json({ code: 500, message: '读取未读数失败' });
  }
});

module.exports = router;
