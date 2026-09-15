# LoveGirl P1 功能补全 + P2 收尾 — 目标驱动迭代

> 复制全部内容到 Codex。上一轮全栈 stabilization 已通过全部门禁，本轮补齐所有遗留缺口。
> 基线 v3.21.2+143 | 服务器 47.121.119.191 | 2026-07-03

---

## 你的角色

你是这个项目的**技术合伙人 + 产品顾问 + QA 工程师**，三重身份随时切换：

| 身份 | 什么时候用 |
|------|-----------|
| 技术合伙人 | 读代码、设计方案、写代码、部署 |
| 真实用户 | 每完成一个功能，分别模拟男生和女生的完整操作 |
| QA 工程师 | 功能做完后找边界情况、并发问题、安全漏洞 |

**核心原则：**

1. **目标驱动循环**：评估现状 → 规划 → 执行 → 验证 → 循环直到全部达标
2. **每完成一个独立功能就验证**：完整链路（数据库 + 后端 + 前端 + Provider），flutter analyze + 编译 + 部署测试全过，再开始下一个
3. **flutter analyze 保持 0**：改完就跑，新增问题立即修
4. **修复范围最小化**：不顺手重构无关代码，不引入新依赖，不改变已有 API 签名
5. **同一问题最多修 2 次**：修不好标记 ⚠️ 跳过
6. **全自动推进**：不需要停下来等确认。每完成一个目标输出简短进度更新，然后继续

**只有以下情况才停：**
- flutter analyze 出现 error（编译级）
- APK 编译失败且修 2 次还失败
- SSH 连不上服务器
- 数据库迁移报错可能破坏数据

---

## 一、项目背景

### 1.1 这是什么 APP

我给女朋友做的私人情侣 APP。Flutter + Node.js + MySQL。不推广，两人用。

**两个灵魂功能：**
- **投喂站**：「虚拟点单 + 真实履约」。女生在 APP 里点想吃的 → 男生去淘宝闪购/美团/京东外卖真实下单 → APP 里标记送出。催单不是为了好玩，是真的应该推送提醒我。
- **旅行地图**：「实用攻略 + 共同记忆」。心愿（想去）→ 计划（做攻略）→ 打卡（去过后的照片+日记）。

### 1.2 技术栈

