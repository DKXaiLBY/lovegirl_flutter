const test = require('node:test');
const assert = require('node:assert/strict');
const { groundedDrafts, createDrafts } = require('../study_drafts');

test('AI prompts keep exact matching sources and discard invented answers and duplicates', () => {
  const quote = '计划包含确定目标和选择行动方案。';
  const valid = { prompt: '计划包含什么？', answer: '确定目标和选择行动方案', source: quote };
  assert.deepEqual(groundedDrafts({ questions: [
    { ...valid, prompt: '幻构', answer: '直接控制' },
    { ...valid, prompt: '假出处', source: '答案不在当前材料中' },
    valid, valid, null,
  ] }, quote), [{ ...valid, kind: 'recall', options: [] }]);
});

test('AI draft route requires account and explicit consent before any provider call', async () => {
  const original = process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY;
  process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY = 'local-test-placeholder';
  try {
    const response = { status(value) { this.code = value; return this; }, json() { return this; } };
    await createDrafts({ user: { id: 21 }, body: { owner: 22, consent: true } }, response);
    assert.equal(response.code, 403);
    await createDrafts({ user: { id: 21 }, body: { owner: 21, consent: false, source: '这是仅用于验证授权条件的测试资料。', subject: 'politics' } }, response);
    assert.equal(response.code, 400);
  } finally {
    if (original === undefined) delete process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY;
    else process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY = original;
  }
});

test('model response stays a draft and preserves matching quotation', async (t) => {
  const original = process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY;
  process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY = 'local-test-placeholder';
  const source = '会计分录在同一笔交易中记录借方科目及贷方科目。';
  try {
    t.mock.method(globalThis, 'fetch', async (url, options) => {
      assert.equal(url, 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      const raw = JSON.parse(options.body);
      assert.deepEqual(JSON.parse(raw.messages[1].content), { subject: 'accounting', material: source });
      return { ok: true, json: async () => ({ choices: [{ message: {
        content: JSON.stringify({ questions: [{ prompt: '会计分录记录什么？', answer: '借方科目及贷方科目', source }] }),
      } }] }) };
    });
    const res = { status(value) { this.code = value; return this; }, json(data) { this.data = data; } };
    await createDrafts({ user: { id: 33 }, body: { owner: 33, subject: 'accounting', source, consent: true } }, res);
    assert.equal(res.data.code, 200);
    assert.equal(res.data.data.questions[0].source, source);
  } finally {
    if (original === undefined) delete process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY;
    else process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY = original;
  }
});
