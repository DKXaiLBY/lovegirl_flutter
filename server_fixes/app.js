const express = require('express');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const app = express();

// ========== Security & Ops Middleware ==========

// 安全 HTTP 头（防 XSS/点击劫持/MIME嗅探等）
// helmet 配置：关闭 HSTS（APP 使用 HTTP，不需要强制 HTTPS）
app.use(helmet({
  hsts: false,  // 禁用 HSTS，避免浏览器强制 HTTPS 导致下载问题
}));

// CORS — 允许APP来源
const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',')
  : ['http://47.121.119.191:3001', 'http://localhost:3000', 'http://localhost:3001'];
app.use(cors({
  origin: function (origin, callback) {
    // 允许无origin的请求（APP端、curl等）
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== 'production') {
      return callback(null, true);
    }
    callback(null, true); // 生产环境收紧时改为 callback(new Error('Not allowed by CORS'))
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Gzip 压缩
app.use(compression());

// 请求日志
app.use(morgan('short'));

// Body 解析
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use(express.urlencoded({ extended: true }));

// 全局限流 — 每IP每分钟最多200次请求
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,      // 1分钟窗口
  max: 200,                  // 最多200次
  standardHeaders: true,
  legacyHeaders: false,
  message: { code: 429, message: '请求太频繁，请稍后再试' },
});
app.use('/api', globalLimiter);

// 登录接口特殊限流 — 每分钟最多10次，防止暴力破解
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { code: 429, message: '登录尝试过于频繁，请1分钟后再试' },
});
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', rateLimit({ windowMs: 60 * 1000, max: 5 }));

// ========== Static Files (APK downloads) ==========
app.use('/public', express.static(path.join(__dirname, 'public'), {
  // APK 文件不缓存，确保下载最新版本
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.apk')) {
      res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
      res.set('Pragma', 'no-cache');
      res.set('Expires', '0');
      res.set('Surrogate-Control', 'no-store');
    }
  },
}));

// ========== Health Check ==========
app.get('/api/health', (req, res) => res.json({ code: 200, message: 'OK', uptime: process.uptime() }));

// ========== Routes ==========
// server_fixes 当前仓库里优先挂载已经落地的真实路由。
app.use('/api/auth', require('./auth'));
app.use('/api/user', require('./user'));
app.use('/api/travel', require('./travel'));
app.use('/api/travel', require('./travel_photos')); // 旅行照片
app.use('/api/period', require('./period'));
app.use('/api/todo', require('./todo'));
app.use('/api/finance', require('./finance'));
app.use('/api/course', require('./course'));
app.use('/api/photo', require('./photo'));
app.use('/api/mood', require('./mood'));
app.use('/api/chat', require('./chat'));
app.use('/api/timeline', require('./timeline'));
app.use('/api/home', require('./home'));
app.use('/api/feeding', require('./feeding_v2'));
app.use('/api/weather', require('./weather'));
app.use('/api/version', require('./version'));
app.use('/api/beans', require('./beans'));
app.use('/api/achievements', require('./achievements'));
app.use('/api/notifications', require('./notifications'));
app.use('/api/sync', require('./sync'));
app.use('/api/activity', require('./activity'));
app.use('/api/admin', require('./admin_products'));
app.use('/api/admin', require('./admin'));
app.use('/api/aliases', require('./aliases'));
app.use('/api/anniversary', require('./anniversary'));
app.use('/api/daily', require('./daily'));
app.use('/api/exam', require('./exam'));
app.use('/api/privacy', require('./privacy'));
app.use('/api/couple', require('./couple'));
app.use('/api/deploy', require('./deploy_api'));

// ========== 404 Handler (all paths return JSON) ==========
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ code: 404, message: `接口不存在: ${req.method} ${req.path}` });
  }
  res.status(404).json({ code: 404, message: '资源不存在' });
});

// ========== Error Handling ==========
app.use((err, req, res, next) => {
  console.error(`[${new Date().toISOString()}] ${req.method} ${req.path}:`, err.message);

  // 区分不同类型的错误
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ code: 400, message: '请求体JSON格式错误' });
  }
  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    return res.status(400).json({ code: 400, message: '上传文件超出限制' });
  }
  if (err.name === 'UnauthorizedError' || err.status === 401) {
    return res.status(401).json({ code: 401, message: '未授权，请重新登录' });
  }
  if (err.name === 'ValidationError') {
    return res.status(400).json({ code: 400, message: err.message });
  }

  res.status(err.status || 500).json({
    code: err.status || 500,
    message: process.env.NODE_ENV === 'production' ? '服务器内部错误' : err.message,
  });
});

// ========== Start ==========
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[LoveGirl] Server running on port ${PORT} (${process.env.NODE_ENV || 'development'})`);
});

module.exports = app;