| 层级 | 路径 | 技术 |
|------|------|------|
| Flutter 前端 | `D:\lovegirl_flutter\` | Flutter 3.x + Provider + Material Design 3 |
| 后端（服务器） | `/opt/love-girl/love-girl-server/` | Node.js + Express |
| 数据库 | Docker `lovegirl-mysql` | MySQL 8.0 |
| 本地补丁 | `D:\lovegirl_flutter\server_fixes\` | 已全部部署到服务器 |
| E2E 脚本 | `D:\lovegirl_flutter\docs\lovegirl_e2e_acceptance.ps1` | PowerShell，可复用 |

### 1.3 服务器

```
IP: 47.121.119.191
SSH: root / Deng79101600.
线上目录: /opt/love-girl/love-girl-server/（注意不是旧文档的 /root/lovegirl-server）
容器: lovegirl-server + lovegirl-mysql + nginx
MySQL: docker exec lovegirl-mysql mysql -u lovegirl -pLoveGirl@2024 love_girl
重启: cd /opt/love-girl && docker compose restart lovegirl-server
备份目录: /opt/love-girl/backups/
API: http://47.121.119.191:3001/api
```

### 1.4 编译 APK

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_HOME="C:/android-ascii"
export JAVA_HOME="C:/Program Files/Java/jdk-17.0.3.1"
cd D:/lovegirl_flutter
D:/flutter-junction/bin/flutter.bat build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

**踩坑：** 必须 JDK 17，不能用 JDK 25；必须 `D:/flutter-junction/`（完整 git 仓库），不能用 `D:/flutter-sdk/`（缺 .git）；编译路径必须纯 ASCII。

---

## 二、上一轮完成了什么（你接手时的基线）

上一轮全栈 stabilization 迭代（2026-07-02~03）已完成：

| 门禁 | 结果 |
|------|------|
| flutter analyze | **0 issues**（从 27 个历史问题清零） |
| APK 构建 | **PASS**，24.8MB |
| 线上 smoke test | 全部 200 |
| 完整 E2E（注册→绑定→投喂→旅行→聊天→经期→待办→记账→课程→心情→纪念日→爱心豆） | **全部 PASS** |
| 测试数据 | 已清理，仅剩 admin |

**P0/P1 修复（8 项）：** 投喂订单 500、投喂创建订单 500、心情字段不兼容、注册性别缺失、聊天发送失败回滚、聊天气泡归属错误、analyzer 27→0、日期时区边界。

**产品闭环（已实现）：**
- 投喂站：下单爱心豆扣减（余额不足拒绝）、订单完成后同步记账+时光轴+接收方奖励、催单 5 分钟限流、经期状态影响商品排序（冷饮降序/热饮推荐）
- 旅行：打卡自动发放奖励+生成时光轴+同步预算到记账、删除景点清理照片、交通/周边/贴士扩展字段
- 首页：`/api/home/today` 和 `/api/home/memory` 后端已建，首页读取真实今日摘要和爱心豆余额，不再是硬编码
- 爱心豆：余额/流水/签到/各模块触发（待办+3、心情+2、纪念日+20、打卡+10、投喂下单扣费、投喂接收+1）
- 跨模块联动：投喂→记账/时光轴/奖励、旅行→奖励/记账/时光轴、经期→投喂商品排序、首页聚合多模块

---

## 三、本轮目标清单（10 项，含 P1 功能 + P2 收尾）

### 目标 1：催单 WebSocket 实时推送 【P1】

**当前状态：** `POST /api/feeding/orders/:id/urge` 有 5 分钟频率限制，但对方不会收到实时通知，只能手动刷新列表才能看到。

**为什么重要：** 催单的设计初衷就是"担心没看到消息错过她的点单"。只计数不推送，违背了这个功能存在的意义。

**你需要做：**

1. **先读代码确认推送基础设施**：检查服务器 `app.js` 是否注册了 Socket.IO、`notifications.js` 有什么能力
2. **方案 A（有 Socket.IO）**：后端催单后推送 `urge_received` 事件（含 order_id、商品名、催单次数、店铺名），Flutter 端全局监听并弹出 SnackBar（含跳转按钮）
3. **方案 B（无 Socket.IO）**：投喂站 Provider 启动 30 秒轮询，检测 `urge_count` 增量后高亮订单卡片 + SnackBar 提示。离开页面清除定时器
4. 被催单的订单在列表中视觉高亮（边框脉冲动画或红色角标）

**边界情况：** 用户不在投喂站页面时也要看到通知；WebSocket 断连自动重连+降级轮询；5 分钟内重复催单后端返回 429，前端提示「X 分钟后再催」。

**验证：** 女生催单 → 男生 APP 3 秒内收到通知 → 点击跳转该订单。

---

### 目标 2：旅行路线规划 【P1】

**当前状态：** 有多个旅行地点，但不能串成路线。地图上不显示地点间连线。

**为什么重要：** 旅行规划的核心就是「把想去的地方串成一条线」。没有路线，地图就只有孤立的点。

**你需要做：**

1. **数据库**：新建 `travel_trips` 表（id, name, description, cover_photo, created_by, created_at, updated_at）和 `trip_spots` 表（id, trip_id, spot_id, sort_order, day_number, notes）
2. **后端 API**（均需 auth）：
   - `POST /api/travel/trips` — 创建路线（name + spots 数组）
   - `GET /api/travel/trips` — 路线列表（含 spot_count）
   - `GET /api/travel/trips/:id` — 路线详情（联表查景点完整信息+照片）
   - `PUT /api/travel/trips/:id/spots` — 更新景点顺序
   - `DELETE /api/travel/trips/:id` — 删除路线（不删景点）
3. **前端 UI**：
   - 旅行页新增「路线」Tab
   - 地点列表长按进入多选模式 → 「创建路线」→ 弹窗命名 → 跳转路线详情
   - 路线详情页：顶部地图预览（所有景点标记 + Polyline 连线）+ 下方可拖拽排序的景点列表（`ReorderableListView`）
   - 每个景点卡片显示「第 X 天」标签、序号圆点
   - 左滑从路线移除景点（不删景点本身）、点击跳转景点详情

**地图连线：** 高德路径规划 API 可用时显示真实路线，不可用时降级为直线。起点绿色标记、终点红色标记。

**边界情况：** 路线最少 2 个景点；同一景点可在多条路线中；删除景点时自动从路线中移除（CASCADE）；删除路线不删景点。

**验证：** 选 3 个地点 → 创建路线 → 地图上看到连线 → 拖拽排序生效 → 左滑移除生效。

---

### 目标 3：打卡成就系统 【P1】

**当前状态：** 没有成就概念。用户打卡 10 个城市和打卡 1 个没有区别。

**为什么重要：** 成就系统给旅行和日常行为增加仪式感和惊喜感——"你们一起解锁了第 5 个城市"比"你又打卡了一个地点"有温度得多。

**你需要做：**

1. **数据库**：新建 `achievements` 表（id, name, description, icon, category, condition_type, condition_value, bean_reward, sort_order）和 `user_achievements` 表（id, user_id, achievement_id, progress, unlocked, unlocked_at, notified）
2. **12 个种子成就**：

| 类别 | 成就 | 条件 | 奖励 |
|------|------|------|------|
| 旅行 | 初出茅庐 / 探索者 / 旅行达人 / 环球旅行家 | 打卡 1/5/10/20 个地点 | 5/10/20/50 |
| 旅行 | 城市漫游者 / 省会收割机 | 解锁 3/5 个城市 | 15/30 |
| 投喂 | 第一次投喂 / 贴心男友 / 专属御膳房 | 完成 1/10/50 次投喂 | 5/15/50 |
| 日常 | 一周全勤 / 月满贯 | 连续签到 7/30 天 | 15/50 |
| 日常 | 心情记录员 | 记录 30 次心情 | 20 |

3. **后端触发**：创建通用函数 `checkAchievements(userId, category)`，在旅行打卡/投喂完成/签到/记录心情时调用。用 INSERT IGNORE 懒初始化用户成就记录，更新 progress，达标时自动解锁+发豆
4. **前端 UI**：
   - 解锁时弹出动画弹窗（`ScaleTransition` + `Curves.elasticOut`）：大号 emoji + 成就名 + 奖励，3 秒自动消失
   - 个人中心新增「我的成就」入口 → 成就列表页（已解锁彩色、未解锁灰色+进度条）
   - 顶部统计「已解锁 X/12」

**边界情况：** 同一成就不会重复解锁（UNIQUE KEY）；计算进度失败不阻断主操作（try-catch）；连续触发多个成就时弹窗排队不堆叠；修改 condition_value 不回溯已解锁的。

**验证：** 打卡第 1 个地点 → 弹出「初出茅庐」→ 打卡第 5 个 → 弹出「探索者」→ 成就列表正确显示进度。

---

### 目标 4：两人地图标记颜色区分 【P1】

**当前状态：** 所有地点标记同一种颜色，分不清是谁添加的。

**为什么重要：** 这是两个人的共同地图。她想去的地方和我想去的地方，颜色不同才能一眼看出"我们一起在计划"。

**你需要做：**

1. **后端**：`GET /api/travel/spots` 确认返回 `created_by` + 联表查 `creator_nickname`
2. **前端地图**：渲染 Marker 时，`created_by == currentUserId` → 蓝色（`#4A90D9`），否则 → 粉色（`#FF6B8A`）。从 AuthProvider 获取当前用户 ID
3. **图例**：地图右下角浮动半透明图例：粉色圆点「她」+ 蓝色圆点「我」
4. **列表**：每个地点卡片加颜色指示器（小圆点）+ 昵称标签
5. **弹窗**：地点详情顶部显示「由 XXX 添加」

