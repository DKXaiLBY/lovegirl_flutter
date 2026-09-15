# LoveGirl 后端部署清单

> **目标服务器**: `47.121.119.191`  
> **远程项目路径**: `/opt/love-girl/love-girl-server`  
> **数据库**: MySQL (love_girl)  
> **生成日期**: 2026-07-07

---

## 一、部署概览

| 类别 | 数量 | 说明 |
|------|------|------|
| SQL 迁移脚本 | 6 | 含完整迁移 + 增量补丁 + 种子数据 |
| Node.js 路由文件 | 24 | 含主入口 app.js |
| 工具函数 | 1 | `utils/lovegirl_rewards.js`（奖励系统核心） |
| 配置文件 | 2 | `.env` / `.env.example` |
| 一次性脚本 | 3 | 维护修复 + 一键部署 |

---

## 二、第一阶段：数据库 SQL 迁移（必须先执行）

> ⚠️ SQL 迁移必须在部署新路由之前完成，否则 API 可能报 `ER_NO_SUCH_TABLE`。

### 部署顺序（按依赖关系）

| 序号 | 文件 | 用途 | 执行命令 |
|------|------|------|----------|
| **1** | `couple_table.sql` | 创建伴侣绑定表 `couples` + 邀请码表 `couple_invites`，含外键关联 `users` 表 | `mysql -u lovegirl -p love_girl < couple_table.sql` |
| **2** | `version_table.sql` | 创建版本管理表 `app_versions`，插入 v3.13.0(build112) 和 v3.14.0(build113) 种子数据 | `mysql -u lovegirl -p love_girl < version_table.sql` |
| **3** | `lovegirl_full_migration.sql` | **核心全量迁移**：创建 `feeding_shops`/`feeding_products`/`feeding_orders`/`achievements`/`bean_transactions`/`love_timeline`/`user_privacy` 等全部表，自动补列，统一 utf8mb4 字符集 | `mysql -u lovegirl -p love_girl < lovegirl_full_migration.sql` |
| **4** | `feeding_note_field.sql` | 为 `feeding_orders` 表添加 `note`（履约备注）字段 | `mysql -u lovegirl -p love_girl < feeding_note_field.sql` |
| **5** | `travel_amap_patch.sql` | 为 `travel_routes` 表添加 `mode`/`distance`/`duration`/`path_json` 四个高德导航字段 | `mysql -u lovegirl -p love_girl < travel_amap_patch.sql` |
| **6** | `travel_photos_table.sql` | 创建 `travel_photos` 表，并为 `travel_spots` 表添加 `weather`/`reason`/`planned_date`/`itinerary`/`budget` 五个字段 | `mysql -u lovegirl -p love_girl < travel_photos_table.sql` |

**一键执行（SSH 到服务器后）**：
```bash
cd /opt/love-girl/love-girl-server
for f in couple_table.sql version_table.sql lovegirl_full_migration.sql feeding_note_field.sql travel_amap_patch.sql travel_photos_table.sql; do
  echo "=== Executing $f ==="
  mysql -u lovegirl -p love_girl < $f
done
```

---

## 三、第二阶段：Node.js 路由 & 工具部署

### 3.1 主入口文件

| 文件 | 用途 | 部署路径 |
|------|------|----------|
| `app.js` | Express 主入口：安全加固（Helmet/CORS/RateLimit/压缩/日志）、注册所有路由模块 | `<远程>/app.js` |

> app.js 是**核心文件**，引入了 Helmet（安全头）、CORS、express-rate-limit（限流）、compression（压缩）、morgan（请求日志）。部署后需更新。

### 3.2 路由文件（按模块分组）

