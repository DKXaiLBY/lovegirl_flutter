const express = require('express');
const https = require('https');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  addBeanTransaction,
  createFinanceRecord,
  createTimelineEvent,
  unlockTravelAchievement,
  checkAchievements,
  todayString,
} = require('./utils/lovegirl_rewards');

const AMAP_BASE_URL = 'https://restapi.amap.com';

function getAmapWebKey() {
  return process.env.AMAP_WEB_KEY || process.env.GAODE_API_KEY || process.env.AMAP_KEY;
}

function amapGet(path, params = {}) {
  const key = getAmapWebKey();
  if (!key) {
    const err = new Error('AMap Web key is not configured');
    err.status = 500;
    throw err;
  }

  const url = new URL(path, AMAP_BASE_URL);
  Object.entries({ ...params, key }).forEach(([name, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(name, value);
    }
  });

  return new Promise((resolve, reject) => {
    const req = https.get(url, (response) => {
      let raw = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => {
        raw += chunk;
      });
      response.on('end', () => {
        try {
          const parsed = JSON.parse(raw);
          if (parsed.status && parsed.status !== '1') {
            const err = new Error(parsed.info || '楂樺痉鏈嶅姟杩斿洖澶辫触');
            err.status = 502;
            err.amapCode = parsed.infocode;
            reject(err);
            return;
          }
          resolve(parsed);
        } catch (err) {
          err.status = 502;
          reject(err);
        }
      });
    });
    req.setTimeout(10000, () => {
      req.destroy(new Error('楂樺痉鏈嶅姟璇锋眰瓒呮椂'));
    });
    req.on('error', (err) => {
      err.status = err.status || 502;
      reject(err);
    });
  });
}

async function getVisibleUserIds(userId) {
  try {
    const [rows] = await pool.query(
      `SELECT CASE WHEN user1_id = ? THEN user2_id ELSE user1_id END AS partner_id
       FROM couples
       WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'
       LIMIT 1`,
      [userId, userId, userId]
    );
    if (rows.length > 0 && rows[0].partner_id) {
      return [userId, rows[0].partner_id];
    }
  } catch (_) {}
  return [userId];
}

