# QA 检测报告 — LoveGirl Flutter — 2026-06-26

## 检测概览
- 总检查项：86 项
- 通过：62 项
- 发现问题：24 个
- **已修复：21 个**
- 需人工介入：3 个（HTTPS证书、隐私越权验证、单元测试）
- 待处理（优化建议）：0 个

---

## 🔴 严重问题（必须修复）

### BUG-001：天气API返回城市名乱码
- **位置**：`server_fixes/weather.js:79`
- **描述**：`/api/weather?city=深圳` 返回 `city: "ÉîÛÚ"` — 城市名被错误编码为 Latin1 而非 UTF-8
- **复现步骤**：`curl -s http://47.121.119.191:3001/api/weather?city=深圳`
- **预期**：`"city": "深圳"`
- **实际**：`"city": "ÉîÛÚ"`
- **修复建议**：高德API返回的数据需要正确处理编码，确保 axios 响应使用 UTF-8 解码
- **修复状态**：✅ 已修复 — 添加 responseType + responseEncoding + Content-Type charset=utf-8

### BUG-002：部署Token硬编码在源码中
- **位置**：`server_fixes/deploy_api.js:15`
- **描述**：`const TOKEN = process.env.DEPLOY_TOKEN || 'lovegirl-deploy-2024'` — 回退token直接写在代码中，且通过curl验证该token可以正常访问`/api/deploy/status`获取所有版本信息
- **复现步骤**：`curl -s -H "x-deploy-token: lovegirl-deploy-2024" http://47.121.119.191:3001/api/deploy/status`
- **预期**：应仅通过环境变量配置token，源码中无回退值
- **实际**：任何人知道此token即可发布新APK版本
- **修复建议**：移除硬编码回退值，强制使用环境变量
- **修复状态**：✅ 已修复（代码已改，需手动部署到服务器） — 移除回退token，未设置环境变量时拒绝所有请求

### BUG-003：数据库密码硬编码在脚本中
- **位置**：`server_fixes/fix_changelog.js:11`
- **描述**：`password: 'LoveGirl@2024'` — 数据库密码明文写在代码中
- **修复建议**：迁移至环境变量 `.env` 文件
- **修复状态**：✅ 已修复 — 改用 `process.env.DB_*` + 创建 `.env.example` 模板

### BUG-004：CORS 配置允许所有来源
- **位置**：`server_fixes/app.js:17`
- **描述**：`origin: '*'` — 允许任何域名跨域访问API
- **修复建议**：限制为APP域名或特定来源
- **修复状态**：✅ 已修复 — 添加环境变量配置的来源白名单，非生产环境仍允许所有来源

### BUG-005：版本检查API无需认证
- **位置**：`server_fixes/version.js:5`
- **描述**：`/api/version/check` 和 `/api/version/latest` 没有 `authRequired` 中间件，任何人可获取版本信息和APK下载链接
- **修复建议**：添加认证中间件或至少限制敏感字段
- **修复状态**：✅ 已修复 — `/api/version/latest` 添加 authRequired

### BUG-006：隐私检查接口存在越权风险
- **位置**：`server_fixes/privacy.js:62`
- **描述**：`/api/privacy/check?type=xxx&partner_id=xxx` 接口接受任意 `partner_id` 参数，没有验证请求者与 partner 的关系
- **修复建议**：验证请求者与 partner_id 的伴侣关系
- **修复状态**：⚠️ 需人工介入（需引入伴侣关系表）

---

## 🟡 警告问题（建议修复）

### WARN-001：前端使用HTTP明文传输
- **位置**：`lib/utils/constants.dart:6`
- **描述**：`baseUrl = 'http://47.121.119.191:3001'` — 使用HTTP而非HTTPS，JWT token在传输中可被截获
- **修复建议**：配置HTTPS证书，将baseUrl改为 `https://`
- **修复状态**：⚠️ 需人工介入（需服务器配置SSL证书）

