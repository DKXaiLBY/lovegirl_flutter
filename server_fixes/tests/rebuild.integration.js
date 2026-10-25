// Run only in the isolated loopback staging harness, never as a public server.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const root = process.env.REBUILD_STAGE;
assert.ok(root && root.startsWith('/app/.rebuild-'), 'An explicit staging root is required');
const pool = require(path.join(root, 'config/database'));
const express = require('express');
const sharp = require('sharp');
const { generateAccessToken } = require('/app/config/jwt');
const ids = [];
const checks = [];
let server;
const check = (name, fn) => { fn(); checks.push(name); console.log(`PASS ${name}`); };

async function main() {
  const migration = await fs.readFile(path.join(root, 'migration.sql'), 'utf8');
  for (const statement of migration.split(';').map(value => value.trim()).filter(Boolean)) await pool.query(statement);
  for (const role of ['boy', 'girl', 'boy']) {
    const [result] = await pool.query(
      'INSERT INTO users (username, password_hash, nickname, role, is_admin) VALUES (?, ?, ?, ?, 0)',
      [`_qa_rebuild_${randomUUID().slice(0, 16)}`, `disabled_${randomUUID()}`, 'Rebuild QA', role]
    );
    ids.push(result.insertId);
  }
  await pool.query("INSERT INTO couples (user1_id, user2_id, status) VALUES (?, ?, 'active')", [ids[0], ids[1]]);
  const tokens = ids.map((id, index) => generateAccessToken({ id, username: `qa_${id}`, role: index === 1 ? 'girl' : 'boy', is_admin: 0 }));
  const spotIds = [];
  for (let index = 0; index < 3; index++) {
    const [result] = await pool.query(
      "INSERT INTO travel_spots (user_id, name, city, lat, lng, status) VALUES (?, ?, 'Shanghai', ?, ?, 'wish')",
      [ids[index], `QA-${index}`, 31.227, 121.49 + index * 0.002]
    );
    spotIds.push(result.insertId);
  }
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.use('/api/creations', require(path.join(root, 'routes/creative_works')));
  app.use('/api/journeys', require(path.join(root, 'routes/travel_journeys')));
  app.use('/api/travel', require(path.join(root, 'routes/travel')));
  app.use('/uploads', express.static(path.join(root, 'uploads')));
  server = await new Promise(resolve => { const instance = app.listen(0, '127.0.0.1', () => resolve(instance)); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  async function request(user, endpoint, method = 'GET', body) {
    const headers = user == null ? {} : { Authorization: `Bearer ${tokens[user]}` };
    if (body && !(body instanceof FormData)) headers['Content-Type'] = 'application/json';
    const response = await fetch(origin + endpoint, { method, headers, body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined });
    return { status: response.status, body: await response.json() };
  }
  const plan = {
    clientId: randomUUID(), title: 'QA two days', days: 2, startDate: '2026-10-24', endDate: '2026-10-25',
    stops: [
      { key: 'first', spotId: spotIds[0], day: 0, mode: 'walking', note: 'Keep this note' },
      { key: 'second', spotId: spotIds[1], day: null, mode: 'driving', note: '' },
      { key: 'return', spotId: spotIds[0], day: 1, mode: 'driving', note: 'Come back' },
    ],
  };
  check('unauthenticated requests are denied', () => {});
  assert.equal((await request(null, '/api/journeys')).status, 401);
  const created = await request(0, '/api/journeys', 'POST', plan);
  check('create a versioned plan with an unplanned stop', () => { assert.equal(created.status, 200); assert.equal(created.body.data.revision, 1); assert.equal(created.body.data.clientId, plan.clientId); assert.equal(created.body.data.stops.length, 3); assert.equal(created.body.data.stops[1].day, null); });
  const tripId = created.body.data.id;
  assert.equal((await request(0, '/api/journeys', 'POST', plan)).status, 409);
  assert.equal((await request(1, `/api/journeys/${tripId}`)).status, 200);
  assert.equal((await request(2, `/api/journeys/${tripId}`)).status, 404);
  const edits = await Promise.all([
    request(0, `/api/journeys/${tripId}`, 'PUT', { ...plan, revision: 1, title: 'QA A edit' }),
    request(1, `/api/journeys/${tripId}`, 'PUT', { ...plan, revision: 1, title: 'QA B edit' }),
  ]);
  check('concurrent partners cannot silently overwrite each other', () => assert.deepEqual(edits.map(value => value.status).sort(), [200, 409]));
  const changed = await request(1, `/api/journeys/${tripId}`, 'PUT', { ...plan, revision: 2, stops: [...plan.stops].reverse().map(value => ({ ...value, day: 1 })) });
  check('reorder and cross-day move preserve explicit stop mode and note', () => { assert.equal(changed.status, 200); assert.equal(changed.body.data.stops.find(stop => stop.key === 'first').mode, 'walking'); assert.equal(changed.body.data.stops.find(stop => stop.key === 'first').note, 'Keep this note'); });
  const legacy = await request(0, `/api/travel/trips/${tripId}`, 'PUT', { title: 'Do not overwrite' });
  check('legacy writers are blocked for versioned plans', () => assert.equal(legacy.status, 409));
  assert.equal((await request(0, `/api/travel/trips/${tripId}`, 'DELETE')).status, 409);
  const denied = await request(0, `/api/journeys/${tripId}`, 'PUT', { ...plan, revision: 3, stops: [{ key: 'outside', spotId: spotIds[2], day: 0 }] });
  check('inaccessible places cannot be attached', () => assert.equal(denied.status, 403));

  const png = await sharp({ create: { width: 24, height: 32, channels: 3, background: '#aabbcc' } }).png().toBuffer();
  const document = {
    kind: 'polaroid', templateId: 'classic', lookId: 'instant_clear', title: 'QA paper', date: '2026-10-24',
    transforms: [{ scale: 1.2, x: 0.1, y: 0 }],
    frontInk: [{ width: 0.006, color: 0xff111111, points: [[0.1, 0.85], [0.7, 0.92]] }],
  };
  const clientId = randomUUID();
  function upload(doc, options = {}) {
    const form = new FormData();
    form.set('clientId', clientId); form.set('document', JSON.stringify(doc));
    form.set('tripId', String(tripId));
    if (options.revision != null) form.set('revision', String(options.revision));
    form.set('preview', new Blob([options.invalid ? Buffer.from('not an image') : png], { type: 'image/png' }), 'preview.png');
    if (options.source) form.set('source0', new Blob([png], { type: 'image/png' }), 'source.png');
    return form;
  }
  const saved = await request(0, '/api/creations', 'POST', upload(document, { source: true }));
  check('publish persists editable ink, crop and original source separately', () => { assert.equal(saved.status, 200); assert.deepEqual(saved.body.data.document.frontInk, document.frontInk); assert.equal(saved.body.data.sourceUrls.length, 1); });
  const workId = saved.body.data.id;
  assert.equal((await request(0, '/api/creations', 'POST', upload(document, { source: true }))).status, 409);
  assert.equal((await request(1, `/api/creations/${workId}`)).status, 200);
  assert.equal((await request(2, `/api/creations/${workId}`)).status, 404);
  assert.equal((await request(1, `/api/creations/${workId}`, 'PUT', upload(document, { revision: 1 }))).status, 403);
  assert.equal((await request(0, `/api/creations/${workId}`, 'PUT', upload({ ...document, note: 'Updated' }, { revision: 1 }))).status, 200);
  assert.equal((await request(0, `/api/creations/${workId}`, 'PUT', upload(document, { revision: 1 }))).status, 409);
  check('completed work is shared but creator-only edits are revision guarded', () => {});
  const assetsBefore = await fs.readdir(path.join(root, 'uploads/creations'));
  assert.equal((await request(0, '/api/creations', 'POST', upload(document, { source: true, invalid: true }))).status, 400);
  const assetsAfter = await fs.readdir(path.join(root, 'uploads/creations'));
  check('invalid uploads are rejected and temporary files removed', () => assert.equal(assetsAfter.length, assetsBefore.length));
  const sourceResponse = await fetch(origin + saved.body.data.sourceUrls[0]);
  assert.equal(sourceResponse.status, 200);
  assert.equal((await sharp(Buffer.from(await sourceResponse.arrayBuffer())).metadata()).format, 'jpeg');
  assert.equal((await request(1, `/api/journeys/${tripId}?revision=2`, 'DELETE')).status, 409);
  assert.equal((await request(1, `/api/journeys/${tripId}?revision=3`, 'DELETE')).status, 200);
  const detached = await request(0, `/api/creations/${workId}`);
  check('deleting a plan retains original places and detaches completed work', () => { assert.equal(detached.status, 200); assert.equal(detached.body.data.tripId, null); assert.equal(detached.body.data.revision, 3); });
  const [originals] = await pool.query('SELECT id FROM travel_spots WHERE user_id IN (?, ?, ?)', ids);
  assert.equal(originals.length, 3);
  await pool.query("UPDATE couples SET status = 'broken' WHERE user1_id = ? AND user2_id = ?", [ids[0], ids[1]]);
  check('sharing closes immediately after the couple relationship ends', () => {});
  assert.equal((await request(1, `/api/creations/${workId}`)).status, 404);
  assert.equal((await request(0, `/api/creations/${workId}`)).status, 200);
  console.log(JSON.stringify({ result: 'passed', checks: checks.length, scope: 'isolated loopback API with three temporary users, not phone dual-session testing' }));
}

async function cleanup() {
  if (server) await new Promise(resolve => server.close(resolve));
  if (ids.length === 3) {
    await pool.query('DELETE FROM creative_works WHERE user_id IN (?, ?, ?)', ids);
    await pool.query('DELETE FROM travel_itinerary_state WHERE trip_id IN (SELECT id FROM travel_trips WHERE user_id IN (?, ?, ?))', ids);
    await pool.query('DELETE FROM travel_trip_spots WHERE trip_id IN (SELECT id FROM travel_trips WHERE user_id IN (?, ?, ?))', ids);
    await pool.query('DELETE FROM travel_trips WHERE user_id IN (?, ?, ?)', ids);
    await pool.query('DELETE FROM travel_spots WHERE user_id IN (?, ?, ?)', ids);
    await pool.query('DELETE FROM couples WHERE user1_id = ? AND user2_id = ?', [ids[0], ids[1]]);
  }
  for (const id of ids) await pool.query('DELETE FROM users WHERE id = ?', [id]);
  await pool.end();
}
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(cleanup);
