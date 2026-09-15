# LoveGirl 票根系 UI 与旅行地图执行目标

日期：2026-07-20

## 一、已确认的 UI 基准

本轮 UI 不再重新发散，以两张本地参考图为最高参照：

- 首页基准图：`D:\lovegirl_flutter\docs\lovegirl-ui-home-09.png`
- 旅行地图基准图：`D:\lovegirl_flutter\docs\lovegirl-ui-home-06.png`

整体方向是“回忆票根 / 专属菜单 / 真实生活记录”。界面要温暖、精致、中文清楚，但不能粉、不能花、不能像办公软件。

## 二、首页目标

首页不是功能宫格，而是恋爱日常总览。

必须保留的结构：

- 顶部：`LoveGirl`、恋爱天数、天气、爱心豆。
- 今日照顾：投喂状态 + 待办清单。
- 随机回忆：照片、时间、地点、文字、生成回忆票根入口。
- 旅行计划：旅行票根卡，显示城市、日期、人数、进度、查看路线入口。
- 生活摘要：本月小账本、本周课程。
- 底部导航：中文、简洁、图标不能老土。

验收标准：

- 全部用户可见文字为中文。
- 天气卡必须包含体感温度，且不能溢出。
- 首页第一屏能看出“被认真照顾”的感觉，而不是普通工具首页。

## 三、旅行地图目标

旅行地图要做成“地图产品 + 情侣记录工具 + 行程票根”的结合体。

必须保留的页面结构：

- 顶部栏：返回、标题、搜索、更多。
- 状态筛选：`想去`、`计划中`、`已打卡`、`我们都编辑`。
- 地图画布：高德真地图、地点标记、路线连线、当前定位。
- 左侧工具：地图类型、定位、路线。
- 底部地点票根：封面、标题、地址、天气、日期、预算、共同编辑、备注。
- 底部操作：`加入路线`、`生成票根`、`记一笔花费`。
- 路线总览：按城市、日期、Day、地点顺序展示。

数据结构方向：

- 地点主状态：`wish` 想去、`planned` 计划中、`visited` 已打卡。
- `我们都编辑` 是叠加属性，不作为地点主状态。
- 双方备注分开保存，展示时合并在同一地点详情里。
- 路线需要独立数据，地点通过顺序和 Day 关联到路线。

验收标准：

- 点击旅行地图不会闪退。
- 无地点、无坐标、模拟器不支持高德原生地图时都有清楚中文兜底。
- 真地图模式不能出现乱码。
- 选中地点后要像参考图一样出现底部票根详情。
- 地图点和路线要能看出状态差异。

## 四、投喂站目标

投喂站要让她下单时感觉“这是真的在叫你买东西”，不是假商城。

必须保留的结构：

- 专属菜单：你预先配置常点商品。
- 她想吃：她临时新增的东西要特殊标注。
- 真实履约：接单、准备中、配送中、已完成。
- 真实平台信息：淘宝闪购 / 美团 / 京东外卖、真实金额、订单号、备注。
- 催单：触发真实通知，不能只是计数。

验收标准：

- 商品列表像专属菜单，不像普通商城。
- 订单状态中文清楚，没有乱码。
- 订单详情能看到真实平台信息。
- 催单失败不能破坏订单数据一致性。

## 五、我的页目标

我的页不要放杂乱入口，要像“关系资料夹”。

建议结构：

- 关系资料卡。
- 纪念日与倒数日合并入口。
- 相册、照片、旅行票根合并为回忆入口。
- 通知、桌面组件、版本更新、设置。

验收标准：

- 中文清楚。
- 入口层级少而稳。
- 不把所有功能平铺成设置列表。

## 六、功能收口目标

强烈保留：

- 投喂站。
- 旅行地图。
- 经期管理。
- 私密聊天。
- 伴侣绑定。
- 记账系统。
- 课程表。
- 心情日记。
- 纪念日/倒数日。
- 相册/照片/回忆票根。
- 恋爱时光轴。
- 首页。

合并：

- 纪念日 + 倒数日。
- 相册 + 照片 + 旅行票根。
- 待办和愿望清单不强行合并为一个概念，建议做成同一入口下的两个分区：日常待办、长期心愿。

删除：

- 全局搜索。
- 卡路里追踪。

## 七、P0 实施顺序

1. 修复旅行地图和高德真地图里的乱码。
2. 修复 `打开高德真地图` 的崩溃风险和无数据兜底。
3. 按参考图重排旅行地图主界面骨架。
4. 补齐地点票根详情中的天气、日期、预算、共同编辑、备注展示。
5. 补齐路线总览的视觉结构。
6. 回查首页、投喂站、我的页是否偏离参考图。
7. 运行 `flutter analyze` 和核心测试。

## 八、暂不作为本轮完成条件

- 正式发布 APK。
- 高德导航 SDK 完整语音导航。
- 真实外卖平台状态自动同步。
- 月度报告完整生成。
- 全量历史页面一次性翻新。

这些功能重要，但要在 P0 稳定后继续分阶段做。

## 九、2026-07-20 当前推进记录

已完成：

- 重建 `TravelProvider`，清除旅行状态层的乱码文案，补齐天气、双人备注、共同编辑、营业时间、路线 Day 等后续票根字段。
- 重建高德真地图页，清除无地点、无坐标、模拟器不支持、加载慢等兜底状态的乱码。
- 高德真地图页补上参考图里的浮层结构：顶部信息、左侧地图工具、底部路线票根、地点票根详情。
- 左侧地图工具中的地图类型、定位、路线按钮都接入真实操作。
- 旅行主页面筛选改成 `想去 / 计划中 / 已打卡 / 我们都编辑 / 全部`，其中 `我们都编辑` 作为叠加属性筛选。
- 地点卡和地点详情补充天气、预算、共同编辑、两人备注等关键信息。
- 核心 widget 测试假数据和断言改成干净中文，避免乱码再次被测试固化。

已验证：

- `flutter analyze lib\providers\travel_provider.dart lib\screens\travel\travel_main_screen.dart lib\screens\travel\travel_amap_mode_screen.dart lib\widgets\travel_map_widget.dart lib\screens\home\home_screen.dart lib\screens\feeding\feeding_screen.dart lib\screens\profile\profile_screen.dart lib\widgets\weather_widget.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`

仍未完成：

- 首页、投喂站、我的页还需要继续做更细的视觉贴图式对齐。
- `加入路线 / 生成票根 / 记一笔花费` 当前已有 UI 入口，但完整业务闭环还需要后端和记账联动继续补。
- 高德真地图最终稳定性仍需 Android 真机验证。

## 十、2026-07-22 当前推进记录

已完成：

