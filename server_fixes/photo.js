/**
 * 相册路由 — 支持上传/查看/删除
 */
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// 上传目录
const uploadDir = path.join(__dirname, '..', 'uploads', 'photos');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// multer 配置
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}_${Math.random().toString(36).substr(2, 8)}${ext}`);
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

// GET /api/photo — 获取照片列表
router.get('/', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const [rows] = await pool.query(
      'SELECT id, url, thumbnail_url, description, created_at FROM photos WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );
    res.json({ code: 200, data: rows });
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      // 表不存在时返回空数组
      return res.json({ code: 200, data: [] });
    }
    console.error('[Photo] 获取列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/photo/upload — 上传照片
router.post('/upload', authRequired, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请选择照片文件' });
    }
    const userId = req.user.id;
    const filename = req.file.filename;
    const url = `/uploads/photos/${filename}`;

    try {
      const [result] = await pool.query(
        'INSERT INTO photos (user_id, url, description, created_at) VALUES (?, ?, ?, NOW())',
        [userId, url, req.body.description || '']
      );
      res.json({
        code: 200,
        message: '上传成功',
        data: { id: result.insertId, url }
      });
    } catch (err) {
      if (err.code === 'ER_NO_SUCH_TABLE') {
        // 表不存在时仍返回成功URL
        return res.json({
          code: 200,
          message: '上传成功',
          data: { id: Date.now(), url }
        });
      }
      throw err;
    }
  } catch (err) {
    console.error('[Photo] 上传失败:', err);
    res.status(500).json({ code: 500, message: '上传失败' });
  }
});

// PUT /api/photo/:id/description — 编辑照片背后的故事（拍立得背卡）
router.put('/:id/description', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const photoId = parseInt(req.params.id);
    const desc = String(req.body.description ?? '').trim().slice(0, 500);
    const [result] = await pool.query(
      'UPDATE photos SET description = ? WHERE id = ? AND user_id = ?',
      [desc, photoId, userId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '照片不存在' });
    }
    res.json({ code: 200, message: '已保存', data: { description: desc } });
  } catch (err) {
    console.error('[Photo] 描述保存失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// DELETE /api/photo/:id — 删除照片
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const photoId = parseInt(req.params.id);
    const [rows] = await pool.query(
      'SELECT url FROM photos WHERE id = ? AND user_id = ?', [photoId, userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: '照片不存在' });
    }
    // 删除文件
    const filePath = path.join(__dirname, '..', rows[0].url);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    // 删除数据库记录
    await pool.query('DELETE FROM photos WHERE id = ?', [photoId]);
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    console.error('[Photo] 删除失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
