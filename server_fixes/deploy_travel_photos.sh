#!/bin/bash
# 旅行照片功能部署脚本
# 服务器: 47.121.119.191
# ⚠ 已废弃：本脚本基于旧路径(D:/lovegirl_flutter)与 pm2 部署方式，现网为 Docker，仅留档勿执行。

set -e

SERVER="root@47.121.119.191"
REMOTE_DIR="/opt/love-girl/love-girl-server"
# 令牌不落仓库：现取 `docker exec lovegirl-server sh -c 'echo $DEPLOY_TOKEN'`
DEPLOY_TOKEN="<REDACTED-见服务器容器环境变量>"

echo "=========================================="
echo "  旅行照片功能部署脚本"
echo "=========================================="

# 1. 上传文件
echo ""
echo "[1/4] 上传文件到服务器..."

# 上传 travel_photos.js
scp D:/lovegirl_flutter/server_fixes/travel_photos.js ${SERVER}:${REMOTE_DIR}/routes/
echo "  ✓ travel_photos.js"

# 上传 app.js（更新路由注册）
scp D:/lovegirl_flutter/server_fixes/app.js ${SERVER}:${REMOTE_DIR}/
echo "  ✓ app.js"

# 上传 SQL 文件
scp D:/lovegirl_flutter/server_fixes/travel_photos_table.sql ${SERVER}:${REMOTE_DIR}/
echo "  ✓ travel_photos_table.sql"

# 创建上传目录
echo ""
echo "[2/4] 创建上传目录..."
ssh ${SERVER} "mkdir -p ${REMOTE_DIR}/uploads/travel && chmod 755 ${REMOTE_DIR}/uploads/travel"
echo "  ✓ uploads/travel 目录已创建"

# 3. 执行SQL
echo ""
echo "[3/4] 执行数据库迁移..."
ssh ${SERVER} "cd ${REMOTE_DIR} && mysql -u lovegirl -p\$(grep DB_PASS .env | cut -d'=' -f2) love_girl < travel_photos_table.sql" 2>/dev/null || {
  echo "  ⚠ SQL 执行可能需要手动确认，请在服务器上执行："
  echo "    mysql -u lovegirl -p love_girl < travel_photos_table.sql"
}
echo "  ✓ 数据库迁移完成"

# 4. 重启服务
echo ""
echo "[4/4] 重启服务..."
ssh ${SERVER} "cd ${REMOTE_DIR} && pm2 restart tomato-server" 2>/dev/null || {
  echo "  ⚠ PM2 重启失败，请手动重启："
  echo "    pm2 restart tomato-server"
}
echo "  ✓ 服务已重启"

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "验证步骤："
echo "  1. 检查服务状态: ssh ${SERVER} 'pm2 status'"
echo "  2. 测试API: curl http://47.121.119.191:3001/api/health"
echo "  3. 测试照片上传: 使用APP上传旅行照片"
echo ""
