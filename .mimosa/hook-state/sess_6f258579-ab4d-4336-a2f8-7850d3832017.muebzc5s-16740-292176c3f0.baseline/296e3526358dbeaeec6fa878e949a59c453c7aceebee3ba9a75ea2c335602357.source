const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');

router.get('/', authRequired, (_req, res) => {
  res.json({
    code: 200,
    data: {
      enabled: false,
      status: 'idle',
      message: '同步中心待接入',
    },
  });
});

module.exports = router;
