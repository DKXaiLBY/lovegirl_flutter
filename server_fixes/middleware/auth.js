// JWT 认证中间件
const { verifyToken } = require('../config/jwt');

/**
 * 必须登录才能访问
 */
function authRequired(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ code: 401, message: '请先登录' });
  }

  const token = authHeader.split(' ')[1];
  const decoded = verifyToken(token);
  if (!decoded || decoded.type === 'refresh' || !Number.isSafeInteger(decoded.id) || decoded.id <= 0) {
    return res.status(401).json({ code: 401, message: '登录已过期，请重新登录' });
  }

  req.user = decoded;
  next();
}

/**
 * 可选登录（未登录也能访问，但登录后能获取更多数据）
 */
function authOptional(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);
    if (decoded && decoded.type !== 'refresh' && Number.isSafeInteger(decoded.id) && decoded.id > 0) {
      req.user = decoded;
    }
  }
  next();
}

/**
 * 仅女生可访问（管理员除外）
 */
function girlOnly(req, res, next) {
  if (req.user.isAdmin) return next();
  if (req.user.role !== 'girl') {
    return res.status(403).json({ code: 403, message: '该功能仅女友可用' });
  }
  next();
}

/**
 * 仅男生可访问（管理员除外）
 */
function boyOnly(req, res, next) {
  if (req.user.isAdmin) return next();
  if (req.user.role !== 'boy') {
    return res.status(403).json({ code: 403, message: '该功能仅男友可用' });
  }
  next();
}

module.exports = { authRequired, authOptional, girlOnly, boyOnly };
