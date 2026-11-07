const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const express = require('express');

// Exercise the actual routers with database/auth boundaries replaced. No files,
// production accounts, map requests or real financial records are touched.
function fixture(route, query) {
  const calls = { sql: [], retired: [], timeline: [], finance: [], transactions: [] };
  const pool = {
    async query(sql, args = []) {
      calls.sql.push({ sql, args });
      assert.doesNotMatch(sql, /bean_balance|bean_transactions|user_achievements|\bachievements\b|daily_answers|slow_letters/);
      if (sql.includes('FROM couples')) return [[{ user1_id: 71, user2_id: 72, partner_id: 72 }]];
      return [await query(sql, args)];
    },
    async beginTransaction() { calls.transactions.push('begin'); },
    async commit() { calls.transactions.push('commit'); },
    async rollback() { calls.transactions.push('rollback'); },
    release() { calls.transactions.push('release'); },
    async getConnection() { return pool; },
  };
  const rewards = {
    todayString: () => '2026-11-01', safeDecrypt: value => value,
    getPartnerId: async () => 72, isUserInPeriod: async () => false,
    createTimelineEvent: async value => { calls.timeline.push(value); },
    createFinanceRecord: async value => { calls.finance.push(value); },
  };
  for (const name of ['addBeanTransaction', 'checkAchievements', 'unlockTravelAchievement']) {
    rewards[name] = async (...args) => { calls.retired.push({ name, args }); return name === 'checkAchievements' ? [] : null; };
  }
  const filename = path.resolve(__dirname, '../' + route + '.js');
  const loaded = new Module(filename, module);
  loaded.filename = filename;
  loaded.paths = Module._nodeModulePaths(path.dirname(filename));
  const original = loaded.require.bind(loaded);
  loaded.require = name => {
    if (name === '../config/database') return pool;
    if (name === '../middleware/auth') return { authRequired(req, res, next) {
      req.user = { id: Number(req.headers['x-test-user'] || 71), role: 'boy' }; next();
    } };
    if (name === './utils/lovegirl_rewards') return rewards;
    if (name === 'fs') return { existsSync: () => true };
    if (name === 'multer') return Object.assign(() => ({ single: () => (_, __, next) => next() }), { diskStorage: options => options });
    return original(name);
  };
  loaded._compile(fs.readFileSync(filename, 'utf8'), filename);
  const app = express(); app.use(express.json()); app.use(loaded.exports);
  return { app, calls, pool };
}

async function request(f, suffix, method = 'GET', body, user = 71) {
  const server = await new Promise(resolve => {
    const instance = f.app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  try {
    const response = await fetch('http://127.0.0.1:' + server.address().port + suffix, {
      method, headers: { 'Content-Type': 'application/json', 'x-test-user': String(user) },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(5000),
    });
    return { status: response.status, body: await response.json() };
  } finally {
    server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
  }
}

test('completing a repeated todo keeps scheduling without calling rewards', async () => {
  const f = fixture('todo', sql => sql.startsWith('SELECT')
    ? [{ id: 8, user_id: 71, title: '整理行李', completed: 0, is_repeat: 1, due_date: '2026-11-01', repeat_type: 'daily' }]
    : { affectedRows: 1, insertId: 9 });
  assert.equal((await request(f, '/8/toggle', 'PUT', {})).body.data.completed, 1);
  assert.ok(f.calls.sql.find(c => c.sql.includes('INSERT INTO todos')).args.includes('2026-11-02'));
  assert.deepEqual(f.calls.retired, []);
});

test('anniversary creation and updating on the date keep data but grant nothing', async () => {
  const f = fixture('anniversary', () => ({ insertId: 8, affectedRows: 1 }));
  const body = { title: '一起的日子', eventDate: '2026-11-01' };
  assert.equal((await request(f, '/', 'POST', body)).body.data.id, 8);
  assert.equal((await request(f, '/8', 'PUT', body)).status, 200);
  assert.deepEqual(f.calls.retired, []);
});

test('a new mood record keeps the legacy empty unlock list without achievements', async () => {
  const f = fixture('mood', sql => sql.startsWith('SELECT') ? [] : { insertId: 8 });
  const result = await request(f, '/', 'POST', { mood: '0', note: '一起散步' });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data, { id: 8, unlocked: [] });
  assert.deepEqual(f.calls.retired, []);
});

test('new cooking entry keeps menu, both timelines and partner notification', async () => {
  const f = fixture('cooking', sql => sql.startsWith('SELECT') ? [] : { insertId: 8, affectedRows: 1 });
  const result = await request(f, '/', 'POST', { title: '番茄炒蛋', isNew: true, addToMenu: true });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data, { id: 8, dishId: 8, unlocked: [] });
  assert.deepEqual(f.calls.timeline.map(c => c.userId), [71, 72]);
  assert.ok(f.calls.sql.some(c => c.sql.includes('INSERT INTO kitchen_dishes')));
  assert.ok(f.calls.sql.some(c => c.sql.includes('INSERT INTO notifications')));
  assert.deepEqual(f.calls.retired, []);
});