- “我的页”继续按关系资料夹方向收口，不再把入口平铺成普通设置列表。
- 关系档案区把 `纪念日` 文案升级为 `纪念日与倒数`，并补充 `倒数日` 入口，承接“纪念日 + 倒数日”合并展示的产品方向。
- 回忆管理区补充 `相册与回忆照片`、`旅行票根` 入口，承接“相册 + 照片 + 旅行票根”合并展示的产品方向。
- `旅行票根` 入口直接跳到旅行地图主 tab，不新增空壳页面。
- 核心 widget 测试同步验证新的“回忆与管理 / 相册与回忆照片 / 旅行票根”结构。
- 回查天气紧凑卡片：当前已有接口超时、本地兜底、缓存恢复和体感温度内部标签，窄屏测试未发现溢出。
- 高德真地图地点底部票根的操作按钮不再全部误触发“编辑地点”：
  - `加入路线` 会按当前有效坐标地点生成步行路线预览，并提示路线状态。
  - `生成票根` 只允许已打卡地点进入正式旅行票根页，未打卡地点给明确中文提示。
  - `记一笔花费` 在记账联动未完成前给明确中文提示，不伪装成已完成闭环。
  - `编辑地点` 保留为单独按钮，避免操作含义混在一起。
- 旅行主界面的地点详情票根也同步修复同类问题：
  - `加入路线` 不再打开编辑表单，而是生成路线预览。
  - `生成票根` 不再打开编辑表单，而是根据打卡状态进入票根页或给提示。
  - `记一笔花费` 不再打开编辑表单，而是明确提示记账联动尚未完成。
  - 主界面和高德真地图页的地点详情操作语义保持一致。
- 投喂站订单详情继续向“真实履约”收口：
  - 男友端在 `配送中` 状态不再直接 `标记已完成`，必须走 `完成履约并记录真实信息`，补充真实平台、真实金额、平台订单号和备注。
  - `催单` 操作进入忙碌态，失败时给明确中文提示，不再静默失败。
  - 核心测试新增配送中订单用例，防止以后把真实履约入口退回成直接完成。
- 首页旅行票根继续向参考图收口：
  - 右侧条码旁的 `LOVEGIRL TRIP` 英文改为中文 `旅行 / 票根`。
  - 旅行票根拆成主内容和路线票根栏，窄屏时自动上下排，降低横向挤压和文字溢出风险。
  - 核心测试新增窄屏首页断言，确认 `旅行票根`、`查看路线` 可见，并确认旧英文票根文案不再出现。

已验证：

- `dart format lib\screens\profile\profile_screen.dart test\widget_test.dart`
- `flutter analyze lib\screens\profile\profile_screen.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`
- `flutter analyze`
- 精确扫描 `lib/`、`test/` 下 Dart 源码中的常见乱码字符：无命中。
- `dart format lib\screens\travel\travel_amap_mode_screen.dart`
- `flutter analyze lib\screens\travel\travel_amap_mode_screen.dart lib\providers\travel_provider.dart lib\screens\travel\travel_ticket_screen.dart lib\widgets\travel_map_widget.dart`
- `dart format lib\screens\travel\travel_main_screen.dart`
- `flutter analyze lib\screens\travel\travel_main_screen.dart lib\providers\travel_provider.dart lib\screens\travel\travel_ticket_screen.dart`
- `dart format lib\screens\feeding\feeding_screen.dart test\widget_test.dart`
- `flutter analyze lib\screens\feeding\feeding_screen.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`，当前 9 个测试通过。
- `dart format lib\screens\home\home_screen.dart test\widget_test.dart`
- `flutter analyze lib\screens\home\home_screen.dart test\widget_test.dart`
- `flutter analyze`
- 精确扫描 `lib/`、`test/` 下 Dart 源码中的常见乱码字符：无命中。

仍未完成：

- 还没有 Android 真机验证高德原生地图入口的实际运行稳定性。
- 首页、旅行地图、投喂站、我的页已经朝参考图靠拢，但仍需继续做截图级视觉对照，不能宣称“一模一样”。

## 十一、2026-07-27 当前推进记录

已完成：

- 公共票根条码组件 `LoveBarcode` 支持小宽度自适应，修复 36px 宽度下横向溢出的风险。
- 旅行路线票根里的 `Day 1` 可见英文改为 `第 1 天`，距离单位改为 `米 / 公里`。
- 高德真地图路线信息里的距离单位同步改为中文 `公里`。
- 高德定位精度显示从 `Xm` 改为 `X 米`，避免核心地图 UI 出现半英文单位。
- 旅行地点卡片的入场动画从不可取消的 `Future.delayed` 改为可取消的 `Timer`，修复页面销毁后仍残留定时器的问题。
- 高德原生插件 `AMapPlatformView.getView()` 增加中文错误视图兜底，地图构造失败或销毁后不再把空 View 交给 PlatformView 层。
- 首页 `LoveGirl` 标题行增加窄屏 `scaleDown`，360 逻辑宽下不再横向溢出。
- 首页紧凑天气卡宽度收敛到 170px，保留体感温度，同时避免和爱心豆栏挤出边界。
- 公共 `LovePill` 增加最大宽度和单行省略，避免长标签撑爆票根布局。
- 高德真地图模拟器兜底文案中的 `Android` 改为 `安卓真机`，原生错误视图中的 `高德 Key` 改为 `高德密钥`。
- 核心测试新增旅行路线票根中文时间线断言，防止后续把 `第 1 天` 回退成 `Day 1`。

已验证：

- `dart format lib\widgets\lovegirl_ui.dart test\widget_test.dart`
- `dart format lib\screens\travel\travel_main_screen.dart`
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `flutter analyze`，全量静态分析通过。
- `cd android && .\gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin`，Android 原生地图插件 Java 编译和 App Kotlin 编译通过。
- 窄屏首页测试改为 360 逻辑宽，已覆盖首页标题、今日照顾、旅行票根在窄屏下不触发 RenderFlex 溢出。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 模拟器截图证据：
  - 登录页：`D:\lovegirl_flutter\tmp_goal_runtime_current.png`
  - 首页：`D:\lovegirl_flutter\tmp_goal_home_runtime.png`
  - 旅行页：`D:\lovegirl_flutter\tmp_goal_travel_runtime.png`
  - 高德模拟器兜底页：`D:\lovegirl_flutter\tmp_goal_amap_runtime_cn.png`
- 模拟器日志检查：打开旅行页和高德兜底页未发现 `FATAL EXCEPTION`、`RenderFlex overflowed`、`AndroidRuntime` 崩溃日志。
- 扫描首页、旅行地图、高德真地图、投喂站、我的页、天气卡片、公共票根组件中的常见乱码字符：无命中。
- 扫描上述核心 UI 文件中的明显可见英文残留：无输出。

仍未完成：

- 模拟器已验证高德入口兜底不崩，但还没有安卓真机验证高德原生地图实际加载、定位蓝点、方向箭头和精度圈，不能宣称真地图入口已经最终完成。
- 还没有完成截图级视觉对照，不能宣称 UI 已经和参考图“一模一样”。
- `加入路线 / 生成票根 / 记一笔花费` 的完整后端闭环仍不是本轮 P0 已完成项。
- 本轮目标明确要求未完成前不发布 APK，因此当前仍不构建、不发布正式安装包。

