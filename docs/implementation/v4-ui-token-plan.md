# LoveGirl v4 UI 风格改造 — Token 级方案

> 2026-10-16 起草。依据：用户指定 8 张参考图（`docs/design/refs/v4-ui/ref-TempDragFile_20261016_*.png`，已逐张读取）× 现行代码实勘。
> 事实来源：`lib/utils/lovegirl_theme.dart`。本文档只做方案，不改代码；所有对比度数值均由脚本实算（WCAG 相对亮度公式），非拍脑袋。

---

## 0. 现状一句话（v3.41 奶油暖白）

现行 = 奶油底 `bgLight #FAF6F0` + 纯白卡（`LovePaper` 已带 1px 暖灰描边 `lgSeparator #EEE8DF` + 阴影 10% 黑/blur8，见 `lib/widgets/lovegirl_ui.dart:53-61`）+ 暖炭字阶 `#2B2723/#6E655B/#7A7062` + 主行动黑底白字（`primary #1A1A1A`）+ 蜜桃 `#F2704F` 双档 + 日出渐变白名单三处（实证 `home_screen.dart:345-348` gradientSunrise 首页 hero）+ 深色微暖深灰 `#1C1917/#262220`。语义扩展 `context.lgXxx` 共 12 个（`lovegirl_theme.dart:301-346`），全库用量：`lgInk` 394 处/57 文件、`lgBg` 109 处/48 文件、`lgSeparator` 84 处/36 文件、`LovePaper(` 69 处/32 文件、`LoveTicketCard(` 21 处/13 文件——**改 token 换值 + 少量共享组件签名即可全局生效**。

已知文档滞后：`docs/DESIGN_SYSTEM.md:20` 写 `primarySoft #F4F4F5`，代码实为 `#F0EAE0`（`lovegirl_theme.dart:14`，v3.41 加暖）。按文档自己的规则以代码为准，本次一并修正文档。

---

## 1. 参考图设计语言 → 落点对照（逐条）

| # | 参考图共性（8 图逐张通读；两暖图取舍见①） | LoveGirl 落点 |
|---|---|---|
| ① | 浅灰渐变底（左上亮右下微暗 135°；灰光感 **6 图**实证：003124/003130/003134/003137/003140/003143。**003112/003119 两张面板实为暖米色（奶油系），只取黑胶囊/玻璃面板要素、不取暖底色——开工前与用户确认此取舍**） | `LovePage` 承担渐变：`surfaceGradient #F7F8FA→#ECEEF2`；`bgLight` 改纯色回退 `#F2F4F6` |
| ② | 大圆角纯白卡 + 1px 细线描边 + 阴影≈0（图 003134/003140） | `LovePaper` 描边换 `cardBorder #E5E7EC`、`elevated` 默认 false、阴影降到 3% 黑/blur2 |
| ③ | 黑胶囊/黑圆角块选中（图 003124 Threads 行、003130 "2-Tue" 与 All 胶囊、003112/003119 More Filters） | **现行已一致**（`primary #1A1A1A` 黑底白字：life TabBar indicator、底部导航胶囊、LovePrimaryButton），全部保留 |
| ④ | 列表行=图标+文字+右侧计数/chevron，行高疏朗 | `LoveMenuRow` 加 `count` 参数渲染徽章、行高 12→14；主战场=我的页 |
| ⑤ | 子列表竖向连接线+缩进（图 003124 Threads 展开、003137 Income→Refunds） | 新组件 `LoveThreadList`（1px 竖线 + 白色胶囊子行选中态） |
| ⑥ | 小圆角计数徽章：中性浅灰底为主，语义色浅底点缀（图 003124 黑 2、003137 薄荷 8/橙 3、003140 红点） | 新 token `badgeBg/badgeText` + `softXxxBg/softXxxText` 系列；新组件 `LoveBadge` |
| ⑦ | 毛玻璃/半透明白弹层，大圆角 20px+（图 003143 命令菜单；003119 取玻璃面板**形态**——其底实为暖米色，不取底色，同①取舍） | 弹层统一 `radiusXl 28` + 白 72% + BackdropFilter（底部导航 `main.dart:210-211` 已有 blur 18 先例） |
| ⑧ | 粉彩浅底色块做分类/状态（图 003130 课程表紫/蓝/黄/绿浅底卡） | `softXxxBg/Text` 六色；心情月历格用现有 10 色 `.withAlpha(28)` 动态浅底（色相语义不动） |
| ⑨ | 统一细线描边图标（1.5-2px、圆角线帽） | Material outlined/rounded 系沿用；AppIcon PNG 深色圆角方底座+白线条体系不动（资源级，另行批次） |
| ⑩ | 留白慷慨、层级靠字重灰度不靠颜色 | `LoveSectionTitle` 弱化成 15/w700 分组小标题；字阶不动 |

