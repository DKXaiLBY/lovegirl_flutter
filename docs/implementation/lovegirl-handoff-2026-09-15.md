# LoveGirl 票根系 UI 与旅行地图交接文档

生成日期：2026-09-15
交接原因：用户要求暂停当前目标，把未完成任务交给其他 AI 继续执行
当前目标状态：暂停，未完成，未发布 APK
仓库根目录：`D:\lovegirl_flutter`
当前分支：`master`
当前 HEAD：`408304b80835db3a01d9401b2430eaf8b762b8c7`（2026-06-27）

---

## 0. 接手方先读这一段

这不是一个“从零开始做 UI”的任务，也不是一个“代码已经完成，只差打包”的任务。

真实状态是：

1. 仓库里已经存在大量围绕票根系 UI、旅行地图、天气、投喂站、我的页的改动，但这些改动几乎全部处于**未提交**状态。
2. 这些改动里有一部分是此前会话完成的，也有一部分可能是用户自己或其他工具完成的。
3. 此前的会话文档记录过“`flutter analyze` 通过”“12 个测试通过”“模拟器运行通过”，但那些记录来自更早的时间点，本次交接时**没有重新运行验证**，不能直接当作当前证据。
4. 高德原生地图从来没有完成安卓真机验证。用户在真实手机上遇到过“点击打开高德地图模式直接闪退”，也遇到过 UI 与展示效果不一致、中文乱码、天气不显示、体感温度越界等问题。
5. 当前目标明确要求：**全部完成并验证之前，不构建正式 APK，不发布新版本。**

接手方最重要的一条原则：

> 不要把“代码里有这个控件”“之前文档说验证过”“模拟器兜底页不崩”当成“需求已经完成”。

必须优先做的是：还原用户真实可见的行为，并按第 8 节的验收清单逐条拿到证据。

---

## 1. 项目背景

LoveGirl 是给女朋友做的私人情侣 APP，不推广，只两个人使用。

- Flutter 前端：`D:\lovegirl_flutter`
- Node.js + Express 后端源码：`D:\lovegirl_flutter\server_fixes`
- MySQL
- 服务器：`47.121.119.191`
- API 基址：`http://47.121.119.191:3001/api`

界面语言必须为中文。整体气质要求：温暖、精致、克制，像一份“专属菜单”和“回忆票根”，不要粉、不要花、不要像办公软件，也不要廉价的通用情侣 APP 风格。

用户明确说过：第一眼不应该让人烦躁，而是“被宠爱、很温暖”的感觉。她在意精致度，愿意把浏览过程本身当成享受，而不是一味追求信息密度。

---

## 2. 当前执行目标原文

> 把已确认的 LoveGirl 票根系 UI 与旅行地图参考图整理成正式执行目标，并按 P0 优先级推进实现：先修复旅行地图/高德真地图里的乱码与明显交互缺口，再把首页、旅行地图、投喂站、我的页逐步对齐参考图，最后通过静态分析和核心测试验证，不在未完成前发布 APK。

拆分后的执行顺序：

1. 修复旅行地图与高德真地图的乱码、闪退和交互缺口。
2. 把首页、旅行地图、投喂站、我的页逐步对齐参考图。
3. 运行静态分析和核心测试。
4. 做 Android 运行验证。
5. 全部通过后才构建正式 APK 并发布。

---

## 3. 设计基准与参考资产

已确认的参考图（仓库内真实存在，接手方应直接打开查看）：

| 用途 | 路径 | 大小 |
|---|---|---|
| 首页基准 | `docs/lovegirl-ui-home-09.png` | 约 1.46 MB |
| 旅行地图基准 | `docs/lovegirl-ui-home-06.png` | 约 1.65 MB |
| 其他历史参考 | `docs/lovegirl-ui-home-05.png` | 约 1.26 MB |
| 其他历史参考 | `docs/lovegirl-ui-home-08.png` | 约 1.17 MB |
| 疑似最终确认版参考 | `docs/ui-reference-confirmed-v3.22.png` | 约 1.82 MB |

另外用户曾保存过一张首页图：`C:\Users\DKX\Downloads\首页B回忆票根版.png`。接手时若该文件仍存在，可以作为补充参考，但它不是仓库内的权威副本。

参考图必须被当作**验收基准**，不是“灵感来源”。用户此前多次因为“实际装到手机上的 UI 和展示给他的图不一样”而不满。

---

## 4. 权威目标文档

优先级从高到低：