**边界情况：** 未绑定伴侣→默认蓝色不显示图例；创建者信息加载失败→降级蓝色不阻塞渲染。

**验证：** 两人分别添加地点 → 地图上不同颜色标记 → 图例正确显示。

---

### 目标 5：商品管理后台 【P1】

**当前状态：** 投喂商品只能通过 SQL 管理，admin 无法在 APP 内操作。

**为什么重要：** 以后想加新店铺/改价格/下架商品，不可能每次都 SSH 到服务器执行 SQL。

**你需要做：**

1. **后端 API**（均需 JWT + admin 权限校验）：
   - 店铺：`GET/POST /api/admin/shops`、`PUT/DELETE /api/admin/shops/:id`
   - 商品：`GET/POST /api/admin/shops/:shopId/products`、`PUT/DELETE /api/admin/products/:id`、`PATCH /api/admin/products/:id/toggle`（启用/禁用）
2. **前端 UI**：
   - 入口：个人中心开发者菜单新增「商品管理」（仅 `isAdmin` 可见）
   - 店铺管理页：卡片列表（图标+名称+商品数量角标）→ 点击进入商品管理 → FAB 新增店铺
   - 商品管理页：卡片列表（图片+名称+价格+启用开关）→ 点击编辑 → FAB 新增商品 → 左滑删除
   - 新增/编辑用 BottomSheet 弹窗

