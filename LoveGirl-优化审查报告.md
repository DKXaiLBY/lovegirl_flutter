# LoveGirl 优化审查报告

生成时间：2026-07-02 23:40  
审查目标：LoveGirl v3.21.2+143 全栈质量迭代  
执行原则：以现有工作区和线上状态为基线；不回滚无关改动；只修 P0/P1；P2 记录待后续排期。

## 总体结论

本轮完成线上部署预检、数据库兼容迁移、后端 P0 修复、Flutter 核心流程 P0/P1 修复、线上 smoke test、`flutter analyze` 和 release APK 构建验证。

最终状态：核心接口 smoke test 通过；投喂 v2 订单接口 500 已修复；release APK 构建成功。仍存在若干历史 P2 问题，包括 analyzer 27 个基线问题、数据库字符集不统一、部分表缺少 `updated_at`、旧版未挂载路由残留、生产环境未执行破坏性 E2E 写入测试。

## Phase 0：线上部署预检与部署

状态：PASS

- 实际线上目录确认为 `/opt/love-girl/love-girl-server`，不是旧文档中的 `/root/lovegirl-server`。
- Docker 容器确认为 `lovegirl-server`，服务运行目录通过 bind mount 映射到 `/app`。
- 部署前已备份线上 schema：`/opt/love-girl/backups/love_girl_schema_20260702232123.sql`。
- 对将覆盖的后端文件执行备份，投喂 v2 本轮追加备份：`/opt/love-girl/backups/feeding_v2.js.20260702233235.bak`。
- 已执行迁移 SQL：
  - `lovegirl_full_migration.sql`
  - `travel_photos_table.sql`
  - `couple_table.sql`
  - `travel_amap_patch.sql`
  - `version_table.sql`
- 已重启 `lovegirl-server` 容器，容器状态为 `running`。

## Phase 1：数据库 Schema 审计

状态：PASS，存在 P2 遗留

关键确认：

- `period_records` 已使用加密列保存经期日期、周期、症状、疼痛、备注等敏感字段。
- `finance_records` 已存在加密金额和描述字段。
- `chat_messages` 已存在 `content_encrypted`。
- `couples`、`bean_transactions`、`travel_photos`、`version` 相关表已通过迁移补齐。
- `feeding_orders` 已补齐 v2 所需兼容字段：`sender_id`、`receiver_id`、`shop_id`、`product_price`、`message`、`urge_count`、`last_urge_at`。
- `feeding_products` 已补齐 v2 所需兼容字段：`shop_id`、`description`、`image`、`sort_order`。
- `feeding_orders.status` 已兼容为 `VARCHAR(20)`，支持 v2 多状态流转。

P0/P1 修复：

- 修复投喂 v2 数据库结构与后端查询不匹配，避免订单列表、催单、状态更新等核心流程因缺列阻断。
- 对旧字段执行兼容回填：`boy_user_id` -> `sender_id`，`girl_user_id` -> `receiver_id`，`note` -> `message`，`total_price / quantity` -> `product_price`。

P2 遗留：

- 数据库表字符集/排序规则存在混用：`utf8mb4_unicode_ci` 与 `utf8mb4_0900_ai_ci` 并存。
- 部分历史表缺少统一的 `updated_at`。
- 生产库未执行写入型完整 E2E，避免生成脏数据；本轮以兼容迁移和读取 smoke 为主。

## Phase 2：Node.js 后端审查

状态：PASS，核心 P0 已修复

覆盖范围：

- 已重点检查 auth、feeding v2、travel、travel_photos、couple、beans、notifications、privacy、version、photo、weather 等线上部署路由。
- 每个关键接口重点关注认证、授权、字段兼容、参数化 SQL、错误响应、敏感日志和生产数据安全。

P0/P1 修复：

- `server_fixes/feeding_v2.js`
  - 修复订单列表查询引用不存在的 `users.avatar`，改为当前 schema 中的 `users.avatar_url`。
  - 订单列表返回补齐 `sender_id`、`receiver_id`，保证 Flutter 端可以稳定判断消息/订单归属。
  - 已上传到线上 `/opt/love-girl/love-girl-server/routes/feeding_v2.js` 并重启容器。
