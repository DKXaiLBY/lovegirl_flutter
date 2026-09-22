# LoveGirl 交接文档 — 2026-09-20 晚（v3.27 已发布 → v3.28 方案已定）

> 写给下一个接手的 AI。先读仓库根目录 AGENTS.md（环境/构建/坑），再读本文档。本文档是唯一任务事实来源，用户已拍板全部决策。

## 当前状态（快照）

- **已发布**：v3.27.0+155（release 已上传服务器，版本表正确，旧客户端会自动弹更新）
- **App 仓库** `D:\lovegirl_flutter`（git，remote=github.com/DKXaiLBY/lovegirl_flutter，master）：
  - 最新 commit `c83df6a`（tag `remove-tree-kiss`），analyze 0 问题、21/21 测试过，已 push 到 GitHub
  - tag 链（回滚地图）：`v3.26.0-base` → `feat-notifications` → `feat-settings-unify` → `feat-warmth-p1` → `feat-daily-question` → `feat-love-tree` → `feat-thumb-kiss` → `feat-slow-letter` → `feat-annual-report` → `v3.27.0` → `v3.27.0-fixes` → `remove-tree-kiss`
- **服务器** `root@47.121.119.191`（SSH 免密），代码在 `/opt/love-girl/love-girl-server`（容器挂载，改文件+`docker restart lovegirl-server` 生效），git 最新 `ba9a67f`（tag `srv-remove-tree-kiss`），工作区干净
- **刚完成**：爱情树和拇指之吻已砍（用户决策：树 UI 劣质、吻场景弱）。App 代码/入口/通知深链已删；服务器 `/api/tree`、`/api/kiss` 路由已下线（404）。**注意**：服务器上的路由文件（routes/love_tree.js、thumb_kiss.js）和表（love_tree 等）还在，只是 app.js 不再 require——彻底清除或恢复都可
- **构建**：`JAVA_HOME="C:\Program Files\Java\jdk-17.0.3.1" D:/flutter-sdk/bin/flutter.bat`；release 发布流程见 AGENTS.md（发布后版本表 version_name 已由接口正确写入，v3.27 起无需再手工修 changelog——发布用 UTF-8 Python multipart 上传即可，勿用 Windows shell curl 发中文）

## 下一轮任务（v3.28），按用户拍板的优先级执行

### 任务 1：爱心豆愿望兑换券（核心功能，先做）

**用户原话：爱心豆做愿望兑换券（她用豆使唤你）。**

方案：
- 服务器新路由 `routes/wish_voucher.js`：兑换券模板表 `voucher_templates`（id/creator_id/title/cost_bean/emoji/cover_url/is_active）+ 兑换记录表 `voucher_redemptions`（id/template_id/redeemer_id/status[pending→done/cancelled]/created_at/done_at）
- 流程：A 创建券（标题+豆价，如"奶茶券 50豆""按摩券 80豆""今晚不打游戏券 200豆"）→ B 用豆兑换（原子扣豆+插记录+通知 A"TA 兑换了你的 XX 券"）→ A 现实兑现后点"已完成"（可拍凭证照，复用 kitchen 的照片上传）→ B 确认。取消退还豆
- 扣豆务必用事务+行锁（`SELECT ... FOR UPDATE` 或 `UPDATE users SET bean_balance=bean_balance-? WHERE id=? AND bean_balance>=?` 检查 affectedRows），参考 bean_transactions 现有写法（routes/utils/lovegirl_rewards.js 的 addBeanTransaction，amount 传负数）
- App 端：入口放"我的"页（替换原爱情树的位置）；两个 tab"券铺（对方的券）/ 我的券"，创建券 bottom sheet，兑换卡用票根风（复用 widgets/ticket_styles.dart）
- UI 语言：这是"使唤对方的权力"，文案要俏皮（"兑换后 TA 会收到通知，快去使唤 TA 吧"）

### 任务 2：记账添加入口（bug 级缺失，小）

**用户原话：目前没找到可以记账的地方，只有列表界面。**
- 生活 tab → 本月小账本（lib/screens/life/widgets/finance_list.dart）只有列表无添加入口
- 加"+记一笔"按钮（FAB 或列表头）→ bottom sheet：金额/分类（餐交购娱等）/备注/归属人（我/TA/共同）/日期 → POST 到现有 /api/finance 路由（routes/finance.js 已有写接口，先确认字段）
- 记得联动首页"本月小账本"卡片数据（routes/home.js）

### 任务 3：旅行页收尾清理（星空地图三连修）

**用户三个痛点，全部成立：**
1. **"我的足迹"卡片关不掉**：改成可收起——卡片顶部加拖拽把手，下拉收成贴边小 pill，点击再展开；或做成地图上的图层开关按钮
2. **地图被框在半屏**（上半屏是静态星空背景）：地图扩到全屏，星空背景砍掉（或只留 status bar 后面），足迹卡/按钮做悬浮层
3. **滑动卡顿**：三个嫌疑逐一查——marker 全量重建（改增量 diff）、足迹连线逐点绘制（改简化折线/抽稀）、背景粒子动画持续耗性能（砍）。**性能对比必须真机**（荣耀 Android 10，测试机信息在 AGENTS.md §经验 6/7）
4. 顺手清文案债：旅行页"真地图"标签对用户是噪音，清掉（v3.23 遗留的模式切换残留）
- 相关文件：lib/screens/travel/stars_map_screen.dart、travel_main_screen.dart、widgets/travel_map_widget.dart

### 任务 4（可选，等用户看到样例再拍板）：温度回归 Phase2 贴纸层

- 和纸胶带斜贴卡片角、小贴纸点缀、空状态插画。**动手前先做 2-3 个样例截图给用户看**，用户之前表示"没看明白有什么用"，眼见为实后再投入

### 明确不做/已否决
- 爱情树、拇指之吻（已砍，勿恢复）
- 实时定位、远程闹钟、私密聊天、AI 陪聊（调研时已排除）
- 慢信解锁日提醒、每日一问自定义题库（用户原话"感觉没什么用"——除非用户再提）

## 工作纪律（本轮已验证有效的做法）

1. 每个功能独立 commit + git tag（回滚点），完成即 `flutter analyze`（必须 0 问题）+ `flutter test`（必须全过）
2. 服务器改动：先拉文件到本地 `server_fixes/` 编辑（本地是副本快照）→ scp 上去 → `docker exec lovegirl-server node --check` 语法检查 → `docker restart lovegirl-server` → curl 实弹验证 → 服务器 git commit + tag
3. 新表用 UTF-8 SQL 文件 docker cp/scp 进容器执行（Windows shell 直接传中文会 GBK 乱码）
4. 测试数据用完必须清（本轮就因没清 couples 绑定导致"未绑定"分支漏测）
5. 对抗性审查：交付前派独立审查 agent 实弹攻击（本轮抓到 1 个 P0 时区 bug——服务器 MySQL 会话时区是 UTC，所有"今天"判断用 JS 层 todayString() 或显式 water_day 列，勿用 MySQL 的 CURDATE/NOW 做北京日判断）
6. adb 截图用 `exec-out screencap -p`（勿 shell+screencap 到 sdcard，会报错）；Flutter 页面 uiautomator 抓不到文本，控件定位靠截图视觉分析+源码推坐标
7. 发布：Python multipart 上传（UTF-8）→ 验证版本表 HEX 字节 → `/api/version/check?version_code=旧版本` 验证更新弹窗