function parseTags(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function normalizeSpot(row) {
  return {
    id: row.id,
    name: row.name,
    city: row.city || '',
    address: row.address || '',
    lng: Number(row.lng || 0),
    lat: Number(row.lat || 0),
    emoji: row.emoji || '馃搷',
    status: row.status || 'wish',
    note: row.note || null,
    diary: row.diary || null,
    visitedDate: row.visited_date || null,
    photos: row.photos ? row.photos.split(',').filter(Boolean) : [],
    rating: row.rating || null,
    mood: row.mood || null,
    tags: parseTags(row.tags),
    reason: row.reason || null,
    desire: row.desire || null,
    plannedDate: row.planned_date || null,
    itinerary: row.itinerary || null,
    budget: row.budget == null ? null : Number(row.budget),
    createdBy: row.created_by || row.user_id,
    weather: row.weather || null,
    traffic: row.traffic || null,
    openingHours: row.opening_hours || null,
    transportation: row.transportation || null,
    nearby: row.nearby || null,
    tips: row.tips || null,
    checkedInAt: row.checked_in_at || null,
    ownerNote: row.owner_note || null,
    partnerNote: row.partner_note || null,
    creatorNickname: row.creator_nickname || row.creatorNickname || null,
    creatorAvatar: row.creator_avatar || row.creatorAvatar || null,
  };
}

function normalizeRoute(row, spots = []) {
  let path = [];
  try {
    path = row.path_json ? JSON.parse(row.path_json) : [];
  } catch (_) {
    path = [];
  }
  return {
    id: row.id,
    title: row.title,
    city: row.city || '',
    description: row.description || '',
    status: row.status || 'draft',
    mode: row.mode || 'driving',
    distance: row.distance == null ? null : Number(row.distance),
    duration: row.duration == null ? null : Number(row.duration),
    path,
    spots,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function normalizeTrip(row, spots = []) {
  let path = [];
  try {
    path = row.path_json ? JSON.parse(row.path_json) : [];
  } catch (_) {
    path = [];
  }
  return {
    id: row.id,
    title: row.title,
    name: row.title,
    city: row.city || '',
    description: row.description || '',
    status: row.status || 'draft',
    mode: row.mode || 'driving',
    distance: row.distance == null ? null : Number(row.distance),
    duration: row.duration == null ? null : Number(row.duration),
    path,
    spotIds: spots.map((spot) => spot.id),
    spots,
    startDate: row.start_date || null,
    endDate: row.end_date || null,
    createdBy: row.created_by || row.user_id,
    creatorNickname: row.creator_nickname || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function handleTravelCheckin(userId, spotId, data) {
  if (data.status !== 'visited') return;

  await pool.query(
    'UPDATE travel_spots SET checked_in_at = COALESCE(checked_in_at, NOW()) WHERE id = ?',
    [spotId]
  );

  try {
    await addBeanTransaction(pool, {
      userId,
      amount: 10,
      type: 'travel_checkin',
      title: 'Travel check-in',
      sourceModule: 'travel',
      sourceId: spotId,
      description: data.name,
    });
  } catch (err) {
    console.error('[Travel] bean reward failed:', err.message);
  }

  await createTimelineEvent({
    userId,
    title: `Travel check-in: ${data.name}`,
    description: data.diary || data.note || data.city || '',
    eventDate: data.visitedDate || todayString(),
    icon: 'map-pin',
    sourceModule: 'travel',
    sourceId: spotId,
  });

  if (data.budget && Number(data.budget) > 0) {
    await createFinanceRecord({
      userId,
      type: 'expense',
      category: 'travel',
      amount: Number(data.budget),
      description: `travel-${data.name}`,
      sourceModule: 'travel',
      sourceId: spotId,
      recordDate: data.visitedDate || todayString(),
    });
  }

  await unlockTravelAchievement(userId, 'first_checkin', 'First travel check-in', data.name, { spotId });
  await checkAchievements(userId, 'travel');
}

function normalizeAmapPois(data) {
  return (data.pois || []).map((poi) => {
    const [lng = '0', lat = '0'] = String(poi.location || '0,0').split(',');
    return {
      id: poi.id || '',
      name: poi.name || '',
      address: Array.isArray(poi.address) ? '' : poi.address || '',
      city: poi.cityname || '',
      district: poi.adname || '',
      type: poi.type || '',
      lng: Number(lng) || 0,
      lat: Number(lat) || 0,
    };
  });
}

function parseAmapPath(polyline) {
  if (!polyline) return [];
  return polyline
    .split(';')
    .map((pair) => {
      const [lng, lat] = pair.split(',').map(Number);
      return { lng, lat };
    })
    .filter((point) => Number.isFinite(point.lng) && Number.isFinite(point.lat));
}

function normalizeDirection(mode, data) {
  if (mode === 'walking') {
    const path = data.route?.paths?.[0];
    return {
      mode,
      distance: Number(path?.distance || 0),
      duration: Number(path?.duration || 0),
      steps: (path?.steps || []).map((step) => ({
        instruction: step.instruction || '',
        road: step.road || '',
        distance: Number(step.distance || 0),
        duration: Number(step.duration || 0),
        path: parseAmapPath(step.polyline),
      })),
      path: (path?.steps || []).flatMap((step) => parseAmapPath(step.polyline)),
    };
  }

  if (mode === 'transit') {
    const transit = data.route?.transits?.[0];
    return {
      mode,
      distance: Number(transit?.distance || data.route?.distance || 0),
      duration: Number(transit?.duration || 0),
      steps: (transit?.segments || []).map((segment) => ({
        instruction: segment.bus?.buslines?.[0]?.name || segment.walking?.origin || '',
        road: segment.bus?.buslines?.[0]?.departure_stop?.name || '',
        distance: Number(segment.bus?.buslines?.[0]?.distance || segment.walking?.distance || 0),
        duration: Number(segment.bus?.buslines?.[0]?.duration || segment.walking?.duration || 0),
        path: [
          ...parseAmapPath(segment.walking?.steps?.map((step) => step.polyline).join(';')),
          ...parseAmapPath(segment.bus?.buslines?.[0]?.polyline),
        ],
      })),
      path: (transit?.segments || []).flatMap((segment) => [
        ...parseAmapPath(segment.walking?.steps?.map((step) => step.polyline).join(';')),
        ...parseAmapPath(segment.bus?.buslines?.[0]?.polyline),
      ]),
    };
  }

  const path = data.route?.paths?.[0];
  return {
    mode: 'driving',
    distance: Number(path?.distance || 0),
    duration: Number(path?.duration || 0),
    strategy: path?.strategy || '',
    taxiCost: data.route?.taxi_cost == null ? null : Number(data.route.taxi_cost),
    steps: (path?.steps || []).map((step) => ({
      instruction: step.instruction || '',
      road: step.road || '',
      distance: Number(step.distance || 0),
      duration: Number(step.duration || 0),
      path: parseAmapPath(step.polyline),
    })),
    path: (path?.steps || []).flatMap((step) => parseAmapPath(step.polyline)),
  };
}

router.get('/amap/poi', authRequired, async (req, res) => {
  try {
    const keyword = (req.query.keywords || req.query.keyword || '').toString().trim();
    if (!keyword) {
      return res.status(400).json({ code: 400, message: 'keyword is required' });
    }
    const data = await amapGet('/v3/place/text', {
      keywords: keyword,
      city: req.query.city || '',
      citylimit: req.query.city ? 'true' : 'false',
      offset: req.query.offset || 20,
      page: req.query.page || 1,
      extensions: 'base',
    });
    res.json({ code: 200, data: { list: normalizeAmapPois(data), rawCount: Number(data.count || 0) } });
  } catch (err) {
    console.error('[Travel][AMap] POI search failed:', err.message);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '楂樺痉鏈嶅姟璇锋眰澶辫触' });
  }
});

router.get('/amap/geocode', authRequired, async (req, res) => {
  try {
    const address = (req.query.address || '').toString().trim();
    if (!address) {
      return res.status(400).json({ code: 400, message: '鍦板潃涓嶈兘涓虹┖' });
    }
    const data = await amapGet('/v3/geocode/geo', {
      address,
      city: req.query.city || '',
    });
    const geocode = data.geocodes?.[0] || {};
    const [lng = '0', lat = '0'] = String(geocode.location || '0,0').split(',');
    res.json({
      code: 200,
      data: {
        address: geocode.formatted_address || address,
        province: geocode.province || '',
        city: geocode.city || '',
        district: geocode.district || '',
        lng: Number(lng) || 0,
        lat: Number(lat) || 0,
      },
    });
  } catch (err) {
    console.error('[Travel][AMap] geocode failed:', err.message);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '楂樺痉鏈嶅姟璇锋眰澶辫触' });
  }
});

router.get('/amap/regeo', authRequired, async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ code: 400, message: '鍧愭爣鍙傛暟鏃犳晥' });
    }
    const data = await amapGet('/v3/geocode/regeo', {
      location: `${lng},${lat}`,
      extensions: 'base',
    });
    const component = data.regeocode?.addressComponent || {};
    res.json({
      code: 200,
      data: {
        address: data.regeocode?.formatted_address || '',
        city: Array.isArray(component.city) ? component.province || '' : component.city || '',
        district: component.district || '',
        province: component.province || '',
      },
    });
  } catch (err) {
    console.error('[Travel][AMap] regeo failed:', err.message);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '楂樺痉鏈嶅姟璇锋眰澶辫触' });
  }
});

