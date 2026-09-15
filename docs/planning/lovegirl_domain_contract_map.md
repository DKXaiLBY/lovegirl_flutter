# LoveGirl Domain 前后端契约映射

更新时间：2026-07-17
适用阶段：方案确认阶段（当前不写业务代码）

## 1. 文档目的

这份文档回答的是：

- 每个业务域前端落在哪些页面
- 后端应该接哪些路由
- 数据主要落在哪些表
- 和其他域的联动关系是什么

它的作用不是替代接口文档，而是为后续重构提供“域级地图”。

## 2. 当前证据基础

本映射基于当前仓库里已经确认的真实证据：

- 前端主入口：`D:/lovegirl_flutter/lib/main.dart`
- 当前统一 API 层：`D:/lovegirl_flutter/lib/services/api_service.dart`
- 后端统一入口：`D:/lovegirl_flutter/server_fixes/app.js`
- 迁移基础：`D:/lovegirl_flutter/server_fixes/lovegirl_full_migration.sql`

已见到的后端路由挂载包括：

- `/api/auth`
- `/api/user`
- `/api/home`
- `/api/feeding`
- `/api/travel`
- `/api/period`
- `/api/todo`
- `/api/finance`
- `/api/course`
- `/api/photo`
- `/api/mood`
- `/api/chat`
- `/api/timeline`
- `/api/weather`
- `/api/version`
- `/api/beans`
- `/api/achievements`
- `/api/anniversary`
- `/api/couple`

## 3. Domain 映射总览

LoveGirl 后续建议按下面这些域组织：

1. App Shell / Platform
2. Home
3. Feeding
4. Travel
5. Life
6. Memory
7. Health
8. Relationship

## 4. App Shell / Platform

### 责任

- 登录态
- 启动流程
- 底部导航
- 主题
- 版本检查
- 通知初始化

### 当前前端落点

- `D:/lovegirl_flutter/lib/main.dart`
- `D:/lovegirl_flutter/lib/providers/auth_provider.dart`
- `D:/lovegirl_flutter/lib/providers/theme_provider.dart`
- `D:/lovegirl_flutter/lib/screens/version/update_dialog.dart`
- `D:/lovegirl_flutter/lib/services/notification_service.dart`

### 目标前端结构

- `app/app_shell.dart`
- `app/app.dart`
- `core/theme/`
- `core/network/`

### 后端契约

- `/api/auth`
- `/api/user`
- `/api/version`

### 主要风险

- 壳层逻辑继续堆在 `main.dart`
- 版本检查、登录切换、导航切换互相缠绕

## 5. Home Domain

### 责任

- 恋爱天数摘要
- 天气与体感温度
- 今日照顾卡
- 回忆票根
- 旅行票根
- 生活摘要
- 快捷入口

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/home/home_screen.dart`
- `D:/lovegirl_flutter/lib/providers/home_provider.dart`
- `D:/lovegirl_flutter/lib/widgets/weather_widget.dart`

### 目标前端状态与服务

- `HomeProvider`
- `HomeSummaryProvider`
- `HomeService`

### 当前 / 目标后端契约

- `/api/home`
- `/api/weather`
- 读取其他域的摘要数据，不直接承担复杂业务写入

### 主要数据来源

- 关系数据
- 天气接口
- 纪念日摘要
- 课程摘要
- 待办摘要
- 旅行摘要
- 投喂摘要

### 联动关系

- 读 `Memory`
- 读 `Life`
- 读 `Travel`
- 读 `Feeding`
- 读 `Relationship`

## 6. Feeding Domain

### 责任

- 店铺
- 商品
- 下单
- 订单追踪
- 男友端履约记录
- 平台、真实金额、备注
- 催单提醒
- 爱心豆抵扣展示

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/feeding/feeding_screen.dart`
- `D:/lovegirl_flutter/lib/services/api_service.dart`

### 目标前端状态与服务

- `FeedingProvider`
- `BeanProvider`
- `FeedingService`
- `BeanService`

### 当前 / 目标后端契约

- `/api/feeding`
- `/api/beans`
- `/api/notifications`

### 主要表方向

- `feeding_shops`
- `feeding_products`
- `feeding_orders`
- `bean_transactions`
- 用户余额缓存字段

### 联动关系

- 写 `Finance`
- 写 `Memory/Timeline`
- 读 `Health/Period` 推荐状态

### 特别说明

- 当前后端存在 `feeding.js` 与 `feeding_v2.js` 双轨痕迹
- 目标是统一到 v2

## 7. Travel Domain

### 责任

