const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { readFile, mkdir, writeFile } = require('node:fs/promises');
const path = require('node:path');
const bcrypt = require('bcryptjs');
const express = require('express');
const pool = require('./config/database');

async function main() {
  const [[{ name }]] = await pool.query('SELECT DATABASE() AS name');
  assert.equal(name, 'lovegirl_clear_qa_20261031', 'QA database required');
  const migration = await readFile(path.join(__dirname, 'migrations/20261123_registration_invites.sql'), 'utf8');
  await pool.query(migration);
  await require('./migrations/20261123_couple_pairs')(pool);
  await require('./migrations/20261123_couple_pairs')(pool);

  const { authRequired } = require('./middleware/auth');
  const { protectUploads } = require('./utils/media_access');
  const app = express();
  app.use(express.json());
  app.use('/api/auth', require('./routes/auth'));
  app.use('/api/couple', require('./routes/couple'));
  app.use('/api/user', require('./routes/user'));
  app.use('/api/privacy', require('./routes/privacy'));
  app.use('/api/journeys', require('./routes/travel_journeys'));
  app.use('/api/kitchen', require('./routes/kitchen'));
  app.use('/uploads', authRequired, protectUploads(pool), express.static(path.join(__dirname, 'uploads')));
  const http = await new Promise((resolve) => {
    const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
  });
  const origin = `http://127.0.0.1:${http.address().port}`;
  const prefix = '_qa_registration_' + randomBytes(6).toString('hex');
  const password = randomBytes(19).toString('hex');
  const nickname = 'Registration QA';
  const bodyFor = (suffix, inviteCode) => ({ username: prefix + suffix, password, nickname, gender: 'female', inviteCode });
  async function request(url, body, token, method = body ? 'POST' : 'GET') {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    const response = await fetch(origin + '/api' + url, {
      headers, method, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(8000),
    });
    return { status: response.status, data: (await response.json()).data };
  }
  async function fetchPicture(url, token, method = 'GET') {
    const headers = token ? { Authorization: 'Bearer ' + token } : {};
    const response = await fetch(origin + url, { headers, method });
    if (response.ok) assert.match(response.headers.get('cache-control'), /private/);
    await response.arrayBuffer();
    return response.status;
  }
  try {
    const [admin] = await pool.query(
      "INSERT INTO users (username,password_hash,nickname,role,gender,is_admin) VALUES (?,?,?,'boy','male',1)",
      [prefix + '-admin', await bcrypt.hash(password, 10), nickname],
    );
    const adminId = admin.insertId;
    const login = await request('/auth/login', { username: prefix + '-admin', password });
    assert.equal(login.status, 200);
    const adminToken = login.data.accessToken;
    const invite = async () => {
      const result = await request('/auth/registration-invites', {}, adminToken);
      assert.equal(result.status, 200);
      assert.match(result.data.code, /^[0-9A-F]{24}$/);
      assert.equal(result.data.expiresIn, 86400);
      return result.data.code;
    };

    assert.equal((await request('/auth/register', bodyFor('-missing'))).status, 400);
    const revoked = await invite();
    const usable = await invite();
    assert.equal((await request('/auth/register', bodyFor('-revoked', revoked))).status, 400);
    assert.equal((await request('/auth/register', bodyFor('-admin', usable))).status, 409);
    const concurrent = await Promise.all([
      request('/auth/register', bodyFor('-race1', usable)),
      request('/auth/register', bodyFor('-race2', usable)),
    ]);
    assert.deepEqual(concurrent.map((item) => item.status).sort(), [200, 400]);
    const [{ data: a }] = concurrent.filter((item) => item.status === 200);
    assert.equal(a.user.isAdmin, false);
    assert.equal((await request('/auth/registration-invites', {}, a.accessToken)).status, 403);
    assert.equal((await request('/auth/refresh', { refreshToken: a.refreshToken })).status, 200);
    assert.equal((await request('/auth/login', { username: a.user.username, password })).status, 200);
    assert.equal((await request('/couple', null, a.accessToken)).data.coupled, false);
    assert.equal((await request('/user/partner', null, a.accessToken)).data, null);
    const [[privacy]] = await pool.query('SELECT photo_visible,mood_visible FROM user_privacy WHERE user_id = ?', [a.user.id]);
    assert.equal(privacy.photo_visible, 0);
    assert.equal(privacy.mood_visible, 0);
    console.log('PASS one-time registration, duplicate retry, concurrent use, login and initial isolation');

    const expired = await invite();
    await pool.query('UPDATE registration_invites SET expires_at = UTC_TIMESTAMP() WHERE issuer_id = ? AND revoked_at IS NULL AND used_at IS NULL', [adminId]);
    assert.equal((await request('/auth/register', bodyFor('-expired', expired))).status, 400);
    const newAccount = async (suffix) => {
      const result = await request('/auth/register', bodyFor(suffix, await invite()));
      assert.equal(result.status, 200);
      return result.data;
    };
    const b = await newAccount('-b');
    const c = await newAccount('-c');
    const d = await newAccount('-d');
    const e = await newAccount('-e');

    const bindCode = async (token) => {
      const result = await request('/couple/invite', {}, token);
      assert.equal(result.status, 200);
      return result.data.invite_code;
    };
    const accept = (token, code) => request('/couple/accept', { code }, token);
    const aCode = await bindCode(a.accessToken);
    const cCode = await bindCode(c.accessToken);
    const bind = await Promise.all([accept(b.accessToken, aCode), accept(b.accessToken, cCode)]);
    assert.deepEqual(bind.map((item) => item.status).sort(), [200, 409]);
    const winner = bind[0].status === 200 ? a : c;
    const other = bind[0].status === 200 ? c : a;
    assert.equal((await request('/couple', null, b.accessToken)).data.partner.id, winner.user.id);
    assert.equal((await accept(d.accessToken, await bindCode(other.accessToken))).status, 200);
    assert.equal((await request('/couple', null, e.accessToken)).data.coupled, false);

    const photosDir = path.join(__dirname, 'uploads', 'photos');
    const kitchenDir = path.join(__dirname, 'uploads', 'kitchen');
    await mkdir(photosDir, { recursive: true });
    await mkdir(kitchenDir, { recursive: true });
    const newPicture = `/uploads/photos/u${winner.user.id}_photo.jpg`;
    const legacyPicture = `/uploads/photos/${prefix.replace(/^_/, '')}.jpg`;
    const mealPicture = `/uploads/kitchen/u${winner.user.id}_meal.jpg`;
    for (const url of [newPicture, legacyPicture, mealPicture]) {
      await writeFile(path.join(__dirname, url.slice(1)), 'QA fixture bytes');
    }
    await pool.query("INSERT INTO photos (user_id, url, visibility) VALUES (?, ?, 'shared'), (?, ?, 'private')",
      [winner.user.id, legacyPicture, winner.user.id, newPicture]);
    await require('./migrations/20261123_legacy_media_owners')(pool);
    assert.equal(await fetchPicture(legacyPicture, winner.accessToken), 200);
    assert.equal(await fetchPicture(legacyPicture, winner.refreshToken), 401);
    assert.equal(await fetchPicture(legacyPicture), 401);
    assert.equal(await fetchPicture(legacyPicture, b.accessToken), 404);
    assert.equal((await request('/privacy', { photo_visible: true }, winner.accessToken, 'PUT')).status, 200);
    assert.equal(await fetchPicture(legacyPicture, b.accessToken), 200);
    assert.equal(await fetchPicture(legacyPicture, d.accessToken), 404);
    assert.equal(await fetchPicture(legacyPicture, e.accessToken, 'HEAD'), 404);
    assert.equal(await fetchPicture(newPicture, b.accessToken), 404);
    assert.equal(await fetchPicture(mealPicture, b.accessToken), 404);
    assert.equal((await request('/kitchen/dishes', { name: 'QA dish', photo_url: mealPicture }, winner.accessToken)).status, 200);
    assert.equal(await fetchPicture(mealPicture, b.accessToken), 200);
    assert.equal(await fetchPicture(mealPicture, d.accessToken), 404);

    const trip = await request('/journeys', { clientId: randomBytes(9).toString('hex'), title: 'QA trip', days: 1, stops: [] }, winner.accessToken);
    assert.equal(trip.status, 200);
    const tripUrl = `/journeys/${trip.data.id}`;
    assert.equal((await request(tripUrl, null, b.accessToken)).status, 200);
    assert.equal((await request(tripUrl, null, d.accessToken)).status, 404);
    assert.equal((await request('/privacy', { travel_visible: false }, winner.accessToken, 'PUT')).status, 200);
    assert.equal((await request(tripUrl, null, b.accessToken)).status, 404);

    assert.equal((await request('/couple', null, b.accessToken, 'DELETE')).status, 200);
    assert.equal(await fetchPicture(legacyPicture, b.accessToken), 404);
    assert.equal(await fetchPicture(mealPicture, b.accessToken), 404);
    assert.equal((await request('/user/partner', null, winner.accessToken)).data, null);
    assert.equal((await accept(winner.accessToken, await bindCode(e.accessToken))).status, 200);
    assert.equal((await request('/couple', null, winner.accessToken)).data.partner.id, e.user.id);
    assert.equal((await request('/couple', null, b.accessToken)).data.coupled, false);
    assert.equal((await request('/couple', null, d.accessToken)).data.partner.id, other.user.id);
    console.log('PASS separate binding, concurrent partner acceptance, unbinding and rebinding with history');
    console.log('PASS two-pair media and journey isolation, account privacy, legacy media and revocation');
  } finally {
    await new Promise((resolve) => http.close(resolve));
    await pool.query('DELETE i FROM registration_invites i JOIN users u ON u.id = i.issuer_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE i FROM couple_invites i JOIN users u ON u.id = i.creator_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE c FROM couples c JOIN users u ON u.id = c.user1_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE s FROM travel_itinerary_state s JOIN travel_trips t ON t.id = s.trip_id JOIN users u ON u.id = t.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE t FROM travel_trips t JOIN users u ON u.id = t.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE m FROM legacy_media_owners m JOIN users u ON u.id = m.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE p FROM photos p JOIN users u ON u.id = p.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE d FROM kitchen_dishes d JOIN users u ON u.id = d.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE p FROM user_privacy p JOIN users u ON u.id = p.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE t FROM themes t JOIN users u ON u.id = t.user_id WHERE LEFT(u.username, ?) = ?', [prefix.length, prefix]);
    await pool.query('DELETE FROM users WHERE LEFT(username, ?) = ?', [prefix.length, prefix]);
  }
}

main().catch((error) => {
  console.error(error.code === 'ERR_ASSERTION' ? error.message : (error.code || error.name));
  process.exitCode = 1;
}).finally(() => pool.end());
