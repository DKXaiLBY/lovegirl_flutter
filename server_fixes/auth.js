// 认证路由：登录/注册/刷新token
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const pool = require('../config/database');
const { generateAccessToken, generateRefreshToken, verifyToken } = require('../config/jwt');
const { authRequired } = require('../middleware/auth');
const registration = require('../utils/registration_invites');
const { partnerId } = require('../utils/creation_access');

// POST /api/auth/login - 登录
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ code: 400, message: '请输入用户名和密码' });
    }

    const [users] = await pool.query(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    if (users.length === 0) {
      return res.status(401).json({ code: 401, message: '用户名或密码错误' });
    }

    const user = users[0];
    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      return res.status(401).json({ code: 401, message: '用户名或密码错误' });
    }

    // 管理员默认进入男友端
    const effectiveRole = user.is_admin ? 'boy' : user.role;

    // 如果当前用户没有love_start_date，从伴侣获取
    let loveStartDate = user.love_start_date;
    const partner = loveStartDate ? null : await partnerId(pool, user.id);
    if (partner !== null) {
      const [partners] = await pool.query(
        'SELECT love_start_date FROM users WHERE id = ?', [partner]
      );
      if (partners.length > 0 && partners[0].love_start_date) {
        loveStartDate = partners[0].love_start_date;
      }
    }

    const tokenPayload = {
      id: user.id,
      username: user.username,
      role: effectiveRole,
      gender: user.gender,
      isAdmin: !!user.is_admin
    };

    res.json({
      code: 200,
      message: '登录成功',
      data: {
        accessToken: generateAccessToken(tokenPayload),
        refreshToken: generateRefreshToken(tokenPayload),
        user: {
          id: user.id,
          username: user.username,
          nickname: user.nickname,
          partnerNickname: user.partner_nickname,
          partnerPhone: user.partner_phone,
          avatarUrl: user.avatar_url,
          role: effectiveRole,
          gender: user.gender,
          isAdmin: !!user.is_admin,
          loveStartDate: loveStartDate
        }
      }
    });
  } catch (err) {
    console.error('登录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

function registrationFailure(res, error) {
  if (error instanceof registration.RegistrationError) {
    return res.status(error.status).json({ code: error.status, message: error.message });
  }
  console.error('[Registration]', error.code || 'unexpected');
  return res.status(500).json({ code: 500, message: '暂时无法注册，请稍后再试' });
}

router.post('/registration-invites', authRequired, async (req, res) => {
  try {
    const data = await registration.issue(pool, req.user.id);
    return res.json({ code: 200, data });
  } catch (error) {
    return registrationFailure(res, error);
  }
});

router.post('/register', async (req, res) => {
  try {
    const user = await registration.register(pool, bcrypt, req.body);
    const { id, username, role, gender } = user;
    const tokenPayload = { id, username, role, gender, isAdmin: false };
    return res.json({
      code: 200,
      message: '注册成功',
      data: {
        accessToken: generateAccessToken(tokenPayload),
        refreshToken: generateRefreshToken(tokenPayload),
        user
      }
    });
  } catch (error) {
    return registrationFailure(res, error);
  }
});

// POST /api/auth/refresh - 刷新token
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ code: 400, message: '缺少刷新令牌' });
    }

    const decoded = verifyToken(refreshToken);
    if (!decoded || decoded.type !== 'refresh') {
      return res.status(401).json({ code: 401, message: '刷新令牌无效或已过期' });
    }

    // 从数据库获取最新角色（管理员可能已切换）
    const [users] = await pool.query('SELECT role, gender, is_admin FROM users WHERE id = ?', [decoded.id]);
    const user = users[0];
    if (!user) return res.status(401).json({ code: 401, message: '登录已过期，请重新登录' });
    const effectiveRole = user.is_admin ? (decoded.role || 'boy') : user.role;

    const tokenPayload = {
      id: decoded.id,
      username: decoded.username,
      role: effectiveRole,
      gender: user.gender,
      isAdmin: !!user.is_admin
    };

    res.json({
      code: 200,
      data: {
        accessToken: generateAccessToken(tokenPayload)
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/auth/switch-role - 管理员切换男女端
router.put('/switch-role', authRequired, async (req, res) => {
  try {
    if (!req.user.isAdmin) {
      return res.status(403).json({ code: 403, message: '仅管理员可切换' });
    }

    const currentRole = req.user.role;
    const newRole = currentRole === 'boy' ? 'girl' : 'boy';

    // 记录切换日志
    await pool.query(
      'INSERT INTO role_switch_log (user_id, from_role, to_role) VALUES (?, ?, ?)',
      [req.user.id, currentRole, newRole]
    );

    // 生成新token
    const tokenPayload = {
      id: req.user.id,
      username: req.user.username,
      role: newRole,
      gender: req.user.gender,
      isAdmin: true
    };

    res.json({
      code: 200,
      message: `已切换至${newRole === 'boy' ? '男友端' : '女友端'}`,
      data: {
        accessToken: generateAccessToken(tokenPayload),
        refreshToken: generateRefreshToken(tokenPayload),
        role: newRole
      }
    });
  } catch (err) {
    console.error('切换角色失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/auth/check-admin - 检查是否管理员（用于前端判断）
router.get('/check-admin', authRequired, (req, res) => {
  res.json({
    code: 200,
    data: { isAdmin: !!req.user.isAdmin }
  });
});

module.exports = router;