**蜜桃降格规则**：`#F2704F` 只允许出现在 ①`softOrangeBg` 徽章、②关键数字/图标级小面积（`peachText` 文字、≤一个图标大小的 peach 图形——现存的「N 年前的今天」回忆卡 `home_screen.dart:86-109` 即全 App 唯一保留的暖色块）、③不再上大面积底色。`gradientSunrise` 白名单三处 hero 全部改用 `surfaceGradient`，日出渐变降为 0 使用（常量保留，防误用标 deprecated）。

---

## 2. tokenChanges（旧值 → 新值 → 理由）

### 2.1 浅色底/卡

| token | 旧 | 新 | 理由 |
|---|---|---|---|
| `bgLight` | `#FAF6F0` 奶油 | **`#F2F4F6`** | 渐变起止 `#F7F8FA/#ECEEF2` 的加权中间值（偏亮侧），Scaffold 纯色回退用；冷灰替代奶油是本次最大的单一变化 |
| `surfaceGradient`（新，见 §3） | — | `#F7F8FA→#ECEEF2` 135° | 参考图①的光感底；LovePage 用，scaffold 保纯色 |
| `paper` / `cardLight` | `#FFFFFF` | **保留 `#FFFFFF`** | 参考图卡片即纯白，配新描边即可 |
| `paperWarm` | `#F1E8DA` 暖米 | **`#F6F7F9` 冷浅灰** | 暖次级底退役。**名字保留不改调用点**（22 处/约 20 文件零改动），沿用 `orange` 历史名先例；后续批次再渐进改名 `surfaceSubtle` |

### 2.2 灰阶三阶 + 分隔

| token | 旧 | 新 | 实算对比度 | 理由 |
|---|---|---|---|---|
| `textPrimary` | `#2B2723` 暖炭 | **`#1F2126`** | 白 16.11:1 / 底 14.61:1 | 暖褐底→中性近黑，参考图标题即近纯黑 |
| `textSecondary` | `#6E655B` | **`#5C6066`** | 白 6.33:1 / 底 5.74:1 | 中性灰，过 AA |
| `textMuted` | `#7A7062` | **`#686D75`** | 白 5.21:1 / 底 4.72:1 | **必须比旧的深**：奶油底时代 4.51:1 达标，换浅灰底后候选 `#7E838C` 只有 3.46:1，实算筛选后定此值（两底均 ≥4.5） |
| `separator` | `#EEE8DF` 暖灰 | **`#ECEEF1`** | 对白 1.24:1 | 分隔线比卡描边更浅一档，只做行间线 |

### 2.3 黑系主色（基本不动）

| token | 旧 | 新 | 理由 |
|---|---|---|---|
| `primary` | `#1A1A1A` | **保留** | 参考图③黑胶囊同款；白字 17.4:1 |
| `primaryLight` | `#4A4A4A` | **保留** | 主色弱化档仍成立 |
| `primarySoft` | `#F0EAE0`（文档误写 `#F4F4F5`） | **`#F1F3F5`** | 选中/hover 中性浅底；冷化并顺带修文档滞后 |
| `brandEmotion` / `pink` / `pinkLight` | 黑系 | **保留** | v3.37 情感黑化结论不变 |

