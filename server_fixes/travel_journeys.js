const express = require('express');
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { visibleIds, slots, errorResponse } = require('../utils/creation_access');
const contract = require('../utils/creation_contract');
const router = express.Router();

function parse(value) { return typeof value === 'string' ? JSON.parse(value) : value; }
async function places(connection, ids) {
  const [rows] = await connection.query(
    'SELECT * FROM travel_spots WHERE user_id IN (?, ?, ?, ?, ?, ?, ?, ?)', slots(ids)
  );
  return new Map(rows.map(row => [row.id, row]));
}
function spot(row) {
  if (!row) return null;
  return {
    id: row.id, name: row.name, city: row.city || '', address: row.address || '',
    lat: Number(row.lat), lng: Number(row.lng), status: row.status,
    photos: parse(row.photos || '[]'), coverImage: row.cover_image,
    diary: row.diary, note: row.note, visitedDate: row.visited_date,
  };
}
function normalize(row, placeMap, legacyLinks = []) {
  let plan;
  if (row.plan_json) plan = parse(row.plan_json);
  else {
    const startDate = row.start_date_text;
    const endDate = row.end_date_text;
    const days = startDate && endDate ? Math.max(1, Math.round((new Date(endDate) - new Date(startDate)) / 86400000) + 1) : 1;
    plan = { days, stops: legacyLinks.map(link => ({
      key: `legacy_${link.id}`, spotId: link.spot_id, day: null,
      mode: contract.MODES.includes(row.mode) ? row.mode : 'driving', note: '',
    })) };
  }
  return {
    id: row.id, clientId: row.client_key ? row.client_key.slice(row.client_key.indexOf('_') + 1) : '', title: row.title, city: row.city || '', description: row.description || '',
    startDate: row.start_date_text, endDate: row.end_date_text,
    days: plan.days, revision: row.revision || 0, ownerId: row.user_id,
    stops: plan.stops.map(stop => ({ ...stop, place: spot(placeMap.get(stop.spotId)) })),
    updatedAt: row.updated_at,
  };
}
async function rows(connection, ids, id = null, lock = false) {
  if (lock) {
    const [trip] = await connection.query(
      'SELECT id FROM travel_trips WHERE id = ? AND user_id IN (?, ?, ?, ?, ?, ?, ?, ?) FOR UPDATE',
      [id, ...slots(ids)]
    );
    if (!trip.length) return [];
  }
  const [result] = await connection.query(
    'SELECT t.*, DATE_FORMAT(t.start_date, \'%Y-%m-%d\') AS start_date_text, DATE_FORMAT(t.end_date, \'%Y-%m-%d\') AS end_date_text, s.client_key, s.revision, s.plan_json FROM travel_trips t LEFT JOIN travel_itinerary_state s ON s.trip_id = t.id WHERE t.user_id IN (?, ?, ?, ?, ?, ?, ?, ?) AND (? IS NULL OR t.id = ?) ORDER BY t.updated_at DESC, t.id DESC',
    [...slots(ids), id, id]
  );
  return result;
}
async function detail(connection, ids, id) {
  const trips = await rows(connection, ids, id);
  if (!trips.length) contract.fail('行程不存在', 404);
  const [links] = await connection.query('SELECT * FROM travel_trip_spots WHERE trip_id = ? ORDER BY sort_order, id', [id]);
  return normalize(trips[0], await places(connection, ids), links);
}

router.get('/', authRequired, async (req, res) => {
  try {
    const ids = await visibleIds(pool, req.user.id);
    const trips = await rows(pool, ids);
    const placeMap = await places(pool, ids);
    const [links] = await pool.query(
      'SELECT ts.* FROM travel_trip_spots ts JOIN travel_trips t ON t.id = ts.trip_id WHERE t.user_id IN (?, ?, ?, ?, ?, ?, ?, ?) ORDER BY ts.trip_id, ts.sort_order, ts.id', slots(ids)
    );
    const grouped = new Map();
    for (const link of links) {
      if (!grouped.has(link.trip_id)) grouped.set(link.trip_id, []);
      grouped.get(link.trip_id).push(link);
    }
    res.json({ code: 200, data: trips.map(row => normalize(row, placeMap, grouped.get(row.id) || [])) });
  } catch (error) { errorResponse(res, error); }
});

router.get('/:id', authRequired, async (req, res) => {
  try {
    res.json({ code: 200, data: await detail(pool, await visibleIds(pool, req.user.id), Number(req.params.id)) });
  } catch (error) { errorResponse(res, error); }
});

