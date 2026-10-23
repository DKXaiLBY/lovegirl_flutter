/**
 * 旅行地点照片路由 — 支持上传/查看/删除
 */
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

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

// 上传目录
const uploadDir = path.join(__dirname, '..', 'uploads', 'travel');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// multer 配置
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `travel_${Date.now()}_${Math.random().toString(36).substr(2, 8)}${ext}`);
  }
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, allowed.includes(ext));
  }
});

// GET /api/travel/spots/:spotId/photos — 获取地点照片列表
router.get('/spots/:spotId/photos', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const spotId = parseInt(req.params.spotId);
    const visibleIds = await getVisibleUserIds(userId);

    // 验证地点属于当前用户或伴侣
    const [spots] = await pool.query(
      `SELECT id FROM travel_spots WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [spotId, ...visibleIds]
    );
    if (spots.length === 0) {
      return res.status(404).json({ code: 404, message: '地点不存在' });
    }

    const [rows] = await pool.query(
      'SELECT id, url, description, source_photo_id, created_at FROM travel_photos WHERE spot_id = ? ORDER BY created_at DESC',
      [spotId]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.status(503).json({ code: 503, message: '地点照片服务暂不可用' });
    }
    console.error('[TravelPhoto] 获取列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/travel/spots/:spotId/photos — 上传地点照片
router.post('/spots/:spotId/photos', authRequired, upload.single('photo'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请选择照片文件' });
    }

    const userId = req.user.id;
    const spotId = parseInt(req.params.spotId);
    const filename = req.file.filename;
    const url = `/uploads/travel/${filename}`;
    const visibleIds = await getVisibleUserIds(userId);

    // 验证地点属于当前用户或伴侣
    const [spots] = await pool.query(
      `SELECT id FROM travel_spots WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [spotId, ...visibleIds]
    );
    if (spots.length === 0) {
      // 删除已上传的文件
      const filePath = path.join(uploadDir, filename);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      return res.status(404).json({ code: 404, message: '地点不存在' });
    }

    try {
      const [result] = await pool.query(
        'INSERT INTO travel_photos (spot_id, user_id, url, description, created_at) VALUES (?, ?, ?, ?, NOW())',
        [spotId, userId, url, req.body.description || '']
      );
      res.json({
        code: 200,
        message: '上传成功',
        data: { id: result.insertId, url }
      });
    } catch (err) {
      throw err;
    }
  } catch (err) {
    console.error('[TravelPhoto] 上传失败:', err);
    res.status(500).json({ code: 500, message: '上传失败' });
  }
});

// GET /api/travel/spots/:spotId/photos/album — 本人共享相册候选。
router.get('/spots/:spotId/photos/album', authRequired, async (req, res) => {
  const spotId = Number(req.params.spotId);
  if (!Number.isSafeInteger(spotId) || spotId <= 0) {
    return res.status(400).json({ code: 400, message: '地点编号不正确' });
  }
  try {
    const userId = req.user.id;
    const visibleIds = await getVisibleUserIds(userId);
    const [spots] = await pool.query(
      'SELECT id FROM travel_spots WHERE id = ? AND user_id IN (?, ?)',
      [spotId, userId, visibleIds[1] || userId]
    );
    if (!spots.length) return res.status(404).json({ code: 404, message: '地点不存在' });
    const [photos] = await pool.query(
      "SELECT id, url, thumbnail_url, description, photo_date FROM photos WHERE user_id = ? AND visibility = 'shared' ORDER BY created_at DESC",
      [userId]
    );
    res.json({ code: 200, data: photos });
  } catch (err) {
    console.error('[TravelPhoto] 相册候选加载失败:', err.code);
    res.status(503).json({ code: 503, message: '相册暂不可用，请稍后重试' });
  }
});

// POST /api/travel/spots/:spotId/photos/link — 引用本人相册，不复制文件。
router.post('/spots/:spotId/photos/link', authRequired, async (req, res) => {
  const spotId = Number(req.params.spotId);
  const photoId = req.body.photoId;
  if (!Number.isSafeInteger(spotId) || spotId <= 0 ||
      !Number.isSafeInteger(photoId) || photoId <= 0) {
    return res.status(400).json({ code: 400, message: '照片或地点编号不正确' });
  }
  try {
    const userId = req.user.id;
    const visibleIds = await getVisibleUserIds(userId);
    const [spots] = await pool.query(
      'SELECT id FROM travel_spots WHERE id = ? AND user_id IN (?, ?)',
      [spotId, userId, visibleIds[1] || userId]
    );
    if (!spots.length) return res.status(404).json({ code: 404, message: '地点不存在' });
    // 相册 GET 仅展示本人的照片，这里遵守相同权限。
    const [photos] = await pool.query(
      "SELECT id, url, description FROM photos WHERE id = ? AND user_id = ? AND visibility = 'shared'",
      [photoId, userId]
    );
    if (!photos.length) return res.status(404).json({ code: 404, message: '照片不存在' });
    const photo = photos[0];
    const [result] = await pool.query(
      'INSERT INTO travel_photos (spot_id, user_id, url, description, source_photo_id, created_at) VALUES (?, ?, ?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)',
      [spotId, userId, photo.url, photo.description || '', photoId]
    );
    res.json({ code: 200, data: { id: result.insertId, source_photo_id: photoId, url: photo.url } });
  } catch (err) {
    console.error('[TravelPhoto] 关联失败:', err.code);
    res.status(503).json({ code: 503, message: '关联暂未完成，请稍后重试' });
  }
});

// DELETE /api/travel/spots/:spotId/photos/:photoId — 删除地点照片
router.delete('/spots/:spotId/photos/:photoId', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const spotId = parseInt(req.params.spotId);
    const photoId = parseInt(req.params.photoId);
    const visibleIds = await getVisibleUserIds(userId);

    // 验证地点属于当前用户或伴侣
    const [spots] = await pool.query(
      `SELECT id FROM travel_spots WHERE id = ? AND user_id IN (${visibleIds.map(() => '?').join(',')})`,
      [spotId, ...visibleIds]
    );
    if (spots.length === 0) {
      return res.status(404).json({ code: 404, message: '地点不存在' });
    }

    // 获取照片信息
    const [photos] = await pool.query(
      'SELECT id, url, source_photo_id FROM travel_photos WHERE id = ? AND spot_id = ?',
      [photoId, spotId]
    );
    if (photos.length === 0) {
      return res.status(404).json({ code: 404, message: '照片不存在' });
    }

    // 删除关联只移除引用；相册原图由相册管理。
    await pool.query('DELETE FROM travel_photos WHERE id = ? AND spot_id = ?', [photoId, spotId]);
    if (photos[0].source_photo_id == null) {
      const filePath = path.join(__dirname, '..', photos[0].url.replace(/^\/+/, ''));
      try {
        if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      } catch (err) {
        console.error('[TravelPhoto] 文件清理失败:', err.message);
      }
    }
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    console.error('[TravelPhoto] 删除失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