router.get('/amap/weather', authRequired, async (req, res) => {
  try {
    const city = (req.query.city || '').toString().trim();
    if (!city) {
      return res.status(400).json({ code: 400, message: '鍩庡競涓嶈兘涓虹┖' });
    }
    const data = await amapGet('/v3/weather/weatherInfo', {
      city,
      extensions: req.query.extensions || 'base',
    });
    res.json({ code: 200, data });
  } catch (err) {
    console.error('[Travel][AMap] weather failed:', err.message);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '楂樺痉澶╂皵璇锋眰澶辫触' });
  }
});

router.get('/amap/direction', authRequired, async (req, res) => {
  try {
    const mode = ['walking', 'driving', 'transit'].includes(req.query.mode) ? req.query.mode : 'driving';
    const origin = (req.query.origin || '').toString();
    const destination = (req.query.destination || '').toString();
    if (!origin || !destination) {
      return res.status(400).json({ code: 400, message: 'origin and destination are required' });
    }

    // 步行规划对超长距离（跨省）会返回 OVER_DIRECTION_RANGE(20803)，
    // 距离超过 90km 时自动降级为驾车规划（现实中也不该步行上百公里）
    let path = mode === 'walking'
      ? '/v3/direction/walking'
      : mode === 'transit'
        ? '/v3/direction/transit/integrated'
        : '/v3/direction/driving';
    if (mode === 'walking') {
      const [oLng, oLat] = origin.split(',').map(Number);
      const [dLng, dLat] = destination.split(',').map(Number);
      if ([oLng, oLat, dLng, dLat].every(Number.isFinite)) {
        const R = 6371000;
        const rad = (x) => (x * Math.PI) / 180;
        const dLatRad = rad(dLat - oLat);
        const dLngRad = rad(dLng - oLng);
        const a = Math.sin(dLatRad / 2) ** 2 +
          Math.cos(rad(oLat)) * Math.cos(rad(dLat)) * Math.sin(dLngRad / 2) ** 2;
        const straight = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        if (straight > 90000) path = '/v3/direction/driving';
      }
    }
    const data = await amapGet(path, {
      origin,
      destination,
      waypoints: mode === 'driving' ? req.query.waypoints || '' : '',
      city: req.query.city || '',
      cityd: req.query.cityd || req.query.city || '',
      strategy: req.query.strategy || '',
      extensions: 'base',
    });
    res.json({ code: 200, data: normalizeDirection(mode, data) });
  } catch (err) {
    console.error('[Travel][AMap] direction failed:', err.message);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.message || '楂樺痉璺緞瑙勫垝璇锋眰澶辫触' });
  }
});