**边界情况：** 删除店铺级联删除商品（需二次确认）；禁用商品后用户端不显示但已有订单不受影响；非 admin 调 API 返回 403；价格修改不追溯已有订单（订单有 product_price 快照）。

**验证：** admin 新增店铺+商品 → 普通用户投喂站看到新内容 → admin 禁用商品 → 用户端消失 → admin 删除店铺 → 全部消失。

---

### 目标 6：地图平滑动画 【P1】

**当前状态：** 点击标记或列表地点后地图直接跳转，没有过渡动画。

**你需要做：** 检查 `TravelMapWidget` 中地图移动用的是 `MapController.move()`（应该已有动画）还是直接设置 center。如果是后者，改为 `_mapController.move(targetCenter, targetZoom)`。动画持续 600-800ms。确保点击标记、列表卡片、搜索结果时都走动画。

**边界情况：** 快速连续点击不卡顿不闪现。

**验证：** 点击不同城市的地点 → 地图平滑过渡，不是闪现。

---

### 目标 7：随机回忆前端展示 【P1】

**当前状态：** 后端 `/api/home/memory` 已建好（从历史照片、时光轴、心情日记中随机返回一条），但不确定前端首页是否接入展示。

**你需要做：**
1. 先读 `home_screen.dart` 和 `HomeProvider`，确认是否已有随机回忆的 UI 卡片
2. 如果没有：在首页「今日摘要」下方新增一张「回忆」卡片，展示从 API 获取的随机回忆（照片缩略图 + 相对时间如"3 个月前" + 标题如"一起去了橘子洲头"）
3. 点击卡片跳转到对应的详情（照片→相册、时光轴→时光轴详情、心情→心情日记）
4. 下拉刷新时随机更换回忆
5. 空状态：如果没有任何历史数据，显示「你们的回忆正在积累中…」

**验证：** 首页下拉 → 看到随机回忆卡片 → 内容正确 → 点击跳转对应页面。

---

### 目标 8：外卖平台记录前端编辑 【P1】

**当前状态：** 后端 `feeding_orders` 表已有 `platform` 和 `platform_order_id` 字段，但不确定男生接单后能否在 APP 里编辑填写。

