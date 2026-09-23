/**
 * 修复版本更新日志编码问题
 * 运行方式: DB_HOST=localhost DB_USER=lovegirl DB_PASS=xxx DB_NAME=love_girl node fix_changelog.js
 */
const mysql = require('mysql2/promise');
require('dotenv').config();

async function fixChangelog() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'lovegirl',
    password: process.env.DB_PASS || '',
    database: process.env.DB_NAME || 'love_girl',
    charset: 'utf8mb4'
  });

  const changelog = `🆕 倒计时 — 记录重要的日子，支持12种图标
✅ 愿望清单 — 情侣共同愿望，5个分类+进度统计
🌤 天气小组件 — 首页实时天气显示
🔧 缓存大小真实计算
💾 推送设置持久化存储
⬇️ 所有列表页支持下拉刷新
🎨 通用空状态组件
🐛 Gradle兼容性修复
📲 更新弹窗优化 — 直接下载安装，不再跳转浏览器`;

  await pool.query(
    'UPDATE app_versions SET changelog = ? WHERE version_code = 114',
    [changelog]
  );

  console.log('✅ 更新日志已修复!');
  await pool.end();
}

fixChangelog().catch(console.error);
