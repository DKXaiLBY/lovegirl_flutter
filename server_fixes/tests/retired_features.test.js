const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const express = require('express');

function fixture() {
  const file = path.resolve(__dirname, '../retired_features.js');
  const loaded = new Module(file, module);
  loaded.filename = file;
  loaded.paths = Module._nodeModulePaths(path.dirname(file));
  loaded.require = name => {
    assert.equal(name, '../middleware/auth');
    return { authRequired(req, res, next) {
      if (!req.headers['x-test-user']) return res.status(401).json({ code: 401 });
      req.user = { id: 71 };
      next();
    } };
  };
  loaded._compile(fs.readFileSync(file, 'utf8'), file);
  const app = express();
  loaded.exports(app);
  app.get('/api/daily/quote', (_, res) => res.json({ code: 200, quotation: true }));
  app.post('/api/kitchen/orders', (_, res) => res.json({ code: 200, kitchen: true }));
  // A future accidentally retained legacy router must not receive these calls.
  app.use('/api/beans', (_, res) => res.status(500).json({ legacyHandlerReached: true }));
  return app;
}

async function withServer(run) {
  const app = fixture();
  const server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  const request = async (suffix, { method = 'GET', authenticated = true } = {}) => {
    const response = await fetch('http://127.0.0.1:' + server.address().port + suffix, {
      method, headers: authenticated ? { 'x-test-user': '71' } : {},
    });
    return { status: response.status, body: await response.json() };
  };
  try { await run(request); }
  finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
}

test('retired namespaces cannot invoke legacy actions through any method', async () => {
  await withServer(async request => {
    for (const route of ['/api/beans/checkin', '/api/beans/check-in', '/api/achievements/check',
      '/api/letter/17', '/api/voucher/17/redeem', '/api/daily/today',
      '/api/daily/answer', '/api/daily/history']) {
      for (const method of ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        const result = await request(route, { method });
        assert.equal(result.status, 410, method + ' ' + route);
        assert.equal(result.body.data.retired, true);
        assert.equal(result.body.message, '该功能已停用，历史记录已保留');
      }
    }
  });
});

test('authentication remains required for retired private namespaces', async () => {
  await withServer(async request => {
    for (const route of ['/api/beans/balance', '/api/achievements', '/api/letter',
      '/api/voucher', '/api/daily/history']) {
      assert.equal((await request(route, { authenticated: false })).status, 401);
    }
  });
});

test('case, trailing slash and query do not reopen retired actions', async () => {
  await withServer(async request => {
    for (const route of ['/API/BEANS/checkin/', '/api/letter/?page=1', '/api/daily/ANSWER/']) {
      assert.equal((await request(route, { method: 'POST' })).status, 410);
    }
  });
});

test('quotation and real kitchen namespaces remain reachable', async () => {
  await withServer(async request => {
    assert.equal((await request('/api/daily/quote')).body.quotation, true);
    assert.equal((await request('/api/kitchen/orders', { method: 'POST' })).body.kitchen, true);
  });
});

test('production mount registers retirement before business routes and removes old loaders', () => {
  const app = fs.readFileSync(path.resolve(__dirname, '../app.js'), 'utf8');
  assert.ok(app.indexOf("require('./routes/retired_features')(app)") < app.indexOf("app.use('/api/auth'"));
  assert.ok(app.includes("require('./routes/retired_features')(app)"));
  for (const route of ['beans', 'achievements', 'daily_question', 'slow_letter', 'wish_voucher']) {
    assert.equal(app.includes("require('./routes/" + route + "')"), false);
  }
});