- `server_fixes/lovegirl_full_migration.sql`
  - 增加投喂 v2 兼容列和回填逻辑。
- `server_fixes/travel_photos_table.sql`
  - 修复 MySQL 环境不支持 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 的迁移兼容性问题，改为存储过程按列存在性新增。

线上 smoke test：

- `GET /api/health`：200
- `GET /api/version/check?version_code=143`：200
- 未登录访问受保护接口：401，符合预期
- 登录后：
  - `GET /api/feeding/shops`：200
  - `GET /api/feeding/shops/1/products`：200
  - `GET /api/feeding/orders`：200
  - `GET /api/feeding/stats`：200
  - `GET /api/travel/spots`：200
  - `GET /api/travel/stats`：200
  - `GET /api/period/status`：200
  - `GET /api/couple`：200
  - `GET /api/beans/balance`：200

P2 遗留：

- `server_fixes/feeding.js` 是旧版投喂路由，当前 `app.js` 未挂载它；文件内仍存在旧 schema 写法 `users.avatar`，建议后续清理或同步修复以免误挂载。
- 后端依赖存在历史 npm audit 风险，未在本轮扩大升级依赖，避免引入兼容性变化。
- 生产 HTTP/HTTPS、token 生命周期、安全头等部署级问题建议单独做安全加固计划。

## Phase 3：Flutter 前端核心模块审查

状态：PASS，核心 P0/P1 已修复

本轮重点修复：

- `lib/services/api_service.dart`
  - 注册请求补充 `gender` 字段，默认 `female`，保留原有三个位置参数语义。
- `lib/providers/auth_provider.dart`
  - 注册方法透传 `gender`。
  - `isAdmin` 同时兼容后端可能返回的 `is_admin` 和 `isAdmin`，避免开发者入口误判。
- `lib/screens/auth/register_screen.dart`
  - 增加性别选择控件，注册时显式提交 `female`/`male`。
  - 修复默认注册为男生导致伴侣/经期等按性别控制的核心流程异常。
- `lib/screens/chat/chat_screen.dart`
  - 聊天气泡归属同时兼容 `sender_id` 与 `senderId`。
  - 发送失败时移除乐观消息并恢复输入内容，避免失败消息假成功和用户输入丢失。
  - 异步结束后增加 mounted 保护。

模块审查结果：

- 投喂站：PASS。后端订单接口恢复 200，店铺/商品/统计读取正常。
- 旅行地图：PASS。景点和统计接口 smoke 通过；照片表和 amap 扩展字段迁移完成。
- 聊天：PASS。消息归属和发送失败回滚已修复；未做生产写入型 E2E。
- 首页：PASS with P2。天气、恋爱天数、摘要类展示需后续继续核实数据真实性。
- 生活模块：PASS with P2。待办、记账、课程表存在历史 analyzer 提示，未发现本轮新增阻断。
- 健康经期：PASS。后端状态接口 200，敏感字段确认加密列存储。
- 心情：PASS with P2。存在历史未使用字段和 async context lint。
- 相册/时光轴/纪念日：PASS with P2。未做生产写入型 E2E。
- 伴侣绑定：PASS with P2。伴侣接口 200，注册性别问题已修复。
- 个人中心/登录注册：PASS。注册性别、管理员字段兼容已修复。

## Phase 4：验证结果

状态：PASS with known baseline

- `D:\flutter-sdk\bin\flutter.bat analyze`
  - 结果：27 issues。
  - 结论：仍为历史基线问题，本轮改动文件未新增 analyzer 问题。
- `D:\flutter-sdk\bin\flutter.bat build apk --release`
  - 首次失败原因：当前 shell 默认 Java 为 `25.0.1`，Gradle 8.3/Kotlin DSL 无法解析该版本号。
  - 处理方式：仅在本次构建命令环境临时设置 `JAVA_HOME=C:\Program Files\Java\jdk-17.0.3.1`。
  - 最终结果：构建成功。
  - APK：`D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`
  - 大小：24.7MB
