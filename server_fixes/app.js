const express = require('express');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();

// ========== Security & Ops Middleware ==========

// 安全 HTTP 头（防 XSS/点击劫持/MIME嗅探等）
app.use(helmet());

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

// ========== Health Check ==========
app.get('/api/health', (req, res) => res.json({ code: 200, message: 'OK', uptime: process.uptime() }));

// ========== Routes ==========
app.use('/api/auth', require('./routes/auth'));
app.use('/api/user', require('./routes/user'));
app.use('/api/travel', require('./routes/travel'));
app.use('/api/period', require('./routes/period'));
app.use('/api/calorie', require('./routes/calorie'));
app.use('/api/todo', require('./routes/todo'));
app.use('/api/finance', require('./routes/finance'));
app.use('/api/course', require('./routes/course'));
app.use('/api/photo', require('./routes/photo'));
app.use('/api/mood', require('./routes/mood'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/timeline', require('./routes/timeline'));
app.use('/api/feeding', require('./routes/feeding'));
app.use('/api/weather', require('./routes/weather'));
app.use('/api/version', require('./routes/version'));
app.use('/api/search', require('./routes/search'));
app.use('/api/sync', require('./routes/sync'));
app.use('/api/activity', require('./routes/activity'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/aliases', require('./routes/aliases'));
app.use('/api/anniversary', require('./routes/anniversary'));
app.use('/api/daily', require('./routes/daily'));
app.use('/api/exam', require('./routes/exam'));
app.use('/api/privacy', require('./routes/privacy'));

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
