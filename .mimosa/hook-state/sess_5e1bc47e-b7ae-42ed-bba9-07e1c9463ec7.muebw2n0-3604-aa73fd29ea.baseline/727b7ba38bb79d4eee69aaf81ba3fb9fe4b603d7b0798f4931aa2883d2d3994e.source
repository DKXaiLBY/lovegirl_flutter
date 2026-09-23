const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');

router.get('/', authRequired, (_req, res) => {
  res.json({
    code: 200,
    data: {
      quote: '今天也要把喜欢和照顾都落到日常里。',
      source: 'LoveGirl',
    },
    meta: {
      enabled: false,
      message: '每日卡片待扩展',
    },
  });
});

module.exports = router;