| 模块 | 文件 | 用途 | 部署路径 |
|------|------|------|----------|
| **投喂站** | `feeding.js` | 投喂站 v1 路由：商品浏览、下单 | `<远程>/routes/feeding.js` |
| | `feeding_v2.js` | 投喂站 v2（当前主力）：店铺体系、订单管理、履约备注、爱心豆奖励联动 | `<远程>/routes/feeding_v2.js` |
| **伴侣** | `couple.js` | 伴侣绑定系统：生成/使用邀请码、绑定/解绑、查询伴侣关系 | `<远程>/routes/couple.js` |
| **版本** | `version.js` | 版本更新检测 API：`/api/version/check` | `<远程>/routes/version.js` |
| **旅行** | `travel.js` | 旅行模块（最大文件 37KB）：CRUD 景点、高德地图 POI/地理编码/路线规划、天气集成 | `<远程>/routes/travel.js` |
| | `travel_photos.js` | 旅行地点照片：上传/查看/删除，伴侣可见共享 | `<远程>/routes/travel_photos.js` |
| **相册** | `photo.js` | 相册路由：上传/查看/删除照片，磁盘存储 | `<远程>/routes/photo.js` |
| **课程表** | `course.js` | 课程表管理：CRUD + Excel 批量导入 | `<远程>/routes/course.js` |
| **姨妈助手** | `period.js` | 经期管理（加密存储）：记录周期、痛经独立记录、flowData 解析 | `<远程>/routes/period.js` |
| **记账** | `finance.js` | 记账路由（金额加密）：增删改查、月度统计、隐私控制、发票图片上传 | `<远程>/routes/finance.js` |
| **首页** | `home.js` | 首页聚合：汇总天气/心情/待办/记账/纪念日/旅行 等多模块概览数据 | `<远程>/routes/home.js` |
| **心情** | `mood.js` | 心情日记：记录/查询/统计，支持10种心情标签，爱心豆奖励 | `<远程>/routes/mood.js` |
| **时光轴** | `timeline.js` | 恋爱时光轴：记录纪念事件，计算距今天数 | `<远程>/routes/timeline.js` |
| **待办** | `todo.js` | 待办事项：CRUD + 重复提醒（每日/每周/每月），完成奖励爱心豆 | `<远程>/routes/todo.js` |
| **成就** | `achievements.js` | 成就系统：查询成就列表、进度追踪、自动检测解锁 | `<远程>/routes/achievements.js` |
| **纪念日** | `anniversary.js` | 纪念日模块：恋爱周年/生日/自定义，计算倒计时、每年重复 | `<远程>/routes/anniversary.js` |
| **爱心豆** | `beans.js` | 爱心豆系统：余额查询、交易记录分页、每日签到（含连续签到） | `<远程>/routes/beans.js` |
| **隐私** | `privacy.js` | 隐私设置：相册/心情/行程/聊天的可见性开关 | `<远程>/routes/privacy.js` |
| **通知** | `notifications.js` | 通知系统：获取用户通知列表（降级兼容无表场景） | `<远程>/routes/notifications.js` |
| **天气** | `weather.js` | 天气查询：按城市名或经纬度获取实时天气，修复默认广州定位问题 | `<远程>/routes/weather.js` |
| **管理后台** | `admin.js` | 管理后台：店铺 CRUD、权限校验（admin only） | `<远程>/routes/admin.js` |
| | `admin_products.js` | 管理后台商品管理：商品 CRUD、排序、上下架 | `<远程>/routes/admin_products.js` |
| **发布** | `deploy_api.js` | APK 自动发布 API：上传 APK 或从 URL 拉取、版本状态查询（需 DEPLOY_TOKEN） | `<远程>/routes/deploy_api.js` |

### 3.3 工具函数

| 文件 | 用途 | 部署路径 |
|------|------|----------|
| `utils/lovegirl_rewards.js` | **奖励系统核心**（400行）：`addBeanTransaction`/`createFinanceRecord`/`createTimelineEvent`/`checkAchievements`/`getCheckinStreak`/`ensureAchievementsSeeded` 等，被 feeding_v2/travel/period/mood/todo/home/achievements/anniversary/beans 等多个模块引用 | `<远程>/routes/utils/lovegirl_rewards.js` |

> ⚠️ lovegirl_rewards.js 的引用路径是 `require('./utils/lovegirl_rewards')`（相对 routes 目录），部署到 `routes/utils/` 下。

### 3.4 配置文件