### 2.4 蜜桃与功能色

| token | 旧 | 新 | 理由 |
|---|---|---|---|
| `accent` / `peach` | `#F2704F` | **保留，角色降格** | 只做徽章前景/关键数字/回忆卡图标（见 §1 蜜桃规则）；不再上大面积底色 |
| `peachText` | `#C9502E` | **保留** | 对白 4.5:1 实算达标；浅色文字档 |
| `peachTextDark`（新，见 §3） | — | `#F2916E` | 深色卡 `#232529` 上 6.62:1；记账收入等关键数字深色态替代直用 `peachText`（旧值深底上 <2.5:1，属现存暗伤） |
| `red` | `#E95B4E` | **保留** | 删除/警示语义不变 |
| `secondary` | `#7A9E7E` | **保留** | 完成/健康绿 |
| `secondarySoft` | `#EFF2EF` | **保留** | 已是浅绿灰，兼容 |
| `planned` | `#9E9AD1` | **保留** | 计划紫；新搭档浅底 `softPurpleBg` |
| `visited` / `wish` | `#4CAF50` / =accent | **保留** | — |
| `orange` | `#8E8E93` | **保留** | 中性态冷灰，双轨制不变 |
| `gradientSunrise` | `[#FFE3C8,#FFD9E3]` | **保留常量，白名单三处清零** | hero 全改 `surfaceGradient`（融入浅灰光感底）；日出渐变 0 使用，标 deprecated |

### 2.5 深色全套（微调，从暖灰转中性冷灰）

| token | 旧 | 新 | 实算对比度 | 理由 |
|---|---|---|---|---|
| `bgDark` | `#1C1917` 微暖 | **`#17181B`** | 对卡 14.15:1 | 对应浅色冷化，近参考图暗室底 |
| `cardDark` | `#262220` | **`#232529`** | — | 中性深灰卡 |
| `textPrimaryDark` | `#EFEAE4` | **`#ECEDEF`** | 卡 13.1:1 / 底 15.15:1 | 冷白 |
| `textSecondaryDark` | `#A89F95` | **`#9BA0A8`** | 卡 5.84:1 / 底 6.75:1 | 过 AA |
| `textMutedDark` | `#8D847A`（卡上仅 4.29:1） | **`#9095A0`** | 卡 5.11:1 / 底 5.91:1 | 顺带修复现状卡上不达标 |
| `separatorDark` | `#33302B` | **`#2F3237`** | — | 行间线 |
| `cardBorderDark`（新） | — | `#33363C` | 对卡 1.27:1 | 深色卡片细线（比分隔线重一档） |
| `primarySoftDark` | `#2E2A26` | **`#2C2F34`** | — | 选中浅底；**§3 六族语义 getter 的深色底统一指向此值**（配对前景对它实算 5.79-8.25:1） |
| `secondarySoftDark` | `#26221E` | **`#262B28`** | — | 绿调深浅底 |

### 2.6 形状与阴影

| token | 旧 | 新 | 理由 |
|---|---|---|---|
| `radius` | 14 | **16** | 参考图行/小卡 16 |
| `radiusLg` | 18 | **20** | 卡片 16-20 区间取上沿（69 处 LovePaper 默认值自动跟随） |
| `radiusXl` | 26 | **28** | 弹层 20px+ 要求，底部弹层/命令菜单档 |
| `cardShadow()` | 10% 黑 blur8 offset(0,2) | **3% 黑 blur2 offset(0,1)**（`Color(0x08000000)`） | 参考图②阴影几乎为零，立体感交给描边 |
| `cardShadowElevated()` | 10% 黑 blur12 offset(0,4) | **5% 黑 blur8 offset(0,2)**（`Color(0x0D000000)`） | 真悬浮元素（FAB/拖拽态）保留一档更重 |
| `glassDecoration` | tint 90% | **tint 72% + 调用点配 BackdropFilter blur 24** | 参考图⑦真毛玻璃；底部导航已有先例。**实勘注：全库 grep `glassDecoration` 仅命中定义行 `lovegirl_theme.dart:284`、零调用，改默认值本身是空操作**——本行价值在于为 §4「弹层统一口径」提供统一参数基准；另 DESIGN_SYSTEM 第 0 节「禁忌：玻璃拟态」与本次毛玻璃方向相抵，随 §6 步骤 2 升 v3.0 时**改写/删除该禁忌条款** |

