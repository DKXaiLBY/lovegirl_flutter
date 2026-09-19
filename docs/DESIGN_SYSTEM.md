# LoveGirl Design System v1.0

> 适用范围：LoveGirl Flutter App（com.lovegirl.lovegirl_flutter）全部页面
> 事实来源：`lib/utils/lovegirl_theme.dart` + 全量代码统计（262 处圆角、600+ 处字号/字重）+ 真机截图走查
> 本文档同时是重构验收标准：新代码不符合本规范 = 不予合入

---

## 0. 产品判断（一切规范的前提）

| 维度 | 结论 |
|---|---|
| 产品气质 | **纸质手账 × 旅行票根 × 双人日记**。温暖、私密、有收藏感，不追求科技感和效率感 |
| 目标用户 | 年轻情侣（两人共用一份账号体系），核心女性视角 + 男友参与视角；场景多为睡前、通勤、约会间隙的碎片时间 |
| 核心场景 | ① 记录共同生活（旅行打卡/回忆/照片）② 双人轻互动（厨房点单/待办/爱心豆激励）③ 看数据（天数/进度/流水） |
| 禁忌气质 | 电商促销感、企业后台感、高饱和渐变科技感、纯白极简性冷淡 |

**一句话**：所有设计决策的最终检验标准是——"这像不像一本两个人一起写的手账？" 不像的，砍掉。

---

## 1. 设计原则（4 条，冲突时按序裁决）

1. **纸感优先**：界面是"纸"，不是"玻璃"也不是"屏幕"。暖白底、柔边界、轻阴影；内容永远比容器重。
2. **手写感排版**：中文标题用重字重（w800/w900）制造"手写用力"的感觉；正文轻。宁可字大留白多，不可字小塞满。
3. **情绪色克制**：陶土橘（主色）只给"爱"和"主行动"；灰绿只给"完成/健康"；其余信息一律中性色。整屏同时出现的彩色 ≤ 3 种。
4. **动效有体温**：动效是"纸的物理性"（回弹/描边/翻页/印章），不是"科技感转场"。禁止生硬线性动画。

---

## 2. 色板

### 2.1 品牌色

| Token | 值 | 用途 | 适用场景 | 不要 |
|---|---|---|---|---|
| `primary` | `#B85C38` 陶土橘 | 主行动、选中态、爱意表达、金额 | 主按钮底色、选中 tab、恋爱天数、价格 | 不要大面积做背景（>30% 屏幕面积）；不要用于删除/警示 |
| `primaryLight` | `#D4876B` | primary 的渐变伴色 | 仅与 primary 组成渐变 | 不要单独做按钮底色 |
| `primarySoft` | `#FBE3E3` | primary 的 12% 氛围底 | 图标底座、禁用 chip、空态插画底 | 不要当卡片背景色（和纸白区分度不够时才用） |
| `secondary` | `#7A9E7E` 灰绿 | 完成、健康、成功、自然系标签 | 已打卡状态、成功 toast、进度条 | 不要做主按钮（主行动永远是橘） |
| `secondarySoft` | `#F0F5EC` | 灰绿氛围底 | 完成态图标底座 | 同 primarySoft |
| `accent` | `#E7B78A` 杏黄 | 心愿、氛围、回忆类点缀 | 心愿单状态、装饰渐变 | 不要做文字色（对比度不足） |
| `red` | `#E95B4E` | 仅删除与警示 | 删除按钮文字、错误 toast | 不要用于"取消"；不要大面积 |
| `orange` | `#E7A25D` | 进行中、等待类状态 | 待接单徽章、心愿状态 | 不要与 accent 在同屏混用 |

### 2.2 中性色

| Token | 值 | 用途 | 适用 | 不要 |
|---|---|---|---|---|
| `bgLight` | `#FFF9F5` | 全局页面底色 | 所有 Scaffold 背景 | 不要在卡内再用 |
| `paper` | `#FFFFFF` | 卡片底 | 主内容卡 | 不要做整页底色（太冷） |
| `paperWarm` | `#FFF5EC` | 强调卡底（回忆/票根类） | 每页至多 1 张强调卡 | 不要连续叠两张暖卡 |
| `separator` | `#EAE4DC` | 分隔线、卡边框 | Divider、卡片描边 | 不要当文字色 |
| `textPrimary` | `#333333` | 标题/正文主色 | 一切可读文字 | 不要用纯黑 `#000` |
| `textSecondary` | `#888888` | 次要说明 | 副标题、摘要 | 不要用于 <11px 文字 |
| `textMuted` | `#999999` | 辅助/占位/禁用 | 时间戳、提示 | 不要用于关键信息 |