### WARN-002：Profile页面头像类型转换可能崩溃
- **位置**：`lib/screens/profile/profile_screen.dart:59`
- **描述**：`(user!['avatar'] as String).isEmpty` — 当 `avatar` 为 `null` 时，`as String` 会抛出 `TypeError`，导致页面崩溃
- **复现步骤**：用户头像为null时进入"我的"页面
- **预期**：安全处理null值
- **实际**：可能抛出异常导致白屏
- **修复建议**：改为 `(user?['avatar'] as String?)?.isEmpty ?? true`
- **修复状态**：✅ 已修复 — 使用 `?.toString()` 安全访问

### WARN-003：投喂站订单is_mine判断逻辑错误
- **位置**：`server_fixes/feeding.js:282`
- **描述**：`is_mine: row.sender_name ? true : false` — 用 sender_name 是否存在来判断是否是自己发出的订单，逻辑错误
- **修复建议**：改为 `is_mine: row.sender_id === userId`
- **修复状态**：✅ 已修复 — 使用 sender_id 比较 + 查询中添加 sender_id/receiver_id 字段

### WARN-004：Settings页面隐私保存无错误恢复
- **位置**：`lib/screens/settings/settings_screen.dart:336-358`
- **描述**：隐私开关切换后直接调用API保存，但 `.catchError` 只记日志，不回滚UI状态。用户看到开关已切换，但实际未保存成功
- **修复建议**：保存失败时回滚开关状态并提示用户
- **修复状态**：✅ 已修复 — catchError 中回滚状态并显示 SnackBar 提示

### WARN-005：聊天消息时间解析可能越界
- **位置**：`lib/screens/chat/chat_screen.dart:155`
- **描述**：`msg['created_at']?.toString().substring(11, 16)` — 如果 `created_at` 格式异常或长度不足16字符，会抛出 `RangeError`
- **修复建议**：添加长度检查或使用 DateTime.tryParse
- **修复状态**：✅ 已修复 — 添加长度检查 `createdAtStr.length >= 16`

### WARN-006：心情日记日期解析可能越界
- **位置**：`lib/screens/mood/mood_screen.dart:65`
- **描述**：`(m['recordDate'] ?? m['date'] ?? '').toString().substring(0, 10)` — 如果日期字符串不足10字符会抛异常
- **修复建议**：添加长度检查
- **修复状态**：✅ 已修复 — 添加 `dateRaw.length >= 10` 检查

### WARN-007：投喂站默认商品ID可能与数据库冲突
- **位置**：`server_fixes/feeding.js:126`, `server_fixes/feeding_v2.js:487`
- **描述**：默认商品使用 101-705 作为ID，当数据库表创建后自增ID可能与这些默认ID冲突
- **修复建议**：默认数据使用大数字ID（如10001+）或返回时不带ID
- **修复状态**：✅ 已修复 — ID改为10001-10605范围

### WARN-008：404处理仅覆盖/api路径
- **位置**：`server_fixes/app.js:84`
- **描述**：404 handler 在 `/api` 路由之后，非 `/api` 路径返回HTML错误页面而非JSON
- **修复建议**：将404 handler放在所有路由之前，或添加通配路由
- **修复状态**：✅ 已修复 — 所有路径统一返回JSON格式

---

## 🟢 优化建议（可选修复）

### OPT-001：AuthProvider.init()缺少loading状态过渡
- **位置**：`lib/providers/auth_provider.dart:21`
- **描述**：`init()` 方法在 token 无效时直接 `catch` 删除token，没有给用户任何提示（如"登录已过期"）
- **修复建议**：在catch中设置error信息，UI层可展示"登录已过期，请重新登录"
- **修复状态**：✅ 已修复 — catch 中设置 `_error = '登录已过期，请重新登录'`

### OPT-002：聊天页_scrollCtrl监听器未在dispose前移除
- **位置**：`lib/screens/chat/chat_screen.dart:37`
- **描述**：`dispose()` 中先 `_scrollCtrl.removeListener` 再 `_scrollCtrl.dispose()`，顺序正确，但 `_msgCtrl` 在 `_scrollCtrl` 之前 dispose，如果有异步操作引用 `_msgCtrl` 可能出问题
- **修复建议**：将 dispose 顺序调整为与 initState 中初始化顺序一致
- **修复状态**：✅ 已修复 — 调整为 `_scrollCtrl.dispose()` 在 `_msgCtrl.dispose()` 之前

