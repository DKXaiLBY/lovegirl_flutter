const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  todayString,
  getPartnerId,
  addBeanTransaction,
} = require('./utils/lovegirl_rewards');

// 阶段定义：累计成长点阈值（只增不减）
const STAGES = [
  { stage: 0, at: 0, name: '一颗种子' },
  { stage: 1, at: 50, name: '破土发芽' },
  { stage: 2, at: 150, name: '小小树苗' },
  { stage: 3, at: 300, name: '亭亭小树' },
  { stage: 4, at: 500, name: '开花啦' },
  { stage: 5, at: 800, name: '硕果累累' },
];

const WATER_POINTS = 10;        // 每人每天浇一次 +10 成长
const STAGE_UP_BEANS = 10;      // 升阶时双方各 +10 豆

function coupleKey(a, b) {
  const [x, y] = a < b ? [a, b] : [b, a];
  return `${x}_${y}`;
}

function stageOf(points) {
  let cur = STAGES[0];
  for (const s of STAGES) if (points >= s.at) cur = s;
  return cur;
}

function nextStageOf(points) {
  for (const s of STAGES) if (points < s.at) return s;
  return null; // 已满级
}

async function ensureTree(key) {
  await pool.query(
    'INSERT IGNORE INTO love_tree (couple_key) VALUES (?)',
    [key]
  );
}

async function wateredToday(key) {
  const today = todayString();
  const [rows] = await pool.query(
    `SELECT user_id FROM love_tree_water_log
     WHERE couple_key = ? AND DATE(created_at) = ?`,
    [key, today]
  );
  const set = new Set(rows.map((r) => r.user_id));
  return set;
}

async function buildState(userId) {
  const partnerId = await getPartnerId(userId);
  const hasPartner = partnerId != null;
  const key = coupleKey(userId, partnerId ?? userId);

  await ensureTree(key);
  const [trees] = await pool.query(
    'SELECT growth_points FROM love_tree WHERE couple_key = ?',
    [key]
  );
  const tree = trees[0] || { growth_points: 0 };

  const watered = hasPartner ? await wateredToday(key) : new Set();
  const points = tree.growth_points;
  const stage = stageOf(points);
  const next = nextStageOf(points);

  let partnerName = null;
  if (partnerId) {
    const [u] = await pool.query('SELECT nickname FROM users WHERE id = ?', [partnerId]);
    partnerName = u.length > 0 ? u[0].nickname : null;
  }

  return {
    hasPartner,
    partnerName,
    growthPoints: points,
    stage: stage.stage,
    stageName: stage.name,
    nextStageAt: next ? next.at : null,
    nextStageName: next ? next.name : null,
    myWateredToday: watered.has(userId),
    partnerWateredToday: watered.has(partnerId),
  };
}

// 爱情树状态
router.get('/', authRequired, async (req, res) => {
  try {
    res.json({ code: 200, data: await buildState(req.user.id) });
  } catch (err) {
    console.error('[Tree] state failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 浇水：每人每天一次，+10 成长；升阶双方 +10 豆并互相通知
router.post('/water', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.status(400).json({ code: 400, message: '先绑定伴侣，一起浇灌小树吧' });
    }

    const key = coupleKey(req.user.id, partnerId);
    await ensureTree(key);

    // 幂等：当天已浇过直接拒绝
    const watered = await wateredToday(key);
    if (watered.has(req.user.id)) {
      return res.status(409).json({ code: 409, message: '今天已经浇过啦' });
    }

    // 升阶判断要在加分前取旧值
    const [before] = await pool.query(
      'SELECT growth_points FROM love_tree WHERE couple_key = ?',
      [key]
    );
    const prevStage = stageOf(before.length > 0 ? before[0].growth_points : 0).stage;

    await pool.query(
      'UPDATE love_tree SET growth_points = growth_points + ? WHERE couple_key = ?',
      [WATER_POINTS, key]
    );
    await pool.query(
      'INSERT INTO love_tree_water_log (couple_key, user_id, points) VALUES (?, ?, ?)',
      [key, req.user.id, WATER_POINTS]
    );

    const state = await buildState(req.user.id);
    const stageUp = state.stage > prevStage;

    if (stageUp) {
      for (const uid of [req.user.id, partnerId]) {
        try {
          await addBeanTransaction(pool, {
            userId: uid,
            amount: STAGE_UP_BEANS,
            type: 'love_tree_stage',
            title: `爱情树 · ${state.stageName}`,
            sourceModule: 'love_tree',
            sourceId: `stage_${state.stage}`,
            description: '你们的树长大了',
          });
        } catch (err) {
          console.error('[Tree] stage bean failed:', err.message);
        }
      }
      try {
        await pool.query(
          'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
          [partnerId, 'love_tree', '你们的树长大了', `爱情树进入「${state.stageName}」阶段`, JSON.stringify({ stage: state.stage })]
        );
      } catch (err) {
        console.error('[Tree] notify failed:', err.message);
      }
    }

    res.json({ code: 200, data: { ...state, stageUp } });
  } catch (err) {
    console.error('[Tree] water failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