**不受影响**：`spaceXxs…spaceXl` 间距、`gradientLove/Sunset/Ocean/Forest`（图级渐变，内容语义）、字阶表（v1.0 统计仍有效）。

---

## 3. newTokens（新增清单）

| 名称 | 值 | 用途 |
|---|---|---|
| `surfaceGradientStart` | `#F7F8FA` | 浅色页面渐变起点（左上亮） |
| `surfaceGradientEnd` | `#ECEEF2` | 渐变终点（右下微暗） |
| `surfaceGradient` | `[start, end]` | LovePage 135° 线性渐变；白名单=三处 hero（首页头部/纪念日倒数卡顶条/月报头图，接替 gradientSunrise） |
| `cardBorder` | `#E5E7EC` | 浅色卡片 1px 细线描边（LovePaper/LoveIconButton 默认） |
| `cardBorderDark` | `#33363C` | 深色卡片描边 |
| `badgeBg` | `#EEF0F3` | 中性计数徽章底（图 003134 行尾计数同款） |
| `badgeText` | `#3A3D45` | 徽章数字/文字（对 badgeBg 9.51:1） |
| `softGreenBg` / `softGreenText` | `#E1F1E7` / `#356B47` | 完成/健康浅底徽章（5.36:1） |
| `softOrangeBg` / `softOrangeText` | `#FBE9DE` / `#A8431F` | 蜜桃族浅底徽章（5.11:1）——蜜桃暖意的合法出口之一 |
| `softBlueBg` / `softBlueText` | `#E3EEF9` / `#3A689F` | 信息蓝浅底（4.88:1） |
| `softPurpleBg` / `softPurpleText` | `#ECEAF6` / `#63609E` | 计划紫浅底（4.78:1） |
| `softYellowBg` / `softYellowText` | `#FBF2DC` / `#7E6424` | 提醒黄浅底（5.04:1） |
| `peachTextDark` | `#F2916E` | 深色态蜜桃文字档（卡上 6.62:1） |
| （深色分支，六族统一） | bg 一律 `primarySoftDark #2C2F34`（不新建六个深色底常量）；fg=已实算配对前景：绿`#8CC9A3` 橙`#F2916E` 蓝`#8FB8E8` 紫`#B0ACDD` 黄`#D9C07E` 中性`#C7CBD1` | 对 `#2C2F34` 实算 5.79-8.25:1；以语义 getter 落地（见下），不得只写括注 |

命名规约：`softXxxBg` 只做底色，文字一律 `softXxxText`（或语义色本体）；`bg` 系饱和度 ≤12%、面积可控（徽章/角标/月历格级，不做整卡底）。

**深色落地（必须落成命名 token + 语义 getter，不得只有括注）**：
- 扩展 `LoveGirlSemanticColors`（`lovegirl_theme.dart:301` 扩展区）新增**六对** getter：`lgBadgeBg/lgBadgeText`、`lgSoftGreenBg/lgSoftGreenText`、`lgSoftOrangeBg/lgSoftOrangeText`、`lgSoftBlueBg/lgSoftBlueText`、`lgSoftPurpleBg/lgSoftPurpleText`、`lgSoftYellowBg/lgSoftYellowText`。浅色分支=上表浅色常量；深色分支 bg=`primarySoftDark`、fg=上表已实算配对前景。随 §6 步骤 1 一并落地，进扩展清单。
- **实现纪律：LovePill / LoveBadge 及一切徽章/胶囊位只准走 `context.lgXxx` getter，禁止直引浅色常量**——LovePill 若把默认底写死浅色 `badgeBg`，深色态 17 处胶囊全变亮灰块（现行默认底 `(color ?? context.lgInk).withAlpha(18)` 深色安全，`lovegirl_ui.dart:302`，本次改造不得回退此性质）。

