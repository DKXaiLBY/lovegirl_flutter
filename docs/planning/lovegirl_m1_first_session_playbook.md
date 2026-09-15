# LoveGirl M1 首次工作会话作战卡

更新时间：2026-07-17
适用阶段：准备正式进入实现阶段的第一个工作会话

## 1. 这份文档的定位

前面的文档已经说明了：

- 为什么应该从 `M1` 开始
- `M1` 要盘哪些东西
- `M1` 完成后要留下哪些证据

这份作战卡只解决一个更具体的问题：

**如果下一条消息就开始干活，第一个工作会话到底按什么顺序推进？**

它不替代 `M1` 工单，而是把 `M1` 的第一段路压成一张可以直接执行的会话卡。

## 2. 本次会话目标

本次会话不追求“一口气做完 M1”，而是追求三件事：

1. 快速确认真实工作区现状
2. 产出第一批结构盘点证据
3. 给后续 M1 持续推进建立稳定节奏

## 3. 开始前只看这 4 份文档

本次会话开始前，最多只需要看下面这些：

1. [LoveGirl-全面修复与重构目标文档.md](D:/lovegirl_flutter/LoveGirl-全面修复与重构目标文档.md)
2. [lovegirl_implementation_kickoff_brief.md](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_kickoff_brief.md)
3. [lovegirl_phase1_baseline_cleanup_worklist.md](D:/lovegirl_flutter/docs/planning/lovegirl_phase1_baseline_cleanup_worklist.md)
4. [lovegirl_master_delivery_control_board.md](D:/lovegirl_flutter/docs/planning/lovegirl_master_delivery_control_board.md)

如果在第一会话里还要额外翻很多文档，说明开工入口设计得不够短。

## 4. 会话顺序

### Step 0：确认工作区真实状态

目标：

- 看当前工作树是否脏
- 看有没有上一次未完成改动
- 看关键目录当前是否仍和文档审计一致

建议确认：

- `git status`
- `lib/screens`
- `lib/providers`
- `lib/services`
- `server_fixes`

本步产出：

- 一段“当前真实起点状态”记录

停点判断：

- 如果发现工作区状态和文档证据差异很大，先补记录，不直接改代码

### Step 1：做主入口与目录级盘点

目标：

- 快速拿到 `main.dart`、screen 目录、provider 目录、service 目录的第一批事实

优先看：

- `lib/main.dart`
- `lib/screens/*`
- `lib/providers/*`
- `lib/services/*`

本步产出：

- `main.dart` 责任拆分笔记初稿
- screen / provider / service 现状表初稿

停点判断：

- 如果连这些目录事实都还没整理出来，不进入任何 UI 改造

### Step 2：做删除与合并目标盘点

目标：

- 把当前最危险的“误删 / 漏删 / 继续平行扩张”风险先框出来

优先盘：

- `search`
- `health / calorie` 残留
- `album / photo`
- `anniversary / countdown`
- `life / tasks`

本步产出：

- 删除残留清单初稿
- 合并迁移源清单初稿

停点判断：

- 如果还不能回答“哪些是真删、哪些是合并、哪些只是迁移源”，先不开始删代码

### Step 3：做后端 route 与投喂双轨盘点

目标：

- 把最容易牵动全局的后端入口先看清

优先看：

- `server_fixes/app.js`
- `server_fixes/feeding.js`
- `server_fixes/feeding_v2.js`
- `server_fixes/finance.js`

本步产出：

- route 盘点表初稿
- feeding v1 / v2 差异盘点初稿
- finance 卡路里残留备注

停点判断：

- 如果后端主线还没盘清，不进入前后端契约重构

### Step 4：结束本次会话并留下标准证据

目标：

- 不在第一会话贪进度
- 把已经查清的内容转成可复用证据

本步产出：

- 一份阶段完成记录
- 一份契约 / 结构变更记录初稿
- 更新过的 M1 证据条目

## 5. 第一会话最小完成标准

只要满足下面这些，本次会话就算有效完成：

- 已确认真实工作区状态
- 已有 `main.dart` / screen / provider / service 现状初稿
- 已有删除与合并目标初稿
- 已有后端 route 和 feeding 双轨盘点初稿
- 已留下至少一份标准化证据记录

这五项没齐之前，不建议把第一会话叫做“已经进入稳定开发”。

## 6. 第一会话不要做的事

下面这些事情，不建议在第一会话就急着做：

- 直接重写首页 UI
- 直接删很多文件但不留盘点记录
- 直接改投喂站状态流
- 直接接高德真地图细节
- 直接改数据库迁移

原因很简单：

- 第一会话的职责是确认起点，不是急着堆结果

## 7. 第一会话推荐证据模板

本次会话结束时，优先使用：

- [实现证据模板](D:/lovegirl_flutter/docs/planning/lovegirl_implementation_evidence_templates.md) 里的：
  - 模板 A：阶段完成记录
  - 模板 B：契约 / 结构变更记录

## 8. 会话结束后的下一个动作

如果本次会话完成质量合格，下一步建议顺序是：

1. 补完 `M1` 剩余盘点
2. 明确可安全执行的第一批清理动作
3. 再进入 `M2 设计系统统一`

## 9. 结论

这份作战卡的价值不在于增加新方案，而在于把“开始实现”这件事从抽象决定，变成一个可以直接落地的第一工作会话。