### 2.3 状态色（语义固定，不得改值）

`visited 已打卡 = secondary #7A9E7E` · `planned 计划中 = #9C27B0 紫` · `wish 想去 = orange #FF9800`
> ⚠️ 现存不一致：travel 模块用 `#4CAF50/#FF9800/#9C27B0`，theme 定义 `visited=7A9E7E`——**两套绿并存**。规范裁定：以 Material 三色（4CAF50 系）为准，`LoveGirlTheme.visited` 待迁移。

### 2.4 深色色板（星空页/夜间专用）

`bgDark #070B14`（星图）/ `cardDark #2A2421`（夜间卡）/ 发光青 `#6FD9F5`（仅星图页内使用）

---

## 3. 字体系统

| 层级 | Token | 字族 |
|---|---|---|
| Logo | `font-logo` | `serif`（仅 "LoveGirl" 标题一处） |
| 全局正文/标题 | `font-sans` | MiSans → PingFang SC → Microsoft YaHei → Noto Sans CJK SC（fallback 链，已配置于 theme） |
| 数字强调 | `font-sans` + `RollingNumber` | 同上，禁止等宽数字字体 |

**适用**：新增页面一律继承 theme，不写 fontFamily。
**不要**：引入新字体文件；在中文正文上用 serif；在数字上用非系统字。

---

## 4. 字号与字重

### 4.1 字阶（7 档，v1.0 收敛结果）

| Token | px | 字重 | 语义 | 适用场景 | 不要 |
|---|---|---|---|---|---|
| `display` | 34/w700 | 大标题 | 仅首页 "LoveGirl" logo | 任何其他地方 |
| `h1` | 25/w900 | 页面标题 | 各 tab 页首行标题 | 卡片内标题 |
| `h2` | 20/w900 | 区块标题 | 弹窗标题、票根大字 | 列表行标题 |
| `h3` | 17/w900 | 卡片标题 | 卡片主标题、条目标题 | — |
| `body` | 14/w600 | 正文 | 待办行、说明文字 | — |
| `caption` | 12/w600 | 辅助 | 时间戳、副标题、chip | 长段落 |
| `micro` | 10/w700 | 微标注 | 英文装饰字（TRAVEL STUB）、徽章脚注 | 正文 |

> 允许 ±1px 微调（15/13 是 14/12 的合法变体）；禁止出现 8/9/11/19/22/24 等游离值（现存 20+ 种字号是历史债务，新代码不得新增）。

### 4.2 字重使用律

- `w900`：标题、菜名、城市名、金额——"手写用力"的部分
- `w800`：按钮文字、chip、次级标题
- `w600`：正文默认（全局 theme 已设）
- `w500/w400`：辅助说明、时间戳
- **不要** `w300`（现存 2 处待清）；**不要**同屏出现 >4 种字重

---

## 5. 圆角 · 边框 · 阴影

### 5.1 圆角 4+1 档（从 262 处统计收敛）

| Token | px | 适用 | 不要 |
|---|---|---|---|
| `radius-xs` | 8 | 小徽章底、微元素 | 卡片 |
| `radius-sm` | 14 | 图标底座、输入框、行内按钮 | 页面级容器 |
| `radius-md` | 18 | 卡片、弹窗、列表条目 | 按钮（用 pill） |
| `radius-lg` | 26 | 地图容器、页面级大卡 | 小元素 |
| `pill` | 999 | 按钮、chip、进度条 | 内容卡 |

> 现存 12/13/16/17/20/22 等 10 种游离值是债务：新代码只允许上表 5 档。票根卡两侧缺口半径固定 8px 不变。

### 5.2 边框

| Token | 定义 | 适用 | 不要 |
|---|---|---|---|
| `border-card` | 1px `separator` | 一切白卡默认边 | 深色边框 |
| `border-highlight` | 1px 顶白 `#FFFFFF88` 渐变高光 | 玻璃/强调卡（由 TicketBorderPainter 提供） | 普通列表行 |
| `border-strong` | 1.5px `primary` | 选中/描边按钮（去看看） | 非交互元素 |

### 5.3 阴影两档

| Token | 定义 | 适用 | 不要 |
|---|---|---|---|
| `shadow-sm` | `0 2 8 #1A000000` | 列表行、普通卡 | 弹窗 |
| `shadow-md` | `0 4 12 #1A000000` | 浮层、票根、FAB | 页面级 |
| 星图专用 | `0 8 16 #30000000` | 翻页书/悬浮面板 | — |

