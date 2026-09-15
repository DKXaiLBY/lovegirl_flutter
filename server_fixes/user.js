const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');

const avatarDir = path.join(__dirname, 'uploads', 'avatars');
if (!fs.existsSync(avatarDir)) {
  fs.mkdirSync(avatarDir, { recursive: true });
}

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, avatarDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
      cb(null, `avatar_${req.user.id}_${Date.now()}${ext}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('只支持图片文件'));
    }
    cb(null, true);
  },
});

function presentUser(user) {
  return {
    id: user.id,
    username: user.username,
    nickname: user.nickname || '',
    avatar: user.avatar_url || '',
    avatarUrl: user.avatar_url || '',
    role: user.role || '',
    gender: user.gender || '',
    isAdmin: !!user.is_admin,
    is_admin: !!user.is_admin,
    partnerNickname: user.partner_nickname || '',
    partnerPhone: user.partner_phone || '',
    emergencyPhone: user.emergency_phone || '',
    loveStartDate: user.love_start_date || null,
    beanBalance: Number(user.bean_balance || 0),
  };
}

router.get('/profile', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, username, nickname, avatar_url, role, gender, is_admin,
              partner_nickname, partner_phone, emergency_phone,
              love_start_date, bean_balance
       FROM users
       WHERE id = ?
       LIMIT 1`,
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }

    res.json({ code: 200, data: presentUser(rows[0]) });
  } catch (err) {
    console.error('[User] profile failed:', err);
    res.status(500).json({ code: 500, message: '获取资料失败' });
  }
});

router.put('/profile', authRequired, async (req, res) => {
  try {
    const updates = [];
    const params = [];

    if (req.body.nickname !== undefined) {
      updates.push('nickname = ?');
      params.push(String(req.body.nickname || '').trim());
    }
    if (req.body.avatar !== undefined) {
      updates.push('avatar_url = ?');
      params.push(String(req.body.avatar || '').trim());
    }
    if (req.body.partnerNickname !== undefined) {
      updates.push('partner_nickname = ?');
      params.push(String(req.body.partnerNickname || '').trim());
    }
    if (req.body.partnerPhone !== undefined) {
      updates.push('partner_phone = ?');
      params.push(String(req.body.partnerPhone || '').trim());
    }
    if (req.body.emergencyPhone !== undefined) {
      updates.push('emergency_phone = ?');
      params.push(String(req.body.emergencyPhone || '').trim());
    }
    if (req.body.loveStartDate !== undefined) {
      updates.push('love_start_date = ?');
      params.push(req.body.loveStartDate || null);
    }

    if (updates.length === 0) {
      const [rows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [
        req.user.id,
      ]);
      return res.json({ code: 200, data: presentUser(rows[0] || {}) });
    }

    params.push(req.user.id);
    await pool.query(
      `UPDATE users SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      params
    );

    const [rows] = await pool.query(
      `SELECT id, username, nickname, avatar_url, role, gender, is_admin,
              partner_nickname, partner_phone, emergency_phone,
              love_start_date, bean_balance
       FROM users
       WHERE id = ?
       LIMIT 1`,
      [req.user.id]
    );

    res.json({ code: 200, message: '资料已更新', data: presentUser(rows[0]) });
  } catch (err) {
    console.error('[User] update profile failed:', err);
    res.status(500).json({ code: 500, message: '保存失败，请稍后再试' });
  }
});

router.post('/avatar', authRequired, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请选择要上传的图片' });
    }

    const url = `/uploads/avatars/${req.file.filename}`;
    await pool.query('UPDATE users SET avatar_url = ? WHERE id = ?', [url, req.user.id]);

    res.json({
      code: 200,
      message: '头像上传成功',
      data: { url },
    });
  } catch (err) {
    console.error('[User] upload avatar failed:', err);
    res.status(500).json({ code: 500, message: '头像上传失败' });
  }
});

module.exports = router;
