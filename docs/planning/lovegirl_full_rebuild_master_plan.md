# LoveGirl 全量重构总方案

更新时间：2026-07-17
适用阶段：方案确认阶段（当前不写业务代码）

## 1. 当前总目标

把 LoveGirl 从“功能很多但体验分散、中文不稳定、模块关系松散”的私人情侣 App，重构成一套：

- UI 统一
- 中文干净
- 核心链路可信
- 模块边界清楚
- 后续容易继续加功能
- 可真机验收
- 可发布上线

这次不是零碎修补，而是一次“有主线的收口重构”。

主线只有三条：

1. 把最重要的 4 个核心体验做对：`首页 / 投喂站 / 旅行地图 / 我的`
2. 把重复模块、无效模块、半成品入口清理干净
3. 把前后端结构整理成以后还能继续长功能的样子

## 2. 这轮方案的边界

### 本轮必须覆盖

- UI 统一方案
- 功能保留 / 合并 / 删除方案
- 前端目录与状态管理重组方案
- 后端路由与服务重组方案
- 模块联动方案
- 爱心豆经济系统方案
- 旅行地图高德方案
- 分阶段实施顺序
- 验收与发布标准

### 本轮先不做的事

- 不在方案阶段直接写业务代码
- 不在方案阶段直接构建正式 APK
- 不在没有真机验收前直接发布新版本

## 3. 设计与工程总原则

### 3.1 产品原则

- 这是“你给女朋友做的真实工具”，不是模板化情侣壳子 App
- 功能要围绕“真的会用”展开，不做堆入口式炫技
- 情绪感要有，但不能影响实用性
- 每个页面都要让人看得懂、用得顺、愿意继续点

### 3.2 UI 原则

- 统一采用已经确认的“回忆票根 / 专属菜单 / 温暖纸感”方向
- 不走办公软件感
- 不走花哨粉色堆叠
- 不走模板商城感
- 页面需要精致，但不是装饰过量

### 3.3 架构原则

- 先做稳定结构，再做视觉和功能补齐
- 模块边界明确，便于以后继续加功能
- 共用逻辑上提，业务逻辑下沉到模块内
- UI、状态、服务、模型四层要分开
- 尽量避免“一个超大文件全包”的继续扩张

### 3.4 可添加性原则

以后新增功能时，应该能按“新模块接入”而不是“到处打补丁”的方式增加。

为此要提前满足：

- 前端按 domain 划分目录
- 每个 domain 自己管理 `models / providers / services / widgets / screens`
- 后端按 `routes / services / middleware / db` 分层
- 联动能力通过事件或统一同步层接入
- 通用 UI 组件和设计 token 独立
- 首页聚合层只读各模块摘要，不反向承担业务逻辑

## 4. 最终产品结构

LoveGirl 最终应当收束成 7 个大域，而不是一堆平铺入口。

### 4.1 App Shell

负责：

- 登录态与启动流程
- 底部导航
- 全局主题
- 全局通知
- 全局版本更新

### 4.2 Home Domain

负责：

- 恋爱天数头部
- 今日摘要
- 天气卡片
- 回忆票根
- 旅行摘要
- 生活摘要
- 快捷入口

### 4.3 Feeding Domain

负责：

- 店铺
- 商品
- 下单
- 订单追踪
- 男友端履约信息
- 催单提醒
- 爱心豆抵扣展示
- 投喂与记账 / 时光轴联动

### 4.4 Travel Domain

负责：

- 旅行主页预览
- 高德真地图模式
- 地点管理
- 路线规划
- 旅行花费
- 打卡
- 旅行小票 / 票根
- 成就
- 与记账 / 时光轴 / 首页联动

### 4.5 Life Domain

负责：

- 待办
- 愿望清单
- 记账
- 课程表

说明：这几个功能都属于“共同生活计划”，但仍然保留各自职责。

### 4.6 Memory Domain

负责：

- 相册
- 旅行照片
- 心情日记
- 纪念日
- 倒数日
- 恋爱时光轴
- 随机回忆
- 月度报告

### 4.7 Relationship / Health Domain

