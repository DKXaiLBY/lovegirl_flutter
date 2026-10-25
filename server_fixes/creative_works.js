const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs/promises');
const { randomUUID } = require('crypto');
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { visibleIds, slots, errorResponse } = require('../utils/creation_access');
const contract = require('../utils/creation_contract');

const router = express.Router();
const directory = path.join(__dirname, '..', 'uploads', 'creations');
const ready = fs.mkdir(directory, { recursive: true });
const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, next) => ready.then(() => next(null, directory), next),
    filename: (req, file, next) => next(null, `${randomUUID()}.upload`),
  }),
  limits: { fileSize: 16 * 1024 * 1024, files: 9, fieldSize: 700000 },
}).fields([
  { name: 'preview', maxCount: 1 },
  ...Array.from({ length: 8 }, (_, index) => ({ name: `source${index}`, maxCount: 1 })),
]);

function parse(value) { return typeof value === 'string' ? JSON.parse(value) : value; }
function normalize(row, ids) {
  const linked = row.trip_id != null && ids.includes(Number(row.trip_owner_id));
  return {
    id: row.id, clientId: row.client_id, ownerId: row.user_id, kind: row.kind,
    title: row.title, tripId: linked ? row.trip_id : null, tripTitle: linked ? row.trip_title : null,
    sourceUrls: parse(row.source_urls), previewUrl: row.preview_url,
    document: parse(row.document_json), revision: row.revision,
    createdAt: row.created_at, updatedAt: row.updated_at,
  };
}
async function remove(files) {
  await Promise.all(files.map(file => fs.unlink(file).catch(() => {})));
}
function multipart(req, res, next) {
  upload(req, res, async error => {
    if (!error) return next();
    await remove(Object.values(req.files || {}).flat().map(file => file.path));
    res.status(400).json({ code: 400, message: '图片过大或上传内容不正确，请重新选择' });
  });
}
async function read(id, ids, connection = pool, lock = false) {
  // The lock query reads only the work row; trip names are loaded separately.
  const [rows] = await connection.query(
    lock
      ? 'SELECT * FROM creative_works WHERE id = ? AND user_id IN (?, ?, ?, ?, ?, ?, ?, ?) AND deleted_at IS NULL FOR UPDATE'
      : 'SELECT w.*, t.title AS trip_title, t.user_id AS trip_owner_id FROM creative_works w LEFT JOIN travel_trips t ON t.id = w.trip_id WHERE w.id = ? AND w.user_id IN (?, ?, ?, ?, ?, ?, ?, ?) AND w.deleted_at IS NULL',
    [id, ...slots(ids)]
  );
  return rows[0];
}

router.get('/', authRequired, async (req, res) => {
  try {
    const ids = await visibleIds(pool, req.user.id);
    const [rows] = await pool.query(
      'SELECT w.*, t.title AS trip_title, t.user_id AS trip_owner_id FROM creative_works w LEFT JOIN travel_trips t ON t.id = w.trip_id WHERE w.user_id IN (?, ?, ?, ?, ?, ?, ?, ?) AND w.deleted_at IS NULL ORDER BY w.updated_at DESC, w.id DESC',
      slots(ids)
    );
    res.json({ code: 200, data: rows.map(row => normalize(row, ids)) });
  } catch (error) { errorResponse(res, error); }
});

router.get('/:id', authRequired, async (req, res) => {
  try {
    const ids = await visibleIds(pool, req.user.id);
    const row = await read(Number(req.params.id), ids);
    if (!row) contract.fail('作品不存在', 404);
    res.json({ code: 200, data: normalize(row, ids) });
  } catch (error) { errorResponse(res, error); }
});

