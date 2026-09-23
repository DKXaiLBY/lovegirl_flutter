const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  todayString,
  getPartnerId,
  addBeanTransaction,
} = require('./utils/lovegirl_rewards');

// 题库：双人关系向，按日期确定性轮换（同一天两人看到的必然是同一题）
const QUESTION_BANK = [
  '如果明天可以一起去一个地方，你想去哪？',
  'TA 做过的哪件小事让你心动了很久？',
  '你们之间最有默契的一个瞬间是什么？',
  '最近一次因为 TA 而笑出声是因为什么？',
  '如果用三个词形容对方，你会选哪三个？',
  '你最想和 TA 一起学会的一件事是什么？',
  '对方做的哪道菜你最想再吃一次？',
  '你们第一次约会时，你心里在想什么？',
  '最近有没有一句想说但没说出口的话？',
  '如果今晚只能点一种外卖，你们会选什么？',
  'TA 的哪个习惯你觉得可爱？',
  '你希望十年后的你们在做什么？',
  '对方给过你的最实用的建议是什么？',
  '今天最想感谢 TA 的一件事是什么？',
  '如果给你们的故事起个电影名，会叫什么？',
  '你最期待和 TA 的下一个纪念日怎么过？',
  'TA 哪一点和你想象中的另一半最不一样？',
  '下雨天你们最合适的活动是什么？',
  '最近对方哪个瞬间让你觉得"就是这个人了"？',
  '如果互换身份一天，你最想替 TA 做什么？',
  '你们最想一起养成的小习惯是什么？',
  'TA 送过的礼物里你最喜欢哪一个？',
  '压力大的时候，你希望 TA 怎么陪你？',
  '你们吵得最凶的一次，后来是怎么和好的？',
  '对方说过的哪句话你一直记得？',
  '如果一起养一只宠物，你想养什么、叫什么名字？',
  '你觉得 TA 最闪闪发光的时刻是什么时候？',
  '一起做过的事里，哪件你想要再来一次？',
  '对方的一个小缺点，其实你觉得有点可爱？',
  '如果现在放假一周，你们的第一站是哪里？',
  '你最想学和 TA 一起玩的桌游或游戏是什么？',
  'TA 的哪个表情包是你最爱的？',
  '你们的"专属暗号"或口头禅是什么？',
  '哪一首歌一放出来你就会想起 TA？',
  '如果给对方的手写一封信，第一句会写什么？',
  '今天有什么想夸 TA 的吗？',
  '你们最像老夫老妻的一个瞬间是什么？',
  '对方为你做过最"离谱但用心"的事是什么？',
  '你想和 TA 一起尝试的极限运动是什么？',
  'TA 生气的时候，你一般怎么哄？',
  '你们的家将来最想有的一个角落是什么？',
  '哪一次旅行（哪怕很小的事）你最想重新经历？',
  '对方睡着后你一般都在干什么？',
  '你们之间最公平的一次"分工"是什么？',
  'TA 的哪个优点是你最想学来的？',
  '如果明天是你们在一起的最后一天，你最想做什么？',
  '你们最近一次彻夜聊天是什么时候，聊了什么？',
  '对方做的哪件事让你觉得特别有安全感？',
  '你偷偷关注 TA 的一个小细节是什么？',
  '一起看过的电影/剧里，你们最爱的是哪部？',
  '你最想和 TA 拍一组什么风格的合照？',
  '如果 TA 是一种食物，你觉得是什么？',
  '你们最想一起完成的一个"100 件事"是什么？',
  'TA 第一次见你朋友/家人时，你紧张吗？',
  '最近对方哪个变化让你眼前一亮？',
  '你们之间最想保留的一个小仪式是什么？',
  '如果可以预知未来一件事，你想知道关于你们的什么？',
  '今天想对 TA 说的一句晚安话是什么？',
];

function questionForDate(dateStr) {
  let h = 0;
  for (const ch of dateStr) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return QUESTION_BANK[h % QUESTION_BANK.length];
}

function addDays(dateStr, delta) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}

function dateToStr(v) {
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).slice(0, 10);
}

// 两人都作答的日期集合
async function bothAnsweredDates(userIds) {
  if (userIds.length < 2) return [];
  const placeholders = userIds.map(() => '?').join(',');
  const [rows] = await pool.query(
    `SELECT question_date FROM daily_answers
     WHERE user_id IN (${placeholders})
     GROUP BY question_date
     HAVING COUNT(DISTINCT user_id) = ?`,
    [...userIds, userIds.length]
  );
  return rows.map((r) => dateToStr(r.question_date));
}

function computeStreaks(dates) {
  const set = new Set(dates);
  const today = todayString();

  // 当前连续：从今天（或昨天）往回数
  let current = 0;
  let cursor = set.has(today) ? today : addDays(today, -1);
  while (set.has(cursor)) {
    current++;
    cursor = addDays(cursor, -1);
  }

  // 最长连续 & 累计
  const sorted = [...set].sort();
  let longest = 0;
  let run = 0;
  let prev = null;
  for (const d of sorted) {
    run = prev && addDays(prev, 1) === d ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }
  return { current, longest, total: sorted.length };
}