**你需要做：**
1. 先读 `feeding_screen.dart` 和 `feeding_v2.js`，确认订单详情弹窗中是否有平台选择（淘宝闪购/美团/京东外卖/其他）和平台订单号输入框
2. 如果没有：在订单状态为 `accepted` 后的订单详情弹窗中，增加「外卖平台」下拉选择 + 「平台订单号」输入框，男生可编辑保存
3. 后端 `PUT /api/feeding/orders/:id` 支持更新这两个字段
4. 订单完成后在时间轴/记账联动中带上平台信息（如「投喂-喜茶多肉葡萄 ¥18（美团）」）

**验证：** 男生接单 → 订单详情看到平台选择 → 选美团填单号 → 保存 → 再次打开显示已填信息。

---

### 目标 9：P2 收尾 — 数据库字符集统一 【P2】

**当前状态：** 数据库表存在 utf8mb4_unicode_ci 和 utf8mb4_0900_ai_ci 两种排序规则混用。

**你需要做：**
1. SSH 到服务器，执行 SQL 查出所有字符集不一致的表：
   ```sql
   SELECT TABLE_NAME, TABLE_COLLATION FROM INFORMATION_SCHEMA.TABLES 
   WHERE TABLE_SCHEMA = 'love_girl' AND TABLE_COLLATION != 'utf8mb4_unicode_ci';
   ```
2. 对每个不一致的表执行：`ALTER TABLE xxx CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`
3. 操作前备份 schema，操作后验证所有表统一为 utf8mb4_unicode_ci

**注意：** 这是低风险操作，CONVERT TO 会自动转换所有字符列。但执行前仍需备份。

**验证：** 执行后查询所有表的排序规则均为 utf8mb4_unicode_ci。

---

### 目标 10：P2 收尾 — 补齐 updated_at + 清理旧路由 + 安全杂项 【P2】

**10.1 补齐核心表的 updated_at 字段**

检查以下核心业务表是否有 `updated_at` 字段，没有则新增：
- `feeding_orders`、`feeding_products`、`feeding_shops`
- `travel_spots`、`travel_photos`
- `todo_items`、`finance_records`、`course_schedules`
- `mood_diary`、`love_timeline`、`anniversaries`

对有 `updated_at` 的表，确认是否设置了 `ON UPDATE CURRENT_TIMESTAMP`。

**10.2 清理旧未挂载路由文件**

`server_fixes/feeding.js` 是旧版投喂路由（v1 模型，categories→products→orders），当前 `app.js` 没有挂载它。但它内部仍存在旧 schema 写法（如 `users.avatar`），万一将来误挂载会出问题。

处理方案：删除服务器上的 `/opt/love-girl/love-girl-server/routes/feeding.js`（如果存在），同时删除 `D:\lovegirl_flutter\server_fixes\feeding.js`。服务器上的 feeding_v2.js 是唯一投喂路由。

**10.3 连续签到 7 天额外奖励**

检查 `beans.js` 签到逻辑是否已实现连续签到 7 天额外 +15 豆。如果没有：
- 在签到接口中计算连续签到天数（从 `bean_transactions` 表的 checkin 记录推算）
- 连续 7 天时额外 INSERT 一条 bonus 流水
- 前端签到时如有额外奖励，SnackBar 提示「连续签到 7 天，额外 +15 💛」

**10.4 纪念日临近首页倒计时**

检查首页 `HomeProvider` 和 `home_screen.dart` 是否已展示 3 天内纪念日倒计时。`/api/home/today` 返回中已有 `upcoming_anniversaries` 字段，确认前端是否正确渲染。

**验证（10.1~10.4）：** updated_at 补齐无报错；旧 feeding.js 已删除；连续签到 7 天触发额外奖励；纪念日临近时首页显示倒计时。

---

## 四、关键文件路径速查

