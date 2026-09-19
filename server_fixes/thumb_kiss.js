const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const { getPartnerId } = require('./utils/lovegirl_rewards');

// 拇指之吻：双机同触同一点 → 双方震动。
// 纯内存态（本来就需要两人同时在线，重启丢状态无影响），坐标一律归一化 0..1。

const rooms = new Map(); // coupleKey -> { players: Map<userId, {x,y,touching,ts}>, matchedAt: 0 }
const STALE_MS = 15000; // 心跳超时视为离场
const MATCH_DIST = 0.13; // 归一化距离阈值（屏幕对角线比例）
const REMATCH_COOLDOWN_MS = 4000; // 两次吻之间的冷却

function coupleKeyOf(a, b) {
  const [x, y] = a < b ? [a, b] : [b, a];
  return `${x}_${y}`;
}

function getRoom(key) {
  let room = rooms.get(key);
  if (!room) {
    room = { players: new Map(), matchedAt: 0 };
    rooms.set(key, room);
  }
  // 清理过期玩家
  const now = Date.now();
  for (const [uid, p] of room.players) {
    if (now - p.ts > STALE_MS) room.players.delete(uid);
  }
  return room;
}

function norm(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return Math.min(1, Math.max(0, n));
}

function dist(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

function buildState(room, userId, partnerId) {
  const me = room.players.get(userId) || null;
  const partner = partnerId != null ? room.players.get(partnerId) || null : null;

  let matched = false;
  let justMatched = false;
  const now = Date.now();
  if (me && partner && me.touching && partner.touching) {
    if (dist(me, partner) <= MATCH_DIST) {
      matched = true;
      if (now - room.matchedAt > REMATCH_COOLDOWN_MS) {
        room.matchedAt = now;
        justMatched = true;
      }
    }
  }

  return {
    matched,
    justMatched,
    partnerOnline: partner != null,
    partnerTouching: partner ? partner.touching : false,
    partnerX: partner ? partner.x : null,
    partnerY: partner ? partner.y : null,
  };
}

// 房间状态轮询
router.get('/state', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.json({ code: 200, data: { hasPartner: false } });
    }
    const key = coupleKeyOf(req.user.id, partnerId);
    const room = getRoom(key);
    res.json({ code: 200, data: { hasPartner: true, ...buildState(room, req.user.id, partnerId) } });
  } catch (err) {
    console.error('[Kiss] state failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 上报我的拇指位置（含心跳；touching=false 也上报以维持在线）
router.post('/position', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.status(400).json({ code: 400, message: '先绑定伴侣' });
    }
    const x = norm(req.body.x);
    const y = norm(req.body.y);
    if (x == null || y == null) {
      return res.status(400).json({ code: 400, message: '坐标非法' });
    }
    const touching = req.body.touching === true;
    const key = coupleKeyOf(req.user.id, partnerId);
    const room = getRoom(key);
    room.players.set(req.user.id, { x, y, touching, ts: Date.now() });
    res.json({ code: 200, data: buildState(room, req.user.id, partnerId) });
  } catch (err) {
    console.error('[Kiss] position failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 离场
router.post('/leave', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId != null) {
      const room = rooms.get(coupleKeyOf(req.user.id, partnerId));
      if (room) {
        room.players.delete(req.user.id);
        if (room.players.size === 0) rooms.delete(coupleKeyOf(req.user.id, partnerId));
      }
    }
    res.json({ code: 200, message: '已离场' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
