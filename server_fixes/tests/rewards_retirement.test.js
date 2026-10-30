const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');

function fixture(active = false) {
  const calls = [];
  const pool = {
    async query(sql, args) {
      calls.push({ sql, args });
      if (!active) throw Error('Retired rewards must not query the database');
      if (sql.includes('FROM couples')) return [[{ partner_id: 72 }]];
      if (sql.startsWith('SELECT')) return [[]];
      return [{ insertId: 81 }];
    },
    async getConnection() {
      calls.push({ connection: true });
      throw Error('Retired rewards must not open a transaction');
    },
  };
  const filename = path.resolve(__dirname, '../utils/lovegirl_rewards.js');
  const loaded = new Module(filename, module);
  loaded.filename = filename;
  loaded.paths = Module._nodeModulePaths(path.dirname(filename));
  const original = loaded.require.bind(loaded);
  loaded.require = name => {
    if (name === '../../config/database') return pool;
    if (name === '../../config/encrypt') return {
      encrypt: text => 'cipher:' + text,
      decrypt: text => text.replace(/^cipher:/, ''),
    };
    return original(name);
  };
  loaded._compile(fs.readFileSync(filename, 'utf8'), filename);
  return { rewards: loaded.exports, pool, calls };
}

test('retired bean grants and deductions perform no database work', async () => {
  const f = fixture();
  for (const amount of [5, -5]) {
    assert.equal(await f.rewards.addBeanTransaction(f.pool, {
      userId: 71, amount, type: 'kitchen_order_done', title: '开饭',
    }), null);
  }
  assert.deepEqual(f.calls, []);
});

test('retired standalone awards cannot start transactions', async () => {
  const f = fixture();
  assert.equal(await f.rewards.awardBeans({ userId: 71, amount: 10,
    type: 'cooking_new', title: '新菜' }), null);
  assert.deepEqual(f.calls, []);
});

test('achievement checks and seeding do not alter legacy tables', async () => {
  const f = fixture();
  await f.rewards.ensureAchievementsSeeded(f.pool);
  assert.deepEqual(await f.rewards.checkAchievements(71, 'cooking'), []);
  assert.deepEqual(f.rewards.achievementSeeds, []);
  assert.deepEqual(f.calls, []);
});

test('legacy check-in progress and travel badges cannot query or write', async () => {
  const f = fixture();
  assert.equal(await f.rewards.getCheckinStreak(71), 0);
  await f.rewards.unlockTravelAchievement(71, 'travel_1', '旅行');
  assert.deepEqual(f.calls, []);
});

test('finance linkage still encrypts data and keeps source references', async () => {
  const f = fixture(true);
  assert.equal(await f.rewards.createFinanceRecord({ userId: 71,
    category: '餐饮', amount: 29, description: '晚饭', sourceModule: 'kitchen',
    sourceId: 19, recordDate: '2026-10-31' }), 81);
  const insert = f.calls.find(c => c.sql.startsWith('INSERT INTO finance_records'));
  assert.ok(insert);
  assert.ok(insert.args.includes('cipher:29'));
  assert.ok(insert.args.includes('cipher:晚饭'));
  assert.ok(insert.args.includes('kitchen'));
  assert.ok(insert.args.includes(19));
  assert.equal(f.calls.some(c => /bean|achievements/.test(c.sql)), false);
});

test('timeline linkage and partner lookup remain available without rewards', async () => {
  const f = fixture(true);
  assert.equal(await f.rewards.getPartnerId(71), 72);
  assert.equal(await f.rewards.createTimelineEvent({ userId: 71,
    title: '一起开饭', sourceModule: 'cooking', sourceId: 19,
    eventDate: '2026-10-31', imageUrl: '/uploads/dinner.jpg' }), 81);
  assert.ok(f.calls.some(c => c.sql.startsWith('INSERT INTO love_timeline')));
  assert.equal(f.calls.some(c => /bean|achievements/.test(c.sql)), false);
});
