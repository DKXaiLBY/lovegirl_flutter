const { test } = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');

function fixture() {
  const links = [];
  const removedFiles = [];
  const photos = [
    { id: 5, user_id: 1, visibility: 'shared', url: '/uploads/original.jpg', description: '散步' },
    { id: 6, user_id: 1, visibility: 'private', url: '/uploads/private.jpg' },
    { id: 8, user_id: 9, visibility: 'shared', url: '/uploads/other.jpg' },
  ];
  let failReads = false;
  const pool = {
    async query(sql, args) {
      if (sql.includes('FROM couples')) return [[{ partner_id: args[0] === 1 ? 2 : 99 }]];
      if (sql.includes('FROM travel_spots')) {
        return [[...(args[0] === 10 && args.slice(1).includes(2) ? [{ id: 10 }] : [])]];
      }
      if (sql.includes('FROM photos')) {
        assert.match(sql, /user_id = \?/);
        assert.match(sql, /visibility = 'shared'/);
        const match = sql.includes('WHERE id = ?')
          ? photos.filter(p => p.id === args[0] && p.user_id === args[1])
          : photos.filter(p => p.user_id === args[0]);
        return [match.filter(p => p.visibility === 'shared')];
      }
      if (sql.startsWith('INSERT INTO travel_photos')) {
        const existing = links.find(p => p.spot_id === args[0] && p.source_photo_id === args[4]);
        if (existing) {
          assert.match(sql, /ON DUPLICATE KEY UPDATE/);
          return [{ insertId: existing.id }];
        }
        const link = { id: 100 + links.length, spot_id: args[0], user_id: args[1],
          url: args[2], description: args[3], source_photo_id: args[4] };
        links.push(link);
        return [{ insertId: link.id }];
      }
      if (sql.startsWith('SELECT') && sql.includes('FROM travel_photos')) {
        if (failReads) throw Object.assign(new Error('missing table'), { code: 'ER_NO_SUCH_TABLE' });
        return [sql.includes('WHERE id = ?')
          ? links.filter(p => p.id === args[0] && p.spot_id === args[1])
          : links.filter(p => p.spot_id === args[0])];
      }
      if (sql.startsWith('DELETE FROM travel_photos')) {
        const index = links.findIndex(p => p.id === args[0] && p.spot_id === args[1]);
        if (index >= 0) links.splice(index, 1);
        return [{ affectedRows: index >= 0 ? 1 : 0 }];
      }
      throw new Error('Unexpected database operation');
    },
  };
  const file = path.resolve(__dirname, '..', 'travel_photos.js');
  const loaded = new Module(file, module);
  loaded.filename = file;
  loaded.paths = Module._nodeModulePaths(path.dirname(file));
  const originalRequire = loaded.require.bind(loaded);
  loaded.require = name => {
    if (name === '../config/database') return pool;
    if (name === '../middleware/auth') return {
      authRequired(req, res, next) {
        const user = Number(req.headers['x-test-user']);
        if (!user) return res.status(401).json({ code: 401 });
        req.user = { id: user };
        next();
      },
    };
    if (name === 'fs') return { existsSync: () => true, unlinkSync: file => removedFiles.push(file) };
    return originalRequire(name);
  };
  loaded._compile(fs.readFileSync(file, 'utf8'), file);
  const app = express();
  app.use(express.json());
  app.use('/api/travel', loaded.exports);
  return { app, links, removedFiles, failReads: () => { failReads = true; } };
}

async function request(f, suffix, { user = 1, method = 'GET', body } = {}) {
  const server = await new Promise(resolve => {
    const instance = f.app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  try {
    const response = await fetch('http://127.0.0.1:' + server.address().port + '/api/travel/' + suffix, {
      method, headers: { 'Content-Type': 'application/json', 'x-test-user': String(user) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
}

test('相册候选只包含本人共享照片', async () => {
  const result = await request(fixture(), 'spots/10/photos/album');
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data.map(p => p.id), [5]);
});

test('未登录不能读取相册候选', async () => {
  assert.equal((await request(fixture(), 'spots/10/photos/album', { user: 0 })).status, 401);
});

test('第三方不能读取或关联其他情侣的地点', async () => {
  const f = fixture();
  assert.equal((await request(f, 'spots/10/photos/album', { user: 9 })).status, 404);
  assert.equal((await request(f, 'spots/10/photos/link',
    { user: 9, method: 'POST', body: { photoId: 8 } })).status, 404);
  assert.equal(f.links.length, 0);
});

test('私密照片和他人相册照片不能直接绕过选片器关联', async () => {
  for (const photoId of [6, 8]) {
    const f = fixture();
    const result = await request(f, 'spots/10/photos/link', { method: 'POST', body: { photoId } });
    assert.equal(result.status, 404);
    assert.equal(f.links.length, 0);
  }
});

test('引用可加入伴侣地点，重复请求不会多建记录', async () => {
  const f = fixture();
  const first = await request(f, 'spots/10/photos/link', { method: 'POST', body: { photoId: 5 } });
  const second = await request(f, 'spots/10/photos/link', { method: 'POST', body: { photoId: 5 } });
  assert.equal(first.status, 200);
  assert.equal(second.body.data.id, first.body.data.id);
  assert.equal(f.links.length, 1);
  assert.deepEqual(f.removedFiles, []);
});

test('移除引用不删除相册原图', async () => {
  const f = fixture();
  f.links.push({ id: 100, spot_id: 10, source_photo_id: 5, url: '/uploads/original.jpg' });
  assert.equal((await request(f, 'spots/10/photos/100', { method: 'DELETE' })).status, 200);
  assert.equal(f.links.length, 0);
  assert.deepEqual(f.removedFiles, []);
});

test('第三方无法移除引用', async () => {
  const f = fixture();
  f.links.push({ id: 100, spot_id: 10, source_photo_id: 5 });
  assert.equal((await request(f, 'spots/10/photos/100', { method: 'DELETE', user: 9 })).status, 404);
  assert.equal(f.links.length, 1);
});

test('缺表必须显示失败，不能伪装成空相册', async () => {
  const f = fixture();
  f.failReads();
  assert.equal((await request(f, 'spots/10/photos')).status, 503);
});

test('拒绝无效地点与照片编号', async () => {
  for (const photoId of [0, -1, '5', 1.2, null, '1 OR 1=1']) {
    assert.equal((await request(fixture(), 'spots/10/photos/link',
      { method: 'POST', body: { photoId } })).status, 400);
  }
  assert.equal((await request(fixture(), 'spots/10x/photos/album')).status, 400);
});