## 十二、2026-07-27 旅行地图首屏重排记录

已完成：

- 旅行主页面地图区从“功能说明卡片”改为“地图画布 + 浮层筛选 + 左侧地图工具 + 地点气泡 + 底部地点票根”的首屏结构，更接近 `docs/lovegirl-ui-home-06.png`。
- 地图预览背景补充水域、绿地、道路网、虚线路线和当前位置方向标记，首屏不再像低质空白卡片。
- 筛选项前移到地图画布顶部，保留 `想去 / 计划中 / 已打卡 / 我们都编辑` 四个核心状态。
- 底部地点票根补齐状态、地址、天气、计划日期、预算、加入路线、生成票根、记花费和打开高德真地图入口。
- `travel_enter_amap_mode` 测试 key 保持不变，避免后续自动化和回归测试失效。
- 旅行页显示层新增坏数据清洗：遇到纯问号、替换字符等明显损坏文本时显示 `未命名地点 / 还没填写地址` 等中文兜底，避免把数据库里的 `???????` 直接显示给用户。
- 路线票根增加 `travel_itinerary_ticket` 稳定 key，减少测试对重复地点名文本的依赖。
- 删除旅行页上说明“先用票根式预览……”的说明性正文，让页面更像真实地图工具。

已验证：

- `dart format lib\screens\travel\travel_main_screen.dart test\widget_test.dart`
- `flutter analyze`
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新模拟器截图证据：
  - 旅行地图首屏：`D:\lovegirl_flutter\tmp_goal_travel_map_refined.png`
  - 高德模拟器兜底页：`D:\lovegirl_flutter\tmp_goal_amap_after_refined.png`
- 最新模拟器运行时 XML 扫描：旅行地图首屏和高德兜底页未命中 `???`、替换字符、旧英文票根文案、`Android 真机`、`高德 Key`。
- 最新模拟器日志检查：打开旅行页和高德兜底页未发现 `FATAL EXCEPTION`、`RenderFlex overflowed`、`AndroidRuntime` 崩溃日志。
- `git diff --check -- lib/screens/travel/travel_main_screen.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md` 只有 CRLF 提示，无空白错误。

仍未完成：

- 高德原生地图的真实蓝点、方向箭头、精度圈还没有在安卓真机上验证；模拟器只能证明兜底页不崩。
- 当前首屏已经明显向参考图靠拢，但仍不是逐像素“一模一样”：顶部仍保留现有页面标题卡，地图气泡与底部票根的空间关系还需要继续截图级微调。
- 旅行花费同步记账、路线保存、票根生成后端闭环仍是后续功能目标，不属于这次首屏 P0 稳定性已完成项。

## 十三、2026-07-27 投喂站与我的页运行时复核记录

已完成：

- 投喂站商品展示增加显示层清洗，不修改接口字段和订单入参，只把明显损坏文本或历史英文种子名转成干净中文。
- 当前已覆盖的历史英文种子名包括 `hot noodles`、`warm meal`、`rice bowl`、`simple lunch`，运行时显示为 `热汤面`、`热乎乎的一餐`、`盖饭套餐`、`简单午餐`。
- 我的页已把独立 `倒数日` 入口合并到 `纪念日与倒数`，对应入口文案为 `纪念日、倒数日和小约定放在同一个资料夹`。
- 公共菜单行 `LoveMenuRow` 增加标题和右侧说明的单行省略约束，修复长说明把标题挤成竖排的问题，同时防止其他菜单行出现同类布局破坏。

已验证：

- `dart format lib\widgets\lovegirl_ui.dart`
- `flutter analyze lib\widgets\lovegirl_ui.dart lib\screens\profile\profile_screen.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `git diff --check -- lib/widgets/lovegirl_ui.dart lib/screens/travel/travel_main_screen.dart lib/screens/home/home_screen.dart lib/screens/profile/profile_screen.dart lib/screens/feeding/feeding_screen.dart lib/widgets/travel_map_widget.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 `test/widget_test.dart` 的 LF/CRLF 提示外无空白错误。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新运行时截图和 XML 证据：
  - 我的页：`D:\lovegirl_flutter\tmp_goal_profile_after_lovemenu_fix.png`
  - 我的页 XML：`D:\lovegirl_flutter\tmp_goal_profile_after_lovemenu_fix.xml`
  - 投喂站商品页：`D:\lovegirl_flutter\tmp_goal_feeding_shop_chinese.png`
  - 投喂站商品页 XML：`D:\lovegirl_flutter\tmp_goal_feeding_shop_chinese.xml`
- 我的页 XML 显示 `纪念日与倒数` 行高度恢复为正常菜单行高度，未再出现标题竖排。
- 投喂站商品页 XML 未命中 `Hot Noodles`、`Rice Bowl`、`Warm meal`、`Simple lunch`，已显示中文商品名。
- 源码扫描 `lib/`、`test/` 下 Dart 文件，未发现常见乱码字符；投喂站历史英文仅保留在显示映射表键中，不作为 UI 文案显示。
- 模拟器运行日志最近 1000 行未发现 `FATAL EXCEPTION`、`RenderFlex overflowed`、`MissingPluginException`、`PlatformException`。

仍未完成：

- 还没有安卓真机验证高德原生地图实际加载、定位蓝点、方向箭头和精度圈。
- 还没有完成首页、旅行地图、投喂站、我的页对参考图的截图级逐项对照，不能宣称 UI 已经“一模一样”。
- 还没有执行正式 APK 构建和服务器发布；本轮目标仍要求未完成前不发布。

## 十四、2026-07-27 首页首屏对齐记录

已完成：

- 首页顶部 `LoveGirl` 标题和恋爱天数字号收紧，减少第一屏顶部占用。
- `今天要照顾的事` 中的 `投喂她` 和 `待办清单` 在 360 逻辑宽设备上改为并排展示，更接近首页参考图的卡片关系。
- 投喂小卡增加窄宽布局：商品图、商品名、店铺、价格、接单人和 `去看看` 按钮改为稳定竖排，避免价格拆行和文字挤压。
- 待办小卡头部改为可收缩标题，避免并排时标题和完成数互相挤出。
- 回忆票根标题增加常见英文心情枚举映射，例如 `excited` 显示为中文，不再把英文状态直接暴露在首页。

已验证：

- `dart format lib\screens\home\home_screen.dart`
- `flutter analyze`
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新首页截图证据：`D:\lovegirl_flutter\tmp_goal_home_chinese_memory.png`
- 最新首页运行时 XML 和日志检查：未发现 `excited`、`???`、替换字符、`RenderFlex overflowed`、`FATAL EXCEPTION`、`AndroidRuntime`。

仍未完成：