router.get('/routes', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [routes] = await pool.query(
      `SELECT *
       FROM travel_routes
       WHERE user_id IN (${visibleIds.map(() => '?').join(',')})
       ORDER BY updated_at DESC, created_at DESC`,
      visibleIds
    );
    if (routes.length === 0) {
      return res.json({ code: 200, data: { list: [], total: 0 } });
    }
    const routeIds = routes.map((route) => route.id);
    const [spotRows] = await pool.query(
      `SELECT rs.route_id, rs.sort_order, s.*,
              u.nickname AS creator_nickname, u.avatar_url AS creator_avatar
       FROM travel_route_spots rs
       JOIN travel_spots s ON s.id = rs.spot_id
       LEFT JOIN users u ON u.id = COALESCE(s.created_by, s.user_id)
       WHERE rs.route_id IN (${routeIds.map(() => '?').join(',')})
       ORDER BY rs.route_id, rs.sort_order ASC`,
      routeIds
    );
    const spotsByRoute = new Map();
    for (const row of spotRows) {
      if (!spotsByRoute.has(row.route_id)) spotsByRoute.set(row.route_id, []);
      spotsByRoute.get(row.route_id).push(normalizeSpot(row));
    }
    const list = routes.map((route) => normalizeRoute(route, spotsByRoute.get(route.id) || []));
    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { list: [], total: 0 } });
    }
    console.error('[Travel] 鑾峰彇璺嚎澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/routes', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const title = (req.body.title || '').toString().trim();
    if (!title) {
      return res.status(400).json({ code: 400, message: '璺嚎鍚嶇О涓嶈兘涓虹┖' });
    }
    const spotIds = Array.isArray(req.body.spotIds) ? req.body.spotIds.map(Number).filter(Number.isFinite) : [];
    const visibleIds = await getVisibleUserIds(req.user.id);
    if (spotIds.length > 0) {
      const [visibleSpots] = await conn.query(
        `SELECT id
         FROM travel_spots
         WHERE id IN (${spotIds.map(() => '?').join(',')})
           AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
        [...spotIds, ...visibleIds]
      );
      if (visibleSpots.length !== spotIds.length) {
        return res.status(403).json({ code: 403, message: 'route contains inaccessible spots' });
      }
    }
    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO travel_routes
       (user_id, title, city, description, status, mode, distance, duration, path_json)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.user.id,
        title,
        req.body.city || null,
        req.body.description || null,
        req.body.status || 'draft',
        req.body.mode || 'driving',
        req.body.distance == null ? null : Number(req.body.distance),
        req.body.duration == null ? null : Number(req.body.duration),
        req.body.path ? JSON.stringify(req.body.path) : null,
      ]
    );
    for (let i = 0; i < spotIds.length; i += 1) {
      await conn.query(
        'INSERT INTO travel_route_spots (route_id, spot_id, sort_order) VALUES (?, ?, ?)',
        [result.insertId, spotIds[i], i]
      );
    }
    await conn.commit();
    res.json({ code: 200, message: 'route saved', data: { id: result.insertId } });
  } catch (err) {
    await conn.rollback();
    console.error('[Travel] 淇濆瓨璺嚎澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  } finally {
    conn.release();
  }
});

async function loadTripSpots(tripIds) {
  if (!tripIds.length) return new Map();
  const [spotRows] = await pool.query(
    `SELECT ts.trip_id, ts.sort_order, s.*,
            u.nickname AS creator_nickname, u.avatar_url AS creator_avatar
     FROM travel_trip_spots ts
     JOIN travel_spots s ON s.id = ts.spot_id
     LEFT JOIN users u ON u.id = COALESCE(s.created_by, s.user_id)
     WHERE ts.trip_id IN (${tripIds.map(() => '?').join(',')})
     ORDER BY ts.trip_id, ts.sort_order ASC`,
    tripIds
  );
  const spotsByTrip = new Map();
  for (const row of spotRows) {
    if (!spotsByTrip.has(row.trip_id)) spotsByTrip.set(row.trip_id, []);
    spotsByTrip.get(row.trip_id).push(normalizeSpot(row));
  }
  return spotsByTrip;
}

async function replaceTripSpots(conn, tripId, spotIds, visibleIds) {
  const ids = Array.isArray(spotIds) ? [...new Set(spotIds.map(Number).filter(Number.isFinite))] : [];
  if (ids.length < 1) {
    const err = new Error('trip needs at least one spot');
    err.status = 400;
    throw err;
  }
  const [visibleSpots] = await conn.query(
    `SELECT id
     FROM travel_spots
     WHERE id IN (${ids.map(() => '?').join(',')})
       AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
    [...ids, ...visibleIds]
  );
  if (visibleSpots.length !== ids.length) {
    const err = new Error('trip contains inaccessible spots');
    err.status = 403;
    throw err;
  }
  await conn.query('DELETE FROM travel_trip_spots WHERE trip_id = ?', [tripId]);
  for (let i = 0; i < ids.length; i += 1) {
    await conn.query(
      'INSERT INTO travel_trip_spots (trip_id, spot_id, sort_order) VALUES (?, ?, ?)',
      [tripId, ids[i], i]
    );
  }
}

router.get('/trips', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [trips] = await pool.query(
      `SELECT t.*, u.nickname AS creator_nickname
       FROM travel_trips t
       LEFT JOIN users u ON u.id = COALESCE(t.created_by, t.user_id)
       WHERE t.user_id IN (${visibleIds.map(() => '?').join(',')})
       ORDER BY t.updated_at DESC, t.created_at DESC`,
      visibleIds
    );
    const spotsByTrip = await loadTripSpots(trips.map((trip) => trip.id));
    const list = trips.map((trip) => normalizeTrip(trip, spotsByTrip.get(trip.id) || []));
    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { list: [], total: 0 } });
    }
    console.error('[Travel] get trips failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/trips/:id', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [rows] = await pool.query(
      `SELECT t.*, u.nickname AS creator_nickname
       FROM travel_trips t
       LEFT JOIN users u ON u.id = COALESCE(t.created_by, t.user_id)
       WHERE t.id = ? AND t.user_id IN (${visibleIds.map(() => '?').join(',')})
       LIMIT 1`,
      [Number(req.params.id), ...visibleIds]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: 'trip not found' });
    const spotsByTrip = await loadTripSpots([rows[0].id]);
    res.json({ code: 200, data: normalizeTrip(rows[0], spotsByTrip.get(rows[0].id) || []) });
  } catch (err) {
    console.error('[Travel] get trip failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/trips', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const title = (req.body.title || req.body.name || '').toString().trim();
    if (!title) return res.status(400).json({ code: 400, message: 'trip title is required' });
    const visibleIds = await getVisibleUserIds(req.user.id);
    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO travel_trips
       (user_id, created_by, title, city, description, status, mode, distance, duration, path_json, start_date, end_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.user.id,
        req.user.id,
        title,
        req.body.city || null,
        req.body.description || null,
        req.body.status || 'draft',
        req.body.mode || 'driving',
        req.body.distance == null ? null : Number(req.body.distance),
        req.body.duration == null ? null : Number(req.body.duration),
        req.body.path ? JSON.stringify(req.body.path) : null,
        req.body.startDate || req.body.start_date || null,
        req.body.endDate || req.body.end_date || null,
      ]
    );
    await replaceTripSpots(conn, result.insertId, req.body.spotIds || req.body.spot_ids, visibleIds);
    await conn.commit();
    res.json({ code: 200, message: 'trip saved', data: { id: result.insertId } });
  } catch (err) {
    await conn.rollback();
    console.error('[Travel] save trip failed:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.status ? err.message : 'server error' });
  } finally {
    conn.release();
  }
});