---

## 4. componentChanges（共享组件改造）

| 组件（文件） | 改什么 | 影响 |
|---|---|---|
| `LovePage`（`lib/widgets/lovegirl_ui.dart:7-29`） | `decoration.color: lgBg` 改 135° `LinearGradient(surfaceGradient)`；深色态维持纯色 `bgDark` 不上渐变（沿用 v3.41 深色红线） | 全部走 LovePage 的页面换底；Scaffold 纯色 `bgLight` 保留兜底（转场/键盘露出的裸 Scaffold 不破） |
| `LovePaper`（`lovegirl_ui.dart:31-65`） | 默认 border 从 `lgSeparator` 换 `cardBorder`（深色 `cardBorderDark`，扩展加 `lgCardBorder`）；`elevated` 默认 true→false（描边替代阴影）；radius 默认跟随 radiusLg→20 | **32 文件 69 处调用一次性换装**——这正是 v4 全局生效的杠杆点；需要阴影的悬浮卡显式传 `elevated: true`（现 20 处 cardShadow 手写调用需逐处过目归类） |
| `LoveSectionTitle`（`lovegirl_ui.dart:241-280`） | 17/w700 → 15/w700 + letterSpacing 0.2 + 色 `lgTextTextPrimary`→`lgTextMuted`（参考图 "Status/Group" 弱化分组标题）；action 链接保留 `lgInk` | 5 文件 7 处 |
| `LoveMenuRow`（`lovegirl_ui.dart:377-444`） | 行高 vertical 12→14；图标 22→20 细线化（outlined 系）；新增 `count` 参数→行尾 `LoveBadge`（value 文本参数保留） | 2 文件 15 处（我的页为主） |
| `LovePill`（`lovegirl_ui.dart:282-329`） | 默认底从墨色 18α（`:302`，深色安全）改 **`context.lgBadgeBg` getter**（浅=badgeBg/深=primarySoftDark）、边 `lgBadgeBg` 同源、文字 `lgInk`；语义色由调用方传 `softXxxText` 或对应 getter。**只准走 getter，禁止直引浅色常量**（防深色 17 处胶囊回亮成灰块） | 11 文件 17 处；life 页头部当前 tab 胶囊等处观感变化需真机过目 |
| `LoveBadge`（**新增**，lovegirl_ui.dart） | 小圆角计数徽章：中性=`context.lgBadgeBg/lgBadgeText`；语义=`lgSoftXxxBg/Text` getter 对；红点告警沿用 `red`。**实现只走 getter** | 新能力，供 ④⑥ 落地 |
| `LoveThreadList` / `LoveThreadRow`（**新增**） | 左侧 1px 竖线（`lgSeparator`）+ 16px 缩进 + 子行白胶囊选中态（参考图⑤ Threads/Income 展开态） | 新能力；我的页子菜单、生活分组、心情多条详情优先用 |
| `LoveTicketCard` / `LoveStickerIcon` / `LoveIconButton`（同文件） | 描边色对齐 `cardBorder`；打孔/锯齿/虚线 painter 逻辑**不动** | 13 文件 21 处 / 8 处 |
| `AppShell` 底部导航（`lib/main.dart:207-242`） | `lgPaper.withAlpha(216)`→毛玻璃白 72%（withAlpha 184）+ 顶边框换 `cardBorder`；blur 18→24；黑胶囊选中 34×30 **保留**（参考图③同款） | 1 处；深色态底色跟随 cardDark |
| 弹层统一口径 | `showModalBottomSheet` 实心底（实证 `mood_screen.dart:139-147`）→ `radiusXl 28` + 半透明白 72% + BackdropFilter blur 24 + `cardBorder` 顶线 | mood/photo/daily/letter 等各弹层调用点（施工时 grep `showModalBottomSheet` 全量过） |
| `EmptyState` / `IllusImg`（`lib/widgets/empty_state.dart`） | 结构不动；插画彩色属内容语义（DESIGN_SYSTEM §6 已容忍），仅底卡描边跟随 | 低风险跟随 |
| 心情月历（`lib/screens/mood/mood_screen.dart:51-62`） | `_moodColors` 10 色**色相不动**（v3.42 消同色成果）；月历格/时间线连线加 `.withAlpha(28)` 浅底版（**真机调参预留：28≈11% 着色明显淡于参考图 003130 粉彩块约 25-30% 着色，真机验收时在 alpha 36-56 档重调**） | 参考图⑧；不新增 token，动态派生 |
| 生活页分类色板（`schedule_list.dart:36-46` Stripe 靛蓝 10 色 / `todo_list.dart` 6 色 / `tasks_screen.dart:26`+`task_form.dart:25` 分类色） | 与 mood 10 色三套并行=生活页同类分类色三种语言；统一收敛到 **mood 低饱和版色板或 softXxx 语义徽章化**（具体对齐方案施工时定，原则=色相语义保留+饱和度降档，方向同心情月历行） | §6 步骤 5 一并施工 |

