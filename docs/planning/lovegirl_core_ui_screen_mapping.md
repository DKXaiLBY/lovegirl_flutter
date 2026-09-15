# LoveGirl 核心 UI 页面落点映射

更新时间：2026-07-17
适用阶段：方案确认阶段（当前不写业务代码）

## 1. 文档目的

这份文档回答一个很实际的问题：

“后面要把确认过的 UI 真正装进 App，到底应该改哪些文件？”

它不是设计稿，也不是实现代码，而是把：

- 已确认的目标体验
- 当前仓库里的真实页面文件
- 相关的 widget / provider / service

一一对应起来。

## 2. 核心页面总览

本轮最高优先级的 4 个页面是：

1. 首页
2. 投喂站
3. 旅行地图
4. 我的页

它们是整套 UI 的母版页，也是后续视觉统一最重要的落点。

## 3. 首页映射

### 目标体验

- 第一屏贴近已确认的首页参考图
- 恋爱天数、天气、体感温度布局稳定
- 今日照顾卡有情绪价值但不花哨
- 回忆票根、旅行票根、生活摘要票根统一
- 所有中文正常可读

### 主要文件

- `D:/lovegirl_flutter/lib/screens/home/home_screen.dart`

### 直接相关文件

- `D:/lovegirl_flutter/lib/providers/home_provider.dart`
- `D:/lovegirl_flutter/lib/widgets/weather_widget.dart`
- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`
- `D:/lovegirl_flutter/lib/services/api_service.dart`

### 后续落地时应拆分的子区域

- 顶部关系头部
- 天气与爱心豆区
- 今日照顾卡
- 回忆票根
- 旅行票根
- 生活摘要
- 快捷入口

### 风险点

- 天气卡信息拥挤
- 图标气质容易回退成普通 Material 页面
- 首页聚合过多时容易重新变回功能看板

## 4. 投喂站映射

### 目标体验

- 像她的专属菜单，而不是普通商城
- 店铺、商品、下单、订单追踪是一条完整体验链
- 她点单时像真的在叫你买东西
- 你履约时可以记录平台、金额、备注、状态
- 爱心豆表现为激励与抵扣，不阻止下单

### 主要文件

- `D:/lovegirl_flutter/lib/screens/feeding/feeding_screen.dart`

### 直接相关文件

- `D:/lovegirl_flutter/lib/services/api_service.dart`
- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`
- `D:/lovegirl_flutter/lib/services/notification_service.dart`

### 后续落地时应拆分的子区域

- 店铺列表
- 商品列表
- 商品详情卡
- 下单确认层
- 订单状态卡
- 催单操作区
- 男友端履约记录区

### 后续应该新增的状态层

- `FeedingProvider`
- `BeanProvider`

### 后续应该新增的服务层

- `FeedingService`
- `BeanService`

### 风险点

- 单文件继续膨胀
- 订单状态、爱心豆、通知逻辑混在页面层
- UI 细节容易被业务逻辑牵着走

## 5. 旅行地图映射

### 目标体验

- 预览页先成立
- 真地图模式走高德原生 SDK
- 有地点时看点位、路线、详情
- 无地点时有引导，不直接进死路
- 地图交互要有平滑移动和更自然反馈
- 底部详情抽屉保持票根感

### 主要文件

- `D:/lovegirl_flutter/lib/screens/travel/travel_main_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_amap_mode_screen.dart`

### 次级页面文件

- `D:/lovegirl_flutter/lib/screens/travel/travel_form_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/map_picker_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_ticket_screen.dart`

### 直接相关文件

- `D:/lovegirl_flutter/lib/providers/travel_provider.dart`
- `D:/lovegirl_flutter/lib/widgets/travel_map_widget.dart`
- `D:/lovegirl_flutter/lib/widgets/travel_photo_grid.dart`
- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/utils/amap_api.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`
- `D:/lovegirl_flutter/lib/services/api_service.dart`

### 后续落地时应拆分的子区域

- 旅行首页票根预览
- 真地图模式容器
- 浮动控件区
- 路线预览卡
- 地点详情抽屉
- 打卡 / 照片区
- 花费 / 成就入口

### 后续应该新增的服务层

- `TravelService`
- 后端高德代理服务

### 风险点

- 地图模式稳定性优先级高于视觉修饰
- 路线、详情、双人标记、天气都往里塞时容易让页面再次过重

## 6. 我的页映射

### 目标体验

- 像关系资料夹，不像设置堆场
- 上半部分先看关系、爱心豆、绑定状态
- 中段再看通知、隐私、安全、偏好
- 下段再看版本、数据、更新

### 主要文件

- `D:/lovegirl_flutter/lib/screens/profile/profile_screen.dart`

### 次级页面文件

- `D:/lovegirl_flutter/lib/screens/profile/achievements_screen.dart`
- `D:/lovegirl_flutter/lib/screens/profile/admin_feeding_screen.dart`

### 直接相关文件

- `D:/lovegirl_flutter/lib/providers/auth_provider.dart`
- `D:/lovegirl_flutter/lib/providers/home_provider.dart`
- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`
- `D:/lovegirl_flutter/lib/services/api_service.dart`

### 后续落地时应拆分的子区域

- 顶部关系 Hero
- 爱心豆与签到区
- 伴侣绑定区
- 通知 / 隐私 / 安全区
- 数据 / 版本 / 更新区

### 后续应该新增的状态层

- `CoupleProvider`
- `BeanProvider`

### 风险点

- 很容易又被塞回一堆功能按钮
- 次级页如果风格不统一，会破坏“资料夹”整体感

## 7. 共同依赖映射

下面这些文件会横跨多个核心页面：

- `D:/lovegirl_flutter/lib/widgets/lovegirl_ui.dart`
- `D:/lovegirl_flutter/lib/widgets/organic_ui.dart`
- `D:/lovegirl_flutter/lib/widgets/empty_state.dart`
- `D:/lovegirl_flutter/lib/utils/lovegirl_theme.dart`
- `D:/lovegirl_flutter/lib/services/api_service.dart`

这些文件的定位应当是：

- 承担共用设计语言
- 承担通用 UI 资产
- 不承担具体业务判断

## 8. 当前阶段结论

截至 2026-07-17，这份映射文档已经把“要改哪几页”进一步落实成了“要改哪几个真实文件、相关依赖在哪里”。

后续进入实现阶段后，可以直接按这份映射来拆任务，而不用再从零找页面文件。
