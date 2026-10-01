# LoveGirl Design System v2.0（冷白工具风）

> 事实来源：`lib/utils/lovegirl_theme.dart`（tokens 唯一权威）。本文件与代码冲突时以代码为准并回改文档。
> v1.0（纸质手账暖白）已整体作废——v3.37 起全局切换**倒数日式冷白工具风**，v3.40 巩固。旧版可在 git 历史查（`git show v3.39.0:docs/DESIGN_SYSTEM.md`）。

## 0. 产品气质（v2.0）

| 维度 | 结论 |
|---|---|
| 气质 | **冷白工具风（倒数日式）**：纯白、黑灰字阶、克制的功能色。私密但不是手账，效率但不冷淡 |
| 保留的温度 | 票根隐喻（打孔/锯齿/虚线，底色纯白）、拍立得实体复刻、手写字体 Caveat、少量插画的柔和色 |
| 禁忌 | 暖橘/杏黄/暖渐变（已清零）、企业后台感、促销感、玻璃拟态 |

## 1. 色板（与 theme.dart 同步，2026-09-30）

| token | 值 | 语义 |
|---|---|---|
| `primary` | `#1A1A1A` | 主行动：黑底白字按钮、选中态、App 内"墨色" |
| `primaryLight` | `#4A4A4A` | 主色弱化 |
| `primarySoft` | `#F4F4F5` | 墨色的浅底（chips 未选中、次级容器） |
| `secondary` | `#7A9E7E` | 绿=完成/健康语义（保留的唯一彩色功能色） |
| `red` | `#E95B4E` | 仅删除/警示（计数红点、删除按钮） |
| `accent` / `orange` | `#B0B0B5` / `#8E8E93` | 已转灰（历史名保留防编译断裂，禁再当橙色用） |
| `bgLight` / `paper` / `cardLight` | `#FFFFFF` | 页面底/卡底 |
| `paperWarm` | `#F7F7F8` | 冷灰白（次级底） |
| `textPrimary` / `textSecondary` / `textMuted` | `#1A1A1A` / `#888888` / `#999999` | 字阶 |
| `separator` | `#ECECEC` | 分隔线/描边 |
| `planned` | `#9E9AD1` | 计划态蓝钟（唯一紫） |
| `visited` | `#4CAF50` | 已打卡 |

**深色模式**（中性深灰体系）：`bgDark #111113` · `cardDark #1C1C1E` · `textPrimaryDark #ECECEE` · `textSecondaryDark #9E9EA3` · `textMutedDark #7C7C82` · `separatorDark #2C2C2E` · `primarySoftDark #2A2A2D`。语义色（secondary 绿/red/planned）两态通用。**发布前真机过深浅两态**是红线。

## 2. 字阶（沿用 v1.0 统计，未变）

页面大标题 20/w800 · 卡片标题 15-16/w700-800 · 正文 13-14/w400-600 · 辅助 11.5-12.5 · 数字 hero（首页天数）38/w800。中文字体系统默认；手写场景（拍立得白框字/日期戳）用 Caveat 400/700。

## 3. 圆角 4+1 档（theme.dart：radius 14 / radiusLg 18 / radiusXl 26）

| 档 | 值 | 用途 |
|---|---|---|
| xs | 8 | 小徽章、微元素 |
| sm（radius） | 14 | 图标底座、输入框、行内按钮 |
| md（radiusLg） | 18 | 卡片、弹窗、列表条目 |
| lg（radiusXl） | 26 | 底部弹层顶部 |
| pill | 999 | 按钮、chips、角标（按钮禁用 md） |

## 4. 组件规范（现行约定）

- **卡片**：LovePaper（白底、radius 16-18、无描边轻浮起）；冷灰白次级底用 paperWarm
- **主行动按钮**：FilledButton 黑底白字（`context.lgInk`）；次行动：OutlinedButton 黑描边
- **chips**：pill、选中=墨色描边+20α墨色底、未选中=白底+separator 描边
- **图标**：AppIcon PNG 体系（`assets/images/icons/` 41 图标×3 色，深色圆角方底座+白色线条）；Material rounded 系列用于表单/操作位
- **空状态**：IllusImg 插画（illus/ 目录，冷色重生成中）+ 一句标题 + 一句引导
- **票根**：travel_ticket/ticket_styles 保留打孔/锯齿/虚线，底色纯白
- **拍立得**：PolaroidFrame 实体复刻（88:107、纸纹、内凹、显影色、动态光泽、落影随动）——组件内自成体系，勿在外部叠加装饰
- **角标**：高饱和小 pill（黑/红底白字）

## 5. 状态与文案

- 删除/警示用 red；完成/健康用 secondary 绿；计划=蓝钟+`planned` 紫
- 文案口径：口语化短句，操作反馈 ≤12 字；失败文案给出"再试一次"预期（如"抠图失败了，稍后重试一次"）
- 老设备（荣耀 Android 10）不支持 Emoji 13+：**用户可见文案禁用新 emoji**，用图标 PNG / Material Icons（v3.40 起 travel_form 天气/心情已图标化）

## 6. 已知例外（容忍清单）

- 天气状态色与 illus 插画为内容语义，暂保留彩色（冷色重生成提示词见 `docs/design/asset-prompts.md` 底部，等豆包生成替换）
- 我的页纸质票根卡暖白底在深色下仍浅色（纸票隐喻，接受）
- 拍立得显影色/纸纹是"实物复刻"的一部分，不适用冷白规则

## 7. 变更记录

- **v2.0（2026-09-30）**：全文重写对齐冷白工具风；补 SegmentCloth/gal/slidable 等新能力涉及的组件口径
- v1.0→v3.37 修订（2026-09-28）：去暖色，见 git 历史