test('partner tasting remains conditional and notifies the chef without points', async () => {
  const f = fixture('cooking', sql => sql.startsWith('SELECT')
    ? [{ id: 8, chef_id: 72, eater_id: null, title: '晚饭' }] : { affectedRows: 1 });
  assert.equal((await request(f, '/8/taste', 'PUT', { rating: 5 })).status, 200);
  assert.ok(f.calls.sql.some(c => c.sql.includes('AND eater_id IS NULL')));
  assert.ok(f.calls.sql.some(c => c.sql.includes('INSERT INTO notifications')));
  assert.deepEqual(f.calls.retired, []);
});

function kitchenFixture(user = 71, fail = false) {
  let order = { id: 8, cook_id: user, orderer_id: 72, status: 'accepted', beans_awarded: 0, items: '[]' };
  return fixture('kitchen', (sql, args) => {
    if (sql.startsWith('SELECT') && sql.includes('FROM kitchen_orders')) return [order];
    if (sql.includes("SET status = 'done'")) {
      if (fail) throw Error('controlled completion failure');
      order = { ...order, status: 'done', photo_url: args[0], done_at: args[1] };
    }
    return { affectedRows: 1, insertId: 81 };
  });
}

test('kitchen completion keeps the transaction and does not set legacy award flags', async () => {
  const f = kitchenFixture();
  const result = await request(f, '/orders/8/status', 'PUT', { status: 'done', photo_url: '/uploads/meal.jpg' });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.status, 'done');
  assert.equal(result.body.data.beans_earned, 0);
  assert.equal(result.body.data.beans_awarded, false);
  assert.equal(f.calls.sql.some(c => /UPDATE.*beans_awarded/i.test(c.sql)), false);
  assert.deepEqual(f.calls.transactions, ['begin', 'commit', 'release']);
  assert.deepEqual(f.calls.retired, []);
});

test('unauthorized and failed kitchen completions cannot grant points or announce success', async () => {
  const forbidden = kitchenFixture(73);
  assert.equal((await request(forbidden, '/orders/8/status', 'PUT', { status: 'done' })).status, 403);
  assert.deepEqual(forbidden.calls.retired, []);
  const failed = kitchenFixture(71, true);
  assert.equal((await request(failed, '/orders/8/status', 'PUT', { status: 'done', photo_url: '/uploads/meal.jpg' })).status, 500);
  assert.deepEqual(failed.calls.transactions, ['begin', 'rollback', 'release']);
  assert.equal(failed.calls.sql.some(c => c.sql.includes('INSERT INTO notifications')), false);
  assert.deepEqual(failed.calls.retired, []);
});

test('a meal can finish without a photo and a repeated completion creates no second notification', async () => {
  const f = kitchenFixture();
  const first = await request(f, '/orders/8/status', 'PUT', { status: 'done' });
  assert.equal(first.status, 200);
  assert.equal(first.body.data.photo_url, null);
  const repeated = await request(f, '/orders/8/status', 'PUT', { status: 'done' });
  assert.equal(repeated.status, 200);
  assert.equal(repeated.body.data.status, 'done');
  assert.equal(f.calls.sql.filter(c => c.sql.includes("SET status = 'done'")).length, 1);
  assert.equal(f.calls.sql.filter(c => c.sql.includes('INSERT INTO notifications')).length, 1);
  assert.ok(f.calls.sql.some(c => c.sql.includes('FOR UPDATE')));
});

test('only the cook can undo an accepted meal, and stale expected status is a conflict', async () => {
  let order = { id: 8, cook_id: 71, orderer_id: 72, status: 'accepted', items: '[]' };
  const f = fixture('kitchen', sql => {
    if (sql.startsWith('SELECT') && sql.includes('FROM kitchen_orders')) return [order];
    if (sql.includes("SET status = 'placed'")) order = { ...order, status: 'placed' };
    return { affectedRows: 1 };
  });
  assert.equal((await request(f, '/orders/8/status', 'PUT', { status: 'placed' }, 72)).status, 403);
  assert.equal((await request(f, '/orders/8/status', 'PUT', { status: 'placed', expected_status: 'placed' })).status, 409);
  assert.equal((await request(f, '/orders/8/status', 'PUT', { status: 'placed', expected_status: 'accepted' })).body.data.status, 'placed');
  assert.ok(f.calls.sql.some(c => c.sql.includes('accepted_at = NULL')));
});

test('a kitchen connection failure returns an error instead of escaping the async router', async () => {
  const f = fixture('kitchen', () => []);
  // The stub is scoped to the real route dependency; no process/database failure is induced.
  f.pool.getConnection = async () => { throw Error('controlled database unavailable'); };
  assert.equal((await request(f, '/orders/8/status', 'PUT', { status: 'done' })).status, 500);
});