---

## 5. exceptions（明确不动）

| 不动项 | 理由 |
|---|---|
| 拍立得体系：`polaroid_frame.dart` / `polaroid_card.dart` / `polaroid_back.dart` / `polaroid_theme.dart`（88:107 相纸、纸纹贴片、照片窗内凹、显影色 ColorFilter、动态光泽、落影随动、HandwrittenDate 手写日期） | 用户明确喜欢的实体复刻；DESIGN_SYSTEM v2.0 §4/§6 已立"组件内自成体系，勿在外部叠加装饰" |
| 票根**形态**：`LoveTicketCard` 打孔/锯齿/虚线 painter、`_TicketBorderPainter`、`LoveBarcode`、`LoveTicketDivider`、旅行票根页布局 | 票根形态保留（AGENTS/DESIGN_SYSTEM 一贯红线）。**"形态不动"≠"颜色不动"**：`ticket_styles.dart` 的容器/打孔/文字区颜色**必须随语义色改造**——`:77` 打孔 `0xFFFFFFFF`、`:173/:298` 容器 `0xFFFFFFFF`、`:316` 文字区 `0xFFF4F0E8` 是已盘点的最大深色漏网（旅行票根页深色=整页亮白）。换法见 §6 步骤 9 |
| 手写字体 Caveat 场景（拍立得白框字/日期戳） | 实体手账隐喻的一部分 |
| 心情 10 色 `_moodColors` 色相 | 功能语义（v3.42 专门消解过同色问题），只加浅底不改色相 |
| 天气状态色与 illus 插画彩色 | 内容语义，DESIGN_SYSTEM §6 容忍清单在案 |
| AppIcon PNG 图标体系（41 图标×3 色） | 资源级重绘属独立批次（细线化重生成），不在 token 方案内；⑨的"细线"要求先由 Material outlined 用法落实 |
| 我的页纸质票根卡深色例外 | 若 paperWarm 冷化后纸感丢失，该卡可局部保留旧暖值——真机验收时定，默认跟随新值 |
| 换装白板画布区：`wardrobe_whiteboard_screen.dart:528`（"白底固定（深浅两态/导出一致）"注释在案）的 3:4 固定画布、形象底图、单品拖缩 | 导出/合成一致性要求白底（步骤 8 引用的"§5 精神"即此条）；画布**外**的页面 chrome 照常跟随新 token |
| 省份点亮地图 `china_memory_map_screen.dart`（W6 真机验收成果） | 轮廓路径/交互/点击命中判定**不动**。唯一待决点：`:238-239` 未点亮填充/描边硬编码旧暖值（浅 `#F0EAE0`/`#E2D8C9`、深 `#2E2A26`/`#3E3833`）——token 冷化后与冷灰页面渐显突兀。是否换 `lgPrimarySoft`（浅 `#F1F3F5`/深 `#2C2F34`）+ 深色描边随新值，**开工前单独拍板**；换则必须重跑真机点亮视觉验证（W6 三个投影坑记忆在案，重验成本低） |

