/**
 * 伴侣绑定路由 — 邀请码绑定系统
 *
 * 数据表：
 * CREATE TABLE IF NOT EXISTS couples (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   user1_id INT NOT NULL,
 *   user2_id INT NOT NULL,
 *   status VARCHAR(20) DEFAULT 'active' COMMENT 'active/broken',
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   broken_at DATETIME DEFAULT NULL,
 *   UNIQUE KEY uk_user1 (user1_id),
 *   UNIQUE KEY uk_user2 (user2_id),
 *   FOREIGN KEY (user1_id) REFERENCES users(id),
 *   FOREIGN KEY (user2_id) REFERENCES users(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 *
 * CREATE TABLE IF NOT EXISTS couple_invites (
 *   id INT AUTO_INCREMENT PRIMARY KEY,
 *   code VARCHAR(6) NOT NULL UNIQUE,
 *   creator_id INT NOT NULL,
 *   expires_at DATETIME NOT NULL,
 *   used TINYINT(1) DEFAULT 0,
 *   used_by INT DEFAULT NULL,
 *   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   FOREIGN KEY (creator_id) REFERENCES users(id)
 * ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 */

const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

// 生成6位随机邀请码
function generateCode() {
  return Math.random().toString().slice(2, 8).padStart(6, '0');
}

// GET /api/couple — 获取当前绑定状态
router.get('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;

    // 查询绑定关系
    const [rows] = await pool.query(
      `SELECT c.id, c.user1_id, c.user2_id, c.created_at,
              u1.nickname AS user1_name, u1.avatar_url AS user1_avatar, u1.role AS user1_role,
              u2.nickname AS user2_name, u2.avatar_url AS user2_avatar, u2.role AS user2_role
       FROM couples c
       JOIN users u1 ON c.user1_id = u1.id
       JOIN users u2 ON c.user2_id = u2.id
       WHERE (c.user1_id = ? OR c.user2_id = ?) AND c.status = 'active'`,
      [userId, userId]
    );

    if (rows.length === 0) {
      return res.json({ code: 200, data: { coupled: false } });
    }

    const couple = rows[0];
    const isUser1 = couple.user1_id === userId;
    const partner = {
      id: isUser1 ? couple.user2_id : couple.user1_id,
      nickname: isUser1 ? couple.user2_name : couple.user1_name,
      avatar: isUser1 ? couple.user2_avatar : couple.user1_avatar,
      role: isUser1 ? couple.user2_role : couple.user1_role,
    };

    res.json({
      code: 200,
      data: {
        coupled: true,
        couple_id: couple.id,
        partner,
        coupled_at: couple.created_at,
      }
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { coupled: false } });
    }
    console.error('[Couple] 查询绑定状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/couple/invite — 生成邀请码
router.post('/invite', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;

    // 检查是否已绑定
    const [existing] = await pool.query(
      "SELECT id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'",
      [userId, userId]
    );
    if (existing.length > 0) {
      return res.status(400).json({ code: 400, message: '你已经绑定过了，先解绑才能重新绑定' });
    }

    // 清理该用户之前的未使用邀请码
    await pool.query('DELETE FROM couple_invites WHERE creator_id = ? AND used = 0', [userId]);

    // 生成新邀请码（确保唯一）
    let code;
    let attempts = 0;
    while (attempts < 10) {
      code = generateCode();
      try {
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10分钟后过期
        await pool.query(
          'INSERT INTO couple_invites (code, creator_id, expires_at) VALUES (?, ?, ?)',
          [code, userId, expiresAt]
        );
        break;
      } catch (e) {
        if (e.code === 'ER_DUP_ENTRY') {
          attempts++;
          continue;
        }
        throw e;
      }
    }

    if (attempts >= 10) {
      return res.status(500).json({ code: 500, message: '生成邀请码失败，请重试' });
    }

    console.log(`[Couple] 用户${userId} 生成邀请码 ${code}`);

    res.json({
      code: 200,
      message: '邀请码已生成',
      data: {
        invite_code: code,
        expires_in: 600, // 10分钟
      }
    });
  } catch (err) {
    console.error('[Couple] 生成邀请码失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/couple/accept — 输入邀请码绑定
router.post('/accept', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const { code } = req.body;

    if (!code || code.length !== 6) {
      return res.status(400).json({ code: 400, message: '请输入6位邀请码' });
    }

    // 检查自己是否已绑定
    const [myCouple] = await pool.query(
      "SELECT id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'",
      [userId, userId]
    );
    if (myCouple.length > 0) {
      return res.status(400).json({ code: 400, message: '你已经绑定过了' });
    }

    // 查找邀请码
    const [invites] = await pool.query(
      'SELECT * FROM couple_invites WHERE code = ? AND used = 0',
      [code]
    );
    if (invites.length === 0) {
      return res.status(400).json({ code: 400, message: '邀请码无效或已使用' });
    }

    const invite = invites[0];

    // 检查是否过期
    if (new Date(invite.expires_at) < new Date()) {
      return res.status(400).json({ code: 400, message: '邀请码已过期，请让对方重新生成' });
    }

    // 不能自己绑定自己
    if (invite.creator_id === userId) {
      return res.status(400).json({ code: 400, message: '不能和自己绑定哦' });
    }

    // 检查邀请方是否已绑定（防止竞态）
    const [creatorCouple] = await pool.query(
      "SELECT id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'",
      [invite.creator_id, invite.creator_id]
    );
    if (creatorCouple.length > 0) {
      return res.status(400).json({ code: 400, message: '对方已经绑定了其他人' });
    }

    // 执行绑定（事务）
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      // 确保 user1_id < user2_id 保持一致性
      const user1 = Math.min(invite.creator_id, userId);
      const user2 = Math.max(invite.creator_id, userId);

      await conn.query(
        'INSERT INTO couples (user1_id, user2_id) VALUES (?, ?)',
        [user1, user2]
      );

      // 标记邀请码已使用
      await conn.query(
        'UPDATE couple_invites SET used = 1, used_by = ? WHERE id = ?',
        [userId, invite.id]
      );

      await conn.commit();
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }

    // 获取双方信息
    const [users] = await pool.query(
      'SELECT id, nickname, role FROM users WHERE id IN (?, ?)',
      [invite.creator_id, userId]
    );

    console.log(`[Couple] 绑定成功: 用户${invite.creator_id} <-> 用户${userId}`);

    res.json({
      code: 200,
      message: '绑定成功！',
      data: {
        partner: users.find(u => u.id !== userId) || {},
      }
    });
  } catch (err) {
    console.error('[Couple] 绑定失败:', err);
    res.status(500).json({ code: 500, message: '绑定失败，请重试' });
  }
});

// DELETE /api/couple — 解除绑定
router.delete('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;

    const [rows] = await pool.query(
      "SELECT id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'",
      [userId, userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: '你还没有绑定' });
    }

    await pool.query(
      "UPDATE couples SET status = 'broken', broken_at = NOW() WHERE id = ?",
      [rows[0].id]
    );

    console.log(`[Couple] 解绑: 用户${userId}`);

    res.json({ code: 200, message: '已解除绑定' });
  } catch (err) {
    console.error('[Couple] 解绑失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
