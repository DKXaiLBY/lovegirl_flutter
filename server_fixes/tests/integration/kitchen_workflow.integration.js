const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

// The external runner supplies ordinary QA sessions. This suite requires the
// owned schema and loopback endpoint; it never creates or signs session tokens.
module.exports = async function runKitchenWorkflow({ pool, tokens, users, baseUrl }) {
  const [database] = await pool.query('SELECT DATABASE() AS name');
  assert.equal(database[0].name, 'lovegirl_clear_qa_20261031');
  assert.equal(baseUrl, 'http://127.0.0.1:3000');
  const marker = 'QA_KITCHEN_' + crypto.randomUUID().replaceAll('-', '').slice(0, 12);
  const resources = { dishes: new Set(), orders: new Set(), logs: new Set() };
  const queries = {
    dishes: 'SELECT * FROM kitchen_dishes ORDER BY id',
    orders: 'SELECT * FROM kitchen_orders ORDER BY id',
    logs: 'SELECT * FROM cooking_logs ORDER BY id',
  };
  const before = {};
  for (const [kind, sql] of Object.entries(queries)) before[kind] = (await pool.query(sql))[0];
  const historicalQueries = [
    'SELECT id, bean_balance FROM users ORDER BY id',
    'SELECT * FROM bean_transactions ORDER BY id',
    'SELECT * FROM daily_answers ORDER BY id',
    'SELECT * FROM slow_letters ORDER BY id',
    'SELECT * FROM achievements ORDER BY id',
    'SELECT * FROM user_achievements ORDER BY id',
    'SELECT * FROM voucher_templates ORDER BY id',
    'SELECT * FROM voucher_redemptions ORDER BY id',
  ];
  async function history() {
    const result = [];
    for (const sql of historicalQueries) result.push(crypto.createHash('sha256').update(JSON.stringify((await pool.query(sql))[0])).digest('hex'));
    return result;
  }
  const historicBefore = await history();
  function remember(kind, id) {
    assert.ok(Number.isSafeInteger(id) && id > 0);
    assert.equal(before[kind].some(row => row.id === id), false, 'a new fixture must not reuse an original record');
    resources[kind].add(id);
    console.log('QA_RESOURCE:' + JSON.stringify({ kind, id, marker }));
    return id;
  }
  async function request(role, path, method = 'GET', body) {
    const response = await fetch(baseUrl + path, {
      method, headers: { Authorization: 'Bearer ' + tokens[role], 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(8000),
    });
    let json = {}; try { json = await response.json(); } catch (_) {}
    return { status: response.status, data: json.data };
  }
  async function ok(role, path, method, body) {
    const result = await request(role, path, method, body);
    assert.equal(result.status, 200, (method || 'GET') + ' ' + path);
    return result.data;
  }
  async function dish(role, suffix, extra = {}) {
    const saved = await ok(role, '/api/kitchen/dishes', 'POST', { name: marker + suffix, category: '家常菜', ...extra });
    remember('dishes', saved.id); return saved;
  }
  async function meal(role, cookId, dishId, extra = {}) {
    const data = await ok(role, '/api/kitchen/orders', 'POST', {
      cook_id: cookId, partner_id: users[role === 'boy' ? 'girl' : 'boy'],
      items: [{ dish_id: dishId, quantity: 1 }], note: marker,
      request_key: 'kw_' + crypto.randomUUID(), ...extra,
    });
    remember('orders', data.id); return data;
  }
  async function status(role, order, target) {
    const saved = await ok(role, '/api/kitchen/orders/' + order.id + '/status', 'PUT', {
      status: target, revision: order.revision, expected_status: order.status,
    });
    if (saved.cooking_log_id) remember('logs', saved.cooking_log_id);
    return saved;
  }
  let boyDish, girlDish, shared, completed, checkoutBody, checkoutMeal;
  let failureConstraint = false;
  try {
    await test('optional ingredients/recipe persist and another account cannot edit the dish', async () => {
      boyDish = await dish('boy', ' boy', { ingredients: '鸡蛋、番茄', recipe: '先炒鸡蛋，再放番茄。' });
      girlDish = await dish('girl', ' girl', { ingredients: '青菜', recipe: '大火快炒。' });
      assert.equal(boyDish.ingredients, '鸡蛋、番茄'); assert.equal(boyDish.recipe, '先炒鸡蛋，再放番茄。');
      assert.equal((await request('outside', '/api/kitchen/dishes/' + boyDish.id, 'PUT', { name: marker + ' bad' })).status, 403);
      assert.equal((await request('boy', '/api/kitchen/dishes/' + boyDish.id, 'PUT', { name: '   ' })).status, 400);
    });
    await test('legacy partner-chef checkout remains valid; arbitrary chefs and invalid dates are rejected', async () => {
      const legacy = await ok('boy', '/api/kitchen/orders', 'POST', { items: [{ dish_id: girlDish.id, quantity: 1 }], note: marker });
      remember('orders', legacy.id); assert.equal(legacy.cook_id, users.girl);
      assert.equal((await request('boy', '/api/kitchen/orders', 'POST', { cook_id: users.outside, items: [{ dish_id: girlDish.id, quantity: 1 }] })).status, 403);
      assert.equal((await request('boy', '/api/kitchen/orders', 'POST', { items: [{ dish_id: girlDish.id, quantity: 1 }], meal_date: '2026-02-30' })).status, 400);
      assert.equal((await request('boy', '/api/cooking/not-an-id')).status, 400);
      for (const quantity of [0, 10, 1.5]) assert.equal((await request('boy', '/api/kitchen/orders', 'POST', { items: [{ dish_id: girlDish.id, quantity }] })).status, 400);
      assert.equal((await request('boy', '/api/kitchen/orders', 'POST', { items: Array.from({length:21},(_,i)=>({dish_id:girlDish.id+i,quantity:1})) })).status, 400);
    });
    await test('self-chef meals remain visible to both participants and hidden from outsiders', async () => {
      shared = await meal('boy', users.boy, boyDish.id, { meal_date: (new Date().getFullYear() + 1) + '-01-01', meal_slot: 'dinner' });
      assert.equal(shared.partner_id, users.girl); assert.equal(shared.revision, 1);
      assert.equal(shared.meal_date, (new Date().getFullYear() + 1) + '-01-01');
      assert.equal(shared.meal_slot, 'dinner');
      const lists = await ok('girl', '/api/kitchen/orders');
      assert.ok([...lists.incoming, ...lists.outgoing].some(order => order.id === shared.id));
      assert.equal((await ok('girl', '/api/kitchen/orders/' + shared.id)).items[0].recipe, boyDish.recipe);
      assert.equal((await request('outside', '/api/kitchen/orders/' + shared.id)).status, 403);
    });
    await test('rotating a legacy null-partner meal persists its original second participant', async () => {
      const legacy = await meal('boy', users.girl, girlDish.id);
      await pool.query('UPDATE kitchen_orders SET partner_id = NULL WHERE id = ? AND orderer_id = ?', [legacy.id, users.boy]);
      const changed = await ok('girl', '/api/kitchen/orders/' + legacy.id, 'PUT', {
        revision: legacy.revision, cook_id: users.boy, items: [{ dish_id: boyDish.id, quantity: 1 }], note: marker + ' legacy rotation',
      });
      assert.equal(changed.partner_id, users.girl); assert.equal(changed.cook_id, users.boy);
      assert.equal((await ok('girl', '/api/kitchen/orders/' + legacy.id)).id, legacy.id);
    });
    await test('four simultaneous identical checkouts create one meal and one notification', async () => {
      const body = { cook_id: users.girl, partner_id: users.girl, items: [{ dish_id: girlDish.id, quantity: 2 }], request_key: 'kw_' + crypto.randomUUID(), note: marker };
      checkoutBody = body;
      const results = await Promise.all(Array.from({ length: 4 }, () => ok('boy', '/api/kitchen/orders', 'POST', body)));
      const ids = new Set(results.map(row => row.id)); assert.equal(ids.size, 1); remember('orders', results[0].id);
      checkoutMeal = results[0];
      const [counts] = await pool.query("SELECT COUNT(*) AS n FROM notifications WHERE type = 'kitchen_order' AND JSON_EXTRACT(payload, '$.order_id') = ?", [results[0].id]);
      assert.equal(counts[0].n, 1);
      assert.equal((await request('boy', '/api/kitchen/orders', 'POST', { ...body, note: marker + ' changed' })).status, 409);
    });
    await test('concurrent edits accept one revision and reject the stale form', async () => {
      const body = { cook_id: users.boy, items: [{ dish_id: boyDish.id, quantity: 1 }], revision: shared.revision, note: marker + ' edited' };
      const results = await Promise.all([request('boy', '/api/kitchen/orders/' + shared.id, 'PUT', body), request('girl', '/api/kitchen/orders/' + shared.id, 'PUT', { ...body, note: marker + ' other edit' })]);
      assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
      shared = results.find(r => r.status === 200).data; assert.equal(shared.revision, 2); assert.equal(shared.status, 'placed');
      assert.equal(shared.meal_date, (new Date().getFullYear() + 1) + '-01-01', 'editing a note must preserve an omitted meal date');
      assert.equal(shared.meal_slot, 'dinner', 'editing a note must preserve an omitted meal slot');
    });
    await test('changing an accepted meal chef requires confirmation and retains both participants', async () => {
      shared = await status('boy', shared, 'accepted');
      const stale = shared.revision;
      shared = await ok('girl', '/api/kitchen/orders/' + shared.id, 'PUT', { revision: shared.revision, cook_id: users.girl, items: [{ dish_id: girlDish.id, quantity: 1 }], note: marker + ' changed chef', meal_date: (new Date().getFullYear() + 1) + '-01-01' });
      assert.equal(shared.status, 'placed'); assert.equal(shared.accepted_at, null); assert.equal(shared.partner_id, users.girl);
      assert.equal((await request('boy', '/api/kitchen/orders/' + shared.id + '/status', 'PUT', { status: 'done', revision: stale })).status, 409);
      assert.equal((await ok('boy', '/api/kitchen/orders/' + shared.id)).id, shared.id);
    });
    await test('parallel no-photo completion creates one journal entry and two timelines', async () => {
      shared = await status('girl', shared, 'accepted');
      const results = await Promise.all(Array.from({ length: 4 }, () => ok('girl', '/api/kitchen/orders/' + shared.id + '/status', 'PUT', { status: 'done', revision: shared.revision })));
      completed = results[0]; remember('logs', completed.cooking_log_id);
      assert.ok(results.every(row => row.cooking_log_id === completed.cooking_log_id && row.status === 'done' && row.photo_url === null && row.beans_earned === 0));
      const [logs] = await pool.query('SELECT * FROM cooking_logs WHERE kitchen_order_id = ?', [shared.id]); assert.equal(logs.length, 1);
      assert.equal(logs[0].dish_id, null, 'meal memories must not use the legacy menu-deletion link');
      assert.equal(logs[0].recipe, `【${girlDish.name}】\n${girlDish.recipe}`);
      assert.notEqual(logs[0].cooked_at, shared.meal_date);
      const [timeline] = await pool.query("SELECT user_id FROM love_timeline WHERE source_module = 'cooking' AND source_id = ?", [completed.cooking_log_id]);
      assert.deepEqual(timeline.map(row => row.user_id).sort(), [users.boy, users.girl].sort());
      assert.equal((await ok('boy', '/api/cooking/' + completed.cooking_log_id)).kitchenOrderId, shared.id);
      assert.equal((await request('outside', '/api/cooking/' + completed.cooking_log_id)).status, 404);
    });
    await test('dish editing/removal preserves the ordered name and recipe snapshots', async () => {
      await ok('girl', '/api/kitchen/dishes/' + girlDish.id, 'PUT', { name: marker + ' renamed', recipe: '修改后的做法' });
      await ok('girl', '/api/kitchen/dishes/' + girlDish.id, 'DELETE');
      const stored = await ok('boy', '/api/kitchen/orders/' + shared.id);
      assert.equal(stored.items[0].name, girlDish.name); assert.equal(stored.items[0].recipe, girlDish.recipe);
      assert.equal((await ok('boy', '/api/kitchen/orders', 'POST', checkoutBody)).id, checkoutMeal.id);
    });
    await test('deleting the linked journal does not delete the meal or recreate it on retry', async () => {
      assert.equal((await request('girl', '/api/cooking/' + completed.cooking_log_id + 'oops', 'DELETE')).status, 400);
      assert.equal((await ok('girl', '/api/cooking/' + completed.cooking_log_id)).id, completed.cooking_log_id);
      await ok('girl', '/api/cooking/' + completed.cooking_log_id, 'DELETE');
      const retry = await ok('girl', '/api/kitchen/orders/' + shared.id + '/status', 'PUT', { status: 'done', revision: shared.revision });
      assert.equal(retry.status, 'done'); assert.equal(retry.cooking_log_id, null);
      const [logs] = await pool.query('SELECT id FROM cooking_logs WHERE kitchen_order_id = ?', [shared.id]); assert.equal(logs.length, 0);
      const [menu] = await pool.query('SELECT id FROM kitchen_dishes WHERE id = ?', [girlDish.id]);
      assert.equal(menu.length, 1, 'deleting a meal memory must preserve its menu entity');
    });
    await test('a journal write failure rolls back completion; retry writes once after recovery', async () => {
      const rollbackDish = await dish('boy', ' rollback');
      let order = await meal('girl', users.boy, rollbackDish.id); order = await status('boy', order, 'accepted');
      await pool.query('ALTER TABLE cooking_logs ADD CONSTRAINT qa_kitchen_memory_failure CHECK (title <> ?)', [rollbackDish.name]); failureConstraint = true;
      try {
        assert.equal((await request('boy', '/api/kitchen/orders/' + order.id + '/status', 'PUT', { status: 'done', revision: order.revision })).status, 500);
        const stored = await ok('girl', '/api/kitchen/orders/' + order.id); assert.equal(stored.status, 'accepted'); assert.equal(stored.revision, order.revision);
        const [logs] = await pool.query('SELECT id FROM cooking_logs WHERE kitchen_order_id = ?', [order.id]); assert.equal(logs.length, 0);
      } finally { await pool.query('ALTER TABLE cooking_logs DROP CHECK qa_kitchen_memory_failure'); failureConstraint = false; }
      const saved = await status('boy', order, 'done'); assert.ok(saved.cooking_log_id);
    });
    await test('adding an existing inactive dish from the journal restores the same menu entry', async () => {
      await ok('boy', '/api/kitchen/dishes/' + boyDish.id, 'DELETE');
      const log = await ok('boy', '/api/cooking', 'POST', { title: boyDish.name, addToMenu: true, isNew: false }); remember('logs', log.id);
      assert.equal(log.dishId, boyDish.id);
      assert.ok((await ok('boy', '/api/kitchen/menu')).mine.some(row => row.id === boyDish.id));
      await ok('boy', '/api/cooking/' + log.id, 'DELETE');
      assert.ok((await ok('boy', '/api/kitchen/menu')).mine.some(row => row.id === boyDish.id), 'removing a journal entry must not remove the menu');
    });
  } finally {
    if (failureConstraint) await pool.query('ALTER TABLE cooking_logs DROP CHECK qa_kitchen_memory_failure');
    // Include marked inserts whose response could have failed after commit.
    for (const [kind, sql] of Object.entries({
      dishes: 'SELECT id FROM kitchen_dishes WHERE LEFT(name, ?) = ? AND user_id IN (?, ?)',
      orders: 'SELECT id FROM kitchen_orders WHERE LEFT(note, ?) = ? AND orderer_id IN (?, ?)',
      logs: 'SELECT id FROM cooking_logs WHERE LEFT(title, ?) = ? AND chef_id IN (?, ?)',
    })) {
      const [rows] = await pool.query(sql, [marker.length, marker, users.boy, users.girl]);
      for (const row of rows) remember(kind, row.id);
    }
    // Cleanup is restricted to IDs returned by this run and their marked rows.
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      for (const id of resources.orders) {
        const [rows] = await conn.query('SELECT orderer_id, note FROM kitchen_orders WHERE id = ?', [id]);
        assert.ok(rows.length && [users.boy, users.girl].includes(rows[0].orderer_id) && rows[0].note.startsWith(marker));
        const [logs] = await conn.query('SELECT id FROM cooking_logs WHERE kitchen_order_id = ?', [id]);
        for (const log of logs) resources.logs.add(log.id);
        await conn.query("DELETE FROM notifications WHERE type = 'kitchen_order' AND JSON_EXTRACT(payload, '$.order_id') = ? AND user_id IN (?, ?)", [id, users.boy, users.girl]);
      }
      for (const id of resources.logs) {
        const [logs] = await conn.query('SELECT title, chef_id FROM cooking_logs WHERE id = ?', [id]);
        if (logs.length) assert.ok(logs[0].title.startsWith(marker) && [users.boy, users.girl].includes(logs[0].chef_id));
        await conn.query("DELETE FROM love_timeline WHERE source_module = 'cooking' AND source_id = ? AND user_id IN (?, ?)", [id, users.boy, users.girl]);
        await conn.query("DELETE FROM notifications WHERE type IN ('cooking','cooking_taste') AND JSON_EXTRACT(payload, '$.cooking_id') = ? AND user_id IN (?, ?)", [id, users.boy, users.girl]);
        await conn.query('DELETE FROM cooking_logs WHERE id = ? AND chef_id IN (?, ?)', [id, users.boy, users.girl]);
      }
      for (const id of resources.orders) await conn.query('DELETE FROM kitchen_orders WHERE id = ? AND orderer_id IN (?, ?)', [id, users.boy, users.girl]);
      for (const id of resources.dishes) {
        const [rows] = await conn.query('SELECT user_id, name FROM kitchen_dishes WHERE id = ?', [id]);
        if (!rows.length) continue; // A destructive bug is asserted by the case, not hidden by cleanup.
        assert.ok(rows[0].name.startsWith(marker) && [users.boy, users.girl].includes(rows[0].user_id));
        await conn.query('DELETE FROM kitchen_dishes WHERE id = ? AND user_id IN (?, ?)', [id, users.boy, users.girl]);
      }
      await conn.commit();
    } catch (error) { await conn.rollback(); throw error; }
    finally { conn.release(); }
  }
  await test('pre-existing rows and all eight retired history groups are unchanged', async () => {
    for (const [kind, sql] of Object.entries(queries)) {
      const [current] = await pool.query(sql), ids = new Set(before[kind].map(row => row.id));
      assert.deepEqual(current.filter(row => ids.has(row.id)), before[kind], kind);
      assert.equal(current.some(row => resources[kind].has(row.id)), false, 'owned fixtures must be cleaned');
    }
    assert.deepEqual(await history(), historicBefore);
  });
  console.log('QA_WORKFLOW_RESULT:' + JSON.stringify({ marker, cleaned: Object.fromEntries(Object.entries(resources).map(([kind, ids]) => [kind, [...ids]])), retiredHistoryGroups: 8, productionMutations: 0 }));
};
