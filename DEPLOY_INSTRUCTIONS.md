# LoveGirl 后端部署指南

## 方案一：SSH 一键部署（推荐）

### 步骤 1：上传补丁脚本到服务器

```bash
# 在本地执行（Windows PowerShell / Git Bash）
scp server_fixes/PATCH_SERVER.sh root@47.121.119.191:/root/
```

### 步骤 2：SSH 登录服务器并执行

```bash
ssh root@47.121.119.191

# 执行补丁脚本
bash /root/PATCH_SERVER.sh
```

脚本会自动：
- ✅ 备份原有文件
- ✅ 修复 app.js（CORS + 404）
- ✅ 修复 deploy_api.js（移除硬编码token）
- ✅ 修复 weather.js（UTF-8编码）
- ✅ 修复 version.js（添加认证）
- ✅ 修复 feeding.js（is_mine逻辑）
- ✅ 创建 .env 文件（含随机 DEPLOY_TOKEN）
- ✅ 安装 dotenv 依赖
- ✅ 重启服务

### 步骤 3：验证

```bash
# 在服务器上
curl http://localhost:3001/api/health

# 在本地测试天气编码
curl -s "http://47.121.119.191:3001/api/weather?city=深圳"
# 应该返回 "city":"深圳" 而不是乱码
```

### 步骤 4：获取新的 DEPLOY_TOKEN

```bash
# 在服务器上查看
cat /root/lovegirl-server/.env | grep DEPLOY_TOKEN
```

### 步骤 5：本地配置 token（用于发布APK）

```bash
# Windows CMD
set DEPLOY_TOKEN=服务器上显示的token值

# Windows PowerShell
$env:DEPLOY_TOKEN="服务器上显示的token值"

# 然后正常发布
python publish.py
```

---

## 方案二：手动逐个修复

如果你不想用脚本，可以手动操作：

### 1. 上传修改后的文件

```bash
# 上传所有 server_fixes 文件到服务器
scp server_fixes/app.js root@47.121.119.191:/root/lovegirl-server/
scp server_fixes/deploy_api.js root@47.121.119.191:/root/lovegirl-server/routes/
scp server_fixes/weather.js root@47.121.119.191:/root/lovegirl-server/routes/
scp server_fixes/version.js root@47.121.119.191:/root/lovegirl-server/routes/
scp server_fixes/feeding.js root@47.121.119.191:/root/lovegirl-server/routes/
scp server_fixes/fix_changelog.js root@47.121.119.191:/root/lovegirl-server/
```

### 2. 在服务器上创建 .env

```bash
ssh root@47.121.119.191
cd /root/lovegirl-server

# 生成随机 token
TOKEN=$(openssl rand -hex 16)
echo "生成的 DEPLOY_TOKEN: $TOKEN"

# 创建 .env
cat > .env << EOF
DB_HOST=localhost
DB_USER=lovegirl
DB_PASS=LoveGirl@2024
DB_NAME=love_girl
PORT=3001
NODE_ENV=production
DEPLOY_TOKEN=$TOKEN
GAODE_API_KEY=你的高德API密钥
CORS_ORIGINS=http://47.121.119.191:3001
EOF

# 安装 dotenv
npm install dotenv --save

# 重启
pm2 restart all
```

### 3. 本地配置 token

```bash
# Windows
set DEPLOY_TOKEN=上面生成的token
python publish.py
```

---

## ⚠️ 安全提醒

1. **DEPLOY_TOKEN 必须修改** — 旧值 `lovegirl-deploy-2024` 已在源码中暴露
2. **数据库密码建议修改** — `LoveGirl@2024` 也在源码中出现过
3. **建议配置 HTTPS** — 当前使用 HTTP 明文传输，JWT token 可被截获

## 修改后验证清单

- [ ] `curl http://localhost:3001/api/health` 返回 200
- [ ] `curl "http://47.121.119.191:3001/api/weather?city=深圳"` 城市名不乱码
- [ ] `curl http://47.121.119.191:3001/api/version/latest` 返回 401（需认证）
- [ ] `python publish.py` 能正常发布（需先设置 DEPLOY_TOKEN 环境变量）