---

## 6. moduleOrder（依赖序施工清单）

先 token/共享组件 → 首页 → 生活 → 心情 → 其他；覆盖 `lib/screens` 全部 28 个一级模块。

1. **`lib/utils/lovegirl_theme.dart`** — 全部 token/渐变/阴影/圆角落地 + `lgCardBorder` 等扩展 + **§3 深色六族语义 getter（lgBadgeBg/lgBadgeText、lgSoftGreenBg/Text、lgSoftOrangeBg/Text、lgSoftBlueBg/Text、lgSoftPurpleBg/Text、lgSoftYellowBg/Text 共六对，深色 bg=`primarySoftDark`、fg=已实算配对前景）**
2. **`lib/widgets/lovegirl_ui.dart`** — LovePage 渐变 / LovePaper 细线 / LoveSectionTitle / LoveMenuRow / LovePill / 新增 LoveBadge + LoveThreadList（LovePill/LoveBadge 只准走上款 getter，禁止直引浅色常量）；同批 `DESIGN_SYSTEM.md` 升 v3.0 修滞后 + **改写第 0 节「禁忌：玻璃拟态」条款为"弹层玻璃化口径（radiusXl 28/白 72%/blur 24）"**（glassDecoration 零调用、改动为弹层统一口径服务，见 §2.6）
3. **`lib/main.dart`** — AppShell 底部导航毛玻璃 + 启动卡（paperWarm 新值验证）
4. **home**（`lib/screens/home`）— hero 三处之一换 surfaceGradient；回忆卡蜜桃保留；**`:673` 错误横幅写死 `Colors.white` 无深色分支（盘点自评 high）→ 底换 `context.lgCard`/`lgPaper`，边框跟随**
5. **life**（`lib/screens/life` + `widgets/todo_list/finance_list/schedule_list`）— 头部票根卡、TabBar、记账关键数字 `peachText`/深色 `peachTextDark`；**分类色板三套归一（§4 生活页分类色板行）：schedule_list `:36-46`（Color 表）与 `:53`（hex 字符串映射）Stripe 靛蓝 10 色、todo_list 6 色、tasks '学习'紫与 mood 对齐低饱和版或 softXxx 徽章化（含 `todo_list.dart:459` 的 `#9C27B0`）**
6. **mood**（`lib/screens/mood`）— 弹层毛玻璃、月历浅底色块
7. **profile**（`lib/screens/profile`）— 我的页菜单 = LoveMenuRow/LoveBadge/竖线子列表主战场；**`:502` 储蓄胶囊底 `#FFF2E1` 奶油硬编码 → 换 `lgPaperWarm` 或 `lgSoftYellowBg`**
8. **wardrobe**（`lib/screens/wardrobe`）— MIROIR 界面白卡细线化；**`wardrobe_home_screen.dart:68` 搜索框 `fillColor: Colors.white` → 换 `context.lgCard`**；白板页例外见 §5（`wardrobe_whiteboard_screen.dart:528` 白底固定画布不动，画布外 chrome 照常跟随）
9. **travel**（`lib/screens/travel`）— 列表/票根页描边对齐；**`ticket_styles.dart` 形态不动、颜色动：`:77` 打孔、`:173/:298` 容器 `0xFFFFFFFF` → `context.lgPaper`，`:316` 文字区 `0xFFF4F0E8` → `context.lgPaperWarm`（消除深色整页亮白）**；**紫清零：`travel_main_screen.dart:902,1313,1737`、`travel_form_screen.dart:481,696` 的 `#9C27B0` 全部改引 `LoveGirlTheme.planned`，并合并 travel 两套 `_statusColor` 消除 wish 顶层蜜桃/详情弹层灰的双色分裂**；高德地图与地图交互不动；省份点亮地图按 §5（轮廓/交互/命中不动，`:238-239` 是否换 `lgPrimarySoft` 开工前拍板，换则重跑真机点亮验证）
10. **notifications + daily + letter** — 列表型模块过 LovePaper 新默认 + 弹层口径
11. **anniversary + countdown + report + beans** — 倒数卡顶条/月报头图换 surfaceGradient（白名单第 2、3 处）；**`anniversary_screen.dart:925` 横幅固定 `#FBF1F0` 粉底无深色分支 → 换 `lgPaperWarm`（或并入 LoveBanner.error 与 home 共用，见步骤 4）；`:596` `LoveTicketCard(color: Colors.white)` → 换 `context.lgPaper`**；**`countdown_screen.dart:35-48` `_iconColors` 彩虹（`#E040FB` 洋红/`#FFD700` 金/`#26C6DA` 青）→ 并入低饱和收敛色板或 `softXxx` 语义色**；**`beans_screen.dart:190-196` 豆子奶油块 `#FFF0D9/#F1D4B1/#B8860B` → 换 `lgPaperWarm`+`lgSoftYellowBg/Text` 语义对**
12. **album + photo + timeline** — 照片墙/时光轴卡片描边
13. **health + kitchen + cooking + tasks + voucher + chat + couple + common** — 批量跟随（**注意：只对 token 引用自动生效，硬编码不会跟随——tasks_screen.dart:26/task_form.dart:25 '学习'紫等遗留硬编码已在步骤 5/9 点名，其余模块施工时逐文件 grep `Color(0x` 与 `Colors.` 兜底**）
14. **settings + admin + auth + version** — 低频页兜底过一遍
15. **全局验收** — `flutter analyze` 0 问题 + `flutter test` 全绿 + 真机深浅两态走查（发布红线）+ 徽章/描边在 720×1600 低分屏的 1px 渲染检查