- 线上 API smoke test：PASS，详见 Phase 2。

## P0/P1 修复清单

| 级别 | 用户视角 | 根因 | 修复方式 | 验证 |
| --- | --- | --- | --- | --- |
| P0 | 投喂订单列表打不开，接口 500 | 后端查询 `users.avatar`，线上 schema 为 `avatar_url` | `feeding_v2.js` 改用 `avatar_url` | `/api/feeding/orders` 200 |
| P0 | 投喂 v2 订单流转可能因缺列失败 | 线上 `feeding_orders` 仍是旧结构 | 兼容新增 v2 字段并回填旧数据 | SQL 执行成功，相关接口 200 |
| P1 | 新用户注册后性别错误，影响伴侣/经期权限和首页状态 | Flutter 注册未提交 `gender`，后端默认可能不符合用户选择 | 注册页增加性别选择，API 透传 `gender` | analyze 无新增问题 |
| P1 | 开发者/管理员入口可能不显示 | 前端只读 `is_admin`，部分响应可能为 `isAdmin` | `AuthProvider.isAdmin` 双字段兼容 | analyze 无新增问题 |
| P1 | 聊天发送失败时消息假成功且输入丢失 | 乐观消息失败后未回滚 | 失败时删除乐观消息并恢复输入框 | analyze 无新增问题 |
| P1 | 聊天气泡归属可能错误 | 前后端字段名 `sender_id`/`senderId` 不一致 | 双字段兼容判断归属 | analyze 无新增问题 |

## 遗留问题与建议

- analyzer 27 个历史问题已在 2026-07-03 补充迭代中处理完成，后续建议保持 `flutter analyze` 清零。
- 统一数据库字符集和排序规则，但应单独排期并先做完整备份与回滚方案。
- 为所有核心业务表补齐统一 `created_at`/`updated_at` 策略。
- 清理未挂载旧路由文件，避免未来误挂载旧 schema 逻辑。
- 建立 staging 环境后补全写入型 E2E：注册绑定、投喂下单/取消/催单、旅行照片、经期记录、课程今日摘要、心情统计、token 过期、角色切换。
- 后续安全加固建议覆盖 HTTPS、CORS 白名单、敏感日志、token 轮换、npm audit 依赖升级。

## 2026-07-03 补充迭代

用户确认如仍有未完成部分则继续推进后，本轮继续处理了前次报告中的 analyzer 历史基线问题。处理范围仍限定为低风险静态质量修复，不触碰生产数据，不修改公共 API。

补充修复：

- 清理伴侣绑定、版本弹窗等未使用局部变量。
- 修复 `shouldRepaint`、`shouldReclip` 覆写参数命名 lint。
- 移除或标记未使用的旧私有状态/方法，保留当前运行路径。
- 为记账、课程、待办、心情、时光轴、日志等异步对话框流程补充 `mounted`/`context.mounted` 保护。
- 修复头像渲染中的无效非空断言，改为本地 `avatar` 字符串判断。
- 修复无意义字符串插值、缺少花括号的单行 if、多余 const 等 analyzer info。
- 设置页 `_isSaving` 现在用于防重复保存/上传，避免字段只写不读。

补充验证：

- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`
- 使用 JDK 17 临时构建环境再次执行 `D:\flutter-sdk\bin\flutter.bat build apk --release`：PASS
- APK：`D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`
- APK 大小：24.7MB

更新后状态：

- 前次报告中的 “analyzer 27 个历史问题” 已处理完成。
- 仍建议后续单独排期：数据库字符集统一、旧未挂载路由清理、staging 写入型 E2E、安全加固和依赖审计。

## 2026-07-03 上线前最终非 UI 验收

验收目标：不处理 UI 视觉优化，不做破坏性数据库迁移，不修改无关代码；上线前最后一次确认非 UI 质量门禁、线上核心 API、核心 E2E 流程和最终上线建议。

测试账号与测试数据策略：

- 空库/预发环境使用一次性测试前缀：`E2E_20260703_<timestamp>`。
- 空库/预发环境由脚本自动创建两名新用户：`e2e_boy_<timestamp>`，`gender=male`；`e2e_girl_<timestamp>`，`gender=female`。
- 线上生产库有角色唯一限制：每个普通角色只能存在一个账号，因此 E2E 前必须保证没有已有 boy/girl 普通账号，或使用已有专用测试账号参数运行。
- 本轮按用户授权，已删除原有两个普通账号及关联测试数据，随后由 E2E 脚本自动注册临时 boy/girl 测试账号。
- 完整 E2E 通过后，已删除自动注册的临时测试账号和残留数据；线上 `users` 表当前仅剩 `admin`。
- 测试数据计划覆盖并可追踪清理：伴侣绑定邀请码、投喂订单、旅行景点和照片、聊天消息、经期记录、待办、记账、课程、心情、时光轴、纪念日。
- 所有写入数据必须带测试前缀或测试账号归属；未获确认前，不复用真实用户，不重置真实用户密码，不直接改库创建/解除情侣关系。
- 数据库策略仅允许兼容性新增或测试数据写入；本轮未执行任何破坏性迁移。

本轮已完成门禁：

- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`（2026-07-03 01:37 复跑）
- 使用 JDK 17 临时环境执行 `D:\flutter-sdk\bin\flutter.bat build apk --release`：PASS
- APK：`D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`
- APK 大小：24.7MB，文件时间：2026-07-03 01:06:38
- 已新增可复用非 UI E2E 验收脚本：`D:\lovegirl_flutter\docs\lovegirl_e2e_acceptance.ps1`
- 脚本已支持两种策略：空库自动注册；线上已有账号登录并默认保留情侣绑定。
- 脚本只读 smoke 验证：`powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\lovegirl_e2e_acceptance.ps1 -SkipWrites -TimeoutSec 25`，PASS，未写入测试数据。
- 2026-07-03 01:06 复跑本地门禁：`flutter analyze` PASS，release APK 构建 PASS。

线上核心 API smoke test：

| 检查项 | 结果 | 说明 |
| --- | --- | --- |
| TCP 3001 | PASS | `Test-NetConnection 47.121.119.191 -Port 3001` 可建立 TCP |
| TCP 22 | PASS | `Test-NetConnection 47.121.119.191 -Port 22` 可建立 TCP |
| SSH 运维通道 | PASS | `ssh root@47.121.119.191 'echo ok'` 返回 `ok` |
| `GET /api/health` | PASS | 返回 `code=200` |
| `GET /api/version/check?version_code=143` | PASS | 返回 `code=200` |
| 非法 token 访问 `/api/user/profile` | PASS | 返回 HTTP 401，符合预期 |

2026-07-03 01:35 后复测确认线上服务已恢复，`lovegirl-server`、`lovegirl-web`、`lovegirl-mysql` 容器均处于运行/健康状态。

完整 E2E 最终复跑结果：

- 已验证 admin 可登录（密码已轮换，不入库），管理员角色切换接口可用，但单一 admin 不能替代真实 boy/girl 双账号绑定流程。
- 按用户授权，已先生成整库备份：`D:\lovegirl_flutter\docs\lovegirl_pre_e2e_cleanup_20260703014559.sql`。
- 已删除原有两个普通账号及其关联测试数据，保留 admin。
- E2E 首轮暴露 P0：投喂 v2 创建订单 500，根因为旧字段 `boy_user_id/girl_user_id` 仍为 NOT NULL，而新插入只写 `sender_id/receiver_id`。已修复为创建订单时同时兼容回填旧字段。
- E2E 二轮暴露 P1：心情记录接口不兼容 Flutter 发送的 `emoji/label/note/date` 字段。已修复后端 mood 路由，兼容接收旧字段并返回前端需要的 `emoji/label/date`。
- E2E 三轮完整通过：注册、登录、情侣绑定、投喂完整流转、旅行照片、时光轴、聊天、经期、待办、记账、课程、心情、纪念日、爱心豆、隐私接口全部 PASS。
- 按用户要求，E2E 完成后已删除自动注册的测试账号和残留数据；线上 `users` 表当前仅剩 `admin`。
- 已复跑只读 smoke、`flutter analyze` 和 release APK 构建，均 PASS。

