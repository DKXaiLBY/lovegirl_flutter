const assert = require('node:assert/strict');
const test = require('node:test');
const { recognizePage } = require('../study_ocr');
const { studyProvider } = require('../study_provider');

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0xff, 0xd9]).toString('base64');
const body = { owner: 37, consent: true, role: 'answer', image: jpeg };
const request = (patch) => ({ user: { id: 37 }, body: { ...body, ...patch } });
const response = () => ({
  status(code) { this.statusCode = code; return this; },
  json(payload) { this.payload = payload; return this; },
});

function configure(t, task, base) {
  const values = {
    BASE_URL: base, MODEL: 'deepseek-flash', API_KEY: 'only-fixture',
  };
  for (const [suffix, value] of Object.entries(values)) {
    const key = `LOVEGIRL_STUDY_${task}_${suffix}`;
    const before = process.env[key];
    process.env[key] = value;
    t.after(() => {
      if (before === undefined) delete process.env[key];
      else process.env[key] = before;
    });
  }
}

test('the server configures OCR and question drafting independently', (t) => {
  configure(t, 'OCR', 'https://api.deepseek.com/');
  configure(t, 'TEXT', 'https://text.example.invalid/v1/chat/completions');
  assert.equal(studyProvider('OCR').url, 'https://api.deepseek.com/chat/completions');
  assert.equal(studyProvider('TEXT').url, 'https://text.example.invalid/v1/chat/completions');
  process.env.LOVEGIRL_STUDY_OCR_BASE_URL = 'http://example.invalid';
  assert.equal(studyProvider('OCR'), null);
});

test('rejects account mismatches, missing consent and non-image input before contacting the provider', async (t) => {
  configure(t, 'OCR', 'https://api.deepseek.com');
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    assert.fail('rejected page reached provider');
  });
  for (const [patch, code] of [
    [{ owner: 38 }, 403], [{ consent: false }, 400],
    [{ image: 'https://example.invalid/page.jpg' }, 400],
    [{ role: 'reflection' }, 400],
  ]) {
    const res = response();
    await recognizePage(request(patch), res);
    assert.equal(res.statusCode, code);
  }
  assert.equal(fetch.mock.callCount(), 0);
});

test('sends the single confirmed page to DeepSeek and returns editable text without saving', async (t) => {
  configure(t, 'OCR', 'https://api.deepseek.com');
  const text = '第一章\n单项选择题\n1. A\n2. C';
  const call = t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://api.deepseek.com/chat/completions');
    assert.equal(options.redirect, 'error');
    const payload = JSON.parse(options.body);
    assert.equal(payload.model, 'deepseek-flash');
    assert.deepEqual(payload.thinking, { type: 'disabled' });
    assert.equal(payload.messages[1].content[0].image_url.url, `data:image/jpeg;base64,${jpeg}`);
    assert.match(payload.messages[0].content, /每组一行/);
    assert.equal(Object.hasOwn(payload, 'owner'), false);
    return { ok: true, json: async () => ({ choices: [
      { finish_reason: 'stop', message: { content: text } },
    ] }) };
  });
  const res = response();
  await recognizePage(request(), res);
  assert.deepEqual(res.payload, { code: 200, data: { text } });
  assert.equal(call.mock.callCount(), 1);
});

test('rejects incomplete transcriptions and keeps local result messaging', async (t) => {
  configure(t, 'OCR', 'https://vision.example.invalid/v1');
  t.mock.method(globalThis, 'fetch', async () => ({
    ok: true,
    json: async () => ({ choices: [{ finish_reason: 'length', message: { content: '1. A' } }] }),
  }));
  const res = response();
  await recognizePage(request(), res);
  assert.equal(res.statusCode, 502);
  assert.match(res.payload.message, /本地结果仍在/);
});
