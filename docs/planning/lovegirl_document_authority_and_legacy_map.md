# LoveGirl 文档权威性与历史资料处置说明

更新时间：2026-07-17
适用阶段：方案确认阶段（当前不写业务代码）

## 1. 文档目的

这份文档解决一个非常现实的问题：

当前仓库里已经积累了不少历史提示词、旧审查稿、旧部署说明、UI 参考文档。

如果后续进入实现阶段时不先说明：

- 哪些文档是当前唯一权威依据
- 哪些只是视觉或历史参考
- 哪些已经不应再作为主执行依据

那么后面很容易出现：

- 同一个问题被旧方案和新方案来回打架
- AI 或开发者误把历史提示词当成当前目标
- 实现顺序被旧文档带偏

## 2. 权威层级定义

### A 类：当前唯一权威执行文档

定义：

- 后续实现与验收时，默认以这些文档为准

### B 类：参考资料

定义：

- 仍然有价值，但不直接覆盖 A 类文档
- 主要用来辅助 UI 还原、历史背景理解或部署核对

### C 类：历史资料 / 不再作为主依据

定义：

- 可以保留，但不能再直接作为当前重构的执行主线

## 3. A 类：当前唯一权威执行文档

当前 A 类文档为：

1. [根目标入口](D:/lovegirl_flutter/LoveGirl-全面修复与重构目标文档.md)
2. [规划索引](D:/lovegirl_flutter/docs/planning/README.md)
3. `docs/planning/` 下的正式规划文档全集（截至 2026-07-18 为 31 份，含 README）

说明：

- 后续如果文档之间有冲突，优先看 `docs/planning/README.md` 的阅读顺序
- 根目标入口负责总目标
- `planning` 目录负责细化执行

## 4. B 类：参考资料

这些文档和资源仍然有用，但属于“参考”而不是“主线指挥”。

### 4.1 UI 参考资料

- `D:/lovegirl_flutter/docs/LoveGirl_UI_参考图还原设计规范.md`
- `D:/lovegirl_flutter/docs/ui/lovegirl-ui-implementation-plan.md`
- `D:/lovegirl_flutter/docs/ui/LoveGirl_UI_prompt_v2.md`
- `D:/lovegirl_flutter/docs/ui/home-b-memory-ticket-reference.png`
- `D:/lovegirl_flutter/docs/ui/ui-board-feeding-travel-profile-v1.png`
- `D:/lovegirl_flutter/docs/ui/profile-folder-ui-v1.png`
- `D:/lovegirl_flutter/docs/ui-reference-confirmed-v3.22.png`

使用方式：

- 这些主要用来对照视觉风格、页面层次、参考图方向
- 不能单独替代新的总方案和实施路线

### 4.2 发布前或验收参考资料

- `D:/lovegirl_flutter/docs/ui/lovegirl-ui-release-preflight.md`
- `D:/lovegirl_flutter/TEST_PLAN.md`
- `D:/lovegirl_flutter/DEPLOY_CHECKLIST.md`
- `D:/lovegirl_flutter/DEPLOY_INSTRUCTIONS.md`

使用方式：

- 适合作为后续发布阶段的补充参考
- 但最终发布门槛，以 `planning` 目录中的正式文档为主

### 4.3 数据与脚本参考资料

- `D:/lovegirl_flutter/docs/lovegirl_e2e_acceptance.ps1`
- `D:/lovegirl_flutter/docs/lovegirl_pre_e2e_cleanup_20260703014559.sql`
- `D:/lovegirl_flutter/docs/schema_check.sql`
- `D:/lovegirl_flutter/docs/remote_admin_before_p1.js`

使用方式：

- 用于了解历史验收和数据库检查方式
- 不直接等同于本轮重构的正式迁移方案

## 5. C 类：历史资料 / 不再作为主依据

这些文档可以保留，但后续不应再直接当作当前实现主线。

### 5.1 历史提示词类

- `D:/lovegirl_flutter/LoveGirl-P1功能补全-提示词.md`

说明：

- 它反映的是某一阶段的补全目标
- 不再覆盖当前这轮完整重构总方案

### 5.2 历史审查类

- `D:/lovegirl_flutter/LoveGirl-优化审查报告.md`

说明：

- 它可以作为历史问题回看材料
- 但不能替代当前这轮的风险、审查、验收要求

### 5.3 仓库默认 README

- `D:/lovegirl_flutter/README.md`

说明：

- 可保留为项目基础说明
- 但当前重构实施顺序不以它为主

## 6. 使用规则

后续进入实现阶段时，建议严格遵守下面这条规则：

### 规则 1：先看 A 类，再看 B 类，最后才看 C 类

顺序：

1. 先看 `LoveGirl-全面修复与重构目标文档.md`
2. 再看 `docs/planning/README.md`
3. 再按 `README` 中的顺序看 planning 文档
4. 需要视觉细节时，再回看 `docs/ui/` 和 UI 参考图
5. 需要历史背景时，再看旧提示词和旧审查稿

### 规则 2：当 A 类和旧文档冲突时，一律以 A 类为准

### 规则 3：不要再从历史提示词倒推当前总方案

应该反过来：

- 先以当前总方案为主
- 再决定历史资料还有哪些能吸收

## 7. 当前阶段结论

截至 2026-07-17，LoveGirl 已经从“多份零散提示词驱动”切换成了“成套权威规划文档驱动”。

这份文档的作用，就是把这个边界明确写死，避免后续再次被旧资料拖回去。
