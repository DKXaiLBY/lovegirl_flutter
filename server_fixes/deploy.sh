#!/bin/bash
# LoveGirl 服务器修复部署脚本
# 修复内容：
#   1. weather.js — 去掉广州硬编码默认值，坐标反查失败时返回错误而非广州
#   2. privacy.js — 新增隐私设置API（相册/心情/行程/聊天可见性）
#   3. user_privacy数据表初始化
#   4. app.js — 注册privacy路由

SERVER="root@47.121.119.191"

echo "=== 1. 上传修复文件 ==="
scp weather.js ${SERVER}:/tmp/weather_new.js
scp privacy.js ${SERVER}:/tmp/privacy_new.js

echo "=== 2. 部署文件到容器 ==="
ssh ${SERVER} << 'ENDSSH'
# 部署weather.js
docker cp /tmp/weather_new.js lovegirl-server:/app/routes/weather.js
echo "weather.js deployed"

# 部署privacy.js
docker cp /tmp/privacy_new.js lovegirl-server:/app/routes/privacy.js
echo "privacy.js deployed"

# 3. 创建隐私设置数据库表（如果不存在）
docker exec lovegirl-mysql mysql -u lovegirl -pLoveGirl@2024 love_girl -e "
CREATE TABLE IF NOT EXISTS user_privacy (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  photo_visible TINYINT(1) DEFAULT 1,
  mood_visible TINYINT(1) DEFAULT 1,
  travel_visible TINYINT(1) DEFAULT 1,
  chat_visible TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null
echo "user_privacy table checked"

# 4. 注册privacy路由到app.js（如果尚未注册）
docker exec lovegirl-server grep -q "routes/privacy" /app/app.js 2>/dev/null
if [ $? -ne 0 ]; then
  docker exec lovegirl-server sed -i "/require.*routes\/user/i app.use('/api/privacy', require('./routes/privacy'));" /app/app.js
  echo "privacy route registered in app.js"
else
  echo "privacy route already registered"
fi

# 5. 重启服务
docker restart lovegirl-server
echo "Server restarting..."

sleep 5
echo "=== 部署完成 ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep lovegirl
ENDSSH

echo ""
echo "=== 验证 ==="
sleep 3
echo -n "Weather API: "
curl -s "http://47.121.119.191:3001/api/weather?city=惠州" | head -c 100
echo ""
echo -n "Privacy API: "
curl -s "http://47.121.119.191:3001/api/privacy" | head -c 100
echo ""
echo "Done!"
