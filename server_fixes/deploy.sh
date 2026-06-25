#!/bin/bash
# ==============================================================
# LoveGirl 服务器一键部署脚本
# 部署内容:
#   1. app.js    — 加固版（helmet / rate-limit / morgan / CORS）
#   2. feeding.js — 投喂站路由（分类/商品/订单/统计 + 默认数据回退）
#   3. search.js  — 全站搜索路由（8模块并行搜索）
#   4. photo.js   — 相册路由（上传/查看/删除，multer文件处理）
#   5. 数据库建表 — feeding_categories / feeding_products / feeding_orders / photos
#   6. NPM依赖   — helmet / morgan / express-rate-limit / multer
# ==============================================================

SERVER="root@47.121.119.191"
CONTAINER="lovegirl-server"
MYSQL_CONTAINER="lovegirl-mysql"
DB_NAME="love_girl"

echo "╔══════════════════════════════════════╗"
echo "║   LoveGirl Server Deploy v2.0       ║"
echo "╚══════════════════════════════════════╝"

# ===== Step 1: Upload files =====
echo ""
echo ">>> Step 1/6: 上传文件到服务器..."
scp app.js ${SERVER}:/tmp/app_new.js || { echo "❌ app.js 上传失败"; exit 1; }
scp feeding.js ${SERVER}:/tmp/feeding_new.js || { echo "❌ feeding.js 上传失败"; exit 1; }
scp search.js ${SERVER}:/tmp/search_new.js || { echo "❌ search.js 上传失败"; exit 1; }
scp photo.js ${SERVER}:/tmp/photo_new.js || { echo "❌ photo.js 上传失败"; exit 1; }
echo "✅ 文件上传完成"

# ===== Step 2-6: Deploy on server =====
ssh ${SERVER} << 'ENDSSH'
set -e

CONTAINER="lovegirl-server"
MYSQL_CONTAINER="lovegirl-mysql"
DB_NAME="love_girl"

echo ""
echo ">>> Step 2/6: 安装 NPM 依赖..."
docker exec ${CONTAINER} npm install helmet morgan express-rate-limit multer --save 2>&1 | tail -3
echo "✅ 依赖安装完成"

echo ""
echo ">>> Step 3/6: 部署路由文件到容器..."
docker cp /tmp/app_new.js ${CONTAINER}:/app/app.js
docker cp /tmp/feeding_new.js ${CONTAINER}:/app/routes/feeding.js
docker cp /tmp/search_new.js ${CONTAINER}:/app/routes/search.js
docker cp /tmp/photo_new.js ${CONTAINER}:/app/routes/photo.js
# 创建上传目录
docker exec ${CONTAINER} mkdir -p /app/uploads/photos
echo "✅ 文件部署完成"

echo ""
echo ">>> Step 4/6: 初始化数据库表..."
docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
CREATE TABLE IF NOT EXISTS feeding_categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  icon VARCHAR(10) DEFAULT '🎁',
  sort_order INT DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null && echo "  ✅ feeding_categories"

docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
CREATE TABLE IF NOT EXISTS feeding_products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  category_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  price INT NOT NULL DEFAULT 10,
  image VARCHAR(255),
  is_active TINYINT(1) DEFAULT 1,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES feeding_categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null && echo "  ✅ feeding_products"

docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
CREATE TABLE IF NOT EXISTS app_versions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  version_code INT NOT NULL,
  version_name VARCHAR(20) NOT NULL,
  apk_url VARCHAR(500) DEFAULT '',
  changelog TEXT,
  file_size VARCHAR(20) DEFAULT '未知',
  force_update TINYINT(1) DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_version_code (version_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null && echo "  ✅ app_versions"

# 插入当前版本记录（旧用户收到更新提醒）
docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
INSERT IGNORE INTO app_versions (version_code, version_name, apk_url, changelog, file_size, force_update, is_active)
VALUES (112, '3.13.0', '', '✨ 新增投喂站\n🔍 全站搜索\n🔄 版本更新检测\n📸 相册上传\n🗺 地图无边全景\n🔧 开发者模式\n🛡 服务器安全加固', '24MB', 0, 1);
" 2>/dev/null && echo "  ✅ 版本记录已插入"

docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
CREATE TABLE IF NOT EXISTS feeding_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT DEFAULT NULL,
  product_id INT NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  product_price INT NOT NULL DEFAULT 0,
  quantity INT NOT NULL DEFAULT 1,
  message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id),
  FOREIGN KEY (product_id) REFERENCES feeding_products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null && echo "  ✅ feeding_orders"

docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
CREATE TABLE IF NOT EXISTS photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500) DEFAULT '',
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" 2>/dev/null && echo "  ✅ photos"