负责：

- 私密聊天
- 伴侣绑定
- 经期管理
- 隐私与权限控制

## 5. 模块保留、合并、删除的总决定

## 5.1 强保留模块

- 投喂站
- 旅行地图
- 首页
- 我的页
- 私密聊天
- 伴侣绑定
- 经期管理
- 记账
- 课程表
- 心情日记
- 恋爱时光轴

这些模块有真实使用场景，且能够支撑“情侣 App 的独特性”。

## 5.2 合并模块

### 纪念日 + 倒数日

合并成一个模块，名称仍可保留“纪念日”。

内部提供两种视图：

- 纪念事件
- 倒数目标

理由：

- 数据模型接近
- 交互接近
- 独立存在会造成重复维护

### 相册 + 照片

合并成一个“相册”模块。

内部再按来源分组：

- 日常相册
- 旅行相册
- 时间线沉淀照片

理由：

- 两者本质都在管理图片资产
- 分开只会造成重复上传、重复展示、重复路由

## 5.3 不建议完全合并的模块

### 待办 + 愿望清单

不建议直接合成一个完全同质的列表。

更合理的做法：

- 放在同一个 Life 域
- 共用 UI 和数据结构的一部分
- 但保留两个子模块

原因：

- 待办是短周期、执行型、可完成型事项
- 愿望清单是长周期、期待型、规划型事项
- 它们确实有关联，但不属于完全同一类心智模型

最终形态：

- 生活页里统一入口
- 默认先看到“待办”
- 可切到“愿望”
- 两者可互相转换

## 5.4 删除模块

- 全局搜索
- 卡路里追踪

删除要求：

- 前端入口删干净
- Provider / Service / API 方法删干净
- 后端路由与无用 SQL 一并清理
- 不留下“死页面、死菜单、死调用”

## 6. UI 总方案

## 6.1 确认方向

以你确认的参考图为母版，整套界面统一往以下语言靠拢：

- 回忆票根
- 纸感卡片
- 专属菜单
- 轻生活档案夹

## 6.2 四个核心页面的目标

### 首页

首页不是九宫格入口，而是一张恋爱生活摘要票根。

应包含：

- 顶部恋爱天数与天气
- 今日照顾卡
- 回忆票根
- 旅行票根
- 生活摘要
- 精简快捷入口

### 投喂站

投喂站不是商城，而是她的专属菜单。

目标体验：

- 她点单时像真的在叫你买东西
- 店铺和商品都像认真编排过的菜单
- 订单状态像真实履约过程

### 旅行地图

旅行地图不是瓦片截图页，而是“旅行地图产品 + 票根详情”。

目标体验：

- 首页预览先有旅行氛围
- 真地图模式再进入高德原生地图
- 点位、路线、票根、花费、天气统一承载

### 我的页

“我的”不是设置堆场，而是“我们的关系资料夹”。

优先展示：

- 两人关系状态
- 爱心豆
- 伴侣绑定
- 通知与隐私
- 数据与版本

## 7. 前端重构方案

## 7.1 当前问题

从现有结构看，`lib/screens` 模块已经很多，但 `lib/providers` 只有：

- `auth_provider.dart`
- `home_provider.dart`
- `theme_provider.dart`
- `travel_provider.dart`

这说明当前页面数量和状态管理颗粒度并不匹配，后续再加功能会越来越难维护。

同时，`lib/main.dart` 仍承担了较多启动和壳层逻辑，而且存在中文乱码遗留。

## 7.2 目标目录结构

建议最终演进到：

```text
lib/
  app/
    app.dart
    app_shell.dart
    routes.dart
  core/
    constants/
    theme/
    network/
    widgets/
    utils/
  domains/
    home/
      models/
      providers/
      services/
      widgets/
      screens/
    feeding/
      ...
    travel/
      ...
    life/
      todo/
      wishlist/
      finance/
      schedule/
    memory/
      album/
      anniversary/
      timeline/
      mood/
    health/
      period/
    relationship/
      couple/
      chat/
      bean/
```

这不是要求一次性大搬家，而是作为最终目标结构。