- 旅行预览页
- 真地图模式
- 地点管理
- 路线规划
- 旅行花费
- 打卡
- 旅行小票 / 票根
- 成就

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/travel/travel_main_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_amap_mode_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_form_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/map_picker_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_ticket_screen.dart`
- `D:/lovegirl_flutter/lib/providers/travel_provider.dart`
- `D:/lovegirl_flutter/lib/widgets/travel_map_widget.dart`

### 目标前端状态与服务

- `TravelProvider`
- `TravelService`

### 当前 / 目标后端契约

- `/api/travel`
- `/api/travel` 下的照片能力
- 高德 Web 服务代理接口：
  - POI
  - 地理编码 / 逆地理编码
  - 路线规划
  - 天气

### 主要表方向

- `travel_spots`
- `travel_photos`
- `travel_routes`
- `travel_route_spots`
- `travel_trips`
- `travel_expenses`
- `travel_tickets`
- `travel_achievements`

### 联动关系

- 写 `Finance`
- 写 `Memory/Timeline`
- 写 `Achievements`
- 读 `Home` 摘要

## 8. Life Domain

### 责任

- 待办
- 愿望清单
- 记账
- 课程表

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/life/life_screen.dart`
- `D:/lovegirl_flutter/lib/screens/life/widgets/finance_list.dart`
- `D:/lovegirl_flutter/lib/screens/life/widgets/schedule_list.dart`
- `D:/lovegirl_flutter/lib/screens/life/widgets/todo_list.dart`
- `D:/lovegirl_flutter/lib/screens/tasks/tasks_screen.dart`
- `D:/lovegirl_flutter/lib/screens/tasks/task_form.dart`

### 目标前端状态与服务

- `TodoProvider`
- `WishlistProvider`
- `FinanceProvider`
- `ScheduleProvider`
- `TodoService`
- `WishlistService`
- `FinanceService`
- `ScheduleService` 或 `CourseService`

### 当前 / 目标后端契约

- `/api/todo`
- `/api/finance`
- `/api/course`

### 主要表方向

- `todos`
- `wishlists`
- `finance_records`
- `courses`

### 联动关系

- 被 `Home` 读取摘要
- 接收 `Feeding` 写入记账
- 接收 `Travel` 写入记账
- 触发 `Beans` 奖励

### 特别说明

- 当前 `finance.js` 仍残留卡路里联动
- 后续删除卡路里时要保证 `Finance` 主流程不受伤

## 9. Memory Domain

### 责任

- 相册
- 旅行照片整合
- 纪念日
- 倒数日整合
- 心情日记
- 时光轴
- 随机回忆
- 月度报告

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/photo/photo_screen.dart`
- `D:/lovegirl_flutter/lib/screens/anniversary/anniversary_screen.dart`
- `D:/lovegirl_flutter/lib/screens/countdown/countdown_screen.dart`
- `D:/lovegirl_flutter/lib/screens/countdown/countdown_form.dart`
- `D:/lovegirl_flutter/lib/screens/mood/*`
- `D:/lovegirl_flutter/lib/screens/timeline/*`

说明：

- `lib/screens/album` 当前是空目录

### 目标前端状态与服务

- `AlbumProvider`
- `AnniversaryProvider`
- `MoodProvider`
- `TimelineProvider`
- `AlbumService`
- `AnniversaryService`
- `MoodService`
- `TimelineService`

### 当前 / 目标后端契约

- `/api/photo`
- `/api/anniversary`
- `/api/mood`
- `/api/timeline`

### 主要表方向

- `albums`
- `album_photos`
- `anniversaries`
- `timeline_events`
- `mood_diary`
- 以及旅行沉淀数据

### 联动关系

- 接收 `Travel` 打卡沉淀
- 接收 `Feeding` 里程碑沉淀
- 被 `Home` 读取回忆摘要

## 10. Health Domain

### 责任

- 经期记录
- 痛经与症状
- 周期状态
- 对投喂推荐的轻联动

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/health/health_screen.dart`
- `D:/lovegirl_flutter/lib/screens/health/widgets/period_tracker.dart`

### 目标前端状态与服务

- `PeriodProvider`
- `PeriodService`

### 当前 / 目标后端契约

- `/api/period`

### 主要数据要求

- 敏感数据加密存储
- 鉴权
- 女友可写权限

### 联动关系

- 向 `Feeding` 暴露推荐状态

## 11. Relationship Domain

### 责任

- 私密聊天
- 伴侣绑定
- 爱心豆账户关系面展示
- 关系摘要

### 当前前端落点

- `D:/lovegirl_flutter/lib/screens/chat/*`
- `D:/lovegirl_flutter/lib/screens/couple/*`
- `D:/lovegirl_flutter/lib/screens/profile/profile_screen.dart`

### 目标前端状态与服务

- `ChatProvider`
- `CoupleProvider`
- `ChatService`
- `CoupleService`

### 当前 / 目标后端契约

- `/api/chat`
- `/api/couple`
- `/api/privacy`
- `/api/beans`

### 主要表方向

- `users`
- `couples`
- `couple_invites`
- 关系扩展字段

### 联动关系

- 向 `Home` 提供关系摘要
- 向 `Profile` 提供关系与绑定状态

## 12. Cross-Domain 基础契约

下面这些东西不应该再被任何单个业务域独占：

### 统一请求层

- `D:/lovegirl_flutter/lib/services/api_service.dart`

定位：

- 只做 transport 层
- 不继续膨胀成全业务中心

### 统一设计系统

- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/widgets/organic_ui.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`

定位：

- 负责共享 UI 语言
- 不承担业务规则

### 统一安全底线

必须跨域共享：

- 鉴权
- 角色权限
- 上传校验
- 敏感数据加密

## 13. 当前阶段结论

截至 2026-07-17，这份文档已经把 LoveGirl 的后续实现，从“页面级计划”进一步推进成了“domain 级前后端契约图”。

后续编码时，应该优先按这个映射拆任务，而不是继续围绕单个大文件堆功能。
