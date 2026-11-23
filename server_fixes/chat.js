// 私密聊天路由：消息加密存储、已读管理、自动匹配聊天对象
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { partnerId: currentPartnerId } = require('../utils/creation_access');
const { encrypt, decrypt } = require('../config/encrypt');
const { authRequired } = require('../middleware/auth');
const { getIO } = require('../utils/socket');

// ==================== GET /api/chat?page=&size= — 获取聊天记录（分页） ====================
// 只获取 sender_id 或 receiver_id 为当前用户的聊天，返回时解密内容
router.get('/', authRequired, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const size = parseInt(req.query.size) || 30;
    const offset = (page - 1) * size;

    const [messages] = await pool.query(
      `SELECT * FROM chat_messages
       WHERE (sender_id = ? OR receiver_id = ?)
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [req.user.id, req.user.id, size, offset]
    );

    const [totalResult] = await pool.query(
      `SELECT COUNT(*) as total FROM chat_messages
       WHERE sender_id = ? OR receiver_id = ?`,
      [req.user.id, req.user.id]
    );

    // 解密消息内容（已撤回的消息特殊处理）
    const data = messages.map(m => ({
      id: m.id,
      senderId: m.sender_id,
      receiverId: m.receiver_id,
      content: m.message_type === 'recalled' ? null : decrypt(m.content_encrypted),
      messageType: m.message_type,
      mediaUrl: m.media_url,
      replyToId: m.reply_to_id,
      quoteContent: m.quote_content ? decrypt(m.quote_content) : null,
      isRead: !!m.is_read,
      createdAt: m.created_at
    }));

    res.json({
      code: 200,
      data: {
        list: data,
        total: totalResult[0].total,
        page,
        size
      }
    });
  } catch (err) {
    console.error('获取聊天记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/chat — 发送消息（content 加密存储） ====================
// 默认为当前伴侣，独立账号可发给自己。
router.post('/', authRequired, async (req, res) => {
  try {
    const { receiverId: requestedReceiver, content, messageType, mediaUrl, replyToId, quoteContent } = req.body;

    if (!content) {
      return res.status(400).json({ code: 400, message: '请输入消息内容' });
    }

    const senderId = Number(req.user.id);
    const partner = await currentPartnerId(pool, senderId);
    const receiverId = requestedReceiver == null ? (partner ?? senderId) : Number(requestedReceiver);
    if (!Number.isSafeInteger(receiverId) || (receiverId !== senderId && receiverId !== partner)) {
      return res.status(403).json({ code: 403, message: '只能向当前伴侣发送消息' });
    }

    const [result] = await pool.query(
      'INSERT INTO chat_messages (sender_id, receiver_id, content_encrypted, message_type, media_url, reply_to_id, quote_content, is_read) VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
      [
        req.user.id,
        receiverId,
        encrypt(content),
        messageType || 'text',
        mediaUrl || null,
        replyToId || null,
        quoteContent ? encrypt(quoteContent) : null
      ]
    );

    // WebSocket 推送新消息通知
    const io = getIO();
    if (io) {
      io.to(`user:${receiverId}`).emit('new_message', {
        from: req.user.id,
        fromNickname: req.user.nickname,
        messagePreview: content.substring(0, 50)
      });
    }

    res.json({
      code: 200,
      message: '发送成功',
      data: {
        id: result.insertId,
        senderId: req.user.id,
        receiverId,
        content,
        messageType: messageType || 'text',
        replyToId: replyToId || null,
        quoteContent: quoteContent || null,
        createdAt: new Date().toISOString()
      }
    });
  } catch (err) {
    console.error('发送消息失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/chat/unread — 获取未读消息数 ====================
// receiver_id 为当前用户且 is_read=0 的计数
router.get('/unread', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      `SELECT COUNT(*) as count FROM chat_messages
       WHERE receiver_id = ? AND is_read = 0`,
      [req.user.id]
    );

    res.json({
      code: 200,
      data: { unreadCount: result[0].count }
    });
  } catch (err) {
    console.error('获取未读消息数失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/chat/read/:senderId — 标记某发送者的消息为已读 ====================
// 将指定 senderId 发给当前用户的所有消息标记 is_read=1
router.put('/read/:senderId', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      `UPDATE chat_messages SET is_read = 1
       WHERE receiver_id = ? AND sender_id = ? AND is_read = 0`,
      [req.user.id, req.params.senderId]
    );

    res.json({
      code: 200,
      message: '已标记为已读',
      data: { updated: result.affectedRows }
    });
  } catch (err) {
    console.error('标记已读失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/chat/:id — 撤回消息（2分钟内，仅发送者） ====================
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const msgId = parseInt(req.params.id);
    const [messages] = await pool.query(
      'SELECT * FROM chat_messages WHERE id = ? AND sender_id = ?',
      [msgId, req.user.id]
    );
    if (messages.length === 0) {
      return res.status(404).json({ code: 404, message: '消息不存在或无权操作' });
    }
    const msg = messages[0];
    const elapsed = (Date.now() - new Date(msg.created_at).getTime()) / 1000;
    if (elapsed > 120) {
      return res.status(400).json({ code: 400, message: '超过2分钟无法撤回' });
    }
    // 软删除：加密标记内容后存储，避免明文标记触发解密异常
    await pool.query(
      'UPDATE chat_messages SET content_encrypted = ?, message_type = ? WHERE id = ?',
      [encrypt('[RECALLED]'), 'recalled', msgId]
    );
    res.json({ code: 200, message: '消息已撤回' });
  } catch (err) {
    console.error('撤回消息失败:', err.message, err.stack);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/chat/perm/:id — 永久删除消息（仅发送者） ====================
router.delete('/perm/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM chat_messages WHERE id = ? AND sender_id = ?',
      [req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '消息不存在或无权操作' });
    }
    res.json({ code: 200, message: '消息已删除' });
  } catch (err) {
    console.error('永久删除消息失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/chat/search?keyword= — 搜索聊天记录 ====================
router.get('/search', authRequired, async (req, res) => {
  try {
    const { keyword } = req.query;
    if (!keyword) {
      return res.status(400).json({ code: 400, message: '请输入搜索关键词' });
    }
    const [messages] = await pool.query(
      `SELECT * FROM chat_messages
       WHERE (sender_id = ? OR receiver_id = ?)
       AND message_type = 'text'
       ORDER BY created_at DESC LIMIT 50`,
      [req.user.id, req.user.id]
    );
    // 解密后过滤包含关键词的消息
    const results = [];
    for (const m of messages) {
      if (m.content_encrypted === '[RECALLED]') continue;
      const decrypted = decrypt(m.content_encrypted);
      if (decrypted && decrypted.includes(keyword)) {
        results.push({
          id: m.id,
          senderId: m.sender_id,
          content: decrypted,
          createdAt: m.created_at,
          isMine: m.sender_id === req.user.id
        });
      }
    }
    res.json({ code: 200, data: { list: results.slice(0, 20) } });
  } catch (err) {
    console.error('搜索消息失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