- 首页在 360 逻辑宽设备上已经接近参考结构，但顶部信息区仍比参考图偏高；后续可继续做截图级比例微调。
- 今日照顾卡里投喂商品仍使用图标占位，不是参考图里的真实饮品图；是否接入商品图片需要继续和投喂站数据一起处理。

## 十五、2026-07-27 高德兜底页二次复核记录

已完成：

- 高德真地图在模拟器/不支持原生地图的设备上不再挂载原生地图组件，继续显示中文兜底预览。
- 不支持原生地图时隐藏左侧地图工具栏，避免 `标准地图 / 定位 / 路线` 按钮压到底部票根卡片。
- 兜底原因只保留在顶部信息卡里，底部不再重复显示相同提示。
- 兜底背景从纯黑空白改成深色地图纹理和路线预览，让页面仍然像地图模式，而不是错误页。

已验证：

- `dart format lib\screens\travel\travel_amap_mode_screen.dart`
- `flutter analyze lib\screens\travel\travel_amap_mode_screen.dart lib\widgets\travel_map_widget.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `git diff --check -- lib/screens/travel/travel_amap_mode_screen.dart lib/widgets/lovegirl_ui.dart lib/screens/travel/travel_main_screen.dart lib/screens/home/home_screen.dart lib/screens/profile/profile_screen.dart lib/screens/feeding/feeding_screen.dart lib/widgets/travel_map_widget.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 `test/widget_test.dart` 的 LF/CRLF 提示外无空白错误。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新高德兜底截图：`D:\lovegirl_flutter\tmp_goal_amap_fallback_refined2.png`
- 最新高德兜底 XML：`D:\lovegirl_flutter\tmp_goal_amap_fallback_refined2.xml`
- 点击旅行页 `打开高德真地图` 后，模拟器进入中文兜底页，未发现 App 崩溃。
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1` 等旧英文可见文案。

仍未完成：

- 安卓真机上的高德原生地图加载、定位蓝点、方向箭头、精度圈仍未验证。
- 本轮仍未构建和发布正式 APK。

## 十六、2026-07-27 旅行地图参考图对齐二次推进

已完成：

- 旅行页顶部从大块统计卡改为更接近参考图的轻量标题栏：左侧 `旅行地图` 标题和爱心标记，右侧搜索与排序按钮。
- 城市、路线等统计从顶部卡片剥离，保留在地图浮层和下方收藏进度里，避免首屏被工具型统计占满。
- 地图区高度提高，首屏第一视觉更接近“地图产品”，不再先看到大卡片再看到地图。
- 地图内地点票根压缩高度：封面、信息格、备注和按钮间距收紧，让路线、定位点和左侧工具露出更多。
- `打开高德真地图` 从地点票根底部的大按钮移到地图右侧悬浮按钮，显示为 `真地图`，同时保留 `travel_enter_amap_mode` 测试 key。
- 左侧 `标准地图 / 定位 / 路线` 工具栏上移并缩小，修复 `路线` 按钮被底部票根遮挡的问题。

已验证：

- `dart format lib\screens\travel\travel_main_screen.dart`
- `flutter analyze lib\screens\travel\travel_main_screen.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `git diff --check -- lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/widgets/lovegirl_ui.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 `test/widget_test.dart` 的 LF/CRLF 提示外无空白错误。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新旅行页首屏截图：`D:\lovegirl_flutter\tmp_goal_travel_map_entry_floating.png`
- 最新旅行页首屏 XML：`D:\lovegirl_flutter\tmp_goal_travel_map_entry_floating.xml`
- 点击地图内 `真地图` 悬浮入口后进入高德中文兜底页，未发现 App 崩溃。
- 最新高德入口点击截图：`D:\lovegirl_flutter\tmp_goal_amap_from_floating_entry2.png`
- 最新高德入口点击 XML：`D:\lovegirl_flutter\tmp_goal_amap_from_floating_entry2.xml`
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1` 等旧英文可见文案。

仍未完成：

- 当前旅行页已经更接近 `docs\lovegirl-ui-home-06.png` 的首屏结构，但不是逐像素复刻；真实地点照片、真实底图、多人头像等内容仍依赖数据和真机地图能力。
- 安卓真机上的高德原生地图加载、定位蓝点、方向箭头、精度圈仍未验证。
- 本轮仍未构建和发布正式 APK。

## 十七、2026-07-27 首页参考图对齐二次推进

已完成：

- 首页顶部从“标题一行、天气爱心豆下一行”的结构，调整为更接近参考图的左右排布：左侧 `LoveGirl` 和恋爱天数，右侧天气、体感温度和爱心豆。
- 紧凑天气卡宽度从 170px 收敛到 118px，同时保留温度、天气、城市和体感温度。
- 恋爱天数文案增加 `FittedBox` 缩放，避免 1607 天这类长数字在 360 逻辑宽设备上挤出标题区。
- 爱心豆徽章尺寸收紧，配合天气卡在 360 逻辑宽设备上保持同一行。
- 修复压缩天气卡后出现的 `BOTTOM OVERFLOWED BY 6.0 PIXELS`，将紧凑天气卡高度调整到安全值。

已验证：