> 禁止手写新阴影；禁止 blur > 24。

---

## 6. 布局与栅格

| Token | 值 | 适用 | 不要 |
|---|---|---|---|
| `space-xs` | 4 | 图文间隙微调 | 卡片间距 |
| `space-sm` | 8 | 同组元素间距、行间距 | 区块间距 |
| `space-md` | 12/14 | 卡内边距、卡片间距 | 页边距 |
| `space-lg` | 16/18 | 页水平边距（18 为页标准）、卡内大间距 | — |
| `space-xl` | 24/28 | 区块间距 | 行间距 |

- 页面水平边距统一 **18**（首页/旅行/列表），地图/全屏容器 **14** + 圆角 26
- 卡内边距统一 **13-16**
- 底部导航高 **74**；页标题区高约 **46**
- FAB：右下 `right 18 / bottom 24`，56×56 圆角 18
- **不要**出现 10/13 等游离间距值（现存债务逐步替换）

---

## 7. 组件风格总则

| 组件 | 规范 | 适用 | 不要 |
|---|---|---|---|
| `LoveTicketCard` | 白底+radius 18+票根缺口+高光边，内容自带 padding 16 | 一切"内容集合"卡（照顾事/账本/订单） | 按钮、行元素 |
| `LovePaper` | 无缺口纯圆角纸 | 非票根类静态卡 | 放交互列表 |
| `LovePill` | 12/w600 文字+10/6 padding+18% 底色 | 状态徽章、标签 | 可点击主操作（包 GestureDetector 除外） |
| `LovePrimaryButton` | pill 999/13 w800 白字/PressableScale | 每屏至多 1 个主行动 | 列表行内（用 LovePill） |
| `LoveIconButton` | 38×38 圆、图标 21 | header 工具钮 | 卡片内小操作 |
| `_HomeTodoRow` 圆圈 | 26px，点击 DRAW 描边 | 待办勾选 | — |
| 图标底座 | 40×40 / radius 13 / soft 底色 | 列表行头图标 | — |
| ShimmerBox | 高度=真实内容高度 | 加载态 | 无限转圈替代 |

---

## 8. 核心组件规范

**8.1 页面骨架**：`Scaffold(bgLight) → header(标题 h1 25/w900 + 工具钮 38×38) → 滚动区`。header 工具钮 ≤ 3 个；第 4 个功能放"我的"。

**8.2 列表条目**（清单化标准型）：
`[图标底座 40][标题 15/w900 + 摘要 11/muted][状态徽章][chevron 18]`，padding 14/13，行高 ≈ 66。
适用：首页照顾事、设置、我的。不要在条目里放超过 1 行摘要。

**8.3 状态徽章**：pill、11/w800、底色 = 语义色 26 alpha、文字 = 语义色。语义：橘=等待、绿=完成/正常、灰=空、紫=计划。

**8.4 空态**：大 emoji（52px）+ 一句话（15/w700）+ 引导（12/muted）+ 可选主按钮。不要只放转圈。

**8.5 底部弹窗**：圆角 24 顶、拖拽把手 40×4、`safeArea(bottom)+viewInsets`、可拖拽关闭。表单类弹窗内按钮必须全宽。

**8.6 票根族**：竖版明信片（3:4，上35% 文字/下65% 照片）、横版入场券（60/40 撕票线）、投喂小票（账目式）。共用：NO.编号、撕票线、`LoveBarcode`、主色从照片提取。

**8.7 星空页**（唯一深色域）：bg `#070B14`、省界 `#7FD4FF` 发光描边、光点 `#6FD9F5` 呼吸、面板 `#12203A` 70% + blur 12 + 青色 30% 边框。**深色组件不得出现在浅色页**。

---

## 9. 状态规范

| 状态 | 规范 | 不要 |
|---|---|---|
| 加载-首载 | ShimmerBox 骨架（高度=真实内容） | 裸转圈占满屏 |
| 加载-操作中 | 按钮内置 20px 转圈 + 禁用 | 双击可重复提交 |
| 空 | 8.4 空态模板 | 灰字一行了事 |
| 错误 | 浮动 SnackBar（floating、13px）+ 重试按钮；网络类文案带"再试一次" | 500/404 等技术码暴露给用户 |
| 禁用 | 按钮 40% 透明度或 separator 底灰字 | 直接隐藏按钮 |
| 按压 | PressableScale 0.965 + InkSparkle | 无反馈的 GestureDetector |
| 完成 | DRAW 描边勾选 / 印章落下 / 彩带 | 仅变颜色 |
| 撤销 | 操作后 3s 内显示撤销 pill，跟手拖动判定 | 无撤销的关键操作 |