```
D:\lovegirl_flutter\lib\
├── main.dart                          # APP入口 + AppShell（5 Tab）
├── providers/
│   ├── auth_provider.dart             # 登录/注册/Token/isAdmin
│   ├── travel_provider.dart           # 旅行地点/路线/统计
│   ├── home_provider.dart             # 首页摘要/随机回忆/天气
│   └── theme_provider.dart            # 主题（已确认，不改）
├── screens/
│   ├── home/home_screen.dart          # 首页
│   ├── feeding/feeding_screen.dart    # 投喂站（~1400行，最复杂）
│   ├── travel/
│   │   ├── travel_main_screen.dart    # 旅行主页
│   │   ├── travel_form_screen.dart    # 地点表单
│   │   └── map_picker_screen.dart     # 地图选点
│   ├── chat/chat_screen.dart          # 聊天
│   ├── health/health_screen.dart      # 经期
│   ├── life/widgets/                  # 待办/记账/课程
│   ├── mood/mood_screen.dart          # 心情
│   ├── photo/photo_screen.dart        # 相册
│   ├── timeline/timeline_screen.dart  # 时光轴
│   ├── anniversary/anniversary_screen.dart
│   ├── couple/couple_binding_screen.dart
│   ├── profile/profile_screen.dart    # 个人中心
│   └── settings/settings_screen.dart
├── services/api_service.dart          # 所有 API 调用（Dio）
├── utils/
│   ├── constants.dart                 # 版本号/baseUrl
│   ├── lovegirl_theme.dart            # 主题（已确认）
│   └── amap_api.dart                  # 高德 API
└── widgets/travel_map_widget.dart     # 地图组件（flutter_map+高德瓦片）

D:\lovegirl_flutter\server_fixes\      # 本地补丁（已全部部署）
├── feeding_v2.js                      # 投喂 v2 路由
├── travel.js / travel_photos.js       # 旅行路由
├── beans.js                           # 爱心豆
├── couple.js / mood.js / notifications.js / privacy.js / version.js
└── lovegirl_full_migration.sql        # 全量迁移脚本
```

---

## 五、通用验证标准

每个目标完成后必须通过：

```
□ 加载态：显示 loading，不是白屏
□ 成功态：数据正确展示
□ 失败态：API 报错有提示+重试
□ 空状态：无数据有引导文案
□ 防重复：快速双击不重复提交
□ 数据刷新：操作后列表自动更新
□ flutter analyze：无新增问题
```

### 最终门禁（10 项目标全部完成后）

```
✅ flutter analyze: 0 issues
✅ APK 构建成功
✅ 线上 smoke test 全部 200
✅ 10 项目标全部验证通过
✅ E2E 脚本扩展覆盖新功能
✅ 测试数据已清理（仅保留 admin）
```

---

## 六、技术约束

- 所有后端路由需认证的加 auth 中间件；admin 接口额外校验 `is_admin = 1`
- 所有 SQL 参数化，禁止字符串拼接
- 联动写入 try-catch 包裹，失败不阻断主操作；爱心豆流水只 INSERT
- 数据库迁移前备份线上 schema；只新增字段/表/索引，不做破坏性变更
- 不引入新 Flutter 依赖（除非 WebSocket 需要 `socket_io_client`）
- 不改变已有 API 签名和数据库已有字段
- JDK 17 编译；Flutter SDK `D:\flutter-junction\bin\flutter.bat`
- E2E 测试后清理测试账号

---

## 七、本轮明确不碰

- ❌ UI 视觉优化（主题/颜色/间距/阴影/字体）— 下一轮专项
- ❌ HTTPS / 安全头 / token 轮换 — 需证书，单独排期
- ❌ npm audit 依赖升级 — 风险大，单独排期
- ❌ 恋爱月度报告 / Android 桌面小组件 — P2 延后

---

## 开始

现在开始。**先回复我：**

「我已读完提示词。基线：analyze=0, E2E全绿, APK构建成功, 产品闭环已跑通。

我将按顺序推进 10 项目标：
1-6 为 P1 功能（催单推送→路线→成就→地图标记→商品管理→平滑动画）
7-8 为 P1 补充（随机回忆前端→外卖平台编辑）
9-10 为 P2 收尾（字符集统一→updated_at/旧路由/签到奖励/纪念日倒计时）

每完成一个目标输出进度更新（完成了什么 / 验证结果 / 下一步），然后继续。遇到编译失败、SSH不通、数据库迁移报错才停，否则不停。」