---

## 7. 本方案的验证记录（本次实际执行）

- 8/8 参考图已用 Read 逐张读取（003112/003119/003124/003130/003134/003137/003140/003143），①-⑩ 设计语言逐图确认。
- 代码实勘：`lovegirl_theme.dart`（全文 347 行）、`lovegirl_ui.dart`（全文 531 行）、`DESIGN_SYSTEM.md`（全文）、`main.dart`（AppShell）、`life_screen.dart`（全文）、`mood_screen.dart`（前 150 行）、`home_screen.dart`（回忆卡 80-137 行 + hero 335-364 行）、`organic_ui.dart`/`empty_state.dart` 头部。
- 全库统计命令：`Get-ChildItem -Recurse lib -Filter *.dart` + `Select-String` 计数（结果见 §0）。
- 对比度实算：PowerShell WCAG 相对亮度脚本四轮（浅色字阶/徽章 6 对/深色字阶/深色徽章 7 对），全部候选值过筛后才定稿；未达标候选（`#7E838C`、`#3E7D52` 等）已淘汰。
- **未运行**：`flutter analyze` / `flutter test` / 真机预览——本任务只产方案未改代码，无新增代码可验；施工批次 1-2 完成后立即补跑。
- **修订 pass（2026-10-16 审查意见后）**：全部新增锚点已逐一实勘复核——`lovegirl_ui.dart:302`（LovePill 墨色 18α 深色安全默认）、`lovegirl_theme.dart:301-346`（语义 getter 扩展区）、`ticket_styles.dart:77/173/298/316` 四处白/暖值、`home_screen.dart:673` 与 `anniversary_screen.dart:925/596` 横幅白卡、9 处 `#9C27B0`（grep 全命中，schedule_list `:40/:53` 为同色板 Color+hex 双行）、`countdown_screen.dart:35-48` `_iconColors`、`schedule_list.dart:36-46`、`wardrobe_home_screen.dart:68`、`profile_screen.dart:502`、`beans_screen.dart:190-196`、`wardrobe_whiteboard_screen.dart:528` 注释、`china_memory_map_screen.dart:238-239` 暖值、`glassDecoration` 全库仅定义行零调用（`grep -rn glassDecoration lib`）。