async function save(req, res) {
  let connection;
  try {
    const plan = contract.itinerary(req.body);
    const ids = await visibleIds(pool, req.user.id);
    connection = await pool.getConnection();
    await connection.beginTransaction();
    let id;
    let revision;
    if (req.params.id) {
      id = contract.integer(req.params.id, 1, 2147483647, '行程不正确');
      const current = await rows(connection, ids, id, true);
      if (!current.length) contract.fail('行程不存在', 404);
      revision = contract.integer(req.body.revision, 0, 2147483647, '请加载最新行程后保存');
      if (revision !== (current[0].revision || 0)) contract.fail('TA更新了行程，你的修改已保留，请加载最新版本', 409);
    }
    const placeMap = await places(connection, ids);
    if (plan.stops.some(stop => !placeMap.has(stop.spotId))) contract.fail('部分地点已不可用，请移除或重新选择', 403);
    if (!req.params.id) {
      const clientId = contract.text(req.body.clientId, 80);
      if (!/^[a-zA-Z0-9_-]{8,80}$/.test(clientId)) contract.fail('行程标识不正确');
      const [result] = await connection.query(
        'INSERT INTO travel_trips (user_id, created_by, title, city, description, start_date, end_date) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [req.user.id, req.user.id, plan.title, plan.city, plan.description, plan.startDate, plan.endDate]
      );
      id = result.insertId;
      await connection.query(
        'INSERT INTO travel_itinerary_state (trip_id, client_key, revision, plan_json) VALUES (?, ?, 1, ?)',
        [id, `${req.user.id}_${clientId}`, JSON.stringify(plan)]
      );
    } else {
      await connection.query(
        'UPDATE travel_trips SET title = ?, city = ?, description = ?, start_date = ?, end_date = ?, updated_at = NOW() WHERE id = ?',
        [plan.title, plan.city, plan.description, plan.startDate, plan.endDate, id]
      );
      if (revision === 0) {
        await connection.query('INSERT INTO travel_itinerary_state (trip_id, revision, plan_json) VALUES (?, 1, ?)', [id, JSON.stringify(plan)]);
      } else {
        await connection.query('UPDATE travel_itinerary_state SET revision = revision + 1, plan_json = ?, updated_at = NOW() WHERE trip_id = ? AND revision = ?', [JSON.stringify(plan), id, revision]);
      }
    }
    // Mirror links for existing home/report consumers without modifying the places.
    await connection.query('DELETE FROM travel_trip_spots WHERE trip_id = ?', [id]);
    const mirrored = new Set();
    for (let index = 0; index < plan.stops.length; index++) {
      if (mirrored.has(plan.stops[index].spotId)) continue;
      mirrored.add(plan.stops[index].spotId);
      await connection.query('INSERT INTO travel_trip_spots (trip_id, spot_id, sort_order) VALUES (?, ?, ?)', [id, plan.stops[index].spotId, index]);
    }
    await connection.commit();
    res.json({ code: 200, message: '行程已保存', data: await detail(connection, ids, id) });
  } catch (error) {
    if (connection) await connection.rollback();
    if (error.code === 'ER_DUP_ENTRY') { error.status = 409; error.message = '行程可能已创建，请刷新列表；当前输入已保留'; }
    errorResponse(res, error);
  } finally { connection?.release(); }
}
router.post('/', authRequired, save);
router.put('/:id', authRequired, save);

router.delete('/:id', authRequired, async (req, res) => {
  let connection;
  try {
    const ids = await visibleIds(pool, req.user.id);
    const id = contract.integer(req.params.id, 1, 2147483647, '行程不正确');
    const revision = contract.integer(req.query.revision, 0, 2147483647, '请刷新后删除');
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const current = await rows(connection, ids, id, true);
    if (!current.length) contract.fail('行程不存在', 404);
    if ((current[0].revision || 0) !== revision) contract.fail('行程有新修改，请刷新后再删除', 409);
    await connection.query('UPDATE creative_works SET trip_id = NULL, revision = revision + 1 WHERE trip_id = ? AND deleted_at IS NULL', [id]);
    await connection.query('DELETE FROM travel_trip_spots WHERE trip_id = ?', [id]);
    await connection.query('DELETE FROM travel_itinerary_state WHERE trip_id = ?', [id]);
    await connection.query('DELETE FROM travel_trips WHERE id = ?', [id]);
    await connection.commit();
    res.json({ code: 200, message: '行程已删除，原地点和作品已保留' });
  } catch (error) {
    if (connection) await connection.rollback();
    errorResponse(res, error);
  } finally { connection?.release(); }
});

module.exports = router;
