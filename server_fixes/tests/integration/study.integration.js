const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const bcrypt = require('bcryptjs');
const pool = require('./config/database');

const origin = 'http://127.0.0.1:3011';

async function request(path, { token, method = 'GET', data } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const response = await fetch(origin + '/api' + path, {
    method, headers, signal: AbortSignal.timeout(8000),
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  return { status: response.status, body: await response.json() };
}

async function main() {
  const [[schema]] = await pool.query('SELECT DATABASE() AS name');
  assert.equal(schema.name, 'lovegirl_clear_qa_20261031');
  const prefix = 'qa_study_' + randomBytes(6).toString('hex');
  const password = randomBytes(16).toString('hex');
  const userIds = [];
  try {
    const accounts = [];
    for (const suffix of ['_a', '_b']) {
      const username = prefix + suffix;
      const [user] = await pool.query(
        "INSERT INTO users (username,password_hash,nickname,role,gender,is_admin) VALUES (?,?,'Study QA','girl','female',0)",
        [username, await bcrypt.hash(password, 10)],
      );
      userIds.push(user.insertId);
      const login = await request('/auth/login', { method: 'POST', data: { username, password } });
      assert.equal(login.status, 200);
      accounts.push(login.body.data.accessToken);
    }
    const [owner, other] = userIds;
    const [token, otherToken] = accounts;
    const get = (auth) => request('/study', { token: auth });
    const put = (auth, payload) => request('/study', { token: auth, method: 'PUT', data: payload });
    const source = '计划包含确定目标和选择行动方案。';
    const card = {
      id: 'study-card-001', title: '计划', reference: '测试资料第1页',
      notes: source, subject: 'management',
      questions: [{ kind: 'recall', prompt: '计划包含什么？', source, answer: source, options: [] }],
      dueOn: null, level: 0, attempts: 0,
    };
    const document = { cards: [card], showOnToday: true };
    assert.equal((await get()).status, 401);
    assert.deepEqual((await get(token)).body.data.document.cards, []);
    assert.equal((await put(otherToken, { owner, revision: 0, document })).status, 403);
    assert.equal((await put(token, { owner, revision: 0, document: {
      ...document, cards: [{ ...card, notes: '不同的资料。' }],
    }})).status, 400);
    const first = await put(token, { owner, revision: 0, document });
    assert.equal(first.status, 200);
    assert.equal(first.body.data.revision, 1);
    assert.deepEqual((await get(otherToken)).body.data.document.cards, []);
    assert.deepEqual((await get(token)).body.data.document, document);
    const otherSave = await put(otherToken, { owner: other, revision: 0, document: { cards: [], showOnToday: false } });
    assert.equal(otherSave.status, 200);
    const altered = { ...card, dueOn: '2026-11-25', level: 0, attempts: 1 };
    const outcomes = await Promise.all([
      put(token, { owner, revision: 1, document: { ...document, cards: [altered] } }),
      put(token, { owner, revision: 1, document: { ...document, cards: [{ ...altered, level: 1 }] } }),
    ]);
    assert.deepEqual(outcomes.map((value) => value.status).sort(), [200, 409]);
    assert.equal((await get(token)).body.data.document.cards[0].attempts, 1);
    assert.equal((await get(otherToken)).body.data.document.cards.length, 0);
    console.log('PASS authenticated independent study workspaces, source validation, revisions and persisted reviews');
  } finally {
    for (const id of userIds) {
      await pool.query('DELETE FROM study_workspaces WHERE user_id = ?', [id]);
      await pool.query('DELETE FROM users WHERE id = ? AND LEFT(username, ?) = ?', [id, prefix.length, prefix]);
    }
  }
}

main().catch((error) => {
  console.error(error.code === 'ERR_ASSERTION' ? error.message : error.code || error.name);
  process.exitCode = 1;
}).finally(() => pool.end());