- `dart format lib\screens\home\home_screen.dart lib\widgets\weather_widget.dart`
- `flutter analyze lib\screens\home\home_screen.dart lib\widgets\weather_widget.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `git diff --check -- lib/screens/home/home_screen.dart lib/widgets/weather_widget.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/widgets/lovegirl_ui.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 LF/CRLF 提示外无空白错误。
- 模拟器调试运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新首页截图：`D:\lovegirl_flutter\tmp_goal_home_compact_header_no_overflow.png`
- 最新首页 XML：`D:\lovegirl_flutter\tmp_goal_home_compact_header_no_overflow.xml`
- 最新首页截图未再出现红色 overflow 标记；日志未发现 `RenderFlex overflowed`、`BOTTOM OVERFLOWED`、`FATAL EXCEPTION`。
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1`、`excited` 等旧英文可见文案。

仍未完成：

- 首页已经更接近 `docs\lovegirl-ui-home-09.png` 的头部排版，但 `LoveGirl` 字体仍受 Flutter/Android 默认字体限制，不是参考图里的衬线标题字体。
- 投喂卡仍使用图标占位，不是参考图里的真实饮品图；后续需要和投喂站商品图片数据一起处理。
- 本轮仍未构建和发布正式 APK。

## 十八、2026-07-27 核心页面运行核验与共享行组件修正

已完成：

- 重新用当前源码启动 debug 版本，确认此前 `tmp_goal_feeding_current_round2` 和 `tmp_goal_profile_current_round2` 实际抓到的是系统桌面，不作为验收依据。
- 重新抓取首页、旅行地图、高德入口、投喂站、我的页、纪念日页面的真实运行截图和 XML。
- 首页当前保持票根首页方向：`LoveGirl`、恋爱天数、天气、体感温度、爱心豆、今日照顾、投喂状态、待办和随机回忆均为中文展示。
- 旅行地图当前保持参考图方向：首屏以地图为主体，包含状态筛选、左侧工具、定位蓝点、路线示意、地点标记、`真地图` 悬浮入口和底部地点票根。
- 高德入口在模拟器上进入中文 `模拟器预览` 兜底页，未复现点击后崩溃。
- 投喂站当前保持专属菜单方向：顶部真实履约语义、搜索框、店铺卡片和菜单入口均为中文展示。
- 我的页当前保持 `关系资料夹` 方向，`纪念日与倒数` 已合并为同一入口。
- 纪念日页面实际运行结果为中文展示，未复现此前用户反馈的乱码。
- 公共 `LoveMenuRow` 调整标题和值的宽度分配：短标题按内容占位，右侧说明拿更多空间，减少我的页入口说明被过早截断的问题。

已验证：

- `dart format lib\widgets\lovegirl_ui.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- `git diff --check -- lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart lib/widgets/lovegirl_ui.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 LF/CRLF 提示外无空白错误。
- `cd android && .\gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin`，Android 地图插件 Java 编译和 App Kotlin 编译通过。
- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 运行时 XML 扫描未命中 `�`、`???`、`LOVEGIRL TRIP`、`Day 1`、`FATAL`、`RenderFlex`、`BOTTOM OVERFLOWED`、`登录`。

本轮截图证据：

- 首页：`D:\lovegirl_flutter\tmp_goal_current_home.png`
- 旅行地图：`D:\lovegirl_flutter\tmp_goal_current_travel.png`
- 高德入口模拟器兜底：`D:\lovegirl_flutter\tmp_goal_current_amap.png`
- 投喂站：`D:\lovegirl_flutter\tmp_goal_current_feeding.png`
- 我的页：`D:\lovegirl_flutter\tmp_goal_current_profile.png`
- 纪念日：`D:\lovegirl_flutter\tmp_goal_current_anniversary.png`

仍未完成：

- 安卓真机上的高德原生地图加载、定位蓝点、方向箭头、精度圈仍未验证。
- UI 已明显对齐票根方向，但还不能宣称和参考图逐像素一模一样。
- 真实商品图片、真实地图底图、真实外卖平台同步、记账联动完整闭环仍不是当前已完成项。
- 本轮仍未构建和发布正式 APK。

## 十九、2026-07-27 首页参考图细节对齐

已完成：

- 对比 `docs\lovegirl-ui-home-09.png` 与当前首页截图，确认差距主要集中在素材和字体，而不是页面结构。
- `LoveGirl` 标题改用系统衬线字体并降低字重，更接近参考图里的品牌标题气质。
- 首页爱心豆图标从小猪图标改为自绘豆子图标，减少和参考图的视觉偏差。
- 自绘豆子使用 `CustomPainter`，不新增外部图片资源，不影响后续换成正式图片资产。
- 复核我的页共享行组件宽度修正，确认 `伴侣绑定`、`时光轴` 等说明展示空间更合理。

已验证：

- `dart format lib\screens\home\home_screen.dart`
- `flutter analyze lib\screens\home\home_screen.dart lib\widgets\weather_widget.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 10 个测试通过。
- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新首页截图：`D:\lovegirl_flutter\tmp_goal_home_serif_bean.png`
- 最新首页 XML：`D:\lovegirl_flutter\tmp_goal_home_serif_bean.xml`
- 最新我的页截图：`D:\lovegirl_flutter\tmp_goal_profile_lovemenu_width.png`
- 最新我的页 XML：`D:\lovegirl_flutter\tmp_goal_profile_lovemenu_width.xml`
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1`、`登录`、`RenderFlex`、`BOTTOM OVERFLOWED`。
- `git diff --check -- lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart lib/widgets/lovegirl_ui.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 LF/CRLF 提示外无空白错误。

仍未完成：

- 首页参考图里的真实饮品图、真实回忆照片、花束便签插画和天气拟物图标目前没有对应项目资产，当前只能用代码绘制和图标占位继续靠近。
- 旅行参考图里的真实高德底图、多个真实地点、多人头像、地点封面照片仍依赖真实数据和安卓真机高德 SDK 验证。
- 目前不发布 APK；发布前必须先完成真机核验或明确接受模拟器兜底验证的限制。

## 二十、2026-07-27 高德真地图定位模式补强

已完成：

- 审查 `TravelMapWidget` 的高德定位路径，确认当前已有定位权限请求、定位层开关、精度圈样式、定位按钮和 `onLocationChanged` 回调。
- 审查本地 `amap_flutter_map` 插件，确认 Android 端已有 `SHOW / FOLLOW / LOCATION_ROTATE` 映射，但 Dart 层没有把 `trackingMode` 暴露出来。
- 在 `MyLocationStyleOptions` 增加 `trackingMode` 参数，并支持 `show / follow / locationRotate` 三种模式序列化。
- 恢复 Android 端 `trackingMode` 读取；未传参时继续使用原来的 `FOLLOW_NO_CENTER` 兼容行为。
- 旅行地图定位层传入 `MyLocationTrackingMode.locationRotate`，使真机高德地图进入带方向旋转的定位模式，更接近用户要求的蓝点/方向箭头体验。
- 新增测试锁定 `trackingMode` 会被传到原生地图参数，防止后续退回只显示普通蓝点。

已验证：

- `dart format packages\amap_flutter_map\lib\src\types\ui.dart lib\widgets\travel_map_widget.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `flutter test test\widget_test.dart`，当前 11 个测试通过。
- `cd android && .\gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin`，Android 地图插件 Java 编译和 App Kotlin 编译通过。
- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 模拟器点击 `真地图` 后仍进入中文兜底页，未发现 App 崩溃。
- 最新高德兜底截图：`D:\lovegirl_flutter\tmp_goal_amap_tracking_mode.png`
- 最新高德兜底 XML：`D:\lovegirl_flutter\tmp_goal_amap_tracking_mode.xml`
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1`、`FATAL`、`RenderFlex`、`BOTTOM OVERFLOWED`。

仍未完成：

- 方向旋转定位模式已经从 Flutter 传到 Android 原生高德插件，但模拟器不会挂载真地图，仍需要安卓真机验证实际蓝点、方向箭头、精度圈显示。
- 若真机仍没有方向箭头，需要继续检查高德 SDK 默认定位图标、传感器权限/设备方向数据，以及是否需要自定义定位蓝点图标资源。

## 二十一、2026-07-27 底部导航票根系改造

已完成：

- 审查当前主框架，确认底栏仍使用系统 `BottomNavigationBar`，视觉上和参考图的轻量票根系导航有差距。
- 将 AppShell 底栏改为自定义 `LoveBottomNavButton`，保留 `首页 / 旅行 / 健康 / 生活 / 我的` 五个入口和原有健康模块权限拦截。
- 选中态使用珊瑚色圆角图标底，未选中态使用灰色线性图标和文字，更接近参考图底栏的干净感。
- 底栏增加 `SafeArea`、顶部细分割线和轻阴影，避免底栏看起来像系统默认控件。
- 修复自定义语义后 `首页 首页` 这类重复朗读问题，底栏 XML 当前只保留单次 `首页 / 旅行 / 健康 / 生活 / 我的`。

