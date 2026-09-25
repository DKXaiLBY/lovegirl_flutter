// 用户路由：个人信息/设置
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// 头像上传目录与 multer 配置
const avatarDir = path.join(__dirname, '..', 'uploads', 'avatars');
if (!fs.existsSync(avatarDir)) {
  fs.mkdirSync(avatarDir, { recursive: true });
}
const AVATAR_EXTS = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, avatarDir),
    filename: (req, file, cb) => {
      const raw = (path.extname(file.originalname || '') || '').toLowerCase();
      const ext = AVATAR_EXTS.includes(raw) ? raw : '.jpg';
      cb(null, `avatar_${req.user.id}_${Date.now()}${ext}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('仅支持图片文件'));
    }
    cb(null, true);
  },
});

// 组装 GET/PUT /profile 共用的响应体（与历史 GET 响应结构逐字段一致）
async function profilePayload(user) {
  // 如果当前用户没有设置love_start_date，从伴侣获取
  let loveStartDate = user.love_start_date;
  if (!loveStartDate) {
    const partnerRole = user.role === 'boy' ? 'girl' : 'boy';
    const [partners] = await pool.query(
      'SELECT love_start_date FROM users WHERE role = ? LIMIT 1',
      [partnerRole]
    );
    if (partners.length > 0 && partners[0].love_start_date) {
      loveStartDate = partners[0].love_start_date;
    }
  }
  return {
    id: user.id,
    username: user.username,
    nickname: user.nickname,
    partnerNickname: user.partner_nickname,
    partnerPhone: user.partner_phone,
    emergencyPhone: user.emergency_phone,
    avatarUrl: user.avatar_url,
    role: user.role,
    gender: user.gender,
    isAdmin: !!user.is_admin,
    loveStartDate: loveStartDate,
    settings: {
      fingerprintEnabled: user.fingerprint_enabled,
      appLockEnabled: user.app_lock_enabled,
      periodLockEnabled: user.period_lock_enabled,
      financeLockEnabled: user.finance_lock_enabled,
      financePrivacyEnabled: user.finance_privacy_enabled
    },
    push: {
      dailyQuote: user.push_daily_quote,
      weather: user.push_weather,
      period: user.push_period,
      exam: user.push_exam,
      todo: user.push_todo,
      course: user.push_course
    },
    createdAt: user.created_at
  };
}

// GET /api/user/profile - 获取个人资料
router.get('/profile', authRequired, async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, username, nickname, partner_nickname, partner_phone, emergency_phone, avatar_url, role, gender, is_admin, love_start_date, fingerprint_enabled, app_lock_enabled, period_lock_enabled, finance_lock_enabled, finance_privacy_enabled, push_daily_quote, push_weather, push_period, push_exam, push_todo, push_course, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    if (users.length === 0) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }
    res.json({ code: 200, data: await profilePayload(users[0]) });
  } catch (err) {
    console.error('获取资料失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/user/profile - 更新个人资料（逐字段静态 UPDATE，全部参数化）
router.put('/profile', authRequired, async (req, res) => {
  try {
    const { nickname, partnerNickname, avatarUrl, loveStartDate, partnerPhone, emergencyPhone } = req.body;
    if (nickname) {
      if (typeof nickname !== 'string' || nickname.length > 30) {
        return res.status(400).json({ code: 400, message: '昵称长度不能超过30个字符' });
      }
      await pool.query('UPDATE users SET nickname = ? WHERE id = ?', [nickname, req.user.id]);
    }
    if (partnerNickname) {
      await pool.query('UPDATE users SET partner_nickname = ? WHERE id = ?', [partnerNickname, req.user.id]);
    }
    if (avatarUrl) {
      await pool.query('UPDATE users SET avatar_url = ? WHERE id = ?', [avatarUrl, req.user.id]);
    }
    if (loveStartDate) {
      await pool.query('UPDATE users SET love_start_date = ? WHERE id = ?', [loveStartDate, req.user.id]);
    }
    if (partnerPhone !== undefined) {
      await pool.query('UPDATE users SET partner_phone = ? WHERE id = ?', [partnerPhone, req.user.id]);
    }
    if (emergencyPhone !== undefined) {
      await pool.query('UPDATE users SET emergency_phone = ? WHERE id = ?', [emergencyPhone, req.user.id]);
    }

    const touched = nickname || partnerNickname || avatarUrl || loveStartDate ||
      partnerPhone !== undefined || emergencyPhone !== undefined;
    if (!touched) {
      return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    }

    // 返回更新后的完整资料（App 端 updateProfile 直接以 data 刷新本地缓存）
    const [users] = await pool.query(
      'SELECT id, username, nickname, partner_nickname, partner_phone, emergency_phone, avatar_url, role, gender, is_admin, love_start_date, fingerprint_enabled, app_lock_enabled, period_lock_enabled, finance_lock_enabled, finance_privacy_enabled, push_daily_quote, push_weather, push_period, push_exam, push_todo, push_course, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    res.json({ code: 200, message: '更新成功', data: await profilePayload(users[0]) });
  } catch (err) {
    console.error('更新资料失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/user/avatar - 上传头像（multipart，字段名 file）
router.post('/avatar', authRequired, avatarUpload.single('file'), async (req, res) => {
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
    console.error('头像上传失败:', err);
    res.status(500).json({ code: 500, message: '头像上传失败' });
  }
});

// PUT /api/user/settings - 更新设置（同时支持驼峰和下划线命名；逐字段静态 UPDATE）
router.put('/settings', authRequired, async (req, res) => {
  try {
    let touched = false;

    if (req.body.fingerprint_enabled !== undefined || req.body.fingerprintEnabled !== undefined) {
      const v = req.body.fingerprint_enabled !== undefined ? req.body.fingerprint_enabled : req.body.fingerprintEnabled;
      await pool.query('UPDATE users SET fingerprint_enabled = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.app_lock_enabled !== undefined || req.body.appLockEnabled !== undefined) {
      const v = req.body.app_lock_enabled !== undefined ? req.body.app_lock_enabled : req.body.appLockEnabled;
      await pool.query('UPDATE users SET app_lock_enabled = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.period_lock_enabled !== undefined || req.body.periodLockEnabled !== undefined) {
      const v = req.body.period_lock_enabled !== undefined ? req.body.period_lock_enabled : req.body.periodLockEnabled;
      await pool.query('UPDATE users SET period_lock_enabled = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.finance_lock_enabled !== undefined || req.body.financeLockEnabled !== undefined) {
      const v = req.body.finance_lock_enabled !== undefined ? req.body.finance_lock_enabled : req.body.financeLockEnabled;
      await pool.query('UPDATE users SET finance_lock_enabled = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.finance_privacy_enabled !== undefined || req.body.financePrivacyEnabled !== undefined) {
      const v = req.body.finance_privacy_enabled !== undefined ? req.body.finance_privacy_enabled : req.body.financePrivacyEnabled;
      await pool.query('UPDATE users SET finance_privacy_enabled = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_daily_quote !== undefined || req.body.pushDailyQuote !== undefined) {
      const v = req.body.push_daily_quote !== undefined ? req.body.push_daily_quote : req.body.pushDailyQuote;
      await pool.query('UPDATE users SET push_daily_quote = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_weather !== undefined || req.body.pushWeather !== undefined) {
      const v = req.body.push_weather !== undefined ? req.body.push_weather : req.body.pushWeather;
      await pool.query('UPDATE users SET push_weather = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_period !== undefined || req.body.pushPeriod !== undefined) {
      const v = req.body.push_period !== undefined ? req.body.push_period : req.body.pushPeriod;
      await pool.query('UPDATE users SET push_period = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_exam !== undefined || req.body.pushExam !== undefined) {
      const v = req.body.push_exam !== undefined ? req.body.push_exam : req.body.pushExam;
      await pool.query('UPDATE users SET push_exam = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_todo !== undefined || req.body.pushTodo !== undefined) {
      const v = req.body.push_todo !== undefined ? req.body.push_todo : req.body.pushTodo;
      await pool.query('UPDATE users SET push_todo = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }
    if (req.body.push_course !== undefined || req.body.pushCourse !== undefined) {
      const v = req.body.push_course !== undefined ? req.body.push_course : req.body.pushCourse;
      await pool.query('UPDATE users SET push_course = ? WHERE id = ?', [v ? 1 : 0, req.user.id]);
      touched = true;
    }

    if (!touched) {
      return res.status(400).json({ code: 400, message: '没有要更新的设置项' });
    }

    res.json({ code: 200, message: '设置更新成功' });
  } catch (err) {
    console.error('更新设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/user/password - 修改密码
router.put('/password', authRequired, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ code: 400, message: '请输入旧密码和新密码' });
    }

    const [users] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
    const match = await require('bcryptjs').compare(oldPassword, users[0].password_hash);
    if (!match) {
      return res.status(400).json({ code: 400, message: '旧密码不正确' });
    }

    const hash = await require('bcryptjs').hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, req.user.id]);
    res.json({ code: 200, message: '密码修改成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/user/status - 获取伴侣状态（双方通用）
router.get('/status', authRequired, async (req, res) => {
  try {
    const partnerRole = req.user.role === 'girl' ? 'boy' : 'girl';
    const [partners] = await pool.query(
      'SELECT id FROM users WHERE role = ? LIMIT 1',
      [partnerRole]
    );
    if (partners.length === 0) {
      return res.json({ code: 200, data: { status: 'online', statusText: '在线', emoji: '🟢' } });
    }
    const [rows] = await pool.query(
      'SELECT status, status_text FROM boyfriend_status WHERE user_id = ? LIMIT 1',
      [partners[0].id]
    );
    const statusMap = {
      online: { emoji: '🟢', text: '在线' },
      busy: { emoji: '💼', text: '正在忙' },
      missing: { emoji: '💕', text: '想你了' },
      traveling: { emoji: '🚗', text: '在路上' },
      offline: { emoji: '😴', text: '已下线' }
    };
    const s = rows.length > 0 ? rows[0] : { status: 'online', status_text: '在线' };
    const mapped = statusMap[s.status] || statusMap.online;
    res.json({
      code: 200,
      data: {
        status: s.status,
        statusText: s.status_text || mapped.text,
        emoji: mapped.emoji
      }
    });
  } catch (err) {
    console.error('获取伴侣状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/user/status - 更新自己的状态（双方通用）
router.put('/status', authRequired, async (req, res) => {
  try {
    const { status, statusText } = req.body;
    if (!status) {
      return res.status(400).json({ code: 400, message: '请选择状态' });
    }
    // 验证状态值合法性
    const validStatuses = ['online', 'busy', 'missing', 'traveling', 'offline'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ code: 400, message: '无效的状态值' });
    }

    const [existing] = await pool.query(
      'SELECT id FROM boyfriend_status WHERE user_id = ?',
      [req.user.id]
    );
    if (existing.length > 0) {
      await pool.query(
        'UPDATE boyfriend_status SET status = ?, status_text = ? WHERE user_id = ?',
        [status, statusText || '', req.user.id]
      );
    } else {
      await pool.query(
        'INSERT INTO boyfriend_status (user_id, status, status_text) VALUES (?, ?, ?)',
        [req.user.id, status, statusText || '']
      );
    }
    res.json({ code: 200, message: '状态更新成功' });
  } catch (err) {
    console.error('更新状态失败:', err.message, 'SQL:', err.sql, 'Code:', err.code, 'User:', req.user?.id);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/user/partner - 获取对方信息（一键呼叫用）
router.get('/partner', authRequired, async (req, res) => {
  try {
    const partnerRole = req.user.role === 'girl' ? 'boy' : 'girl';
    const [users] = await pool.query(
      'SELECT id, nickname, partner_phone, emergency_phone FROM users WHERE role = ? AND is_admin = 0 LIMIT 1',
      [partnerRole]
    );
    if (users.length === 0) {
      return res.json({ code: 200, data: null, message: '对方还未注册' });
    }
    const u = users[0];
    res.json({
      code: 200,
      data: {
        nickname: u.nickname,
        phone: u.partner_phone || u.emergency_phone || null
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/user/love-days - 获取恋爱天数详情和下一个里程碑
router.get('/love-days', authRequired, async (req, res) => {
  try {
    const [users] = await pool.query('SELECT love_start_date FROM users WHERE id=?', [req.user.id]);
    if (!users[0]?.love_start_date) return res.json({ code: 200, data: { loveStartDate: null, loveDays: 0, nextMilestone: null } });
    const start = new Date(users[0].love_start_date);
    const today = new Date(); today.setHours(0,0,0,0);
    const loveDays = Math.floor((today - start) / 86400000);
    // 计算下一个里程碑
    const milestones = [
      { days: 100, name: '100天纪念日' }, { days: 200, name: '200天纪念日' },
      { days: 300, name: '300天纪念日' }, { days: 365, name: '一周年❤️' },
      { days: 520, name: '520天' }, { days: 730, name: '两周年💕' },
      { days: 999, name: '999天' }, { days: 1000, name: '1000天💍' },
    ];
    let nextMilestone = null;
    for (const m of milestones) {
      if (m.days > loveDays) {
        const milestoneDate = new Date(start); milestoneDate.setDate(milestoneDate.getDate() + m.days);
        nextMilestone = { ...m, date: milestoneDate.toISOString().split('T')[0], daysUntil: m.days - loveDays };
        break;
      }
    }
    res.json({ code: 200, data: { loveStartDate: start.toISOString().split('T')[0], loveDays, nextMilestone } });
  } catch (err) { console.error('获取恋爱天数失败:', err); res.status(500).json({ code: 500, message: '服务器错误' }); }
});

module.exports = router;