| 文件 | 用途 | 部署路径 |
|------|------|----------|
| `.env` | 环境变量：数据库连接、端口、AMAP 高德 Key、DEPLOY_TOKEN、CORS Origins | `<远程>/.env` |
| `.env.example` | 环境变量模板（不含敏感值），供新开发者参考 | `<远程>/.env.example` |

> ⚠️ `.env` 包含高德 API Key，需确认服务器上 `.env` 中 `DB_PASS` 和 `DEPLOY_TOKEN` 已填入真实值后再覆盖。

---

## 四、一次性脚本（按需执行）

| 文件 | 用途 | 何时执行 |
|------|------|----------|
| `fix_changelog.js` | 修复 `app_versions` 表中 build 114 的更新日志编码 | 如果 changelog 中文乱码时执行：`DB_HOST=localhost DB_USER=lovegirl DB_PASS=xxx DB_NAME=love_girl node fix_changelog.js` |
| `fix_version_api.js` | 为 `version.js` 新增 `PUT /api/version/fix` 路由（管理员在线修复版本记录） | 将代码片段合并到 `version.js` 中即可，无需单独部署 |
| `deploy_travel_photos.sh` | 旅行照片功能一键部署脚本（SCP 上传 + SQL 迁移 + PM2 重载） | 历史部署脚本，参考用途，新部署按本清单手动操作 |

---

## 五、部署命令建议

### 5.1 上传文件到服务器

```bash
SERVER="root@47.121.119.191"
REMOTE_DIR="/opt/love-girl/love-girl-server"

# 上传主入口
scp app.js ${SERVER}:${REMOTE_DIR}/

# 上传所有路由文件
scp feeding.js feeding_v2.js couple.js version.js travel.js travel_photos.js photo.js course.js period.js finance.js home.js mood.js timeline.js todo.js achievements.js anniversary.js beans.js privacy.js notifications.js weather.js admin.js admin_products.js deploy_api.js ${SERVER}:${REMOTE_DIR}/routes/

# 上传工具函数
scp utils/lovegirl_rewards.js ${SERVER}:${REMOTE_DIR}/routes/utils/

# 上传 SQL 脚本
scp couple_table.sql version_table.sql lovegirl_full_migration.sql feeding_note_field.sql travel_amap_patch.sql travel_photos_table.sql ${SERVER}:${REMOTE_DIR}/

# 上传配置文件（注意备份）
scp .env ${SERVER}:${REMOTE_DIR}/.env.new
scp .env.example ${SERVER}:${REMOTE_DIR}/
```

### 5.2 服务器端执行

```bash
# SSH 登录
ssh root@47.121.119.191
cd /opt/love-girl/love-girl-server

# ---- 第一步：备份 ----
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# ---- 第二步：数据库迁移 ----
mysql -u lovegirl -p love_girl < couple_table.sql
mysql -u lovegirl -p love_girl < version_table.sql
mysql -u lovegirl -p love_girl < lovegirl_full_migration.sql
mysql -u lovegirl -p love_girl < feeding_note_field.sql
mysql -u lovegirl -p love_girl < travel_amap_patch.sql
mysql -u lovegirl -p love_girl < travel_photos_table.sql

# ---- 第三步：更新配置文件 ----
# 对照 .env.new 和 .env.backup，合并配置后覆盖
diff .env.new .env.backup.*
# 确认无误后
mv .env.new .env

# ---- 第四步：安装新增依赖（如果有） ----
npm install

# ---- 第五步：重启服务 ----
pm2 reload love-girl-server     # 或 pm2 restart love-girl-server
pm2 status                       # 确认 online
pm2 logs love-girl-server --lines 20  # 检查日志无报错
```

### 5.3 验证清单