---

## 10. 页面跳转规范

| 类型 | 规范 |
|---|---|
| 二级页 | `MaterialPageRoute`（全局已配 Cupertino 跟手滑退）；左上返回钮 38×38 |
| 底部 tab | 5 个固定；点击不动画；跨 tab 跳转用 `onNavigateToTab` |
| 全屏沉浸 | 真地图/星图：无 AppBar，左上悬浮返回钮 |
| 权限页 | 门口拦截（如男友视角健康页：锁定卡+一句"这里会保护她的私密记录"），**绝不**让请求飞出去失败 |
| 跳转后刷新 | 返回值 `result == true` → `provider.refreshAll()` |
| 更新弹窗 | 版本 152 起走服务器 app_versions 表，changelog 中文 |

---

## 11. 文案语气规范

| 场景 | 语气 | 示例 | 不要 |
|---|---|---|---|
| 标题 | 名词短语，≤6 字 | "今天要照顾的事" | 动宾长句 |
| 引导/空态 | 第二人称，口语，带一点撒娇 | "菜单等你来翻" "明天再来，爱你♥" | "暂无数据""请稍后" |
| 成功反馈 | 动作结果+表情 | "下单成功！等 TA 开火啦 🔥" | "操作成功" |
| 失败反馈 | 原因+行动 | "有菜品刚被下架了，刷新一下菜单" | "请求失败" |
| 撤销 | 中性动词 | "已撤销接单" | 道歉式文案 |
| 金额 | ¥+整数 | ¥59 | 59.00 元 |

---

## 12. 黑暗模式设计红线

1. **现状**：App 仅有 light 主题完整实现；`bgDark/cardDark` 已定义但 darkTheme 未接线。星图页是**唯一**的深色页面（特批域）。
2. **红线**：
   - 深色页内禁止使用 `bgLight/paper/paperWarm/separator` 任何浅色 token 做背景
   - 浅色页内禁止出现 `#070B14/#12203A` 深色卡（星图入口按钮除外）
   - 深色下文字最低 `#BFEFFF`（星图）/ `#E8E0D9`（夜间），禁止 `#999` 灰字直接上深底
   - 接入 darkTheme 时：`textPrimary→#E8E0D9, separator→#3A342E, paper→#2A2421`，主色不变
3. **不要**：给深色页加彩色阴影；用纯白 `#FFF` 文字（用 90% 白）。

---

## 13. 现存不一致清单（重构优先级）

| # | 问题 | 位置 | 修复方向 |
|---|---|---|---|
| 1 | 两套绿色并存（`7A9E7E` vs `4CAF50`） | theme.visited vs travel 模块 | 统一为 `4CAF50` 系，theme.visited 迁移 |
| 2 | 圆角 12/13/14/16/17/20/22/26 八种混用 | 全局 | 收敛 8/14/18/26 |
| 3 | 字号 20+ 种（8~48），游离值 9/11/19/22/24 | 全局 | 收敛 7 档字阶 |
| 4 | `_StatusChip` 与 `LovePill` 两种徽章并存 | home_screen | 统一 LovePill |
| 5 | 图标底座底色 4 种（primarySoft/secondarySoft/`FFF0D9`/`E8E0D9`） | 各列表 | 按语义映射，收敛 3 种 |
| 6 | 间距游离值 10/13/14 大量出现 | 全局 | 逐步替换 12/16 |
| 7 | 阴影三处手写（nav/preview/stars） | main 等 | 收敛 shadow-sm/md |
| 8 | 出发计划卡底色 `F6FBF4` 独一份 | home | 改 paper 或 secondarySoft |
| 9 | w300 残留 2 处 | 待查 | 删 |
| 10 | darkTheme 未接线（仅 token） | theme | 需要时单独立项 |

---

## 14. Design Tokens

### 14.1 CSS Variables

