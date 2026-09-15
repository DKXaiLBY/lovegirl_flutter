# LoveGirl 实现启动简报

更新时间：2026-07-17
适用阶段：从方案阶段切换到实现阶段时使用

## 1. 这份文档是干什么的

如果后续要正式开始写代码，不需要先把 `docs/planning/` 里的所有文档从头读一遍。

先看这份简报，就能快速知道：

- 当前总目标是什么
- 哪些决定已经冻结
- 第一阶段应该先做什么
- 哪些坑最容易踩
- 开工前还缺什么外部条件

它相当于整套规划文档的“实现入口页”。

## 2. 当前总目标

把 LoveGirl 从“功能很多但体验分散、结构松散”的私人情侣 App，重构成一套：

- UI 统一
- 中文干净
- 核心链路可信
- 可继续扩展
- 可真机验收
- 可发布上线

当前仍未完成的部分是：

- 业务代码实现
- 真机验证
- 服务器部署
- APK 发布

## 3. 已冻结的关键决定

## 3.1 核心保留

- 首页
- 投喂站
- 旅行地图
- 我的页
- 私密聊天
- 伴侣绑定
- 经期管理
- 记账
- 待办
- 愿望清单
- 课程表
- 心情日记
- 恋爱时光轴

## 3.2 合并

- `相册 + 照片`
- `纪念日 + 倒数日`

## 3.3 删除

- 全局搜索
- 卡路里追踪

说明：

- 删除不是只删入口
- 必须连 Provider / Service / API / route / 残留联动一起清掉

## 3.4 UI 方向

统一采用：

- 回忆票根
- 专属菜单
- 纸感卡片
- 关系资料夹

最重要的 4 个落点页：

- `D:/lovegirl_flutter/lib/screens/home/home_screen.dart`
- `D:/lovegirl_flutter/lib/screens/feeding/feeding_screen.dart`
- `D:/lovegirl_flutter/lib/screens/travel/travel_main_screen.dart`
- `D:/lovegirl_flutter/lib/screens/profile/profile_screen.dart`

## 3.5 地图方向

彻底放弃：

- `flutter_map + 高德瓦片`

统一改走：

- 高德 Android 原生地图 SDK
- 高德 Web 服务 API
- 后端代理 Key

## 3.6 安全底线

重构时绝对不能丢：

- 经期数据加密
- 记账金额加密
- 路由鉴权
- 角色权限校验
- 上传校验

## 4. 一开工先做什么

实现阶段不要直接冲进首页或投喂站改 UI。

正确起点是：

### Step 1：执行 `M1 工程基线清理`

先看：

- [Phase 1 工程基线清理工单](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)

先做这些：

- 盘点重复模块
- 盘点空目录
- 盘点 Provider 缺口
- 盘点 Service 缺口
- 盘点搜索 / 卡路里残留
- 盘点投喂 v1 / v2 切换边界

### Step 2：统一设计系统

先看：

- [核心 UI 页面落点映射](D:/lovegirl_flutter/docs/planning/lovegirl_core_ui_screen_mapping.md)

先做这些：

- 收口 `LoveGirlTheme`
- 收口共用 UI 组件
- 明确 `lovegirl_ui.dart` / `organic_ui.dart` 的角色

### Step 3：再改四大核心页

顺序建议：

1. 首页
2. 投喂站
3. 旅行地图
4. 我的页

### Step 4：再补联动与后端统一

不要一上来就做所有联动。

先做：

- 投喂 -> 记账
- 旅行 -> 记账
- 旅行 -> 时光轴
- 经期 -> 投喂推荐

## 5. 开工前最该看的文档

如果时间很紧，按这个顺序看：

1. [根目标入口](D:/lovegirl_flutter/LoveGirl-全面修复与重构目标文档.md)
2. [规划索引](D:/lovegirl_flutter/docs/planning/README.md)
3. [总方案](D:/lovegirl_flutter/docs/planning/lovegirl_full_rebuild_master_plan.md)
4. [实施待办与里程碑](D:/lovegirl_flutter/docs/planning/lovegirl_delivery_backlog_and_milestones.md)
5. [Phase 1 工程基线清理工单](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)
6. [核心 UI 页面落点映射](D:/lovegirl_flutter/docs/planning/lovegirl_core_ui_screen_mapping.md)
7. [风险登记与缓解方案](D:/lovegirl_flutter/docs/planning/lovegirl_risk_register_and_mitigation.md)
8. [外部依赖与发布前置条件](D:/lovegirl_flutter/docs/planning/lovegirl_external_dependencies_and_release_prerequisites.md)

## 6. 当前最容易踩的坑

### 坑 1：跳过基线清理，直接写页面

后果：

- 旧目录、旧 Provider、旧 route 会一直拖着你

### 坑 2：地图等到最后才上真机

后果：

- 返工成本爆炸

### 坑 3：只删入口，不删残留链路

当前已知例子：

- `D:/lovegirl_flutter/server_fixes/finance.js` 里仍有卡路里残留联动

### 坑 4：把 `ApiService` 和页面继续写成巨石文件

后果：

- 改一块牵全身

### 坑 5：忘记敏感数据的加密兼容

后果：

- 经期和记账旧数据可能直接报废

## 7. 开工前外部条件

至少要先确认这些：

- Android 地图 SDK Key
- Android 导航 SDK Key
- 高德 Web 服务 Key
- debug / release SHA1
- 真机设备
- 服务器环境变量
- 版本发布路径

看这里：

- [外部依赖与发布前置条件](D:/lovegirl_flutter/docs/planning/lovegirl_external_dependencies_and_release_prerequisites.md)

## 8. 当前推荐的实现顺序

最推荐的实际推进顺序：

1. 基线清理
2. 设计系统
3. 首页
4. 投喂站
5. 旅行地图
6. 我的页
7. 生活域
8. 回忆域
9. 爱心豆与联动
10. 后端统一与迁移
11. 对抗式审查
12. 真机验收与发布

## 9. 什么情况下可以认为“该停止补方案，开始干活”

到 2026-07-17 为止，答案已经很明确：

- 当前最缺的已经不是新的抽象规划
- 当前最缺的是按既有规划开始实现

也就是说：

- 方案阶段已经足够完整
- 后面继续推进时，最合理动作就是切入实现阶段

## 10. 这份简报的使用方式

后面无论是我继续做，还是换另一个 AI / 开发者接力，都建议先：

1. 打开这份简报
2. 看根目标入口
3. 看规划索引
4. 直接从 `M1` 开始干

这样最省时间，也最不容易被旧材料带偏。
