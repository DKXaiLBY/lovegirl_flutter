const { authRequired } = require('../middleware/auth');

function retiredFeature(req, res) {
  return res.status(410).json({
    code: 410,
    message: '该功能已停用，历史记录已保留',
    data: { retired: true },
  });
}

module.exports = function mountRetiredFeatures(app) {
  for (const prefix of ['/api/beans', '/api/achievements', '/api/letter', '/api/voucher']) {
    app.use(prefix, authRequired, retiredFeature);
  }
  // /api/daily and /quote belong to the separate, retained quotation API.
  app.use(['/api/daily/today', '/api/daily/answer', '/api/daily/history'],
    authRequired, retiredFeature);
};