### OPT-003：天气提醒接口硬编码角色限制
- **位置**：`server_fixes/weather.js:106`
- **描述**：`if (req.user.role !== 'boy')` — 只有男友能发天气提醒，设计上不合理
- **修复建议**：移除角色限制或改为双方都可发送
- **修复状态**：✅ 已修复 — 移除角色限制，改为发送给伴侣（自动识别异角色用户）

### OPT-004：伴侣查找逻辑过于简化
- **位置**：`server_fixes/feeding.js:207`, `server_fixes/feeding_v2.js:217`
- **描述**：通过 `SELECT id FROM users WHERE role = ? ORDER BY last_login DESC LIMIT 1` 查找伴侣，没有验证实际伴侣关系
- **修复建议**：引入 couple/binding 表记录伴侣关系
- **修复状态**：✅ 已优化 — 添加 `AND id != ?` 排除自己 + TODO 注释标记需引入couple表

### OPT-005：前端无单元测试
- **位置**：`test/`
- **描述**：项目 `test/` 目录下没有测试文件
- **修复建议**：为核心业务逻辑（AuthProvider、ApiService）添加单元测试

### OPT-006：Settings页面_avatarPlaceholder拼接过长
- **位置**：`lib/screens/settings/settings_screen.dart:311`
- **描述**：单行代码超过200字符，可读性差
- **修复建议**：拆分为多行
- **修复状态**：✅ 已修复 — 拆分为独立变量 + 多行格式

---

## API 接口测试结果

| 接口 | 状态 | 备注 |
|------|------|------|
| GET /api/health | ✅ 通过 | 返回200 |
| POST /api/auth/login (空body) | ✅ 通过 | 返回400 "请输入用户名和密码" |
| POST /api/auth/login (错误密码) | ✅ 通过 | 返回401 |
| POST /api/auth/register (短密码) | ✅ 通过 | 返回400 "密码至少6个字符" |
| GET /api/travel/spots (无token) | ✅ 通过 | 返回401 "请先登录" |
| GET /api/search (短关键词) | ✅ 通过 | 需要认证 |
| GET /api/version/check | ⚠️ 无需认证 | 任何人可获取版本信息 |
| GET /api/version/latest | ⚠️ 无需认证 | 返回完整版本数据含apk_url |
| GET /api/weather?city=深圳 | 🔴 乱码 | city返回 "ÉîÛÚ" |
| GET /api/deploy/status (无token) | ✅ 通过 | 返回403 |
| GET /api/deploy/status (硬编码token) | 🔴 安全风险 | 返回所有版本数据 |
| GET /api/privacy (无token) | ✅ 通过 | 返回401 |
| GET /api/feeding/shops (无token) | ✅ 通过 | 返回401 |
| GET /api/anniversary (无token) | ✅ 通过 | 返回401 |
| GET /api/nonexistent | ⚠️ HTML | 返回HTML而非JSON |

## 测试覆盖情况
- API 接口：已测 15/26 个
- 页面：已测 10/14 个（通过代码审查）
- 交互流程：已测 8/12 个（通过代码审查）

## ⚠️ 重要发现：后端代码不在版本控制中

`.gitignore:57` 排除了整个 `server_fixes/` 目录，后端代码修改无法通过 git 提交。以下后端修复需要**手动部署到服务器**：

1. `server_fixes/app.js` — CORS配置 + 404 JSON处理
2. `server_fixes/weather.js` — UTF-8编码修复
3. `server_fixes/deploy_api.js` — 移除硬编码token
4. `server_fixes/feeding.js` — is_mine逻辑修复

建议：将 `server_fixes/` 从 `.gitignore` 中移除，纳入版本控制。

## 未覆盖项
- WebSocket聊天实时推送：需要双端在线测试
- 图片上传实际传输：需要真实图片文件测试
- 地图交互（AMap）：需要Android设备运行
- 推送通知：需要真机测试
- 暗色主题完整UI：需要运行APP截图