1. `docs/implementation/lovegirl-ticket-ui-travel-map-target.md`
   - 这是最完整的执行目标 + 历史推进记录（约 55 KB）。
   - 里面按日期记录了每一轮改动、验证命令和“仍未完成”的事项。
   - 注意：其中的“已验证”是**当时**的验证记录，不等于当前状态，必须重新跑。
2. `docs/implementation/lovegirl-unified-goal-2026-07-18.md`
3. `docs/implementation/m1-baseline-cleanup-2026-07-18.md`
4. `CLAUDE.md`（项目概况、服务器信息、编译命令）
5. `LoveGirl-全面修复与重构目标文档.md`（仓库根目录，属更早的全面重构方案）

不要以 `README` 或旧聊天记录为准，以当前代码和目标文档为准。

---

## 5. 当前仓库状态（重要）

### 5.1 Git 状态

`git status --short` 的结果非常庞大，包含：

- 大量已修改但未提交的 `lib/`、`android/`、`server_fixes/`、`packages/`、`test/` 文件。
- 已删除的 `lib/screens/health/widgets/calorie_tracker.dart`、`lib/screens/search/search_screen.dart`、`server_fixes/search.js`。
- 大量未跟踪的新文件。

结论：

> 接管时**绝对不要**执行 `git reset --hard`、`git checkout -- .`、`git clean -fd` 之类的操作。

这些改动代表此前所有工作成果，一旦回滚就全部丢失。用户没有授权回滚。

### 5.2 工作区被临时产物污染

仓库根目录堆积了数百个 `tmp_*.png`、`tmp_*.xml`、`tmp_*.txt`、`build_log*.txt` 等调试产物。

这些不是产品代码，但**在没有确认之前不要直接删除**，因为部分文件可能仍被用户或此前会话当作证据引用（例如 `tmp_goal_home_weather_cs.png`、`tmp_goal_amap_*`）。

合理做法：

1. 先把它们列入 `.gitignore`。
2. 或者移动到独立的 `docs/evidence/` 目录。
3. 清理前先询问用户，不要自作主张删除。

### 5.3 版本号

`pubspec.yaml` 中当前为 `version: 3.22.0+150`。

此前历史发布到过 `3.21.3+144`。发布链路相关经验见第 11 节。

---

## 6. 关键代码位置

### 6.1 旅行地图

| 文件 | 作用 | 行数（大致） |
|---|---|---|
| `lib/screens/travel/travel_main_screen.dart` | 旅行主页面，含预览地图、筛选、地点票根、路线入口 | 很大，需分段阅读 |
| `lib/screens/travel/travel_amap_mode_screen.dart` | 高德真地图全屏页、浮层 UI、兜底逻辑 | 很大 |
| `lib/widgets/travel_map_widget.dart` | 真正包裹 `AMapWidget` 的地图组件 | 约 600 行 |
| `lib/providers/travel_provider.dart` | 旅行状态管理、路线预览、CRUD | 约 600 行 |
| `lib/screens/travel/travel_form_screen.dart` | 新增/编辑地点表单 | - |
| `lib/screens/travel/map_picker_screen.dart` | 地图选点 | - |
| `lib/screens/travel/travel_ticket_screen.dart` | 旅行票根 | - |

### 6.2 首页与天气

- `lib/screens/home/home_screen.dart`（约 2077 行）
- `lib/widgets/weather_widget.dart`（约 636 行）
- `lib/providers/home_provider.dart`

### 6.3 投喂站

- `lib/screens/feeding/feeding_screen.dart`（约 2210 行）

### 6.4 我的页

- `lib/screens/profile/profile_screen.dart`（约 723 行）
- `lib/screens/profile/achievements_screen.dart`
- `lib/screens/profile/admin_feeding_screen.dart`

### 6.5 公共 UI 与主题

- `lib/widgets/lovegirl_ui.dart`（约 510 行，票根、条码、菜单行等公共组件）
- `lib/widgets/organic_ui.dart`
- `lib/utils/lovegirl_theme.dart`（约 200 行）
- `lib/main.dart`（AppShell、底部导航）