router.put('/trips/:id', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const tripId = Number(req.params.id);
    const title = (req.body.title || req.body.name || '').toString().trim();
    if (!title) return res.status(400).json({ code: 400, message: 'trip title is required' });
    const visibleIds = await getVisibleUserIds(req.user.id);
    await conn.beginTransaction();
    const [result] = await conn.query(
      `UPDATE travel_trips
       SET title = ?, city = ?, description = ?, status = ?, mode = ?, distance = ?, duration = ?,
           path_json = ?, start_date = ?, end_date = ?, updated_at = NOW()
       WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [
        title,
        req.body.city || null,
        req.body.description || null,
        req.body.status || 'draft',
        req.body.mode || 'driving',
        req.body.distance == null ? null : Number(req.body.distance),
        req.body.duration == null ? null : Number(req.body.duration),
        req.body.path ? JSON.stringify(req.body.path) : null,
        req.body.startDate || req.body.start_date || null,
        req.body.endDate || req.body.end_date || null,
        tripId,
        ...visibleIds,
      ]
    );
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({ code: 404, message: 'trip not found' });
    }
    if (req.body.spotIds !== undefined || req.body.spot_ids !== undefined) {
      await replaceTripSpots(conn, tripId, req.body.spotIds || req.body.spot_ids, visibleIds);
    }
    await conn.commit();
    res.json({ code: 200, message: 'trip updated' });
  } catch (err) {
    await conn.rollback();
    console.error('[Travel] update trip failed:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.status ? err.message : 'server error' });
  } finally {
    conn.release();
  }
});

router.put('/trips/:id/spots', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const tripId = Number(req.params.id);
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [rows] = await conn.query(
      `SELECT id FROM travel_trips WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [tripId, ...visibleIds]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: 'trip not found' });
    await conn.beginTransaction();
    await replaceTripSpots(conn, tripId, req.body.spotIds || req.body.spot_ids, visibleIds);
    await conn.commit();
    res.json({ code: 200, message: 'trip spots updated' });
  } catch (err) {
    await conn.rollback();
    console.error('[Travel] update trip spots failed:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.status ? err.message : 'server error' });
  } finally {
    conn.release();
  }
});

