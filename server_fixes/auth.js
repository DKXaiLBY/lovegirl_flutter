const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const router = express.Router();
const pool = require('../config/database');

const JWT_SECRET =
  process.env.JWT_SECRET || process.env.APP_SECRET || 'lovegirl-dev-jwt-secret';
const TOKEN_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30d';

function normalizeRole(gender) {
  return gender === 'male' ? 'boy' : 'girl';
}

function buildToken(user) {
  return jwt.sign(
    {
      id: user.id,
      userId: user.id,
      username: user.username,
      role: user.role,
      isAdmin: !!user.is_admin,
      is_admin: !!user.is_admin,
    },
    JWT_SECRET,
    { expiresIn: TOKEN_EXPIRES_IN }
  );
}

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
    loveStartDate: user.love_start_date || null,
  };
}

async function verifyPassword(plainText, storedHash) {
  if (!storedHash) return false;

  try {
    if (storedHash.startsWith('$2')) {
      return await bcrypt.compare(plainText, storedHash);
    }
  } catch (_) {}

  if (storedHash === plainText) return true;

  const sha256 = crypto
    .createHash('sha256')
    .update(String(plainText))
    .digest('hex');
  return sha256 === storedHash;
}

router.post('/register', async (req, res) => {
  try {
    const username = String(req.body.username || '').trim();
    const password = String(req.body.password || '');
    const nickname = String(req.body.nickname || '').trim();
    const gender = req.body.gender === 'male' ? 'male' : 'female';

    if (!username || !password || !nickname) {
      return res.status(400).json({ code: 400, message: '请填写完整注册信息' });
    }

    if (username.length < 2 || username.length > 50) {
      return res.status(400).json({ code: 400, message: '用户名长度需要在 2-50 个字符之间' });
    }

    if (password.length < 6) {
      return res.status(400).json({ code: 400, message: '密码至少需要 6 位' });
    }

    const [existing] = await pool.query(
      'SELECT id FROM users WHERE username = ? LIMIT 1',
      [username]
    );
    if (existing.length > 0) {
      return res.status(400).json({ code: 400, message: '用户名已经被注册了' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const role = normalizeRole(gender);

    const [result] = await pool.query(
      `INSERT INTO users
       (username, password_hash, nickname, role, gender)
       VALUES (?, ?, ?, ?, ?)`,
      [username, passwordHash, nickname, role, gender]
    );

    const [rows] = await pool.query(
      'SELECT * FROM users WHERE id = ? LIMIT 1',
      [result.insertId]
    );
    const user = rows[0];
    const token = buildToken(user);

    res.json({
      code: 200,
      message: '注册成功',
      data: {
        token,
        accessToken: token,
        user: presentUser(user),
      },
    });
  } catch (err) {
    console.error('[Auth] register failed:', err);
    res.status(500).json({ code: 500, message: '注册失败，请稍后再试' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const username = String(req.body.username || '').trim();
    const password = String(req.body.password || '');

    if (!username || !password) {
      return res.status(400).json({ code: 400, message: '请输入用户名和密码' });
    }

    const [rows] = await pool.query(
      'SELECT * FROM users WHERE username = ? LIMIT 1',
      [username]
    );
    if (rows.length === 0) {
      return res.status(401).json({ code: 401, message: '用户名或密码错误' });
    }

    const user = rows[0];
    const ok = await verifyPassword(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ code: 401, message: '用户名或密码错误' });
    }

    const token = buildToken(user);
    res.json({
      code: 200,
      message: '登录成功',
      data: {
        token,
        accessToken: token,
        user: presentUser(user),
      },
    });
  } catch (err) {
    console.error('[Auth] login failed:', err);
    res.status(500).json({ code: 500, message: '登录失败，请稍后再试' });
  }
});

module.exports = router;