### 6.6 Android 与高德配置

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/lovegirl/lovegirl_flutter/MainActivity.kt`
- `packages/amap_flutter_map/`（项目内 fork，非 pub 官方包）
- `packages/amap_flutter_base/`（项目内 fork）

---

## 7. 已完成 / 未完成对照表

以下状态按“代码层面存在”与“是否有当前可验证证据”区分。

### 7.1 旅行地图

| 需求 | 代码状态 | 当前验证状态 |
|---|---|---|
| 使用高德原生地图而非瓦片 | 已实现：`TravelMapWidget` 使用 `AMapWidget` | 未在真机验证 |
| 当前位置蓝点 | 已实现：`myLocationStyleOptions` + `locationRotate` | 未在真机验证 |
| 方向指示 | 代码中传入 `bearing`、`trackingMode: locationRotate` | 未在真机验证 |
| 精度圈 | 已配置 `circleFillColor` / `circleStrokeColor` / `circleStrokeWidth` | 未在真机验证 |
| 点击地点平滑移镜 | 已实现：`AMapController.moveCamera(..., animated: true, duration: 650)` | 未在真机验证 |
| Marker 高亮 | 已实现：`highlightedId` + `BitmapDescriptor.hueRose` | 未在真机验证 |
| 路线折线 | 已实现：`Polyline` + 双层描边 | 未在真机验证 |
| 中文兜底状态 | 已实现：无坐标、空数据、加载慢均有中文提示 | 模拟器曾验证不崩 |
| 接口 Key 管理 | Key 硬编码在 Dart 与 Manifest 中 | 需要改进 |
| 打开真地图不闪退 | 模拟器入口改成兜底页，不再崩溃 | 真机仍未知 |

### 7.2 首页

| 需求 | 状态 |
|---|---|
| 顶部 LoveGirl、恋爱天数、天气、爱心豆 | 代码已存在 |
| 今日照顾（投喂 + 待办） | 代码已存在，含窄屏并排布局 |
| 随机回忆票根 | 代码已存在 |
| 旅行票根卡 | 代码已存在，英文已被替换为中文 |
| 生活摘要（账本 + 课程） | 代码已存在 |
| 天气体感温度 | 代码已存在，compact 卡片含 `体感` 标签 |
| 与参考图逐像素对齐 | **未完成** |

### 7.3 投喂站

| 需求 | 状态 |
|---|---|
| 专属菜单视觉 | 已朝该方向改造 |
| 历史英文种子名转中文 | 已实现显示层映射（`热汤面`、`盖饭套餐` 等） |
| 真实履约状态流 | 已实现接单 → 准备 → 配送 → 完成 |
| 配送中必须补真实平台/金额/订单号 | 已实现 |
| 乱码清理 | 源码扫描曾无命中，需复验 |
| 催单触发真实通知 | 未完成，仍是计数语义 |
| 下单弹窗运行态 | 曾有模拟器截图证据 |

### 7.4 我的页

| 需求 | 状态 |
|---|---|
| 关系资料夹方向 | 已实现 |
| 纪念日 + 倒数日合并入口 | 已实现 |
| 相册/照片/旅行票根合并为回忆入口 | 已实现入口层 |
| 不堆砌无关内容 | 已朝该方向收口，仍需复核 |

### 7.5 全局

| 需求 | 状态 |
|---|---|
| 删除全局搜索 | 代码已删除（`search_screen.dart`、`server_fixes/search.js`） |
| 删除卡路里追踪 | 代码已删除 |
| 待办 / 愿望清单 | 保留为同一入口下两个分区，未强行合并概念 |
| 中文界面 | 代码层做过清理，仍需运行时复验 |

---

## 8. 验收清单（接手方必须逐条拿到证据）

### 8.1 旅行地图（P0）

- [ ] 安卓真机上点击“打开高德地图模式”不闪退、不白屏。
- [ ] 原生高德底图能正常加载（不是模拟器兜底页）。
- [ ] 当前位置蓝点可见。
- [ ] 方向/朝向指示可见且随移动更新。
- [ ] 精度圈可见。
- [ ] 点击地点后相机平滑移动过去（有动画，不是瞬时跳转）。
- [ ] 被选中的 Marker 有明显高亮。
- [ ] 路线折线正常绘制，起终点和途经点可辨。
- [ ] 地点底部票根详情能弹出，含封面、标题、地址、天气、日期、预算、共同编辑、双方备注。
- [ ] “加入路线”可生成路线预览。
- [ ] “生成票根”只对已打卡地点生效，未打卡给明确中文提示。
- [ ] “记一笔花费”给出明确状态，不假装已完成闭环。
- [ ] 无坐标、空数据、Key 错误、定位被拒、网络失败都有清楚中文提示。
- [ ] 页面上不出现 `???`、`�`、`LOVEGIRL TRIP`、`Day 1`、`RenderFlex`、`BOTTOM OVERFLOWED`。

### 8.2 首页

- [ ] 全部用户可见文字为中文。
- [ ] 天气卡显示城市、天气、温度、体感温度。
- [ ] 体感温度不越界、不被裁切。
- [ ] 天气定位失败时显示明确错误态，不使用硬编码城市伪装成功。
- [ ] 第一屏体现“被认真照顾”的感觉，而不是功能宫格。
- [ ] 360 逻辑宽设备上无溢出。
- [ ] 与 `docs/lovegirl-ui-home-09.png` 逐项比对。

### 8.3 投喂站

- [ ] 商品列表像专属菜单。
- [ ] 无乱码、无英文残留。
- [ ] 下单弹窗完整可用。
- [ ] 订单状态中文清楚。
- [ ] 订单详情能看到真实平台信息、真实金额、订单号、备注。
- [ ] 催单失败不破坏订单数据一致性。

### 8.4 我的页

- [ ] 中文清楚，入口层级少而稳。
- [ ] 关系资料卡正常。
- [ ] 纪念日与倒数合并入口正常。
- [ ] 回忆入口正常。
- [ ] 不把所有功能平铺成设置列表。

### 8.5 工程验证命令

```powershell
# 推荐使用项目 SDK（当前 PATH 上可能没有 flutter）
D:\flutter-sdk\bin\flutter.bat analyze --no-pub
D:\flutter-sdk\bin\flutter.bat test test\widget_test.dart