```css
:root {
  /* ===== Color / Brand ===== */
  --lg-primary:        #B85C38;
  --lg-primary-light:  #D4876B;
  --lg-primary-soft:   #FBE3E3;
  --lg-secondary:      #7A9E7E;
  --lg-secondary-soft: #F0F5EC;
  --lg-accent:         #E7B78A;
  --lg-orange:         #E7A25D;
  --lg-red:            #E95B4E;

  /* ===== Color / Neutral ===== */
  --lg-bg:             #FFF9F5;
  --lg-paper:          #FFFFFF;
  --lg-paper-warm:     #FFF5EC;
  --lg-separator:      #EAE4DC;
  --lg-text-primary:   #333333;
  --lg-text-secondary: #888888;
  --lg-text-muted:     #999999;

  /* ===== Color / Status (travel) ===== */
  --lg-visited:  #4CAF50;
  --lg-planned:  #9C27B0;
  --lg-wish:     #FF9800;

  /* ===== Color / Dark (星图专用) ===== */
  --lg-dark-bg:        #070B14;
  --lg-dark-card:      #2A2421;
  --lg-dark-panel:     rgba(18, 32, 58, 0.75);
  --lg-glow:           #6FD9F5;
  --lg-glow-text:      #BFEFFF;

  /* ===== Radius ===== */
  --lg-radius-xs: 8px;
  --lg-radius-sm: 14px;
  --lg-radius-md: 18px;
  --lg-radius-lg: 26px;
  --lg-radius-pill: 999px;

  /* ===== Spacing ===== */
  --lg-space-xs: 4px;
  --lg-space-sm: 8px;
  --lg-space-md: 12px;
  --lg-space-lg: 16px;
  --lg-space-xl: 24px;
  --lg-page-x: 18px;

  /* ===== Shadow ===== */
  --lg-shadow-sm: 0 2px 8px rgba(0,0,0,0.10);
  --lg-shadow-md: 0 4px 12px rgba(0,0,0,0.10);
  --lg-shadow-float: 0 8px 16px rgba(0,0,0,0.19);

  /* ===== Typography ===== */
  --lg-font-sans: MiSans, "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", sans-serif;
  --lg-font-size-display: 34px;
  --lg-font-size-h1: 25px;
  --lg-font-size-h2: 20px;
  --lg-font-size-h3: 17px;
  --lg-font-size-body: 14px;
  --lg-font-size-caption: 12px;
  --lg-font-size-micro: 10px;
}
```

### 14.2 Tailwind tokens（tailwind.config.js extend）

```js
theme: {
  extend: {
    colors: {
      lg: {
        primary:      { DEFAULT: '#B85C38', light: '#D4876B', soft: '#FBE3E3' },
        secondary:    { DEFAULT: '#7A9E7E', soft: '#F0F5EC' },
        accent:       '#E7B78A',
        orange:       '#E7A25D',
        red:          '#E95B4E',
        bg:           '#FFF9F5',
        paper:        { DEFAULT: '#FFFFFF', warm: '#FFF5EC' },
        separator:    '#EAE4DC',
        text:         { primary: '#333333', secondary: '#888888', muted: '#999999' },
        status:       { visited: '#4CAF50', planned: '#9C27B0', wish: '#FF9800' },
        dark:         { bg: '#070B14', card: '#2A2421', panel: 'rgba(18,32,58,0.75)' },
        glow:         { DEFAULT: '#6FD9F5', text: '#BFEFFF' },
      },
    },
    borderRadius: {
      lg: { xs: '8px', sm: '14px', md: '18px', lg: '26px', pill: '999px' },
    },
    boxShadow: {
      lg: { sm: '0 2px 8px rgba(0,0,0,0.10)', md: '0 4px 12px rgba(0,0,0,0.10)', float: '0 8px 16px rgba(0,0,0,0.19)' },
    },
    fontSize: {
      'lg-display': ['34px', { fontWeight: '700' }],
      'lg-h1': ['25px', { fontWeight: '900' }],
      'lg-h2': ['20px', { fontWeight: '900' }],
      'lg-h3': ['17px', { fontWeight: '900' }],
      'lg-body': ['14px', { fontWeight: '600' }],
      'lg-caption': ['12px', { fontWeight: '600' }],
      'lg-micro': ['10px', { fontWeight: '700' }],
    },
    spacing: {
      'lg-xs': '4px', 'lg-sm': '8px', 'lg-md': '12px',
      'lg-lg': '16px', 'lg-xl': '24px', 'lg-page': '18px',
    },
    fontFamily: {
      lg: ['MiSans', 'PingFang SC', 'Microsoft YaHei', 'Noto Sans CJK SC', 'sans-serif'],
    },
  },
}
```

### 14.3 Flutter 侧对照（现有实现）

tokens 的权威实现就是 `lib/utils/lovegirl_theme.dart`（色彩/圆角/阴影/间距常量已存在），新组件必须引用 theme 常量，**禁止再写魔法数字**。

---

*v1.0 · 2026-09-19 · 基于 v3.23.0+152 代码与真机截图归纳 · 维护者随版本演进更新*