async function buildState(userId) {
  const partnerId = await getPartnerId(userId);
  const date = todayString();
  const question = questionForDate(date);

  const [mine] = await pool.query(
    'SELECT answer_text, created_at FROM daily_answers WHERE user_id = ? AND question_date = ?',
    [userId, date]
  );
  const myAnswer = mine.length > 0 ? mine[0].answer_text : null;

  let partnerAnswer = null;
  let partnerName = null;
  if (partnerId) {
    const [p] = await pool.query(
      'SELECT answer_text FROM daily_answers WHERE user_id = ? AND question_date = ?',
      [partnerId, date]
    );
    partnerAnswer = p.length > 0 ? p[0].answer_text : null;
    // 双盲：自己没答时看不到对方的答案
    if (myAnswer == null) partnerAnswer = null;
    const [u] = await pool.query(
      'SELECT nickname FROM users WHERE id = ?',
      [partnerId]
    );
    partnerName = u.length > 0 ? u[0].nickname : null;
  }

  const streak = computeStreaks(
    await bothAnsweredDates(
      partnerId ? [userId, partnerId] : [userId]
    )
  );

  return {
    date,
    question,
    hasPartner: partnerId != null,
    partnerName,
    myAnswer,
    partnerAnswer,
    bothAnswered: myAnswer != null && partnerAnswer != null,
    streak,
  };
}

// 今日一问状态
router.get('/today', authRequired, async (req, res) => {
  try {
    res.json({ code: 200, data: await buildState(req.user.id) });
  } catch (err) {
    console.error('[Daily] today failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 提交答案（双盲揭晓：两人都提交后互相可见）
router.post('/answer', authRequired, async (req, res) => {
  try {
    const answer = String(req.body.answer ?? '').trim();
    if (!answer) {
      return res.status(400).json({ code: 400, message: '答案不能为空' });
    }
    if (answer.length > 500) {
      return res.status(400).json({ code: 400, message: '答案太长了（500字以内）' });
    }

    const date = todayString();
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [existing] = await conn.query(
        'SELECT id FROM daily_answers WHERE user_id = ? AND question_date = ?',
        [req.user.id, date]
      );
      if (existing.length > 0) {
        await conn.rollback();
        return res.status(409).json({ code: 409, message: '今天已经答过了' });
      }
      await conn.query(
        'INSERT INTO daily_answers (question_date, user_id, answer_text) VALUES (?, ?, ?)',
        [date, req.user.id, answer]
      );
      await conn.commit();
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }

    // 提交本身 +2 豆（幂等：同一天同一来源只发一次）
    try {
      await addBeanTransaction(pool, {
        userId: req.user.id,
        amount: 2,
        type: 'daily_question',
        title: '每日一问',
        sourceModule: 'daily_question',
        sourceId: date,
        description: '完成今日一问',
      });
    } catch (err) {
      console.error('[Daily] bean reward failed:', err.message);
    }

    const state = await buildState(req.user.id);

    // 两人都答完：双方各 +5 豆 + 通知对方
    if (state.bothAnswered) {
      const partnerId = await getPartnerId(req.user.id);
      if (partnerId != null) {
        for (const uid of [req.user.id, partnerId]) {
          try {
            await addBeanTransaction(pool, {
              userId: uid,
              amount: 5,
              type: 'daily_question_both',
              title: '每日一问 · 双人完成',
              sourceModule: 'daily_question_both',
              sourceId: date,
              description: '两个人都完成了今日一问',
            });
          } catch (err) {
            console.error('[Daily] both reward failed:', err.message);
          }
        }
        try {
          await pool.query(
            'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
            [partnerId, 'daily_question', '今日一问 · 双双完成', '你们都答完了今天的问题，去看看对方的答案吧', JSON.stringify({ date })]
          );
        } catch (err) {
          console.error('[Daily] notify failed:', err.message);
        }
      }
    }

    res.json({ code: 200, data: state });
  } catch (err) {
    console.error('[Daily] answer failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 历史双方答案
router.get('/history', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      return res.json({ code: 200, data: [] });
    }
    const size = Math.min(30, Math.max(1, parseInt(req.query.size) || 14));
    const [rows] = await pool.query(
      `SELECT da.question_date, da.user_id, da.answer_text
       FROM daily_answers da
       WHERE da.user_id IN (?, ?)
       ORDER BY da.question_date DESC
       LIMIT 120`,
      [req.user.id, partnerId]
    );
    const byDate = new Map();
    for (const r of rows) {
      const d = dateToStr(r.question_date);
      if (!byDate.has(d)) byDate.set(d, {});
      byDate.get(d)[r.user_id] = r.answer_text;
    }
    const data = [];
    for (const [d, answers] of byDate) {
      const mine = answers[req.user.id];
      const theirs = answers[partnerId];
      if (mine != null && theirs != null) {
        data.push({ date: d, question: questionForDate(d), myAnswer: mine, partnerAnswer: theirs });
      }
      if (data.length >= size) break;
    }
    res.json({ code: 200, data });
  } catch (err) {
    console.error('[Daily] history failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