# 仅在全部完成后再执行
D:\flutter-sdk\bin\flutter.bat build apk --release
```

Android 原生插件编译检查：

```powershell
cd D:\lovegirl_flutter\android
.\gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin
```

---

## 9. 高德地图真实链路（接手方必读）

### 9.1 调用链

```
TravelMainScreen._openAmapMode()
  -> Navigator.push(TravelAmapModeScreen)
       -> _initNativeMapSupport()
            -> MethodChannel('lovegirl/device').getSupportedAbis()
            -> 若包含 x86 前缀：判定为模拟器，显示兜底页
       -> _scheduleMapMount()  延迟 420ms
            -> TravelMapWidget
                 -> AMapWidget
                      -> AndroidView(viewType: com.amap.flutter.map)
                           -> AMapPlatformView -> TextureMapView
```

### 9.2 关键事实

1. `TravelAmapModeScreen` 会在检测到 x86 模拟器时**主动跳过**原生地图，显示“模拟器预览”。这意味着在 x86 模拟器上做“高德地图验证”是无效的。
2. `TravelMapWidget` 里确实使用了 `AMapWidget`、`AMapController`、`Marker`、`Polyline`、`moveCamera`，这部分是真实实现，不是假地图。
3. 原生插件 `packages/amap_flutter_map` 是项目内 fork，已经被改动过（`AMapPlatformView.java`、`MapController.java`、`AMapOptionsBuilder.java`、`ConvertUtil.java`、`AMapErrorPlatformView.java` 等）。升级或替换该包时要特别小心。
4. `AMapPlatformView.getView()` 在 `mapView == null` 时返回中文错误兜底 View，避免把空 View 交给 PlatformView 层导致崩溃。

### 9.3 当前 Key 与隐私合规

- Android 地图 Key：`2209d350da6804c16673f5c36d52f64b`
  - 出现在 `lib/widgets/travel_map_widget.dart` 的 `_androidMapKey`
  - 也出现在 `android/app/src/main/AndroidManifest.xml` 的 `com.amap.api.v2.apikey`
- `MainActivity.kt` 中调用了：
  - `MapsInitializer.updatePrivacyShow(...)`
  - `MapsInitializer.updatePrivacyAgree(...)`
  - `MapsInitializer.setApiKey(...)`
  - `AMapLocationClient.updatePrivacyShow(...)`
  - `AMapLocationClient.updatePrivacyAgree(...)`
- 依赖：`com.amap.api:3dmap:10.0.600`
- `APSService` 已在 Manifest 声明
- 已声明的权限：`INTERNET`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`CHANGE_WIFI_STATE`、`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`ACCESS_LOCATION_EXTRA_COMMANDS`
- 此前记录的签名 SHA1：`07:68:51:95:5C:55:C4:C7:19:17:26:9A:14:11:AE:9F:CE:99:F6:72`
- 此前 release 构建仍使用 debug 签名

