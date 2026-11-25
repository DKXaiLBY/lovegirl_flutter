const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const drafts = require('./study_drafts');
const ocr = require('./study_ocr');
const coach = require('./study_coach');
const { partnerId } = require('../utils/creation_access');

const subjects = new Set(['politics', 'management', 'accounting']);
const kinds = new Set(['recall', 'choice', 'multiChoice', 'blank', 'multiBlank', 'journal']);
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const cardIdPattern = /^[A-Za-z0-9_-]{8,80}$/;
const fileIdPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
const boundedString = (value, min, max) =>
  typeof value === 'string' && value.trim().length >= min && value.length <= max;

function validQuestion(question) {
  if (!question || !kinds.has(question.kind) ||
      !boundedString(question.prompt, 1, 700) ||
      !boundedString(question.answer, 1, 2400) ||
      !boundedString(question.source, 1, 2400) ||
      (question.explanation != null && !boundedString(question.explanation, 1, 1200)) ||
      !Array.isArray(question.options) ||
      !validPage(question.questionPage) || !validPage(question.answerPage)) return false;
  const parts = question.answerParts ?? [];
  if (!Array.isArray(parts) || parts.length > 8 ||
      !parts.every((part) => boundedString(part, 1, 700))) return false;
  if (question.kind === 'choice' || question.kind === 'multiChoice') {
    if (question.options.length !== 4 || new Set(question.options).size !== 4 ||
        !question.options.every((option) => boundedString(option, 1, 260))) return false;
    return question.kind === 'choice'
      ? parts.length === 0 && question.options.includes(question.answer)
      : parts.length >= 2 && new Set(parts).size === parts.length &&
        parts.every((part) => question.options.includes(part));
  }
  if (question.options.length !== 0) return false;
  if (question.kind === 'multiBlank') {
    return parts.length >= 2 && (question.prompt.match(/_{2,}/g) || []).length === parts.length;
  }
  return parts.length === 0;
}

function validPage(page) {
  return page === undefined || page === null ||
    (typeof page.documentId === 'string' && fileIdPattern.test(page.documentId) &&
      boundedString(page.name, 1, 160) && Number.isInteger(page.page) && page.page >= 1 && page.page <= 20000);
}

function richQuestion(question) {
  return question.kind === 'multiBlank' || question.kind === 'multiChoice' ||
    question.questionPage != null || question.answerPage != null;
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
const needsUpgrade = (res) => res.status(426).json({ code: 426, message: '请更新 LoveGirl 后查看或修改导入的题目' });

router.post('/drafts', authRequired, drafts.draftLimit, drafts.createDrafts);
router.post('/ocr', authRequired, ocr.ocrLimit, ocr.recognizePage);
router.post('/ask', authRequired, coach.askLimit, coach.ask);
router.post('/chapter', authRequired, coach.chapterLimit, coach.uploadPdf, coach.generateChapter(validCard, subjects));

router.post('/chapter/share', authRequired, async (req, res) => {
  const { owner, cards } = req.body || {};
  if (owner !== req.user.id) {
    return res.status(403).json({ code: 403, message: '账号已切换，请重新打开备考' });
  }
  if (!Array.isArray(cards) || cards.length < 1 || cards.length > 8 || !cards.every(validCard) ||
      new Set(cards.map((card) => card.id)).size !== cards.length) {
    return res.status(400).json({ code: 400, message: '请先核对要发送的考点和练习' });
  }
  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const recipient = await partnerId(connection, req.user.id);
    if (recipient === null) {
      await connection.rollback();
      return res.status(409).json({ code: 409, message: '先绑定伴侣，再把本章发给 TA' });
    }
    await connection.query(
      'INSERT IGNORE INTO study_workspaces (user_id, revision, document) VALUES (?, 0, ?)',
      [recipient, JSON.stringify(empty)],
    );
    const [[row]] = await connection.query(
      'SELECT document FROM study_workspaces WHERE user_id = ? FOR UPDATE', [recipient],
    );
    const document = typeof row.document === 'string' ? JSON.parse(row.document) : row.document;
    const existing = new Set(document.cards.map((card) => card.id));
    const additions = cards.filter((card) => !existing.has(card.id)).map((card) => ({
      ...card, dueOn: null, level: 0, attempts: 0,
      questions: card.questions.map(({ questionPage, answerPage, ...question }) => question),
    }));
    if (additions.length) {
      document.cards.unshift(...additions);
      const payload = JSON.stringify(document);
      if (document.cards.length > 300 || Buffer.byteLength(payload) > 2 * 1024 * 1024) {
        await connection.rollback();
        return res.status(413).json({ code: 413, message: '对方备考资料已满，暂时无法发送' });
      }
      await connection.query(
        'UPDATE study_workspaces SET document = ?, revision = revision + 1 WHERE user_id = ?',
        [payload, recipient],
      );
    }
    await connection.commit();
    res.json({ code: 200, data: { count: additions.length } });
  } catch (error) {
    await connection?.rollback();
    console.error('[Study Share]', error.code || error.name);
    res.status(503).json({ code: 503, message: '本章暂未发送，请重试' });
  } finally {
    connection?.release();
  }
});

router.get('/', authRequired, async (req, res) => {
  try {
    const [[row]] = await pool.query(
      'SELECT revision, document FROM study_workspaces WHERE user_id = ?', [req.user.id]
    );
    const stored = row ? row.document : empty;
    const document = typeof stored === 'string' ? JSON.parse(stored) : stored;
    if (req.query.schema !== '2' && document.schema === 2) return needsUpgrade(res);
    const draftService = drafts.provider();
    const ocrService = ocr.provider();
    res.json({ code: 200, data: {
      revision: row?.revision ?? 0,
      document,
      ...(req.query.schema === '2' ? {
        aiAvailable: Boolean(draftService),
        ocrAvailable: Boolean(ocrService),
        coachAvailable: coach.configured(),
        aiProvider: draftService?.label,
        ocrProvider: ocrService?.label
      } : {}),
    }});
  } catch (error) {
    console.error('[Study]', error.code || error.name);
    res.status(503).json({ code: 503, message: '备考资料暂时无法读取，请重试' });
  }
});

router.put('/', authRequired, async (req, res) => {
  const { owner, revision, document, schema } = req.body || {};
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
  const rich = document.cards.some((card) => card.questions.some(richQuestion));
  if (rich && schema !== 2) return needsUpgrade(res);
  const payload = JSON.stringify({ cards: document.cards, showOnToday: document.showOnToday,
    ...(rich ? { schema: 2 } : {}) });
  if (Buffer.byteLength(payload) > 2 * 1024 * 1024) {
    return res.status(413).json({ code: 413, message: '备考资料达到容量，请精简长篇讲义' });
  }
  try {
    const userId = req.user.id;
    // Older clients replace the whole document. Prevent a legacy writer from
    // removing question types or PDF references it cannot represent.
    if (schema !== 2 && revision > 0) {
      const [[existing]] = await pool.query(
        "SELECT JSON_EXTRACT(document, '$.schema') AS version FROM study_workspaces WHERE user_id = ? AND revision = ?",
        [userId, revision]);
      if (Number(existing?.version) === 2) return needsUpgrade(res);
    }
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