已验证：

- `dart format lib\main.dart`
- `flutter analyze lib\main.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`，当前 11 个测试通过。
- `flutter analyze`，全量静态分析通过。
- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新首页底栏截图：`D:\lovegirl_flutter\tmp_goal_nav_semantics_fixed.png`
- 最新首页底栏 XML：`D:\lovegirl_flutter\tmp_goal_nav_semantics_fixed.xml`
- 最新旅行页底栏截图：`D:\lovegirl_flutter\tmp_goal_nav_travel.png`
- 最新旅行页底栏 XML：`D:\lovegirl_flutter\tmp_goal_nav_travel.xml`
- 源码和运行时 XML 扫描未命中常见乱码字符、`LOVEGIRL TRIP`、`Day 1`、`登录`、`RenderFlex`、`BOTTOM OVERFLOWED`。

仍未完成：

- 底栏已接近参考图方向，但图标仍使用 Material Icons，不是定制图标资产。
- 正式发布前仍需要在真机检查底栏安全区、手势导航栏、不同屏幕密度下的触控范围。

## 二十二、2026-07-27 旅行地图顶部筛选条修正

已完成：

- 审查旅行地图顶部筛选条，确认原实现是横向 `ListView.separated`，在 1080x2280 模拟器上会把最后一项 `我们都编辑` 压缩成 `我们...`，视觉上没有达到参考图要求。
- 将筛选条改为四等分票根分段控件，四个状态固定显示为 `想去 / 计划中 / 已打卡 / 我们都编辑`。
- 将筛选项内部布局改为上方小圆形图标、下方中文标签，避免长标签在窄屏被横向挤掉。
- 保留原有筛选行为：再次点击当前状态会清空筛选，点击其他状态会切换到对应筛选。
- 为每个筛选项增加稳定 key：`travel_map_filter_wish / planned / visited / both`，方便后续测试和运行态定位。
- 修复筛选按钮辅助访问语义重复问题，XML 中不再出现 `想去\n想去`、`我们都编辑\n我们都编辑`，并保持按钮 `clickable=true`。
- 新增 Widget 测试覆盖筛选条四个中文标签和 `我们都编辑` 点击后 `activeStatus == both`。

已验证：

- `dart format lib\screens\travel\travel_main_screen.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`，当前 12 个测试通过。
- `flutter analyze lib\screens\travel\travel_main_screen.dart test\widget_test.dart`
- `flutter analyze`，全量静态分析通过。
- `cd android && .\gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin`，Android 地图插件 Java 编译和 App Kotlin 编译通过。
- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 最新旅行页截图：`D:\lovegirl_flutter\tmp_goal_travel_filter_final_semantics.png`
- 最新旅行页 XML：`D:\lovegirl_flutter\tmp_goal_travel_filter_final_semantics.xml`
- 运行时 XML 扫描未命中常见乱码、登录弹窗、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`。
- `git diff --check -- lib/screens/travel/travel_main_screen.dart test/widget_test.dart docs/implementation/lovegirl-ticket-ui-travel-map-target.md`，除 LF/CRLF 提示外无空白错误。

仍未完成：

- 当前旅行地图预览页仍是代码绘制的票根风格地图，不是真实高德底图；真实高德地图只在 `真地图` 入口中打开。
- 模拟器无法证明真机高德定位蓝点、方向箭头和精度圈表现，发布前仍需要安卓真机验证。
- 旅行页和参考图已经更接近，但仍缺真实地点封面、真实地图底图、多人头像等资产级细节。

## 二十三、2026-07-27 真地图入口复验

已完成：

- 在当前源码 debug 包中，从旅行页点击 `真地图` 入口进行运行态复验。
- 当前环境为 Android x86_64 模拟器，入口没有继续加载高德原生地图，而是进入专门的中文兜底预览页。
- 兜底页清楚说明 `当前设备是模拟器架构，高德原生真地图建议在安卓真机上查看。`
- 页面保留 `新增地点`、`查看全局` 等操作入口，不再出现点击后直接闪退或空白。

已验证：

- 当前源码 debug 运行通过：`flutter run -d emulator-5554 --debug --no-resident --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`。
- 点击旅行页 `真地图` 后抓图：`D:\lovegirl_flutter\tmp_goal_amap_entry_after_filter_fix.png`
- 点击旅行页 `真地图` 后 XML：`D:\lovegirl_flutter\tmp_goal_amap_entry_after_filter_fix.xml`
- 点击后的 logcat：`D:\lovegirl_flutter\tmp_goal_amap_entry_after_filter_fix_logcat.txt`
- 精确扫描 logcat 未命中 `FATAL EXCEPTION`、`Process: com.lovegirl.lovegirl_flutter`、`java.lang.RuntimeException`、`NullPointerException`、`UnsatisfiedLinkError`、`Lost connection to device`、`Force finishing activity`。
- 运行态 XML 显示 `旅行地图 / 当前设备是模拟器架构 / 模拟器预览 / 新增地点 / 查看全局`，未出现登录弹窗、乱码或 `???`。

仍未完成：

- 这里只证明模拟器不会因为 `真地图` 入口闪退；不能证明安卓真机上的高德原生地图、定位蓝点、方向箭头和精度圈已经符合最终要求。
- 发布前仍需要在实体 Android 手机上点击 `真地图`，并确认高德 SDK Key、包名、release SHA1、定位权限和隐私合规初始化均正常。

## 二十四、2026-07-27 我的页运行态复核

已完成：

- 从当前 debug 运行态进入 `我的` 页，复核页面是否仍符合已确认的资料夹/票根系方向。
- 当前首屏结构为 `关系资料夹` 标题、关系卡、`关系档案` 模块和底部票根系导航。
- 页面已将纪念日和倒数合并展示为 `纪念日与倒数`，相册入口表达为 `相册与回忆照片`，符合之前确定的主从关系。
- 本轮没有对我的页代码做新改动，原因是截图未显示 P0 级乱码、英文残留、布局溢出或明显错位。

已验证：

- 当前我的页截图：`D:\lovegirl_flutter\tmp_goal_profile_current_audit.png`
- 当前我的页 XML：`D:\lovegirl_flutter\tmp_goal_profile_current_audit.xml`
- 运行态 XML 扫描未命中 `登录`、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`、替换字符或 `???`。

仍未完成：

- 我的页仍使用 Material 图标和代码绘制头像，不是定制图标/插画资产。
- 页面下半部分 `回忆与管理` 需要后续继续滚动复核，确认每个入口都与最终功能清单一致。

## 二十五、2026-08-24 投喂站下单弹窗与订单详情代码审查

已完成：