**待确认**：高德开放平台上的 Key 是否绑定了正确的包名 `com.lovegirl.lovegirl_flutter` 与上述 SHA1。如果 Key 绑定的是旧 SHA1 或旧包名，真机上会出现底图空白，而代码层看不出问题。

### 9.4 建议改进

1. 把硬编码的 Android Key 移到 `--dart-define` 或本地配置，避免提交进仓库。
2. Web 服务 Key（地理编码、POI、路径规划、天气）应放在服务器 `.env`，由后端代理，不要进 Flutter 前端。
3. `_checkNativeMapSupport()` 目前只按 ABI 判断是否模拟器。这个判断能避免模拟器崩溃，但也让模拟器完全无法验证地图；接手方应考虑增加显式开关（例如 `--dart-define=LOVE_GIRL_FORCE_AMAP=true`），便于在支持的模拟器上强制尝试。

---

## 10. 已知问题与坑

### 10.1 会导致返工的坑

1. **不要用 `flutter_map` + 高德瓦片替代原生地图。**
   用户已经明确否决瓦片方案，评价是“根本不好用、很劣质”。必须走高德 Android 地图 SDK。

2. **模拟器验证不等于真机验证。**
   当前实现会在 x86 模拟器上走兜底页。兜底页不崩，不能证明原生地图可用。

3. **不要把“代码里有控件”当成“用户能看到”。**
   用户真实反馈过：更新到最新版本后 UI 和展示的图完全不一样。
   任何 UI 结论都必须以真机/模拟器截图 + UI XML 为准。

4. **不要只改一层就宣布完成。**
   地理编码、天气、路线依赖后端接口。前端改了但后端没部署，用户端依然看不到效果。

5. **注意自动登录与版本弹窗。**
   运行态截图时容易被登录页或版本更新弹窗挡住，导致误判页面状态。调试时可用：
   ```powershell
   --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true
   ```
   `AppShell._skipVersionCheckInQa` 会跳过版本检查。

### 10.2 编码与乱码

1. Dart 源码中曾用 `\uXXXX` 转义写中文，目的是避免编辑过程引入乱码。接手时保持这个习惯，或确保编辑器使用 UTF-8。
2. 历史数据库里存在英文种子数据（例如 `hot noodles`、`rice bowl`），已在显示层做中文映射。修改商品逻辑时不要绕过这层映射。
3. 旅行页对明显损坏的文本（`???`、`�`）做了显示层清洗，会回退成 `未命名地点`、`还没填写地址`。这是有意设计，不要删掉。
4. 服务器 changelog 路径曾出现中文乱码，更新对话框建议保持 ASCII 内容。

### 10.3 工具链与构建