## 7.3 Provider 目标拆分

建议逐步补齐：

- `AuthProvider`
- `ThemeProvider`
- `HomeProvider`
- `FeedingProvider`
- `TravelProvider`
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

同时允许再有 1 个聚合层：

- `HomeSummaryProvider`

这个 Provider 只做摘要拼装，不承担底层业务逻辑。

## 7.4 Service 层原则

保留 `ApiService` 作为底层 HTTP 传输层，但不再让它继续无限膨胀成“全站业务中心”。

后续应补上按模块划分的上层 service：

- `HomeService`
- `FeedingService`
- `TravelService`
- `FinanceService`
- `TodoService`
- `WishlistService`
- `AlbumService`
- `AnniversaryService`
- `TimelineService`
- `PeriodService`
- `BeanService`

关系：

- `ApiService` 负责通用请求
- Domain Service 负责业务 API 组合
- Provider 负责状态与页面交互

## 8. 后端重构方案

## 8.1 当前问题

`server_fixes` 里已有大量文件：

- `feeding_v2.js`
- `travel.js`
- `travel_photos.js`
- `beans.js`
- `weather.js`
- `finance.js`
- `timeline.js`
- `anniversary.js`
- `todo.js`
- `couple.js`
- 等等

但当前入口 `server_fixes/app.js` 仍是一个巨型集中挂载点，且存在：

- 中文乱码
- 路由目录假设与实际文件组织不完全一致
- 维护成本高

## 8.2 后端最终结构目标

建议最终整理为：

```text
server/
  app.js
  routes/
    auth/
    home/
    feeding/
    travel/
    life/
    memory/
    relationship/
    health/
  services/
  middleware/
  db/
    migrations/
    seeds/
    queries/
  utils/
```

## 8.3 路由策略

按业务域拆：

- `/api/home`
- `/api/feeding`
- `/api/travel`
- `/api/finance`
- `/api/todo`
- `/api/wishlist`
- `/api/course`
- `/api/anniversary`
- `/api/album`
- `/api/timeline`
- `/api/mood`
- `/api/period`
- `/api/couple`
- `/api/chat`
- `/api/beans`
- `/api/weather`

## 8.4 关键后端原则

- 所有敏感路由默认鉴权
- 参数化查询
- 文件上传校验类型
- 中文响应文案统一
- 平台 Key 放环境变量
- 高德 Web API 只走后端代理，不写进 Flutter 前端

## 9. 数据模型方向

## 9.1 已确认的重要表方向

当前迁移文件已经体现出一部分目标表设计，包括：

- `feeding_shops`
- `feeding_products`
- `feeding_orders`
- `bean_transactions`
- `travel_spots`
- `travel_photos`
- `travel_routes`
- `travel_route_spots`
- `travel_trips`

这些方向应保留。

## 9.2 建议的数据域

### 用户与关系

- `users`
- `couples`
- `couple_invites`

### 投喂

- `feeding_shops`
- `feeding_products`
- `feeding_orders`
- `feeding_order_status_logs`

### 爱心豆

- `bean_transactions`
- 用户余额字段可缓存到 `users.bean_balance`

### 旅行

- `travel_trips`
- `travel_spots`
- `travel_routes`
- `travel_route_spots`
- `travel_photos`
- `travel_expenses`
- `travel_achievements`

### 生活

- `todos`
- `wishlists`
- `finance_records`
- `courses`

### 回忆

- `albums`
- `album_photos`
- `anniversaries`
- `timeline_events`
- `mood_diary`
- `memory_cards`

## 10. 模块联动方案

联动必须有意义，不能为了“看起来高级”而硬连。

## 10.1 第一批必须做的联动

### 投喂站 -> 记账

订单完成后自动写入记账：

- 类别：投喂
- 标题：商品名或订单摘要
- 金额：真实支付金额
- 来源：`feeding_order`

### 旅行 -> 记账

旅行内记录花费时，同时同步到记账：

- 类别：交通 / 门票 / 餐饮 / 住宿
- 所属旅行
- 来源：`travel_expense`