- 审查投喂站下单弹窗 `_showSendSheet` 方法的完整实现（`feeding_screen.dart:973-1176`）。
- 下单弹窗使用 `_feedingDisplayText` 清洗商品名和描述，已覆盖历史英文种子名映射、乱码替换字符、疑问句占比过滤。
- 下单弹窗按钮文案为 `确认投喂 ¥xx`，文本域提示为 `给这次投喂留一句话`，均为中文。
- `OrderDetailSheet` 类（`feeding_screen.dart:1426-1966`）已有 Widget 测试覆盖订单详情展示和配送中状态强制履约流程。
- 下单弹窗使用 `Column(mainAxisSize: MainAxisSize.min)` 自适应高度，`isScrollControlled: true` 处理键盘弹出，不会溢出。
- 当前已有运行态截图证据：`tmp_goal_feeding_shop_audit.png`（店铺菜单页）、`tmp_goal_feeding_current_audit.png`（投喂站首页）。
- 模拟器启动遇到 Gradle 锁文件问题，清理后重试仍因模拟器连接不稳定而无法完成运行态点击验证。

已验证：

- `flutter test test\widget_test.dart`，12 个测试通过，含 2 个投喂站订单详情测试。
- `flutter analyze lib\screens\feeding\feeding_screen.dart lib\screens\home\home_screen.dart lib\screens\travel\travel_main_screen.dart lib\screens\profile\profile_screen.dart lib\widgets\lovegirl_ui.dart test\widget_test.dart`，无问题。
- 下单弹窗代码中所有 `Text` 和 `SnackBar` 内容均为中文 Unicode 转义，没有英文硬编码。
- 尚未完成 Android 真机上的运行态点击验证。

仍未完成：

- 模拟器环境不稳定，未能完成下单弹窗的运行态截图验证。
- 仍需要 Android 真机验证高德原生地图和投喂站完整链路。
- 没有执行正式 APK 构建和发布。

## 二十六、2026-08-24 投喂站下单弹窗运行态复核

已完成：

- 通过 Gradle 8.9 缓存直接构建 debug APK，绕过损坏的 Gradle 8.3 wrapper 下载锁。
- 在模拟器 `emulator-5554` 上安装并启动 `app-debug.apk`。
- 使用测试账号 `admin / admin123` 登录，跳过版本更新弹窗，进入首页。
- 从首页 `今天要照顾的事` 点击 `去看看` 进入投喂站首页。
- 点击 `喜茶` 店铺卡片进入商品菜单页，确认历史英文种子名已显示为中文：`热汤面`、`盖饭套餐`。
- 点击第一个商品的 `选这份` 打开下单弹窗，验证弹窗内容完整。

已验证：

- 下单弹窗 XML：`D:\lovegirl_flutter\tmp_goal_send_sheet.xml`
- 下单弹窗截图：`D:\lovegirl_flutter\tmp_goal_send_sheet.png`
- 下单弹窗日志：`D:\lovegirl_flutter\tmp_goal_send_sheet_logcat.txt`
- 弹窗显示 `热汤面 / 热乎乎的一餐 / 1 / 预计合计 ¥18 / 她想吃的`。
- 弹窗输入框和按钮显示正常：备注输入框 + `确认投喂 ¥18` 按钮。
- XML 未命中 `�`、`???`、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`。
- logcat 未命中 `FATAL EXCEPTION`、`RenderFlex overflowed`、`BOTTOM OVERFLOWED`、`MissingPluginException`。
- 日志中的 Error/Exception 均为模拟器系统网络探测、SELinux、时间同步等系统噪声，不是 App 崩溃。

仍未完成：

- 模拟器只验证了弹窗展示和文字清洗，没有实际提交订单，避免污染测试数据。
- 高德原生地图仍需要 Android 真机验证蓝点、方向箭头和精度圈。
- 没有执行正式 APK 构建和发布。

## 二十七、2026-08-24 首页与四核心页最终运行态汇总

已完成：

- 使用同一 debug 构建完成首页、投喂站、投喂站商品菜单、下单弹窗的运行态复核。
- 首页运行态 XML 确认票根结构完整：`LoveGirl`、恋爱天数、天气、体感温度、爱心豆、今日照顾、投喂状态、待办、随机回忆票根。
- 首页所有可见文案为中文，未发现历史英文残留、乱码、登录弹窗或溢出标记。
- 投喂站运行态确认专属菜单方向：顶部真实履约语义、搜索框、店铺卡片、`查看菜单` 入口均正常。
- 投喂站商品菜单确认历史英文种子名已映射为中文：`热汤面`、`盖饭套餐`。
- 投喂站下单弹窗确认商品名、描述、数量、金额、备注输入框和 `确认投喂 ¥18` 按钮均正常显示。
- 我的页在上一轮运行态复核中确认 `关系资料夹 / 关系档案 / 纪念日与倒数 / 回忆与管理` 结构完整。
- 旅行地图在上一轮运行态复核中确认筛选条四个标签完整、`真地图` 入口不闪退、中文兜底页正常。

已验证：

- 首页最终 XML：`D:\lovegirl_flutter\tmp_goal_home_final.xml`
- 首页最终截图：`D:\lovegirl_flutter\tmp_goal_home_final.png`
- 投喂站最终 XML：`D:\lovegirl_flutter\tmp_goal_feeding_page.xml`
- 投喂站商品菜单 XML：`D:\lovegirl_flutter\tmp_goal_shop_menu.xml`
- 投喂站下单弹窗 XML：`D:\lovegirl_flutter\tmp_goal_send_sheet.xml`
- 投喂站下单弹窗截图：`D:\lovegirl_flutter\tmp_goal_send_sheet.png`
- 四核心页运行态 XML 均未命中 `�`、`???`、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`。
- `flutter test test\widget_test.dart`，12 个测试通过。
- `flutter analyze` 通过。
- Android debug APK 构建成功。

仍未完成：

- 高德原生地图真实加载、蓝点、方向箭头和精度圈需要 Android 真机验证。
- UI 与参考图在视觉资产上仍有差距：真实饮品照片、真实地图底图、定制图标/插画尚未完全替换代码占位。
- 尚未执行正式 release APK 构建和服务器发布。

## 二十八、2026-08-24 旅行页与我的页同一构建复验

已完成：

- 使用与首页/投喂站相同的 debug APK，完成旅行页和我的页的同一构建运行态复验。
- 旅行页确认标题为 `旅行地图`，筛选条四个标签 `想去 / 计划中 / 已打卡 / 我们都编辑` 均完整显示且可点击。
- 旅行页确认地图预览、`标准地图`、`定位`、`路线`、`真地图` 入口、地点票根、`加入路线 / 生成票根 / 记花费` 操作均存在。
- 旅行页地点详情信息完整：`未命名地点 / 计划中 / 还没填写地址 / 待同步 / 2026-07-20 / ¥88 / 天气 / 计划日期 / 预计预算`。
- 我的页确认 `关系资料夹` 方向：关系卡、`关系档案`、`纪念日与倒数`、`伴侣绑定`、`时光轴`、`回忆与管理` 均正常。
- 我的页确认 `纪念日与倒数` 已合并展示，`相册` 入口保持为回忆管理方向。