核心 E2E 验收状态：

| 场景 | 状态 | 说明 |
| --- | --- | --- |
| 注册并登录两名测试用户 | PASS | 自动注册 boy/girl 测试账号成功；验收后已删除 |
| 伴侣邀请码创建与接受 | PASS | 邀请码生成、接受、双方状态读取通过 |
| 投喂店铺、商品、下单、催单、状态流转 | PASS | pending -> accepted -> preparing -> delivering -> completed 全流程通过 |
| 旅行景点、照片、时光轴联动 | PASS | 景点 CRUD、照片上传/列表、时光轴创建/列表通过 |
| 经期记录与首页状态 | PASS | 经期开始、状态、结束、分析接口通过 |
| 课程今日摘要、待办、记账 | PASS | 待办、记账、课程创建/读取/统计/清理通过 |
| 心情记录与统计 | PASS | 心情记录、列表、统计通过 |
| Token 过期/非法 token | PASS | 非法 token 访问受保护接口返回 HTTP 401 |
| 开发者角色切换/管理员入口 | PASS | admin 登录和角色切换接口通过 |

P0/P1 结论：

| 级别 | 问题 | 影响 | 当前结论 |
| --- | --- | --- | --- |
| P0 | 投喂创建订单 500 | 用户无法完成投喂下单 | 已修复并通过 E2E |
| P1 | 心情记录字段不兼容 | 用户在 App 里记录心情会失败或记录后无法正常显示 | 已修复并通过 E2E |

最终上线建议：

建议上线。

非 UI 范围内，上线前关键质量门禁已满足：`flutter analyze` 为 0，release APK 构建成功，线上核心 API smoke test 通过，核心写入型 E2E 全流程通过，E2E 测试账号和测试数据已清理。UI 视觉优化、数据库字符集统一、npm audit 依赖升级、旧 push_messages 兼容告警等仍按 P2/后续专项处理，不阻断本次非 UI 上线结论。