# 插入默认数据（仅当表为空时）
CAT_COUNT=$(docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -sN -e "SELECT COUNT(*) FROM feeding_categories" 2>/dev/null || echo "0")
if [ "$CAT_COUNT" = "0" ]; then
  echo "  📦 插入默认分类和商品数据..."
  docker exec ${MYSQL_CONTAINER} mysql -u lovegirl -pLoveGirl@2024 ${DB_NAME} -e "
    INSERT INTO feeding_categories (name, icon, sort_order) VALUES
    ('甜品', '🍰', 1), ('饮品', '🧋', 2), ('鲜花', '🌹', 3), ('零食', '🍿', 4), ('礼物', '🎀', 5);

    -- 甜品 (category_id=1)
    INSERT INTO feeding_products (category_id, name, description, price) VALUES
    (1, '草莓蛋糕', '新鲜草莓配上奶油蛋糕', 20),
    (1, '巧克力慕斯', '浓郁巧克力，入口即化', 25),
    (1, '马卡龙礼盒', '6枚精致法式马卡龙', 30),
    (1, '冰淇淋球', '双球哈根达斯', 15),
    (1, '甜甜圈', '彩色糖霜甜甜圈', 12),
    (1, '提拉米苏', '经典意式提拉米苏', 28);

    -- 饮品 (category_id=2)
    INSERT INTO feeding_products (category_id, name, description, price) VALUES
    (2, '珍珠奶茶', 'Q弹珍珠，甜蜜满分', 15),
    (2, '拿铁咖啡', '香浓拿铁，温暖TA的心', 18),
    (2, '水果茶', '满满维C，清爽一夏', 16),
    (2, '热可可', '冬日里的温暖拥抱', 14),
    (2, '星冰乐', '冰爽甜蜜，快乐加倍', 22),
    (2, '蜂蜜柚子茶', '养生又甜蜜', 12);

    -- 鲜花 (category_id=3)
    INSERT INTO feeding_products (category_id, name, description, price) VALUES
    (3, '红玫瑰花束', '99朵代表长长久久', 99),
    (3, '粉色康乃馨', '温馨浪漫，表达爱意', 50),
    (3, '向日葵', '你是我的太阳', 30),
    (3, '满天星', '星星点点的浪漫', 35),
    (3, '郁金香', '优雅的爱', 45),
    (3, '薰衣草', '等待爱情', 28);

    -- 零食 (category_id=4)
    INSERT INTO feeding_products (category_id, name, description, price) VALUES
    (4, '薯片大礼包', '追剧必备零食', 20),
    (4, '坚果混合装', '健康美味每一天', 25),
    (4, '巧克力棒', '能量满满的甜蜜', 10),
    (4, '果冻布丁', 'Q弹爽滑的甜蜜', 15),
    (4, '牛肉干', '咸香可口的零食', 28),
    (4, '小熊饼干', '可爱又美味', 12);

    -- 礼物 (category_id=5)
    INSERT INTO feeding_products (category_id, name, description, price) VALUES
    (5, '情侣手链', '刻上你们的名字', 88),
    (5, '泰迪熊', '软软的陪伴', 50),
    (5, '情侣戒指', '爱的承诺', 99),
    (5, '音乐盒', '播放你们的主题曲', 60),
    (5, '相册本', '珍藏美好回忆', 35),
    (5, '星空投影灯', '每晚一起看星星', 45);
  " 2>/dev/null
  echo "  ✅ 默认数据已插入"
else
  echo "  ⏭ 数据已存在，跳过插入"
fi
echo "✅ 数据库初始化完成"

echo ""
echo ">>> Step 5/6: 重启服务..."
docker restart ${CONTAINER}
echo "⏳ 等待服务启动..."
sleep 6

# 检查容器状态
STATUS=$(docker ps --format "{{.Status}}" -f name=${CONTAINER} | head -1)
echo "容器状态: ${STATUS}"

# 检查启动日志
echo ""
echo ">>> 启动日志 (最近5行):"
docker logs ${CONTAINER} --tail 5 2>&1

echo ""
echo ">>> Step 6/6: 验证 API..."
echo ""

# Health
echo -n "  Health: "
curl -s http://localhost:3000/api/health | head -c 60
echo ""

# Feeding
echo -n "  Feeding categories: "
curl -s http://localhost:3000/api/feeding/categories | head -c 80
echo ""

# Search
echo -n "  Search: "
curl -s "http://localhost:3000/api/search?keyword=test" | head -c 80
echo ""

ENDSSH

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   ✅ 部署完成!                       ║"
echo "║   服务器: http://47.121.119.191:3001  ║"
echo "╚══════════════════════════════════════╝"
