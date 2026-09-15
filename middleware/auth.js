const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || process.env.APP_SECRET || 'lovegirl-dev-jwt-secret';

function extractBearerToken(header) {
  if (!header || typeof header !== 'string') return null;
  const [scheme, token] = header.split(' ');
  if (!scheme || !token || scheme.toLowerCase() !== 'bearer') return null;
  return token.trim();
}

function authRequired(req, res, next) {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    return res.status(401).json({ code: 401, message: '未登录或登录已过期' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = {
      id: decoded.id || decoded.userId,
      username: decoded.username,
      role: decoded.role,
      isAdmin: decoded.isAdmin || decoded.is_admin || decoded.role === 'admin',
    };

    if (!req.user.id) {
      return res.status(401).json({ code: 401, message: '登录信息无效' });
    }

    next();
  } catch (error) {
    return res.status(401).json({ code: 401, message: '登录已过期，请重新登录' });
  }
}

module.exports = {
  authRequired,
};