router.delete('/trips/:id', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    await conn.beginTransaction();
    const [result] = await conn.query(
      `DELETE FROM travel_trips WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [Number(req.params.id), ...visibleIds]
    );
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({ code: 404, message: 'trip not found' });
    }
    await conn.query('DELETE FROM travel_trip_spots WHERE trip_id = ?', [Number(req.params.id)]);
    await conn.commit();
    res.json({ code: 200, message: 'trip deleted' });
  } catch (err) {
    await conn.rollback();
    console.error('[Travel] delete trip failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  } finally {
    conn.release();
  }
});

router.get('/spots', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const { status, city } = req.query;
    const where = [`s.user_id IN (${visibleIds.map(() => '?').join(',')})`];
    const params = [...visibleIds];

    if (status) {
      where.push('s.status = ?');
      params.push(status);
    }
    if (city) {
      where.push('s.city = ?');
      params.push(city);
    }

    const [rows] = await pool.query(
      `SELECT s.*,
              u.nickname AS creator_nickname, u.avatar_url AS creator_avatar,
              GROUP_CONCAT(p.url ORDER BY p.created_at DESC SEPARATOR ',') AS photos
       FROM travel_spots s
       LEFT JOIN travel_photos p ON p.spot_id = s.id
       LEFT JOIN users u ON u.id = COALESCE(s.created_by, s.user_id)
       WHERE ${where.join(' AND ')}
       GROUP BY s.id, u.nickname, u.avatar_url
       ORDER BY s.updated_at DESC, s.created_at DESC`,
      params
    );

    const list = rows.map(normalizeSpot);
    res.json({ code: 200, data: { list, total: list.length } });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { list: [], total: 0 } });
    }
    console.error('[Travel] 鑾峰彇鍦扮偣澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/spots/:id', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [rows] = await pool.query(
      `SELECT s.*,
              u.nickname AS creator_nickname, u.avatar_url AS creator_avatar,
              GROUP_CONCAT(p.url ORDER BY p.created_at DESC SEPARATOR ',') AS photos
       FROM travel_spots s
       LEFT JOIN travel_photos p ON p.spot_id = s.id
       LEFT JOIN users u ON u.id = COALESCE(s.created_by, s.user_id)
       WHERE s.id = ? AND s.user_id IN (${visibleIds.map(() => '?').join(',')})
       GROUP BY s.id, u.nickname, u.avatar_url`,
      [parseInt(req.params.id), ...visibleIds]
    );
    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: 'spot not found' });
    }
    res.json({ code: 200, data: normalizeSpot(rows[0]) });
  } catch (err) {
    console.error('[Travel] 鑾峰彇鍦扮偣璇︽儏澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/spots', authRequired, async (req, res) => {
  try {
    const data = spotPayload(req.body);
    const [result] = await pool.query(
      `INSERT INTO travel_spots
       (user_id, created_by, name, city, address, lng, lat, emoji, status, note, diary,
        visited_date, rating, mood, tags, reason, desire, planned_date, itinerary, budget,
        weather, traffic, opening_hours, transportation, nearby, tips, owner_note, partner_note)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.user.id,
        req.user.id,
        data.name,
        data.city,
        data.address,
        data.lng,
        data.lat,
        data.emoji,
        data.status,
        data.note,
        data.diary,
        data.visitedDate,
        data.rating,
        data.mood,
        JSON.stringify(data.tags),
        data.reason,
        data.desire,
        data.plannedDate,
        data.itinerary,
        data.budget,
        data.weather,
        data.traffic,
        data.openingHours,
        data.transportation,
        data.nearby,
        data.tips,
        data.ownerNote,
        data.partnerNote,
      ]
    );
    await handleTravelCheckin(req.user.id, result.insertId, data);
    res.json({ code: 200, message: 'spot saved', data: { id: result.insertId } });
  } catch (err) {
    console.error('[Travel] 鍒涘缓鍦扮偣澶辫触:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.status ? err.message : 'server error' });
  }
});

