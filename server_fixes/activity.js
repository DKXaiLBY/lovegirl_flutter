const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');

router.get('/', authRequired, (_req, res) => {
  res.json({
    code: 200,
    data: [],
    meta: {
      enabled: false,
      message: '活动流待接入',
    },
  });
});

module.exports = router;