1. 当前环境的 `flutter` 不在 PATH 上，`adb` 也不在 PATH 上。需要使用：
   - Flutter：`D:\flutter-sdk\bin\flutter.bat`
   - ADB：通常在 `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
2. 建议设置环境变量：
   ```
   JAVA_HOME=C:\Program Files\Java\jdk-17.0.3.1
   PUB_HOSTED_URL=https://pub.flutter-io.cn
   FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
   ```
3. `rg.exe` 在本机曾出现 `StandardOutputEncoding` 报错，改用 `Get-ChildItem`、`Select-String`、`Get-Content` 更稳。
4. Gradle 曾遇到锁文件冲突和 wrapper 下载失败，需要清理 Gradle 锁或直接使用已缓存的 Gradle 8.9。
5. `amap_flutter_map 3.0.0` / `amap_flutter_base 3.0.0` 与 Flutter 3.27.4 不兼容（`hashValues`、`hashList` 被移除），当前改用项目内 fork。不要轻易 `flutter pub upgrade` 把它换回官方包。

### 10.4 发布链路的坑（仅在最终发布时相关）

1. `pubspec.yaml`、`lib/utils/constants.dart` 的版本号必须一致。
2. 发布走 `/api/deploy/publish`，更新检查走 `/api/version/check?version_code=...`。
3. APK 下载路径为 `/public/download/LoveGirl-latest.apk`。
4. `file_size` 必须是原始字节数。
5. `app_versions` 表需要 `uk_version_code(version_code)` 唯一键，否则 upsert 会产生重复行。
6. 有效 `DEPLOY_TOKEN` 曾出现在 `/opt/love-girl/docker-compose.yml`，不是 `.env`。
7. `publish.py` 读取文件需要 UTF-8，并对子进程用 `encoding='utf-8', errors='replace'`。
8. 本次目标明确要求：**未完成前不构建、不发布。**

---

## 11. 接手后建议的执行顺序

### 第一步：恢复执行环境

1. 确认 `D:\flutter-sdk\bin\flutter.bat` 可用。
2. 确认 `adb devices -l` 能列出安卓真机。
3. 记录当前 `git status --short` 快照，**不要回滚**。

### 第二步：先跑基线验证

```powershell
D:\flutter-sdk\bin\flutter.bat analyze --no-pub
D:\flutter-sdk\bin\flutter.bat test test\widget_test.dart
```

目的：确认当前未提交的代码至少是能分析的、测试是过的。如果这里就报错，先修好再谈 UI。

### 第三步：真机高德验证（P0）

1. 连接安卓真机，确认高德 Key 的包名和 SHA1 匹配。
2. 授权定位权限。
3. 打开旅行 → 打开高德地图模式。
4. 逐条核对第 8.1 节清单。
5. 抓 logcat，检查是否有 `FATAL EXCEPTION`、`UnsatisfiedLinkError`、`NullPointerException`。

如果真机不可用，**不要假装完成**，明确标注为阻塞并继续做其他可验证的部分。

### 第四步：修 P0 问题

优先级从高到低：

1. 真地图闪退 / 白屏。
2. 中文乱码。
3. 定位蓝点、方向、精度圈。
4. Marker 高亮与平滑移镜。
5. 路线折线。
6. 底部票根详情完整性。

### 第五步：四页 UI 对齐

顺序：旅行地图 → 首页 → 投喂站 → 我的页。

对每一页：

1. 打开参考图。
2. 截取真机/模拟器当前界面。
3. 逐项列出差异（间距、层级、字号、圆角、图标、文案）。
4. 改代码。
5. 重新截图对比。

不要跳过第 3 步，否则会重复“看起来差不多但其实不一样”的问题。

### 第六步：完整验证

```powershell
D:\flutter-sdk\bin\flutter.bat analyze
D:\flutter-sdk\bin\flutter.bat test test\widget_test.dart
```

再加上运行态检查：

- 无 `FATAL EXCEPTION`
- 无 `RenderFlex overflowed`
- 无 `BOTTOM OVERFLOWED`
- 无 `MissingPluginException`
- UI XML 中无 `???`、`�`
- 不误弹登录页

### 第七步：仅在全部通过后发布

发布前再次确认版本号、APK、`/api/version/check`、APK HEAD 元数据、`app_versions` 唯一键。

---

## 12. 当前明确未完成的事项

1. 高德原生地图的安卓真机验证（蓝点、方向、精度圈、底图加载）。
2. 真实手机上“打开高德地图模式”是否仍然闪退。
3. 四个核心页面与参考图的截图级对齐。
4. 首页天气在真实定位下的稳定性与体感温度布局。
5. 投喂站催单触发真实推送通知。
6. 旅行花费同步到记账模块的完整闭环。
7. 旅行票根的正式生成闭环。
8. 路线保存的后端闭环。
9. 正式 release 签名与高德 Key 的绑定确认。
10. 正式 APK 构建与服务器发布。

---

## 13. 需要向用户确认的问题

接手方在推进前，建议向用户确认：

1. 高德开放平台上 Android 地图 Key 当前绑定的包名和 SHA1 是否与仓库配置一致。
2. 是否已经有可用的安卓真机可以连接调试；如果没有，用户可以自己安装 debug 包来验证。
3. 正式签名方案（当前 release 仍用 debug 签名），是否要切换到正式签名。
4. 参考图以 `docs/ui-reference-confirmed-v3.22.png` 还是 `docs/lovegirl-ui-home-09.png` 为最终基准。
5. 投喂站催单通知的推送通道选择（本地通知 / 极光 / Firebase / 其他）。

---

## 14. 交接总结

这个任务的核心难点不是“写 UI”，而是：

1. 工作区有大量未提交的历史改动，必须在不破坏它们的前提下继续。
2. 高德原生地图在模拟器上走兜底，真机验证从未完成。
3. 用户对“代码里有”和“手机上看得到”的差异非常敏感，必须拿到运行态证据。
4. 目标明确要求未完成前不发布。

接手方只要坚持三件事，就不会走偏：

> 先跑基线验证，再做真机地图验证，最后才逐页对齐 UI。
>
> 任何“已完成”的结论都必须有当前工作区或设备的证据。
>
> 不构建、不发布，直到第 8 节清单全部通过。