| 验证项 | 方法 |
|--------|------|
| PM2 服务 online | `pm2 status` |
| API 健康检查 | `curl http://localhost:3001/` |
| 伴侣绑定 | `curl http://47.121.119.191:3001/api/couple -H "Authorization: Bearer <token>"` |
| 版本检查 | `curl http://47.121.119.191:3001/api/version/check?version_code=0` |
| 投喂站 | `curl http://47.121.119.191:3001/api/feeding/shops -H "Authorization: Bearer <token>"` |
| 首页聚合 | `curl http://47.121.119.191:3001/api/home -H "Authorization: Bearer <token>"` |
| 成就系统 | `curl http://47.121.119.191:3001/api/achievements -H "Authorization: Bearer <token>"` |
| 旅行模块 | `curl http://47.121.119.191:3001/api/travel -H "Authorization: Bearer <token>"` |
| 天气 | `curl "http://47.121.119.191:3001/api/weather?city=深圳"` |

---

## 六、文件清单（36个文件总览）

| # | 文件名 | 类型 | 大小 | 最后修改 |
|---|--------|------|------|----------|
| 1 | `couple_table.sql` | SQL 迁移 | 952 B | 2026-06-26 |
| 2 | `version_table.sql` | SQL 迁移 | 2 KB | 2026-06-23 |
| 3 | `lovegirl_full_migration.sql` | SQL 迁移 | 18 KB | 2026-07-03 |
| 4 | `feeding_note_field.sql` | SQL 迁移 | 226 B | 2026-07-07 |
| 5 | `travel_amap_patch.sql` | SQL 迁移 | 987 B | 2026-07-02 |
| 6 | `travel_photos_table.sql` | SQL 迁移 | 1.7 KB | 2026-07-02 |
| 7 | `app.js` | 主入口 | 5.8 KB | 2026-07-03 |
| 8 | `feeding.js` | 路由 v1 | 14 KB | 2026-06-26 |
| 9 | `feeding_v2.js` | 路由 v2 | 30 KB | 2026-07-07 |
| 10 | `couple.js` | 路由 | 8.1 KB | 2026-06-27 |
| 11 | `version.js` | 路由 | 1.6 KB | 2026-06-26 |
| 12 | `travel.js` | 路由 | 36 KB | 2026-07-03 |
| 13 | `travel_photos.js` | 路由 | 5.7 KB | 2026-07-02 |
| 14 | `photo.js` | 路由 | 3.6 KB | 2026-06-23 |
| 15 | `course.js` | 路由 | 12 KB | 2026-07-03 |
| 16 | `period.js` | 路由 | 19 KB | 2026-07-03 |
| 17 | `finance.js` | 路由 | 13 KB | 2026-07-03 |
| 18 | `home.js` | 路由 | 6.5 KB | 2026-07-07 |
| 19 | `mood.js` | 路由 | 6.8 KB | 2026-07-03 |
| 20 | `timeline.js` | 路由 | 4.7 KB | 2026-07-03 |
| 21 | `todo.js` | 路由 | 8.2 KB | 2026-07-03 |
| 22 | `achievements.js` | 路由 | 3.2 KB | 2026-07-03 |
| 23 | `anniversary.js` | 路由 | 4.7 KB | 2026-07-03 |
| 24 | `beans.js` | 路由 | 4 KB | 2026-07-03 |
| 25 | `privacy.js` | 路由 | 4 KB | 2026-06-26 |
| 26 | `notifications.js` | 路由 | 1.4 KB | 2026-07-02 |
| 27 | `weather.js` | 路由 | 5.4 KB | 2026-07-02 |
| 28 | `admin.js` | 路由 | 8.1 KB | 2026-07-03 |
| 29 | `admin_products.js` | 路由 | 7.7 KB | 2026-07-03 |
| 30 | `deploy_api.js` | 路由 | 4.4 KB | 2026-06-26 |
| 31 | `utils/lovegirl_rewards.js` | 工具函数 | 13 KB | 2026-07-07 |
| 32 | `.env` | 配置 | 487 B | 2026-07-02 |
| 33 | `.env.example` | 配置模板 | 607 B | 2026-07-02 |
| 34 | `fix_changelog.js` | 维护脚本 | 1.1 KB | 2026-06-26 |
| 35 | `fix_version_api.js` | 维护脚本 | 1.1 KB | 2026-06-24 |
| 36 | `deploy_travel_photos.sh` | 部署脚本 | 2 KB | 2026-06-27 |