router.put('/spots/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const visibleIds = await getVisibleUserIds(req.user.id);
    const data = spotPayload(req.body, true);
    const [result] = await pool.query(
      `UPDATE travel_spots
       SET name = ?, city = ?, address = ?, lng = ?, lat = ?, emoji = ?, status = ?,
           note = ?, diary = ?, visited_date = ?, rating = ?, mood = ?, tags = ?,
           reason = ?, desire = ?, planned_date = ?, itinerary = ?, budget = ?,
           weather = ?, traffic = ?, opening_hours = ?, transportation = ?, nearby = ?, tips = ?,
           owner_note = ?, partner_note = ?,
           updated_at = NOW()
       WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [
        data.name,
        data.city,
        data.address,
        data.lng,
        data.lat,
        data.emoji,
        data.status,
        data.note,
        data.diary,
        data.visitedDate,
        data.rating,
        data.mood,
        JSON.stringify(data.tags),
        data.reason,
        data.desire,
        data.plannedDate,
        data.itinerary,
        data.budget,
        data.weather,
        data.traffic,
        data.openingHours,
        data.transportation,
        data.nearby,
        data.tips,
        data.ownerNote,
        data.partnerNote,
        id,
        ...visibleIds,
      ]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: 'spot not found' });
    }
    await handleTravelCheckin(req.user.id, id, data);
    res.json({ code: 200, message: 'spot updated' });
  } catch (err) {
    console.error('[Travel] 鏇存柊鍦扮偣澶辫触:', err);
    res.status(err.status || 500).json({ code: err.status || 500, message: err.status ? err.message : 'server error' });
  }
});

router.delete('/spots/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [photos] = await pool.query('SELECT url FROM travel_photos WHERE spot_id = ?', [id]);
    const [result] = await pool.query(
      `DELETE FROM travel_spots WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [id, ...visibleIds]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: 'spot not found' });
    }
    await pool.query('DELETE FROM travel_trip_spots WHERE spot_id = ?', [id]);
    await pool.query('DELETE FROM travel_route_spots WHERE spot_id = ?', [id]);
    try {
      const path = require('path');
      const fs = require('fs');
      for (const photo of photos) {
        const filePath = path.join(__dirname, '..', photo.url.replace(/^\/+/, ''));
        if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      }
      await pool.query('DELETE FROM travel_photos WHERE spot_id = ?', [id]);
    } catch (_) {}
    res.json({ code: 200, message: 'spot deleted' });
  } catch (err) {
    console.error('[Travel] 鍒犻櫎鍦扮偣澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/stats', authRequired, async (req, res) => {
  try {
    const visibleIds = await getVisibleUserIds(req.user.id);
    const [rows] = await pool.query(
      `SELECT
         SUM(status = 'visited') AS visited,
         SUM(status = 'wish') AS wish,
         SUM(status = 'planned') AS planned,
         COUNT(DISTINCT NULLIF(city, '')) AS cities,
         COALESCE(SUM(budget), 0) AS totalBudget
       FROM travel_spots
       WHERE user_id IN (${visibleIds.map(() => '?').join(',')})`,
      visibleIds
    );
    res.json({
      code: 200,
      data: {
        visited: Number(rows[0]?.visited || 0),
        wish: Number(rows[0]?.wish || 0),
        planned: Number(rows[0]?.planned || 0),
        cities: Number(rows[0]?.cities || 0),
        totalBudget: Number(rows[0]?.totalBudget || 0),
      },
    });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: { visited: 0, wish: 0, planned: 0, cities: 0, totalBudget: 0 } });
    }
    console.error('[Travel] 缁熻澶辫触:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

function spotPayload(body) {
  const name = (body.name || '').toString().trim();
  if (!name) {
    const err = new Error('鍦扮偣鍚嶇О涓嶈兘涓虹┖');
    err.status = 400;
    throw err;
  }

  return {
    name,
    city: body.city || '',
    address: body.address || '',
    lng: Number(body.lng || body.longitude || 0),
    lat: Number(body.lat || body.latitude || 0),
    emoji: body.emoji || '馃搷',
    status: body.status || 'wish',
    note: body.note || null,
    diary: body.diary || null,
    visitedDate: body.visitedDate || body.visited_date || null,
    rating: body.rating || null,
    mood: body.mood || null,
    tags: Array.isArray(body.tags) ? body.tags : parseTags(body.tags),
    reason: body.reason || null,
    desire: body.desire || null,
    plannedDate: body.plannedDate || body.planned_date || null,
    itinerary: body.itinerary || null,
    budget: body.budget === undefined || body.budget === '' ? null : Number(body.budget),
    weather: body.weather || null,
    traffic: body.traffic || null,
    openingHours: body.openingHours || body.opening_hours || null,
    transportation: body.transportation || null,
    nearby: body.nearby || null,
    tips: body.tips || null,
    ownerNote: body.ownerNote || body.owner_note || null,
    partnerNote: body.partnerNote || body.partner_note || null,
  };
}

module.exports = router;
