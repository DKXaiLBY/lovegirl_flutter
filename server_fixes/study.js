const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');

const subjects = new Set(['politics', 'management', 'accounting']);
const kinds = new Set(['recall', 'choice', 'blank', 'journal']);
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const cardIdPattern = /^[A-Za-z0-9_-]{8,80}$/;
const boundedString = (value, min, max) =>
  typeof value === 'string' && value.trim().length >= min && value.length <= max;

function validQuestion(question) {
  if (!question || !kinds.has(question.kind) ||
      !boundedString(question.prompt, 1, 700) ||
      !boundedString(question.answer, 1, 2400) ||
      !boundedString(question.source, 1, 2400) ||
      !Array.isArray(question.options)) return false;
  if (question.kind !== 'choice') return question.options.length === 0;
  return question.options.length === 4 &&
    new Set(question.options).size === 4 &&
    question.options.every((option) => boundedString(option, 1, 260)) &&
    question.options.includes(question.answer);
}

function validCard(card) {
  return card && typeof card.id === 'string' && cardIdPattern.test(card.id) &&
    subjects.has(card.subject) && boundedString(card.title, 1, 120) &&
    boundedString(card.reference, 0, 200) && boundedString(card.notes, 1, 12000) &&
    Array.isArray(card.questions) && card.questions.length <= 6 &&
    card.questions.every((question) =>
      validQuestion(question) && card.notes.includes(question.source)) &&
    (card.dueOn === null || (typeof card.dueOn === 'string' && datePattern.test(card.dueOn))) &&
    Number.isInteger(card.level) && card.level >= 0 && card.level <= 3 &&
    Number.isInteger(card.attempts) && card.attempts >= 0 && card.attempts <= 100000;
}

const empty = { cards: [], showOnToday: false };

router.get('/', authRequired, async (req, res) => {
  try {
    const [[row]] = await pool.query(
      'SELECT revision, document FROM study_workspaces WHERE user_id = ?', [req.user.id]
    );
    const document = row ? row.document : empty;
    res.json({ code: 200, data: {
      revision: row?.revision ?? 0,
      document: typeof document === 'string' ? JSON.parse(document) : document,
    }});
  } catch (error) {
    console.error('[Study]', error.code || error.name);
    res.status(503).json({ code: 503, message: '备考资料暂时无法读取，请重试' });
  }
});

router.put('/', authRequired, async (req, res) => {
  const { owner, revision, document } = req.body || {};
  if (owner !== req.user.id) {
    return res.status(403).json({ code: 403, message: '账号已切换，请重新打开备考' });
  }
  if (!Number.isInteger(revision) || revision < 0 || revision > 4294967293 ||
      !document || typeof document.showOnToday !== 'boolean' ||
      !Array.isArray(document.cards) || document.cards.length > 300 ||
      !document.cards.every(validCard) ||
      new Set(document.cards.map((card) => card.id)).size !== document.cards.length) {
    return res.status(400).json({ code: 400, message: '考点或题目内容有误，请检查后再保存' });
  }
  const payload = JSON.stringify({ cards: document.cards, showOnToday: document.showOnToday });
  if (Buffer.byteLength(payload) > 2 * 1024 * 1024) {
    return res.status(413).json({ code: 413, message: '备考资料达到容量，请精简长篇讲义' });
  }
  try {
    const userId = req.user.id;
    if (revision === 0) {
      const [insert] = await pool.query(
        'INSERT IGNORE INTO study_workspaces (user_id, revision, document) VALUES (?, 1, ?)',
        [userId, payload]
      );
      if (insert.affectedRows === 1) {
        return res.json({ code: 200, data: { revision: 1 } });
      }
    } else {
      const [update] = await pool.query(
        'UPDATE study_workspaces SET document = ?, revision = revision + 1 WHERE user_id = ? AND revision = ?',
        [payload, userId, revision]
      );
      if (update.affectedRows === 1) {
        return res.json({ code: 200, data: { revision: revision + 1 } });
      }
    }
    return res.status(409).json({ code: 409, message: '另一台设备已更新备考资料，请刷新后重试' });
  } catch (error) {
    console.error('[Study]', error.code || error.name);
    return res.status(503).json({ code: 503, message: '备考资料暂未保存，请重试' });
  }
});

module.exports = router;