async function save(req, res) {
  const temporary = Object.values(req.files || {}).flat().map(file => file.path);
  const added = [];
  let connection;
  let committed = false;
  try {
    const data = contract.document(req.body.document);
    const ids = await visibleIds(pool, req.user.id);
    const clientId = contract.text(req.body.clientId, 80);
    if (!/^[a-zA-Z0-9_-]{8,80}$/.test(clientId)) contract.fail('作品标识不正确');
    const tripId = req.body.tripId === '' || req.body.tripId == null
      ? null : contract.integer(req.body.tripId, 1, 2147483647, '旅行关联不正确');
    if (tripId != null) {
      const [trips] = await pool.query(
        'SELECT id FROM travel_trips WHERE id = ? AND user_id IN (?, ?, ?, ?, ?, ?, ?, ?)',
        [tripId, ...slots(ids)]
      );
      if (!trips.length) contract.fail('关联旅行已不存在，请重新选择', 409);
    }
    const preview = req.files?.preview?.[0];
    if (!preview) contract.fail('请先生成作品预览');
    // Decode, bound and re-encode every uploaded image. Extensions are never trusted.
    async function image(file, isPreview) {
      const filename = `${randomUUID()}${isPreview ? '.png' : '.jpg'}`;
      const target = path.join(directory, filename);
      added.push(target);
      try {
        let transform = sharp(file.path, { limitInputPixels: 60000000 })
          .rotate().resize(2400, 2400, { fit: 'inside', withoutEnlargement: true });
        transform = isPreview ? transform.png() : transform.jpeg({ quality: 90 });
        await transform.toFile(target);
      } catch (_) { contract.fail('图片无法读取，请重新选择'); }
      return `/uploads/creations/${filename}`;
    }
    const previewUrl = await image(preview, true);
    const sources = [];
    for (let index = 0; index < 8; index++) {
      const file = req.files?.[`source${index}`]?.[0];
      if (file) {
        if (sources.length !== index) contract.fail('照片顺序不正确');
        sources.push(await image(file, false));
      }
    }
    connection = await pool.getConnection();
    await connection.beginTransaction();
    if (tripId != null) {
      const [trips] = await connection.query(
        'SELECT id FROM travel_trips WHERE id = ? AND user_id IN (?, ?, ?, ?, ?, ?, ?, ?) LOCK IN SHARE MODE',
        [tripId, ...slots(ids)]
      );
      if (!trips.length) contract.fail('关联旅行已不存在，请重新选择', 409);
    }
    let id;
    if (req.params.id) {
      id = contract.integer(req.params.id, 1, 2147483647, '作品不正确');
      const current = await read(id, ids, connection, true);
      if (!current) contract.fail('作品不存在', 404);
      if (current.user_id !== Number(req.user.id)) contract.fail('只有制作者可以修改这份作品', 403);
      const revision = contract.integer(req.body.revision, 1, 2147483647, '请重新打开作品后保存');
      if (revision !== current.revision) contract.fail('作品有新修改，你的草稿已保留，请加载最新版本', 409);
      if (!sources.length) sources.push(...parse(current.source_urls));
      if (sources.length !== data.transforms.length) contract.fail('照片数量与裁切设置不一致');
      await connection.query(
        'UPDATE creative_works SET kind = ?, title = ?, trip_id = ?, source_urls = ?, preview_url = ?, document_json = ?, revision = revision + 1, updated_at = NOW() WHERE id = ? AND revision = ?',
        [data.kind, data.title || (data.kind === 'ticket' ? '旅行票根' : '拍立得'), tripId,
          JSON.stringify(sources), previewUrl, JSON.stringify(data), id, revision]
      );
    } else {
      if (sources.length !== data.transforms.length) contract.fail('请选择完整的原照片');
      const [existing] = await connection.query(
        'SELECT id FROM creative_works WHERE user_id = ? AND client_id = ? LIMIT 1', [req.user.id, clientId]
      );
      if (existing.length) contract.fail('这份作品已经保存，请加载后继续编辑；当前草稿已保留', 409);
      const [result] = await connection.query(
        'INSERT INTO creative_works (user_id, client_id, kind, title, trip_id, source_urls, preview_url, document_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [req.user.id, clientId, data.kind, data.title || (data.kind === 'ticket' ? '旅行票根' : '拍立得'),
          tripId, JSON.stringify(sources), previewUrl, JSON.stringify(data)]
      );
      id = result.insertId;
    }
    await connection.commit();
    committed = true;
    const row = await read(id, ids, connection);
    await remove(temporary);
    temporary.length = 0;
    res.json({ code: 200, message: '已收藏', data: normalize(row, ids) });
  } catch (error) {
    if (connection && !committed) await connection.rollback();
    await remove(temporary);
    temporary.length = 0;
    if (!committed) { await remove(added); added.length = 0; }
    if (error.code === 'ER_DUP_ENTRY') { error.status = 409; error.message = '作品已保存，请加载最新版本；草稿已保留'; }
    errorResponse(res, error);
  } finally {
    connection?.release();
    await remove(temporary);
    if (!committed) await remove(added);
  }
}
router.post('/', authRequired, multipart, save);
router.put('/:id', authRequired, multipart, save);

router.delete('/:id', authRequired, async (req, res) => {
  try {
    const revision = contract.integer(req.query.revision, 1, 2147483647, '请刷新后删除');
    const row = await read(Number(req.params.id), [req.user.id]);
    if (!row) contract.fail('作品不存在或没有删除权限', 404);
    const [result] = await pool.query(
      'UPDATE creative_works SET deleted_at = NOW(), revision = revision + 1 WHERE id = ? AND user_id = ? AND revision = ? AND deleted_at IS NULL',
      [row.id, req.user.id, revision]
    );
    if (!result.affectedRows) contract.fail('作品有新修改，请刷新后再删除', 409);
    // Keep source files for rollback; never unlink an original album/travel image.
    res.json({ code: 200, message: '已删除' });
  } catch (error) { errorResponse(res, error); }
});

module.exports = router;
