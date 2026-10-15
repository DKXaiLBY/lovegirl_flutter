# LoveGirl Design System v3.0（冷灰工具风 v4）

> 事实来源：`lib/utils/lovegirl_theme.dart`（tokens 唯一权威）。本文件与代码冲突时以代码为准并回改文档。
> v2.0（v3.41 奶油暖白）自 v4 token 批次（2026-10-16）起由 v3.0 取代，全文其余章节待后续批次渐进修订；旧版可在 git 历史查（`git show v3.42.0:docs/DESIGN_SYSTEM.md`）。

## 0. 产品气质（v3.0）

| 维度 | 结论 |
|---|---|
| 气质 | **冷灰工具风（v4.0，倒数日式回归）**：浅灰渐变底（LovePage 135° `surfaceGradient #F7F8FA→#ECEEF2`）、纯白卡 1px 细线描边、中性近黑字阶、黑胶囊主行动。奶油底与暖炭字阶退役 |
| 保留的温度 | 票根隐喻（打孔/锯齿/虚线，底色纯白）、拍立得实体复刻、手写字体 Caveat、少量插画的柔和色、蜜桃点缀（降格：仅 softOrangeBg 徽章/关键数字/回忆卡，不再上大面积底色） |
| 弹层玻璃化口径 | 弹层统一 `radiusXl 28` + 半透明白 72%（withAlpha 184）+ BackdropFilter blur 24 + `cardBorder` 顶线（替代旧"禁忌：玻璃拟态"条款；指弹层口径，非全页玻璃滥用） |
| 禁忌 | 企业后台感、促销感、无白名单的渐变滥用（渐变白名单=LovePage 页底 + 后续批次三处 hero 换 surfaceGradient；`gradientSunrise` 已退役 0 使用目标） |

## 1. 色板（v4 增量——与 theme.dart 同步，2026-10-16）

| token | 值 | 语义 |
|---|---|---|
| `bgLight` | `#F2F4F6` | Scaffold 纯色回退底（渐变加权中间值，冷灰替代奶油 #FAF6F0） |
| `paperWarm` | `#F6F7F9` | 冷浅灰次级底（暖米 #F1E8DA 退役；名字暂保留，后续改名 surfaceSubtle） |
| `primarySoft` | `#F1F3F5` | 选中/hover 中性浅底（修 v2.0 文档误写 #F4F4F5；代码曾是 #F0EAE0） |
| `textPrimary` / `textSecondary` / `textMuted` | `#1F2126` / `#5C6066` / `#686D75` | 中性近黑字阶（muted 两底均 ≥4.5:1，比旧暖值深） |
| `separator` / `cardBorder` | `#ECEEF1` / `#E5E7EC` | 行间线 / 卡片 1px 细线（描边重一档） |
| `surfaceGradient` | `#F7F8FA→#ECEEF2` | 浅色页面 135° 渐变（LovePage 用；深色不上渐变） |
| `badgeBg` / `badgeText` | `#EEF0F3` / `#3A3D45` | 中性计数徽章（深色走 `lgBadgeBg/Text` getter） |
| `softGreen/Orange/Blue/Purple/Yellow` `Bg/Text` 六族 | 见 theme | 语义浅底徽章（底饱和 ≤12%；深色 bg 统一 `primarySoftDark #2C2F34`，fg 走 `lgSoftXxxText` getter，禁直引浅色常量） |
| `peachTextDark` | `#F2916E` | 深色态蜜桃文字档（卡上 6.62:1；走 `lgPeachText`） |
| `cardShadow()` | 3% 黑 blur2 | 阴影≈0，立体感交给描边；悬浮卡用 `cardShadowElevated()`（5% blur8） |

**其余色板**（primary/secondary/red/orange/planned/peach 系/圆角 16/20/28、深色 `bgDark #17181B`·`cardDark #232529`·字阶冷化全套）以 `lib/utils/lovegirl_theme.dart` 现值为准；v2.0 第 1-6 节中与本节冲突处一律以 theme 代码为准。

## 2. 字阶（沿用 v1.0 统计，未变）

页面大标题 20/w800 · 卡片标题 15-16/w700-800 · 正文 13-14/w400-600 · 辅助 11.5-12.5 · 数字 hero（首页天数）38/w800。中文字体系统默认；手写场景（拍立得白框字/日期戳）用 Caveat 400/700。

## 3. 圆角 4+1 档（theme.dart：radius 16 / radiusLg 20 / radiusXl 28，v4 起）

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

- **v3.0（2026-10-16）**：v4 token 批次——冷灰化全套（bg/字阶/深色系）、cardBorder 细线体系、badge 六族浅底徽章、surfaceGradient 页底渐变、圆角 16/20/28、阴影降档、弹层玻璃化口径（替换旧"禁忌：玻璃拟态"）、`gradientSunrise` 退役（白名单三处 hero 后续批次换 surfaceGradient）。仅改第 0/1/3 节与本文头，第 2/4/5/6 节待模块批次渐进修订
- **v2.0（2026-09-30）**：全文重写对齐冷白工具风；补 SegmentCloth/gal/slidable 等新能力涉及的组件口径
- v1.0→v3.37 修订（2026-09-28）：去暖色，见 git 历史