已验证：

- 旅行页 XML：`D:\lovegirl_flutter\tmp_goal_travel_current_build.xml`
- 旅行页截图：`D:\lovegirl_flutter\tmp_goal_travel_current_build.png`
- 我的页 XML：`D:\lovegirl_flutter\tmp_goal_profile_current_build.xml`
- 我的页截图：`D:\lovegirl_flutter\tmp_goal_profile_current_build.png`
- 两个页面 XML 均未命中 `�`、`???`、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`、`登录`。

仍未完成：

- 高德真地图入口在当前模拟器仍显示中文兜底预览页，需要 Android 真机验证原生地图。
- 旅行页预览地图仍是代码绘制底图，不是真实高德底图。
- 尚未执行正式 release APK 构建和服务器发布。

## 二十九、2026-08-24 天气组件真实定位修正

已完成：

- 发现天气组件仍直接请求写死的 `city=长沙`，与用户此前明确要求“不要硬编码城市”冲突。
- 后端已存在 `/api/weather/coords?lat=&lng=` 接口，本轮将前端天气组件改为真实定位优先。
- 新增定位权限检查和 `Geolocator.getCurrentPosition` 流程，成功后再请求 `/api/weather/coords`。
- 定位权限拒绝、定位失败、网络失败时显示明确错误态，不再用写死的长沙天气伪装成功。
- 删除写死的 `长沙` 默认请求和本地假天气占位，只保留上一次成功天气缓存作为离线恢复。
- 修正 geolocator 11.1.0 的 `getCurrentPosition` 参数为 `desiredAccuracy + timeLimit`。

已验证：

- `dart format lib\widgets\weather_widget.dart`
- `flutter test test\widget_test.dart`，12 个测试通过。
- `flutter analyze lib\widgets\weather_widget.dart lib\screens\home\home_screen.dart test\widget_test.dart`，无问题。
- 首页运行态 XML 仍显示 `26° 小雨 长沙市 体感 28°`（上一次构建的数据来自后端接口，非前端写死）。

仍未完成：

- 真实定位天气需要在 Android 真机或模拟器带定位环境下验证 `/api/weather/coords` 返回。
- 需要重新构建 debug APK 并在模拟器复验首页天气卡片，确认无布局溢出。

## 三十、2026-08-24 天气真实定位端到端验证

已完成：

- 重新构建并安装包含天气定位修正的 debug APK。
- 首次启动触发系统定位权限请求，授权后进入真实定位流程。
- 将模拟器定位设为长沙坐标 `28.2282,112.9388`，App 通过 `/api/weather/coords` 获取真实天气。
- 首页最终显示 `26° / 小雨 / 湖南省长沙市岳麓区 / 体感 26°`，不再使用前端写死的城市。
- 当定位无法解析出有效天气时（如模拟器默认的海外坐标），前端不再把 `未知` 当作成功天气显示，而是进入数据不可用错误态。

已验证：

- 首页最终 XML：`D:\lovegirl_flutter\tmp_goal_home_weather_cs.xml`
- 首页最终截图：`D:\lovegirl_flutter\tmp_goal_home_weather_cs.png`
- 生产接口真实返回：`{"code":200,"data":{"city":"湖南省长沙市岳麓区","temp":26,"feelsLike":26,"tempHigh":31,"tempLow":25,"weather":"小雨",...}}`
- `flutter test test\widget_test.dart`，12 个测试通过。
- `flutter analyze lib\widgets\weather_widget.dart lib\screens\home\home_screen.dart test\widget_test.dart`，无问题。
- Android debug APK 构建成功。

仍未完成：

- 高德原生地图真实加载、蓝点、方向箭头和精度圈需要 Android 真机验证。
- 首页/投喂站真实饮品照片、真实地图底图、定制图标/插画等视觉资产尚未完全替换。
- 尚未执行正式 release APK 构建和服务器发布。

## 三十一、2026-08-24 最终代码审计记录

已完成：

- 全量 `flutter analyze` 通过，无静态分析问题。
- 扫描首页、旅行、投喂站、我的页、天气组件、地图组件和高德兜底页源码，未发现可见乱码或英文残留。
- 源码中仅保留英文映射键（如 `excited`、`hot noodles`），运行时全部映射为中文，不是 UI 可见文案。
- 复核 `travel_amap_mode_screen.dart`，确认中文兜底、`回到预览 / 新增地点 / 查看全局` 操作和错误提示均完整。
- 高德兜底页对模拟器架构显示明确提示，对无坐标地点、地图加载慢、空地图分别提供中文处理状态。

已验证：

- `flutter analyze`，全量通过。
- `flutter test test\widget_test.dart`，12 个测试通过。
- 核心目录源码扫描无乱码/英文残留命中。
- 高德兜底页代码包含完整的中文错误/空态/加载态。

仍未完成：

- 高德原生地图真实加载、蓝点、方向箭头和精度圈需要 Android 真机验证。
- 视觉资产（真实饮品照片、真实地图底图、定制图标/插画）尚未替换代码占位。
- 尚未执行正式 release APK 构建和服务器发布。

## 三十二、2026-08-24 高德真机验证准备清单

已完成：

- 确认 AndroidManifest 已配置 `ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`INTERNET`、`ACCESS_NETWORK_STATE`。
- 确认 `com.amap.api.v2.apikey` 已写入 `AndroidManifest.xml`。
- 确认 `MainActivity` 已初始化高德隐私合规，并调用 `MapsInitializer.setApiKey`。
- 确认项目依赖 `com.amap.api:3dmap:10.0.600`。
- 确认 `APSService` 已声明。
- 当前 release 构建仍使用 debug 签名，当前签名 SHA1 为 `07:68:51:95:5C:55:C4:C7:19:17:26:9A:14:11:AE:9F:CE:99:F6:72`。

真机验证时需要确认：

- 高德开放平台 Android 地图 Key 的包名为 `com.lovegirl.lovegirl_flutter`。
- 高德开放平台 Key 绑定 SHA1 为 `07:68:51:95:5C:55:C4:C7:19:17:26:9A:14:11:AE:9F:CE:99:F6:72`（当前 debug/release 共用签名）。
- 真机首次进入旅行页点击 `真地图`，确认原生底图加载、蓝点、方向箭头、精度圈。
- 确认真机定位权限已授权，且 App 能通过 `/api/weather/coords` 获取当前城市天气。
- 如果高德地图 Key 绑定的是正式 release SHA1，需要在切换正式签名后重新核对。

仍未完成：

- Android 真机尚未连接，无法执行上述原生地图验证。
- 正式 release 签名尚未确定，当前构建仍使用 debug 签名。
- 尚未执行正式 release APK 构建和服务器发布。
