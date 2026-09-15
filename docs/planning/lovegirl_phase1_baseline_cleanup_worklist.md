# LoveGirl Phase 1 工程基线清理工单

更新时间：2026-07-17
适用阶段：方案确认阶段（当前不写业务代码）

## 1. 文档定位

这份文档是 `M1 工程基线清理` 的直接施工清单。

它和前面的方案文档不同：

- 不是讲方向
- 不是讲里程碑
- 而是讲“后面一开工先从哪些文件和目录下手”

## 2. 当前已知的结构起点

基于当前仓库证据：

- `lib/screens` 下有 21 个模块目录
- `lib/providers` 下只有 4 个 Provider 文件
- `lib/services` 下只有 3 个 service 文件
- `lib/screens/album` 目前是空目录
- `lib/screens/search` 目前是空目录
- `lib/screens/photo` 目前由 `photo_screen.dart` 承担图片入口
- `lib/screens/countdown` 目前有 `countdown_screen.dart` 和 `countdown_form.dart`
- `lib/screens/anniversary` 目前有 `anniversary_screen.dart`
- `lib/screens/tasks` 目前有 `tasks_screen.dart` 和 `task_form.dart`
- `lib/screens/life` 目前有 `life_screen.dart` 及 `finance / schedule / todo` 小组件

这些都说明：第一阶段不是“想象中的清理”，而是有明确目标目录可查的清理。

## 3. Phase 1 总目标

在不新增业务功能的前提下，把当前工程基线清理到下面这种状态：

- 模块边界更清楚
- 重复入口更少
- 删除目标更明确
- 后续 Provider / Service 拆分有落点
- 旧目录和空目录不再干扰实施判断

## 4. 前端清理工单

## 4.1 App 壳层与主入口

目标文件：

- `D:/lovegirl_flutter/lib/main.dart`

清理任务：

- 识别 App 壳层逻辑与页面逻辑的边界
- 标记后续应迁移到 `app_shell` 的逻辑
- 标记当前底部导航与目标信息架构的差距
- 标记仍在主入口里承担的版本检查、登录切换、子 tab 跳转逻辑

本阶段输出：

- 一份 `main.dart` 责任拆分表

## 4.2 Provider 基线

目标目录：

- `D:/lovegirl_flutter/lib/providers`

当前证据：

- 只有 `auth / home / theme / travel`

清理任务：

- 列出现有 Provider 负责范围
- 列出缺失 Provider 清单：
  - `FeedingProvider`
  - `FinanceProvider`
  - `TodoProvider`
  - `WishlistProvider`
  - `ScheduleProvider`
  - `AnniversaryProvider`
  - `AlbumProvider`
  - `TimelineProvider`
  - `MoodProvider`
  - `PeriodProvider`
  - `CoupleProvider`
  - `ChatProvider`
  - `BeanProvider`
- 标记这些 Provider 后续分别挂在哪些 screen / domain 上

本阶段输出：

- 一份 Provider 补齐清单

## 4.3 Service 基线

目标目录：

- `D:/lovegirl_flutter/lib/services`

当前证据：

- `api_service.dart`
- `log_service.dart`
- `notification_service.dart`

清理任务：

- 明确 `ApiService` 保留为底层 transport 层
- 列出未来要新增的 domain service：
  - `HomeService`
  - `FeedingService`
  - `TravelService`
  - `FinanceService`
  - `TodoService`
  - `WishlistService`
  - `AlbumService`
  - `AnniversaryService`
  - `TimelineService`
  - `BeanService`
- 标记哪些现有 API 方法应在后续迁移出“巨石式单文件”

本阶段输出：

- 一份 service 拆分清单

## 4.4 核心页面目标文件

优先关注文件：

- `D:/lovegirl_flutter/lib/screens/home/home_screen.dart`
- `D:/lovegirl_flutter/lib/screens/feeding/feeding_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_main_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_amap_mode_screen.dart`
- `D:/lovegirl_flutter/lib/screens/profile/profile_screen.dart`

清理任务：

- 标记每个核心页面当前承担的责任
- 标记页面内哪些部分属于“UI 结构”，哪些部分属于“业务状态”
- 标记哪些代码块后续应下沉到 widgets / provider / service

本阶段输出：

- 一份核心页责任拆分笔记

## 4.5 重复与空目录处理

### `album`

路径：

- `D:/lovegirl_flutter/lib/screens/album`

当前状态：

- 空目录

处理建议：

