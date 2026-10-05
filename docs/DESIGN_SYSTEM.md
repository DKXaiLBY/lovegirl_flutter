# LoveGirl Design System v2.0（冷白工具风）

> 事实来源：`lib/utils/lovegirl_theme.dart`（tokens 唯一权威）。本文件与代码冲突时以代码为准并回改文档。
> v1.0（纸质手账暖白）已整体作废——v3.37 起全局切换**倒数日式冷白工具风**，v3.40 巩固。旧版可在 git 历史查（`git show v3.39.0:docs/DESIGN_SYSTEM.md`）。

## 0. 产品气质（v2.0）

| 维度 | 结论 |
|---|---|
| 气质 | **奶油暖白工具风（v3.41，倒数日式的暖化版）**：奶油底、暖炭字阶、白卡浮起、蜜桃点缀。私密但不手账，明亮但不糖果 |
| 保留的温度 | 票根隐喻（打孔/锯齿/虚线，底色纯白）、拍立得实体复刻、手写字体 Caveat、少量插画的柔和色 |
| 禁忌 | 企业后台感、促销感、玻璃拟态、无白名单的渐变滥用（暖色自 v3.41 以「奶油底+蜜桃点缀」双轨回归：蜜桃=情感/点缀，冷灰 #8E8E93=内容中性态） |

## 1. 色板（与 theme.dart 同步，2026-09-30）

| token | 值 | 语义 |
|---|---|---|
| `primary` | `#1A1A1A` | 主行动：黑底白字按钮、选中态、App 内"墨色" |
| `primaryLight` | `#4A4A4A` | 主色弱化 |
| `primarySoft` | `#F4F4F5` | 墨色的浅底（chips 未选中、次级容器） |
| `secondary` | `#7A9E7E` | 绿=完成/健康语义（保留的唯一彩色功能色） |
| `red` | `#E95B4E` | 仅删除/警示（计数红点、删除按钮） |
| `orange` | `#8E8E93` | 内容中性态冷灰（历史名保留；与蜜桃双轨，见第 0 节） |
| `bgLight` | `#FAF6F0` | 页面底（奶油白，v3.41） |
| `paper` / `cardLight` | `#FFFFFF` | 卡底（在奶油底上浮起） |
| `paperWarm` | `#F1E8DA` | 暖次级底（v3.41） |
| `textPrimary` / `textSecondary` / `textMuted` | `#2B2723` / `#6E655B` / `#7A7062` | 暖炭字阶（v3.41；muted 对奶油底 4.5:1） |
| `accent` / `peach` | `#F2704F` | 蜜桃珊瑚=情感/点缀/选中态（图形与底色专用，勿做正文色） |
| `peachText` | `#C9502E` | 蜜桃文本档（对白 4.5:1，财务收入/标签文字用） |
| `gradientSunrise` | `#FFE3C8→#FFD9E3` | 蜜桃日出渐变（白名单三处：首页头部/纪念日卡顶条/月报头图；仅浅色态） |
| `separator` | `#ECECEC` | 分隔线/描边 |
| `planned` | `#9E9AD1` | 计划态蓝钟（唯一紫） |
| `visited` | `#4CAF50` | 已打卡 |

**深色模式**（微暖深灰体系，v3.41）：`bgDark #1C1917` · `cardDark #262220` · `textPrimaryDark #EFEAE4` · `textSecondaryDark #A89F95` · `textMutedDark #8D847A` · `separatorDark #33302B` · `primarySoftDark #2E2A26`。语义色（secondary 绿/red/planned/peach）两态通用。**深色态不上日出渐变**（三处 hero 用 primarySoftDark 单色）。**发布前真机过深浅两态**是红线。

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
- **渐变 hero 白名单**：仅首页头部/纪念日卡顶条/月报头图三处；装饰层不带正文文字，渐变上只放墨黑系文字
- **蜜桃双档**：`peach` 做图形/底色/描边，文字一律 `peachText`；与功能红 #E95B4E 同族，删除按钮同屏时真机验证

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