最终验证命令与结果：

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\lovegirl_e2e_acceptance.ps1 -TimeoutSec 30`：PASS，`ALL CORE NON-UI E2E CHECKS PASSED`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\lovegirl_e2e_acceptance.ps1 -TimeoutSec 25 -SkipWrites`：PASS
- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`
- `D:\flutter-sdk\bin\flutter.bat build apk --release`：PASS，`D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`，24.7MB

## 2026-07-03 最终产品闭环验收补充

本轮补充目标：在不处理 UI 视觉美化的前提下，完成投喂站真实履约、旅行攻略与记忆、首页今日摘要、爱心豆经济系统、跨模块联动的上线前最终非 UI 闭环，并保持 analyze、APK、线上 smoke、核心 E2E 全部通过。

### 本轮新增/修复范围

- 投喂站：接入爱心豆扣减事务；下单余额不足返回明确错误；订单完成后同步记账、时光轴、接收方爱心豆奖励；催单保留 5 分钟限流；前端下单弹窗显示余额/下单后余额并防重复提交。
- 旅行：新增 `transportation`、`nearby`、`tips`、`checked_in_at` 等兼容字段；打卡自动发放旅行奖励、生成时光轴、同步旅行预算到记账；删除景点时清理照片记录和文件；地图 marker 支持按创建人/状态区分。
- 首页：新增 `/api/home/today` 与 `/api/home/memory`，Flutter 新增 `HomeProvider`，首页改为读取真实今日摘要、记忆、恋爱天数、爱心豆余额，不再依赖硬编码占位数据。
- 爱心豆：新增/补齐余额、流水、签到状态、签到接口；流水支持来源模块、来源 ID、描述和幂等去重；完成待办、记录心情、纪念日当天、旅行打卡、投喂接收、投喂下单均进入统一流水。
- 跨模块联动：投喂完成联动记账/时光轴/奖励；旅行打卡联动奖励/记账/时光轴；经期状态参与投喂商品排序；首页聚合待办、课程、心情、记账、纪念日、爱心豆。
- 日期边界修复：Node 端原本使用 `toISOString()` 导致中国时间凌晨业务日期落到 UTC 前一天；已统一关键业务日期为 `Asia/Shanghai`，并验证 `/api/home/today` 返回 `2026-07-03`。

### 部署与数据

- 已执行兼容 SQL 迁移，只新增字段/表/索引，不做破坏性迁移。
- 已备份线上后端文件，备份目录：`/root/lovegirl_backup_final_20260703024432`。
- 已上传并重启线上 `lovegirl-server`，容器状态：healthy。
- 测试账号策略：E2E 使用 `e2e_` 前缀临时 boy/girl 账号；投喂前通过签到、待办、心情、纪念日、旅行打卡等真实奖励路径获取爱心豆；测试后删除临时账号和残留数据。
- 清理结果：线上 `users` 表最终只剩 `admin`。

### 最终验证结果

- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`
- `D:\flutter-sdk\bin\flutter.bat build apk --release`：PASS，APK 输出 `D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`，大小 24.8MB，时间 2026-07-03 02:57。
- 线上 smoke：PASS，`/api/health`、登录、`/api/feeding/shops`、`/api/travel/spots`、`/api/version/check?version_code=143`、`/api/home/today`、`/api/beans/checkin/status` 均返回 200。
- 完整 E2E：PASS，`docs\lovegirl_e2e_acceptance.ps1` 返回 `ALL CORE NON-UI E2E CHECKS PASSED`。
- 爱心豆奖励复核：测试用户流水中已确认 `anniversary_day +20`、`daily_check_in +5`、`todo_completed +3`、`mood_record +2`、`travel_checkin +10`、`feeding_order -18`、`feeding_received +1` 均产生。

### 最终结论

建议上线。非 UI 范围内的 P0/P1 已修复，核心 API 与核心写入型 E2E 已通过，Flutter analyze 为 0，release APK 构建成功，测试账号和测试数据已清理。UI 视觉优化、依赖安全升级、数据库字符集统一、旧未挂载路由清理可作为后续 P2 专项，不阻断本次上线。
## 2026-07-03 14:30 最终上线闭环复核

本次复核范围仍限定为非 UI 上线质量：不处理视觉美化，不做破坏性数据库迁移，不修改无关代码。

### 最后补丁

- 已备份线上 `routes/home.js`：`/opt/love-girl/backups/pre_logfix_20260703_142220/home.js`。
- 修复 `/api/home/today` 财务聚合查询引用不存在的 `amount` 字段问题，改为读取现有加密金额字段，避免首页摘要降级告警。
- 兼容扩展 `push_messages.type` 枚举，新增 `feeding_order`、`feeding_urge`、`feeding_status`、`feeding_delivery`，避免投喂下单、催单、状态流转写推送消息时被数据库截断。
- 已重启 `lovegirl-server`，容器状态 healthy。

### 最终验证

- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`。
- release APK：PASS，输出 `D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`。
- 线上 smoke：PASS，`/api/health`、`/api/version/check?version_code=143`、`/api/feeding/shops`、`/api/travel/spots`、`/api/achievements`、`/api/home/today` 均返回 `code=200`。
- 投喂最小回归：PASS，临时 boy/girl 账号完成店铺读取、商品读取、下单、催单、接单；最近日志未再出现 `push failed`、`Data truncated`、`Home subquery failed`。
- 测试数据清理：PASS，`codex_e2e_%` 与 `codex_reg_%` 临时账号剩余数量为 `0`。

### 最终结论

建议上线。非 UI 范围内，当前 P0/P1 已修复并完成闭环验证；`flutter analyze` 为 0，release APK 构建成功，线上核心 API smoke 通过，核心写入型 E2E 与投喂日志回归通过，临时测试账号和测试数据已清理。剩余事项为 P2 或后续专项：UI 视觉优化、依赖安全升级、MySQL 配置告警、字符集历史数据治理、旧未挂载路由清理。

## 2026-07-03 14:45 上线前非 UI 收尾复核

本次收尾范围：不重做 UI 视觉，不改 API 签名，不做数据库迁移，仅处理上线前容易误导用户或暴露敏感信息的非 UI 风险。

### 收尾修复

- 个人中心：移除没有真实后端/页面支撑的“即将支持”入口；资料编辑、通知提醒、隐私权限统一进入现有设置页；检查更新接入现有手动版本检查弹窗。
- 版本展示：个人中心版本号由硬编码 `v3.22` 改为读取 `AppConstants.versionName/versionCode`，与当前 `3.21.2+143` 保持一致。
- 本地日志：API 日志不再持久化完整响应体，避免聊天、经期、记账、隐私等接口数据被写入本地调试日志。
- Android 权限：移除旧版 `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` 权限，保留当前功能仍需要的网络、定位、相机、图片读取和应用内 APK 更新权限。

### 本次验证

- `D:\flutter-sdk\bin\flutter.bat analyze`：PASS，`No issues found!`。
- `D:\flutter-sdk\bin\flutter.bat build apk --release`：PASS，输出 `D:\lovegirl_flutter\build\app\outputs\flutter-apk\app-release.apk`，大小 24.8MB，时间 2026-07-03 14:44。
- 线上 smoke：PASS，`/api/health`、`/api/version/check?version_code=143`、`/api/feeding/shops`、`/api/travel/spots` 均返回 `code=200`。
- 残留扫描：PASS，个人中心无 `_showSoon` 和 `v3.22`，API 日志无 `response.data`，Android manifest 无旧存储读写权限。

### 最终结论

仍建议上线。当前非 UI 范围内的核心质量门禁保持通过。HTTPS 切换、真实远程推送、应用商店权限政策说明需要域名/证书/推送密钥或上架材料配合，属于上线配置专项，不应在缺少服务器条件时硬改客户端以免破坏现有线上可用性。

## 2026-07-03 15:00 v3.21.3+144 发布记录

发布目标：将本轮上线前非 UI 收尾结果发布为可被 App 内更新检测到的新版本，版本号必须高于当前线上 `3.21.2+143`。

### 发布内容

- 客户端版本已同步为 `3.21.3+144`：`pubspec.yaml` 与 `AppConstants.versionName/versionCode` 一致。
- 发布脚本修复：源码读取固定 UTF-8；Flutter 构建输出按 UTF-8 容错读取；`file_size` 上传真实 APK 字节数，避免后端 `parseInt("24.8MB")` 截断成 `24`。
- 线上版本表修复：备份 `app_versions_backup_20260703_1458`；清理历史重复 `version_code` 记录；补充唯一索引 `uk_version_code(version_code)`，确保后续同版本发布会覆盖而不是插入重复记录。
- 新 APK 已上传为 `http://47.121.119.191:3001/public/download/LoveGirl-latest.apk`，本地归档为 `D:\lovegirl_flutter\LoveGirl-v3.21.3-build144.apk`。

### 发布验证

- `D:\flutter-sdk\bin\flutter.bat analyze --no-pub`：PASS，`No issues found!`。
- `python publish.py`：PASS，服务器返回 `v3.21.3 发布成功!`。
- `GET /api/version/check?version_code=143`：PASS，`hasUpdate=true`，返回 `code=144`、`name=3.21.3`、`size=25983884`。
- `GET /api/version/check?version_code=144`：PASS，`hasUpdate=false`。
- APK 下载头：PASS，`Content-Length=25983884`，`Content-Type=application/vnd.android.package-archive`。
- 版本表：PASS，`144 / 3.21.3 / file_size=25983884 / is_active=1`，重复 `version_code` 数量为 `0`。

### 结论

v3.21.3+144 已发布。当前安装 `3.21.2+143` 的 App 进入检查更新应能看到 `3.21.3` 更新；安装 `3.21.3+144` 后再次检查不会重复提示。
