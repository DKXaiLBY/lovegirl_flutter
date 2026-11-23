// 隐私设置路由
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const { partnerId, privacyFor, privacyDefaults } = require('../utils/creation_access');

// GET /api/privacy — 获取当前隐私设置
router.get('/', authRequired, async (req, res) => {
  try {
    res.json({ code: 200, data: await privacyFor(pool, req.user.id) });
  } catch (err) {
    console.error('获取隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/privacy — 更新隐私设置
router.put('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const { photo_visible, mood_visible, travel_visible, chat_visible } = req.body || {};
    const updates = [photo_visible, mood_visible, travel_visible, chat_visible];
    if (updates.some((value) => value != null && typeof value !== 'boolean')) {
      return res.status(400).json({ code: 400, message: '隐私开关必须为布尔值' });
    }
    await pool.query(
      `INSERT INTO user_privacy (user_id, photo_visible, mood_visible, travel_visible, chat_visible)
       VALUES (?, COALESCE(?, 0), COALESCE(?, 0), COALESCE(?, 1), COALESCE(?, 1))
       ON DUPLICATE KEY UPDATE
         photo_visible = COALESCE(?, photo_visible), mood_visible = COALESCE(?, mood_visible),
         travel_visible = COALESCE(?, travel_visible), chat_visible = COALESCE(?, chat_visible)`,
      [userId, ...updates.map((value) => value ?? null), ...updates.map((value) => value ?? null)]
    );
    res.json({ code: 200, data: await privacyFor(pool, userId), message: '隐私设置已更新' });
  } catch (err) {
    console.error('更新隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/privacy/check?type=photo|mood|travel|chat&partner_id=xxx
// 检查对方是否允许访问某类数据（需验证伴侣关系）
router.get('/check', authRequired, async (req, res) => {
  try {
    const { type, partner_id } = req.query;
    const field = typeof type === 'string' ? type + '_visible' : '';
    const counterpart = Number(partner_id);
    if (!Object.hasOwn(privacyDefaults, field) || !Number.isSafeInteger(counterpart) || counterpart <= 0) {
      return res.status(400).json({ code: 400, message: '隐私类型或伴侣编号不正确' });
    }
    if (await partnerId(pool, req.user.id) !== counterpart) {
      return res.status(403).json({ code: 403, message: '无权访问对方隐私设置' });
    }
    const settings = await privacyFor(pool, counterpart);
    res.json({ code: 200, data: { visible: settings[field] } });
  } catch (err) {
    console.error('检查隐私设置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
