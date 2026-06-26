/**
 * 自动发布 API
 * POST /api/deploy/publish — 上传 APK 或从 URL 拉取
 * GET  /api/deploy/status  — 查看版本状态
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');
const pool = require('../config/database');

const TOKEN = process.env.DEPLOY_TOKEN;
if (!TOKEN) {
  console.warn('[Deploy] WARNING: DEPLOY_TOKEN not set, deploy API will reject all requests');
}
const uploadDir = path.join(__dirname, '..', 'public', 'download');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) { cb(null, uploadDir); },
  filename: function (req, file, cb) { cb(null, 'LoveGirl-latest.apk'); }
});
const upload = multer({ storage: storage, limits: { fileSize: 50 * 1024 * 1024 } });

// Token 验证
router.use(function (req, res, next) {
  if (!TOKEN) return res.status(500).json({ code: 500, message: 'DEPLOY_TOKEN 未配置' });
  if (req.headers['x-deploy-token'] === TOKEN) return next();
  res.status(403).json({ code: 403, message: 'Token 无效' });
});

// 下载文件辅助
function downloadFile(url, dest) {
  return new Promise(function (resolve, reject) {
    var mod = url.startsWith('https') ? https : http;
    mod.get(url, function (response) {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        return downloadFile(response.headers.location, dest).then(resolve, reject);
      }
      if (response.statusCode !== 200) {
        return reject(new Error('HTTP ' + response.statusCode));
      }
      var file = fs.createWriteStream(dest);
      response.pipe(file);
      file.on('finish', function () { file.close(resolve); });
      file.on('error', reject);
    }).on('error', reject);
  });
}

// POST /api/deploy/publish
router.post('/publish', upload.single('apk'), async function (req, res) {
  try {
    var vname = req.body.v || req.body.version_name || '';
    var vcode = parseInt(req.body.c || req.body.version_code || 0);
    var changelog = req.body.l || req.body.changelog || '';
    var filesize = req.body.s || req.body.file_size || '0';
    var force = req.body.f === '1' ? 1 : 0;
    var url = req.body.url || '';

    if (!vname || !vcode) {
      return res.status(400).json({ code: 400, message: '缺少版本信息' });
    }

    var apkPath = req.file ? req.file.path : null;

    // 如果有 URL，从 URL 下载
    if (!apkPath && url) {
      console.log('[Deploy] 从 URL 下载 APK: ' + url);
      var destFile = path.join(uploadDir, 'LoveGirl-latest.apk');
      try {
        await downloadFile(url, destFile);
        apkPath = destFile;
      } catch (e) {
        return res.status(400).json({ code: 400, message: '下载 APK 失败: ' + e.message });
      }
    }

    if (!apkPath) {
      return res.status(400).json({ code: 400, message: '请上传 APK 文件或提供下载 URL' });
    }

    // 重命名带版本号
    var versionedFile = path.join(uploadDir, 'LoveGirl-v' + vname + '-build' + vcode + '.apk');
    fs.copyFileSync(apkPath, versionedFile);

    var apkUrl = 'http://47.121.119.191:3001/public/download/LoveGirl-latest.apk';

    await pool.query(
      'INSERT INTO app_versions (version_code, version_name, apk_url, changelog, file_size, force_update, is_active) VALUES (?, ?, ?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE apk_url = VALUES(apk_url), changelog = VALUES(changelog), file_size = VALUES(file_size), force_update = VALUES(force_update), is_active = 1',
      [vcode, vname, apkUrl, changelog, parseInt(filesize) || 0, force]
    );

    await pool.query('UPDATE app_versions SET is_active = 0 WHERE version_code != ?', [vcode]);

    console.log('[Deploy] v' + vname + ' (build ' + vcode + ') OK!');
    res.json({ code: 200, message: 'v' + vname + ' 发布成功!', data: { url: apkUrl } });
  } catch (err) {
    console.error('[Deploy] 失败:', err);
    res.status(500).json({ code: 500, message: '发布失败: ' + err.message });
  }
});

// GET /api/deploy/status
router.get('/status', async function (req, res) {
  try {
    var result = await pool.query('SELECT * FROM app_versions ORDER BY version_code DESC LIMIT 3');
    res.json({ code: 200, data: result[0] });
  } catch (err) {
    res.status(500).json({ code: 500, message: '查询失败' });
  }
});

module.exports = router;