### 旅行 -> 时光轴

打卡后可自动生成时间线条目：

- 地点
- 照片
- 心情 / 备注

### 投喂站 -> 时光轴

里程碑订单自动沉淀：

- 第一次投喂
- 第 100 次投喂
- 深夜投喂

### 经期 -> 投喂站

在推荐层联动，不在权限层强制：

- 热饮上浮
- 冰饮降权
- 可出现轻提示

### 纪念日 / 课程表 / 待办 -> 首页

首页只显示摘要：

- 3 天内纪念日
- 今日课程
- 未完成待办

## 10.2 联动实现原则

- 写入方负责落库
- 读取方负责展示
- 通过统一联动服务触发
- 首页只读摘要，不写业务数据

## 11. 爱心豆总方案

爱心豆不应该阻止她下单，而应成为“你们关系里真实可感知的奖励系统”。

## 11.1 定位

更像：

- 成就值
- 仪式感积分
- 可用于小额抵扣的心意券

而不是：

- 必须攒够才能点单的余额墙

## 11.2 赚取方式

第一批建议保留：

- 每日签到
- 完成待办
- 记录心情
- 纪念日当天
- 连续签到奖励
- 打卡旅行地点

## 11.3 消费方式

第一优先是投喂站抵扣。

规则建议：

- 不影响正常下单
- 按比例抵扣真实金额
- 抵扣额有上限
- 明确展示本次用了多少豆、抵了多少钱

## 11.4 数据结构

- 用户余额缓存字段
- 交易流水表
- 来源类型
- 来源业务 ID
- 正负变动
- 备注

## 11.5 UI 位置

- 首页头部可见余额摘要
- 投喂站下单弹窗可见本次抵扣
- 我的页可查看余额和流水

## 12. 旅行地图高德方案

## 12.1 方案结论

废弃 `flutter_map + 高德瓦片` 方案，统一改走高德 Android 原生 SDK 路线。

## 12.2 地图方案组成

- Flutter 主地图组件：`amap_flutter_map`
- 路线 / POI / 地理编码 / 天气：高德 Web 服务 API
- 导航：分阶段接 Android 导航 SDK

## 12.3 分阶段落地

### 第一阶段

- 真地图稳定显示
- 蓝点 / 定位 / 精度圈
- 地点 Marker
- 路线折线预览
- 底部票根详情
- 高德路线查询代理

### 第二阶段

- 接 Android 导航 SDK
- 通过 Platform Channel 启动导航
- 返回导航开始 / 取消 / 到达等状态

## 12.4 地图页视觉目标

- 第一眼像真实地图产品
- 不是低质瓦片截图
- 地图上方为轻量浮层
- 点位点击后平滑移动
- 底部抽屉保持票根风格

## 13. 实施顺序

## 阶段 A：结构与清理

- 梳理模块边界
- 确认保留 / 合并 / 删除清单
- 建立新文档基线

## 阶段 B：设计系统

- 统一主题
- 统一卡片
- 统一按钮 / 标签 / 底部抽屉 / 空状态

## 阶段 C：核心页面

- 首页
- 投喂站
- 旅行地图
- 我的页

## 阶段 D：生活与回忆

- 记账
- 待办
- 愿望清单
- 课程表
- 相册
- 纪念日
- 时光轴
- 心情日记

## 阶段 E：联动与经济系统

- 爱心豆
- 自动记账
- 自动时光轴
- 首页摘要联动

## 阶段 F：地图深水区

- 高德真地图真机验收
- 路线规划
- 导航能力

## 阶段 G：发布准备

- 分析通过
- 关键流程走通
- 真机验收
- 服务器部署
- 版本发布

## 14. 完成定义

只有同时满足下面这些条件，目标才算完成：

- UI 与确认方向一致
- 中文无明显乱码
- 首页天气稳定且不溢出
- 投喂站主流程可用
- 旅行地图高德模式不崩溃
- 核心联动可用
- 删除模块已清干净
- 真机可验收
- 服务器已部署正确版本
- 版本可正常更新

在这些条件同时满足前，都不能算“真正完成”。
