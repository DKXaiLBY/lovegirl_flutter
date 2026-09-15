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
      'SELECT id, url, description, created_at FROM travel_photos WHERE spot_id = ? ORDER BY created_at DESC',
      [spotId]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.json({ code: 200, data: [] });
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
      if (err.code === 'ER_NO_SUCH_TABLE') {
        return res.json({
          code: 200,
          message: '上传成功',
          data: { id: Date.now(), url }
        });
      }
      throw err;
    }
  } catch (err) {
    console.error('[TravelPhoto] 上传失败:', err);
    res.status(500).json({ code: 500, message: '上传失败' });
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
      'SELECT id, url FROM travel_photos WHERE id = ? AND spot_id = ?',
      [photoId, spotId]
    );
    if (photos.length === 0) {
      return res.status(404).json({ code: 404, message: '照片不存在' });
    }

    // 删除文件
    const filePath = path.join(__dirname, '..', photos[0].url.replace(/^\/+/, ''));
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

    // 删除数据库记录
    await pool.query('DELETE FROM travel_photos WHERE id = ?', [photoId]);
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    console.error('[TravelPhoto] 删除失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
