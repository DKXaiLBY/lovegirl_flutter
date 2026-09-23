const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');

router.get('/', authRequired, (_req, res) => {
  res.json({
    code: 200,
    data: {},
    meta: {
      enabled: false,
      message: '别名映射待接入',
    },
  });
});

module.exports = router;
