// Opt-in live smoke check. Runs only in the isolated loopback staging service.
const path = require('path');
const stage = process.env.REBUILD_STAGE;
if (!stage || !stage.startsWith('/app/.rebuild-')) throw new Error('staging directory required');
const express = require('express');
const { generateAccessToken } = require('/app/config/jwt');
const pool = require('/app/config/database');
(async () => {
  const app = express();
  app.use('/travel', require(path.join(stage, 'routes/travel')));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    const [rows] = await pool.query('SELECT id, username, role FROM users WHERE id = 1');
    const token = generateAccessToken(rows[0]);
    for (const mode of ['walking', 'bicycling', 'driving', 'transit']) {
      const query = new URLSearchParams({ mode, origin: '120.1495,30.2491', destination: '120.2126,30.2903', city: '杭州' });
      const response = await fetch(`http://127.0.0.1:${server.address().port}/travel/amap/direction?${query}`, { headers: { Authorization: `Bearer ${token}` } });
      const body = await response.json();
      console.log(JSON.stringify({ mode, status: response.status, returnedMode: body.data?.mode,
        distance: body.data?.distance, duration: body.data?.duration, points: body.data?.path?.length,
        message: response.ok ? undefined : body.message }));
    }
  } finally { server.close(); await pool.end(); }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