- 在 Phase 1 明确它是否保留为将来的统一相册 domain 占位
- 或直接移除空目录，等合并时再建立新结构

### `search`

路径：

- `D:/lovegirl_flutter/lib/screens/search`

当前状态：

- 空目录

处理建议：

- 因为全局搜索已确认删除，优先列为“直接清理对象”

### `photo`

路径：

- `D:/lovegirl_flutter/lib/screens/photo/photo_screen.dart`

处理建议：

- 标记为未来“统一相册”迁移源

### `anniversary + countdown`

路径：

- `D:/lovegirl_flutter/lib/screens/anniversary/anniversary_screen.dart`
- `D:/lovegirl_flutter/lib/screens/countdown/countdown_screen.dart`
- `D:/lovegirl_flutter/lib/screens/countdown/countdown_form.dart`

处理建议：

- 标记为统一纪念日模块的主要迁移源

### `life + tasks`

路径：

- `D:/lovegirl_flutter/lib/screens/life/life_screen.dart`
- `D:/lovegirl_flutter/lib/screens/life/widgets/*.dart`
- `D:/lovegirl_flutter/lib/screens/tasks/tasks_screen.dart`
- `D:/lovegirl_flutter/lib/screens/tasks/task_form.dart`

处理建议：

- Phase 1 必须先澄清职责边界
- 避免后续既保留 `life` 又继续平行扩张 `tasks`

## 4.6 UI 基础件

目标文件：

- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/widgets/organic_ui.dart`
- `D:/lovegirl_flutter/lib/widgets/empty_state.dart`
- `D:/lovegirl_flutter/lib/widgets/weather_widget.dart`
- `D:/lovegirl_flutter/lib/widgets/travel_map_widget.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`

清理任务：

- 标记哪些已经属于当前设计系统资产
- 标记哪些命名或职责还模糊
- 决定后续统一设计系统以哪套组件为主

本阶段输出：

- 一份设计系统保留资产清单

## 5. 后端清理工单

## 5.1 统一入口

目标文件：

- `D:/lovegirl_flutter/server_fixes/app.js`

清理任务：

- 列出现有 route 挂载清单
- 标记哪些 route 属于核心主线
- 标记哪些 route 属于后续删除对象
- 标记哪些 route 需要按业务域重新收口

本阶段输出：

- 一份后端路由盘点表

## 5.2 投喂 route 双轨处理

目标文件：

- `D:/lovegirl_flutter/server_fixes/feeding.js`
- `D:/lovegirl_flutter/server_fixes/feeding_v2.js`

清理任务：

- 确认 v1 / v2 当前各自承担什么
- 明确是否存在旧入口残留
- 为后续完全切换 v2 做迁移准备

本阶段输出：

- 一份 feeding v1 -> v2 替换清单

## 5.3 旅行图片与相册边界

目标文件：

- `D:/lovegirl_flutter/server_fixes/travel_photos.js`
- `D:/lovegirl_flutter/server_fixes/photo.js`

清理任务：

- 明确旅行照片和通用照片的后端关系
- 标记后续相册合并时的迁移风险

本阶段输出：

- 一份图片资产后端归属表

## 5.4 删除目标 route

Phase 1 需要重点确认：

- 当前是否仍存在全局搜索后端残留
- 当前是否仍存在卡路里相关后端残留
- 若不存在，要记录为“目录或历史需求残留，不再继续恢复”

本阶段输出：

- 一份删除目标确认表

## 5.5 数据迁移基线

目标文件：

- `D:/lovegirl_flutter/server_fixes/lovegirl_full_migration.sql`
- `D:/lovegirl_flutter/server_fixes/*.sql`

清理任务：

- 列出主迁移文件与补丁 SQL 的关系
- 标记哪些表已体现未来主结构
- 标记哪些 SQL 只是历史修补

本阶段输出：

- 一份迁移文件角色表

## 6. Phase 1 完成标准

只有满足下面这些条件，`M1 工程基线清理` 才算完成：

- 前端重复目录和空目录处理策略明确
- Provider 缺口列表完成
- Service 拆分列表完成
- 核心页责任拆分完成
- 后端路由盘点完成
- 投喂 v1 / v2 替换边界明确
- 相册 / 旅行照片边界明确
- 删除目标残留确认完成

## 7. 当前阶段结论

截至 2026-07-17，这份文档已经把 `M1` 从“一个抽象里程碑”推进成了“有文件目标的清理工单”。

后续一旦进入实现阶段，第一步就可以按这里列出的文件和目录逐项执行。