test('visited places retain visit time, timeline, actual expense and partner notification', async () => {
  const f = fixture('travel', () => ({ insertId: 8, affectedRows: 1 }));
  const result = await request(f, '/spots', 'POST', { name: '沙坡尾', lng: 118.08, lat: 24.43, status: 'visited', budget: 20, visitedDate: '2026-11-01' });
  assert.equal(result.status, 200);
  assert.ok(f.calls.sql.some(c => c.sql.includes('checked_in_at = COALESCE')));
  assert.equal(f.calls.timeline[0].sourceId, 8);
  assert.equal(f.calls.finance[0].amount, 20);
  assert.ok(f.calls.sql.some(c => c.sql.includes('INSERT INTO notifications')));
  assert.deepEqual(f.calls.retired, []);
});

test('feeding orders record the request without a retired points payment or linked ledger update', async () => {
  const f = fixture('feeding_v2', sql => sql.includes('FROM feeding_products')
    ? [{ id: 8, name: '热汤面', price: '18.00', shop_id: 1 }] : { insertId: 9, affectedRows: 1 });
  const result = await request(f, '/orders', 'POST', { product_id: 8, quantity: 2 });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.total_price, 36);
  assert.deepEqual(f.calls.transactions, ['begin', 'commit', 'release']);
  assert.deepEqual(f.calls.retired, []);
  assert.deepEqual(f.calls.finance, []);
});

for (const [method, suffix, body] of [
  ['PUT', '/orders/8/status', { status: 'completed' }],
  ['POST', '/orders/8/fulfill', { actual_amount: 19 }],
  ['PUT', '/orders/8/delivery', { actual_amount: 19, delivery_status: 'completed' }],
]) {
  test('feeding completion keeps finance and timeline without rewards: ' + suffix, async () => {
    const f = fixture('feeding_v2', sql => sql.includes('FROM feeding_orders')
      ? [{ id: 8, sender_id: 72, receiver_id: 71, product_name: '热汤面', total_price: 18, status: 'delivering' }]
      : { affectedRows: 1 });
    assert.equal((await request(f, suffix, method, body)).status, 200);
    assert.equal(f.calls.finance.length, 1);
    assert.equal(f.calls.timeline.length, 1);
    assert.equal(f.calls.finance[0].sourceId, 8);
    assert.deepEqual(f.calls.retired, []);
  });
}

test('home reads active content only and returns neutral legacy reward fields', async () => {
  const f = fixture('home', sql => {
    if (sql.includes('FROM users')) return [{ id: 71, nickname: '测试', created_at: '2026-10-01' }];
    if (sql.includes('FROM todos')) return [{ total: 2, active: 1, dueToday: 1 }];
    if (sql.includes('FROM finance_records') && sql.includes("'expense'")) return [{ amount_encrypted: '19' }];
    return [];
  });
  const result = await request(f, '/today');
  assert.equal(result.status, 200);
  assert.equal(result.body.data.beanBalance, 0);
  assert.deepEqual(result.body.data.recentAchievements, []);
  assert.equal(result.body.data.todo.active, 1);
  assert.equal(result.body.data.financeToday.expense, 19);
  assert.equal(f.calls.sql.some(c => /bean|achievements/.test(c.sql)), false);
});

test('partner activity keeps cooking and travel without reading old question answers', async () => {
  const f = fixture('partner_recent', sql => {
    if (sql.includes('FROM cooking_logs')) return [{ id: 8, title: '晚饭', is_new: 1, cooked_at: '2026-11-01' }];
    if (sql.includes('FROM travel_spots')) return [{ id: 9, name: '沙坡尾', visited_date: '2026-10-31' }];
    return [];
  });
  const result = await request(f, '/recent');
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data.items.map(c => c.type), ['travel', 'cooking']);
  assert.equal(f.calls.sql.some(c => c.sql.includes('daily_answers')), false);
});

for (const suffix of ['/?year=2026', '/monthly?year=2026&month=11']) {
  test('report keeps active counts without reading retired histories: ' + suffix, async () => {
    const f = fixture('love_report', sql => {
      if (sql.includes('FROM photos')) return [{ n: 3 }];
      if (sql.includes('FROM love_timeline')) return [{ n: 4 }];
      if (sql.includes('FROM travel_spots')) return [{ spots: 2, cities: 1 }];
      return [];
    });
    const result = await request(f, suffix);
    assert.equal(result.status, 200);
    assert.equal(result.body.data.photos, 3);
    assert.equal(result.body.data.dailyDays, 0);
    assert.equal(result.body.data.letters, 0);
    assert.equal(result.body.data.beansEarned, 0);
    if (suffix.startsWith('/monthly')) assert.equal(result.body.data.beansSpent, 0);
    assert.equal(f.calls.sql.some(c => /daily_answers|slow_letters|bean_transactions/.test(c.sql)), false);
  });
}
