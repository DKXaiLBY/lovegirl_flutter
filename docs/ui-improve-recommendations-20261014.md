# LoveGirl UI 改版推荐清单

> 流程：3 名勘察员盘点现状 → 3 个方向并行出方案 → 评委合并排序 → 独立复核员逐条核验仓库依据。全程只读，未改任何代码。

## 结论

## Top 8 推荐

| # | 改什么 | 怎么改 | 为什么 | 工作量 | 来自 | 评委理由 |
|---|---|---|---|---|---|---|
| 1 | lib/widgets/lovegirl_ui.dart 的 LovePaper + lib/utils/lovegirl_theme.dart（cardShadowRest） | LovePaper 加可选 material 参数：'paper' 档在 ClipRRect 内叠 paper_grain.png（Opacity≈0.55 ImageRepeat.repeat，照抄 polaroid_frame.dart:258-269）+ 上下缘压暗/受光渐变；theme 新增 cardShadowRest() 双层静置影（近硬影 0x40000000 blur3 + 远环境影 0x26000000 blur22 offset(0,12)，数值取自 polaroid_frame.dart:23-26 的 kPolaroidRestShadows）。纯加参数，32 个调用文件零迁移；深色态双层黑影可见性需真机各验一遍 | 用户最满意的实体质感目前锁死在拍立得组件内部，LovePaper 是全 App 白卡的公共底座，一处加参数即让 32 个页面获得'纸不是 UI'的观感，深浅两态在一处收敛 | medium | 实体感升级 | 用户口味契合度全场最高——把最被认可的拍立得质感以一次改动铺满全 App，且是纯增量参数、零迁移零破坏；杠杆率与风险比全场最优，排第一。 |
| 2 | 厨房/兑换券/设置页用户可见 emoji 文案（倒计时页的随死码项消失） | kitchen_screen.dart:1610「+5 爱心豆 🫘」（🫘=Emoji 14）等去 emoji 换纯文字或 AppIcon PNG；wish_voucher_screen.dart:773 _emojiChoices 选择器（含 🧋=Emoji 13）照 travel_form 天气/心情已换 Material 图标的同款做法换图标；settings_screen.dart:699,795 🔧 同理；countdown_screen.dart:209 🎉 随第 8 条死模块删除一并消失，不单独处理 | 这是项目硬红线不是审美问题：荣耀 Android 10 不支持 Emoji 13/14，🫘🧋 直接渲染豆腐块，用户在自己的高频页看到乱码 | medium | 体系打磨 | 老设备豆腐块是 AGENTS.md 点名的硬红线，且 kitchen/兑换券是情侣高频页、用户实际测试机就是荣耀 Android 10，乱码必然可见；同为红线项但工作量中等，排在深色修复之后。 |
| 3 | 首页/纪念日错误横幅统一为 LoveBanner + 衣橱搜索框深色适配 | 合并为 LoveBanner.error 共享组件：lgPaperWarm 底 + paper_grain 纹 + lgSeparator 描边 + cardShadow（'便签纸条'隐喻），图标/文案/重试行为不变，重试钮包 PressableScale；home_screen.dart:673 与 anniversary_screen.dart:924 两个调用点替换；wardrobe_home_screen.dart:68 搜索框 Colors.white 改 context.lgCard 同批修掉 | home 横幅写死 Colors.white、anniversary 写死固定粉底且无深色分支——深色模式下浮亮块/粉底配米白字低对比，直接违反'发布前深浅两态必过'红线；同语义组件两套样式也是维护分叉 | small | 体系打磨 + 实体感升级（两方向重复提出，合并） | 深色模式是全局硬性要求，两处深色漏网是必修项；工作量最小、还能顺手统一两套分叉样式并贴合便签纸条隐喻，性价比极高排第三。 |
| 4 | 旅行状态色双胞胎合一 + 9×#9C27B0 归 planned token + 分类色板收敛 + 设计文档回改 | travel_main_screen.dart:895-906 与 1730-1741 两处 _statusColor 合一（列表卡 wish=蜜桃、详情弹层 wish=灰的肉眼不一致）；wish 建议落 peachText #C9502E 深一档，与同屏左滑删除红 #E95B4E 拉开色距；全仓 9 处 Color(0xFF9C27B0) 统一改引 LoveGirlTheme.planned #9E9AD1；schedule_list.dart:35-46 Stripe 靛蓝/荧光绿色板收敛到 mood_screen.dart:51-62 的低饱和 10 色体系；DESIGN_SYSTEM.md:20 primarySoft（文档#F4F4F5 vs 代码#F0EAE0）、:31 separator（#ECECEC vs #EEE8DF）按'以代码为准'回改 | 同一列表'心愿单'卡片左缘蜜桃、点开弹层变灰是用户可感知的不一致；planned 紫在 travel/todo/tasks/life 四模块硬编码、token 形同虚设，schedule 的 Stripe 高饱色板与奶油基调打架 | medium | 体系打磨 + 布局与导航动线焕新（两方向重复提出，合并） | 同一地点列表里蜜桃、点开变灰是用户一眼可感知的不一致，9 处紫硬编码跨四模块也全验属实；改动全为机械替换风险低，但单条用户价值不及前三的红线项，排第四。 |
| 5 | 首页「本帮你账本/本周课程」生活面板（_LifeSummaryTicket） | home_screen.dart:1488-1500 的 fallback 全部移除（¥1520/¥480/'设计心理学'/'14:00'/'教二楼 302'/'周四'），接口无数据时整卡塌缩或出真实空态，有数据才渲染；顺带用 LoveSectionTitle 给卡片流加'今天/回忆/生活'分组锚点 | 没记账/没录课程时首页会显示'总支出 ¥1520、设计心理学 教二楼 302'的假数字——这是展示错误数据伤信任，比任何布局问题都严重 | small | 布局与导航动线焕新 | 假数字比布局问题更伤信任且必然发生（只要没记账就出现），半天级工作量修一个确定性伤信任点，价值/风险比好，但视觉冲击面小故居中。 |
| 6 | 票根共享样式层（ticket_styles.dart + lovegirl_ui.dart 边框 painter + 旅行票根页） | ①TicketNotchLine 打孔 Color(0xFFFFFFFF)（ticket_styles.dart:77）改 context.lgBg——打孔应透出页面底色，深色下不再浮白圆片；②HorizontalTicketStub/VerticalPostcardTicket 容器硬编码白（:173,:297）改 context.lgPaper、明信片文字区 #F4F0E8 改 lgPaperWarm；③travel_ticket_screen.dart:432,437 固定暖白 #FFF8F0 改 context.lgPaperWarm 并叠纸纹；④_TicketBorderPainter 加双层内描边（内缩 1px 白高光 + 内缩 3px 极浅暗沿，复用 polaroid_frame.dart:281-301 的 _WindowBevel 凹陷配方），LoveTicketCard 13 个使用文件零迁移 | 票根是本 App 最强实体隐喻但四处硬编码浅色，旅行票根页整页在深色模式下是一大块固定暖白亮区（该页还是保存/分享高光页）；内凹 bevel 让'厚卡纸'的分量立现 | medium | 实体感升级 | 票根是全 App 最强实体隐喻、口味契合度仅次于第 1 条，且一次收掉最大的深色漏网；但 bevel 属锦上添花、调用点多需真机回归，排红线与数据正确项之后。 |
| 7 | 心情页导航层级——补『年视图』钻取（月↔年两级） | 月历头部加'年'级入口：4 列×12 月年视图，每格按该月记录密度着色（复用 _moodColors 低饱和体系），点月下钻回现有月历，弹层返回不丢层级；结构按 docs/reference-backlog.md 已勘定的 star_book 方案（MIT 相符，仅借结构不移植代码） | 『这一年我们过得怎么样』是情侣核心回看诉求，当前 UI 回看一年要连点 12 次；v3.42 刚做过心情模块多心情治理，是弹药库点名的最大缺口 | medium | 布局与导航动线焕新 |  couples 核心回看诉求、仓库自己的弹药库已把年视图列为可借结构，用户价值高；但属新增视图而非修错，工作量中等，排七。 |
| 8 ⚠️ | 倒计时死模块 + theme 死 token/黑灰别名清理 | ①lib/screens/countdown/ 整目录删除（countdown_screen.dart + countdown_form.dart，SharedPreferences 本地存储）——grep 全 lib/test 已验证零外部引用，唯一活入口在 profile 第三屏但指向的是 anniversary；②删除 lovegirl_theme.dart:71-76 gradientSunset/gradientOcean/gradientForest 与 :284-296 glassDecoration（grep 已验证 lib 内零引用，glassDecoration 与 DESIGN_SYSTEM'禁忌玻璃拟态'直接矛盾）；③pink/pinkLight 别名 4 处引用（period_tracker:303、finance_list:1246、todo_list:605、tasks_screen:401）改直写 lgInk/primaryLight 后删别名 | 死码留着就是歧义温床：glassDecoration 与设计规范禁忌直接矛盾、死渐变色值已散落别处；countdown 模块与 anniversary 是同一'倒数'语义的两套实现 | small | 布局与导航动线焕新 + 体系打磨（合并） | 删除项全部经本会话 grep 实证零引用，是接近零风险的纯收益，但用户不可见、直接价值低，做票根/心情等可见项时顺路清掉即可，排末位。 |

## 复核发现

- ⚠️ 第 8 条（medium）：pink/pinkLight 别名引用实测 5 处而非清单所列 4 处：grep 'LoveGirlTheme\.pink' lib 实测 5 处（pinkLight 恰 4 处：period_tracker:303、finance_list:1246、todo_list:605、tasks_screen:401，与清单一致），但 period_tracker.dart:245 还有一处 `backgroundColor: LoveGirlTheme.pink`（ElevatedButton 黑底按钮）。按清单只改列出的 4 处就删 pink/pinkLight 别名会导致编译失败；且 245 处是按钮底色（foregroundColor 写死 Colors.white），若照清单'改直写 lgInk/primaryLight'机械处理成 lgInk，深色态 lgInk=米白(#EFEAE4) 配白字不可读——lovegirl_theme.dart:340 注释明言 lgInk 用于文字/图标/描边、黑底座容器勿用，此处应直写 primary

## 现状盘点发现的问题（勘察员原报，未经二次复核）

- 【medium】lib/utils/lovegirl_theme.dart:61 vs lib/screens/travel/travel_form_screen.dart:481,696、travel_main_screen.dart:902,1313,1737（硬编码 0xFF9C27B0）：计划态紫色分裂：token `planned` 定义为 #9E9AD1（文档第 1 节还称'唯一紫'），但 lib 中仅 settings_screen.dart:570 引用 token 一次，travel/todo/tasks/mood 等实际全用硬编码 0xFF9C27B0（Material Purple），mood_screen.dart:60 还把 token 值 #9E9AD1 以硬编码形式复制，同一语义出现两种紫 → 建议：travel/todo/schedule/tasks/mood 各处统一改引 LoveGirlTheme.planned（或 context.lgEmotion 语义化），并明确 9C27B0 与 9E9AD1 谁是最终态
- 【medium】docs/DESIGN_SYSTEM.md:20,31 vs lib/utils/lovegirl_theme.dart:14,42：文档色板两处值滞后于代码：primarySoft 文档写 #F4F4F5（冷灰）实际代码 #F0EAE0（暖米）；separator 文档写 #ECECEC 实际代码 #EEE8DF（暖灰）——v3.41 暖化时代码先行，规范文档未跟上，后续开发按文档取色会产生色差 → 建议：按文档自己'与代码冲突时以代码为准并回改文档'的约定，更新 DESIGN_SYSTEM.md 第 1 节这两个值
- 【medium】lib/screens/anniversary/anniversary_screen.dart:924：纪念日加载失败提示条用固定浅粉底 #FBF1F0 且无深色分支：文字虽走 lgTextSecondary（深色下米白），但深色模式下会出现浅粉底+米白字的低对比组合，违背'深浅两态真机过一遍'红线精神 → 建议：底色改 context.lgPaperWarm（其深色态已映射 cardDark）或加 lgIsDark 分支
- 【low】lib/utils/lovegirl_theme.dart:71-76,284-296：死 token/死方法：gradientSunset、gradientOcean、gradientForest 三个彩色渐变与 glassDecoration() 在 lib 内零引用（git grep 仅命中定义行）；且 glassDecoration 是半透明+白描边+阴影的玻璃拟态写法，与文档第 0 节'禁忌：玻璃拟态'自相矛盾；gradientOcean 的色值反而以硬编码散落在 register_screen.dart:81-82,277 与 countdown_screen.dart 等处 → 建议：删除 glassDecoration 与三个死渐变 token；register/countdown 处硬编码若仍需要则收编为显式命名常量
- 【low】lib/utils/lovegirl_theme.dart:25-26,70；使用点 lib/screens/health/widgets/period_tracker.dart:245,303、lib/screens/life/widgets/finance_list.dart:1246、todo_list.dart:605、lib/screens/tasks/tasks_screen.dart:401、lib/screens/auth/login_screen.dart:67、lib/screens/version/update_dialog.dart:61：黑灰别名 token 残留：pink/pinkLight 语义已死（=primary/primaryLight 黑灰）却仍在 5 处被引用，阅读时误导；gradientLove 黑灰渐变仍用于登录页与版本更新弹窗头带——v3.41 渐变白名单只给了日出渐变三处，更新弹窗这处装饰渐变属白名单外遗留 → 建议：调用点改用 context.lgInk/lgPrimarySoft 或 LoveGirlTheme.primary 直写后删除 pink/pinkLight 别名；update_dialog 头带改 primarySoft 单色或纳入白名单明示
- 【low】lib/screens/life/widgets/schedule_list.dart:36-45、todo_list.dart:459-469、lib/screens/tasks/task_form.dart:22-27、tasks_screen.dart:23-27、lib/screens/countdown/countdown_screen.dart:36-47、lib/screens/mood/mood_screen.dart:52-61、lib/widgets/organic_ui.dart:275,378,429-431：内容分类色板散装硬编码、绕过 token 体系：日程/待办/任务/倒数/心情五个模块各自维护互不一致的影子色板（如日程 10 色 #635BFF/#00D4AA…、任务'学习'紫 #9C27B0、心情 10 色），文档容忍清单只豁免了天气与插画，这些色板既未入规范也无深色模式校验；organic_ui.dart 组件默认色 #635BFF/#00D4AA 同属体系外 → 建议：将分类/心情色板统一收编到 theme（或专项 palette 文件）并注明深色可用性，文档第 6 节补录'内容语义彩板'豁免条目
- 【high】lib/screens/travel/travel_main_screen.dart:895-906 与 1730-1741：「wish（想去）」状态在清单卡左缘/状态胶囊里渲染为蜜桃色（LoveGirlTheme.wish=accent #F2704F，见 lovegirl_theme.dart:20），但同一模块内 _SpotDetailSheet._statusColor 却把 wish 写成灰色 Color(0xFF8E8E93)——同一个地点列表里是暖桃、点开底部详情弹层变灰；两套 _statusColor 同时存在（顶层 :895 与 sheet 内 :1730），且 visited=#4CAF50、planned=#9C27B0 全部绕过 theme 硬编码 → 建议：合并为单一 _statusColor（或挂到 LoveGirlTheme 加 statusWish/statusPlanned token），详情弹层复用顶层函数，消除同状态两色
- 【medium】lib/screens/travel/travel_main_screen.dart:899,979 与 :420；lib/screens/kitchen/kitchen_screen.dart:498-504：愿望单地点卡片的蜜桃色边/底（:899-900、:979）与同一屏左滑「删除」的功能红 #E95B4E（:420）几乎同色相；DESIGN v3.41 本身注明「蜜桃与功能红同族，删除按钮同屏需真机验证」（lovegirl_theme.dart:19）。另厨房菜单价签用 LoveGirlTheme.red 当装饰色（kitchen_screen.dart:498-504），违背「功能性红仅删除/警示」的规范，进一步模糊红=危险的语义 → 建议：旅行 wish 态改用 peachText(#C9502E) 或深一档色与红拉开；菜品价签红改 lgInk/peachText
- 【high】lib/screens/kitchen/kitchen_screen.dart:131,769,1610；lib/screens/travel/travel_form_screen.dart:356-365,477-481；lib/screens/countdown/countdown_screen.dart:209；lib/screens/voucher/wish_voucher_screen.dart:773：用户可见文案大量使用新 emoji：爱心豆提示「+5 爱心豆 🫘」（🫘 是 Emoji 14，正是 AGENTS.md 点名荣耀 Android 10 显示豆腐块的例子）、下单成功「🔥」、标题「情侣厨房 ❤」、旅行状态 emoji ✅⭐📋 作为存储值与 chip 文案、倒计时「就是今天！🎉」、券/菜品 emoji 选择器含 🧋(Emoji 13) 等——直接违反经验教训 3「用户可见文案禁用新 emoji」 → 建议：Toast/标题类换 AppIcon PNG 或纯文字；存储值可保留 emoji 但展示层兜底；选择器换图标素材（同 travel_form 天气/心情已换 Material 图标的做法）
- 【medium】lib/utils/lovegirl_theme.dart:24；lib/screens/home/home_screen.dart:1216-1224；lib/screens/travel/travel_main_screen.dart:563；lib/screens/settings/settings_screen.dart:541,639,695-703：v3.37 把 orange token 转灰 #8E8E93 后，20+ 处仍把它当「暖色强调」用：首页连续签到火焰与天数（home_screen.dart:1216-1224）、旅行票根评分星（travel_main_screen.dart:563）、设置页心情可见/清除缓存/开发者模式图标与文字（settings_screen.dart:541,639,695-703）、爱心豆爆散粒子硬编码同色（beans_screen.dart:521）、兑换券豆子图标（wish_voucher_screen.dart:167,662）——意图是高亮，实际渲染成中性灰，看起来像被禁用 → 建议：把这些调用点改为语义化 token（警示→peachText、星/火→专用金色或 lgInk），或恢复一个真正的暖色 token，避免「orange 即灰」的语义陷阱继续扩散
- 【medium】lib/screens/settings/settings_screen.dart:423-429,865-875,227-277：亮/暗色模式行内图标用硬编码琥珀 #FFB300 与紫 #7C4DFF（:423-429），与全局黑灰+蜜桃体系冲突；整页用自建 _cardDeco 而非 LovePaper（:865-875），页头「资料夹管理」文件夹图标卡+返回钮自制（:227-277）而非其余模块统一的 AppBar；「🔧 开发者模式」emoji 文案（:699,795）同触红线 → 建议：图标色收敛到 lgInk/peachText/secondary；卡片与页头改用 LovePaper/AppBar 与其他设置类页（mood/beans）对齐；🔧 移除
- 【medium】lib/screens/countdown/countdown_screen.dart:35-48,275：_iconColors 是 2014 式 Material 彩虹（洋红 #E040FB、金 #FFD700、青 #26C6DA 等），奶油暖白底上尤其跳；数字层级用 FontWeight.w300（:275），而全 App 数字 hero 统一 w900（首页 38 号 home_screen.dart:406、纪念日 58 号 anniversary_screen.dart:679）——同一 App 两套数字表达 → 建议：图标色并入 mood/旅行那套收敛色板；倒计时数字改 w900 并与纪念日倒数卡同一视觉规则
- 【medium】lib/screens/life/widgets/schedule_list.dart:36-45；lib/screens/life/widgets/todo_list.dart:457-469：两个并排子模块各自维护一套 10 色/6 色分类色板（Stripe 靛蓝 #635BFF、Material 紫 #9C27B0、蓝 #2196F3、粉 #E91E63、FlatUI 橙 #E67E22 等），与 mood_screen 的 10 色（mood_screen.dart:51-62，v3.42 刚做过消同色治理）互不相交；生活 tab 内同类「分类色」出现三种语言，默认分配的色块饱和度明显高于全 App 基调 → 建议：抽公共分类色板常量（对齐 mood_screen._moodColors 的低饱和版），课表/待办/心情共用
- 【high】lib/screens/home/home_screen.dart:673,544-546；lib/screens/wardrobe/wardrobe_home_screen.dart:68；lib/screens/beans/beans_screen.dart:190-196；lib/screens/profile/profile_screen.dart:502；lib/screens/anniversary/anniversary_screen.dart:924：首页错误横幅背景写死 Colors.white（:673，另 anniversary 版本是粉底 #FBF1F0 anniversary_screen.dart:924，同组件两套样式）；衣橱搜索框 fillColor: Colors.white（:68）；爱心豆相关奶油底 #FFF0D9/#F1D4B1/#FFF2E1（home_screen.dart:544-546、beans_screen.dart:190-196、profile_screen.dart:502）与金褐 #B8860B——这些不是票根隐喻卡，深色模式下会浮出刺眼亮块，违反「深浅两态发布前必过」的自查线 → 建议：全部换 context.lgCard/lgPaperWarm 系语义色；错误横幅抽成共享组件统一两种样式
- 【low】lib/screens/anniversary/anniversary_screen.dart:66；lib/screens/travel/travel_form_screen.dart:481；lib/screens/mood/mood_screen.dart:60：「first（第一次）」类型用紫 #9E78D8（ChoiceChip/LoveStickerIcon），travel planned 用 #9C27B0，mood planned/wedding 紫 #9E9AD1——三种相近紫互不相干，观感像三个时代的遗留 → 建议：统一到 mood 色板的紫 #9E9AD1 一档，收入 LoveGirlTheme
- 【low】lib/screens/photo/photo_screen.dart:290,473,497；lib/screens/travel/travel_main_screen.dart:396：故事编辑弹层底色写死 #E9E4DC、输入框纯白（纸面隐喻有意为之可接受），但深色模式下弹层整块亮米+纯白输入框与系统深色断裂；左滑置顶钮写死蓝灰 #6B7A8F（travel_main_screen.dart:396）不在任何色板内 → 建议：纸面底色深色态给 cardDark 变体或加暗罩；置顶钮色并入收敛色板或 lgInk

## 三个方向完整方案

### 体系打磨（奶油暖白+蜜桃日出）
不动风格底盘，只清账：把 planned 紫双胞胎、wish 态双色、orange 语义陷阱等不一致统一回 token，把深色漏网亮块和违反老设备红线的 emoji 补齐，顺手删死 token、回改滞后文档。

1. **厨房/倒计时/兑换券/设置页的用户可见 emoji 文案**（medium）：Toast/弹窗文案去掉 emoji 换纯文字或 AppIcon PNG：kitchen_screen.dart:1610「+5 爱心豆 🫘」（🫘=Emoji 14，AGENTS.md 点名荣耀 Android 10 豆腐块的同一个字符）、kitchen_screen.dart:769 🔥、kitchen_screen.dart:131 标题「情侣厨房 ❤」、countdown_screen.dart:209「就是今天！🎉」、settings_screen.dart:699,795 🔧；wish_voucher_screen.dart:773 的 _emojiChoices 选择器含 🧋(Emoji 13)——照 travel_form 天气/心情已换 Material 图标的同款做法换图标，或至少展示层做老设备兜底
   - 为什么：这是项目硬红线（老设备豆腐块=用户直接看到乱码），不是审美问题；kitchen/兑换券恰是情侣高频使用页
   - 依据：lib/screens/kitchen/kitchen_screen.dart:131,769,1610（已读）；lib/screens/countdown/countdown_screen.dart:209（已读）；lib/screens/voucher/wish_voucher_screen.dart:773（已读）；lib/screens/settings/settings_screen.dart:699,795（已读）；AGENTS.md 经验教训 3
2. **旅行地点状态色（wish/planned/visited）与 planned token**（small）：合并为单一取色函数挂到 LoveGirlTheme（statusWish/statusPlanned/statusVisited 三个 token）：travel_main_screen.dart:1730-1741 详情弹层的 _statusColor 与 :895-906 顶层版 wish 一蜜桃一灰、planned 各自硬编码；全仓 9 处 Color(0xFF9C27B0) 统一改引 LoveGirlTheme.planned(#9E9AD1)；同时定夺 token planned 与 Material 紫谁是最终态（建议留 #9E9AD1，mood 色板也用它，见 mood_screen.dart:60）
   - 为什么：同一列表里「心愿单」卡片左缘是蜜桃、点开底部弹层变灰，用户一眼能感知的不一致；且 planned 在 travel/todo/tasks/life 四模块全是硬编码、token 形同虚设
   - 依据：lib/screens/travel/travel_main_screen.dart:895-906,1730-1741,902,1313,1737（已读）；lib/utils/lovegirl_theme.dart:59-61（已读）；grep "0xFF9C27B0" lib 实测 9 处（schedule_list:40、todo_list:459、tasks_screen:26、task_form:25、travel_form:481,696、travel_main:902,1313,1737）
3. **首页/纪念日错误横幅 + 衣橱搜索框 + 旅行 wish 与删除红同屏**（medium）：①两个错误横幅抽成 lib/widgets 下共享组件，底色走 context.lgCard/lgPaperWarm（深色态已映射 cardDark）统一两种样式；②wardrobe 搜索框 fillColor: Colors.white 改 context.lgCard；③同屏有wish 蜜桃卡与删除红时，wish 边/底改用 peachText(#C9502E) 深一档与 #E95B4E 拉开色距，发布前深浅两态真机各过一遍（token 注释本身要求的验证项）
   - 为什么：home_screen.dart:673 写死 Colors.white、anniversary_screen.dart:924 写死 #FBF1F0 粉底且无深色分支——深色模式浮亮块+粉底配米白字低对比；wardrobe_home_screen.dart:68 搜索框纯白同理
   - 依据：lib/screens/home/home_screen.dart:670-682（已读）；lib/screens/anniversary/anniversary_screen.dart:920-933（已读）；lib/screens/wardrobe/wardrobe_home_screen.dart:60-73（已读）；lib/utils/lovegirl_theme.dart:19,60（已读）
4. **orange token 的语义陷阱（grey 装暖色）**（small）：把当「暖色强调」用的调用点逐个改语义 token：home_screen.dart:1216-1224 连续签到火焰+文字改 peachText；settings_screen.dart:695-703 开发者模式条改 lgInk；travel_main_screen.dart:563 评分星改 peachText 或 lgInk；其余 BeansScreen:521 等同理。改完 orange 在 lib 里只剩真正的中性态用途，陷阱消除
   - 为什么：orange=#8E8E93 中性灰（lovegirl_theme.dart:24），但签到火焰/评分星/开发者模式条仍拿它当高亮——意图是强调，渲染出来像禁用态，这是 v3.37 转灰后遗留的语义债
   - 依据：lib/utils/lovegirl_theme.dart:24（已读）；lib/screens/home/home_screen.dart:1214-1226（已读）；lib/screens/settings/settings_screen.dart:690-704（已读）；lib/screens/travel/travel_main_screen.dart:560-564（已读）
5. **生活/任务/倒计时的散装分类色板**（medium）：以 mood_screen.dart:51-62（v3.42 刚做过消同色治理的低饱和 10 色）为基准抽一个公共常量（如 lib/utils/category_palette.dart 或挂 theme），schedule/todo/tasks/countdown 四处替换并删除各自影子色板；DESIGN_SYSTEM.md 第 6 节补「内容语义彩板」豁免条目并注明深色可用性
   - 为什么：schedule_list.dart:36-45（Stripe 靛蓝 #635BFF/#00D4AA）、countdown_screen.dart:35-48（洋红 #E040FB/金 #FFD700）、tasks 三处 #9C27B0——同一 App 内分类色三种语言且饱和度远超奶油基调；mood 刚治理过，直接复用成果成本最低
   - 依据：lib/screens/mood/mood_screen.dart:50-62（已读）；lib/screens/life/widgets/schedule_list.dart:35-46（已读）；lib/screens/countdown/countdown_screen.dart:35-48（已读）；lib/screens/tasks/tasks_screen.dart:23-27 与 task_form.dart:22-27（grep 命中后已核对行号）
6. **厨房菜单红价签**（small）：kitchen_screen.dart:498-504 菜品价签 color: LoveGirlTheme.red 改 peachText（金额是正文档，按规范用文本档蜜桃）；顺手排查同文件其他 red 装饰用法
   - 为什么：kitchen_screen.dart:503 用 LoveGirlTheme.red(#E95B4E) 做价格装饰，违反「功能性红仅删除/警示」；且蜜桃与红同族（lovegirl_theme.dart:19 注明同屏需真机验证），红被稀释后真正的删除/警示语义跟着变弱
   - 依据：lib/screens/kitchen/kitchen_screen.dart:496-509（已读）；lib/utils/lovegirl_theme.dart:19,23（已读）
7. **DESIGN_SYSTEM.md 色板滞后值**（small）：①DESIGN_SYSTEM.md:20 primarySoft 文档 #F4F4F5（冷灰）→ 代码实况 #F0EAE0（暖米，lovegirl_theme.dart:14）；②:31 separator #ECECEC → #EEE8DF（lovegirl_theme.dart:42）——文档第 3 行自己写明「与代码冲突时以代码为准并回改文档」，按文档规则回改；同节顺手把 planned 的「唯一紫」措辞与 9C27B0 硬编码现状对齐（联动第 2 条）
   - 为什么：v3.41 暖化时代码先行文档没跟上，后续按文档取色会把冷灰写回暖色系页面，是下一个不一致的源头
   - 依据：docs/DESIGN_SYSTEM.md:20,31 与 lib/utils/lovegirl_theme.dart:14,42（两处均已读，值不同属实）
8. **死 token 与黑灰别名清理**（small）：删除 lib/utils/lovegirl_theme.dart:71-76 gradientSunset/gradientOcean/gradientForest 与 :284-296 glassDecoration（grep 实证 lib 内零引用，仅定义行）；pink/pinkLight（:25-26）5 处引用（period_tracker:303、finance_list:1246、todo_list:605、tasks_screen:401 等）改 context.lgInk/primaryLight 直写后删别名；update_dialog.dart:61 头带 gradientLove 属渐变白名单外遗留，改 primarySoft 单色（login_screen:67 可保留并纳入白名单明示）
   - 为什么：glassDecoration 是半透明白描边玻璃拟态，与 DESIGN_SYSTEM 第 0 节「禁忌：玻璃拟态」直接矛盾，留着就会被人复用；死渐变的色值已经以硬编码形式散落到别处（教训重演的温床）
   - 依据：lib/utils/lovegirl_theme.dart:25-26,70-76,284-296（已读）；grep "glassDecoration|gradientSunset|gradientOcean|gradientForest|pinkLight|gradientLove" lib 实测：死 token 仅定义行命中，pinkLight 5 处使用、gradientLove 2 处（login_screen.dart:67、update_dialog.dart:61）

### 实体感升级——把拍立得相纸的质感语汇下沉为全 App 共享能力
以用户最认可的 polaroid_frame.dart 为母本，把双层实体影/纸纹贴片/内凹 bevel/受光亮线四件套下沉到 LovePaper、票根、横幅、空态与按压反馈，顺路修掉票根系统四处硬编码浅色的深色模式漏网（红线项）。

1. **lib/widgets/lovegirl_ui.dart 的 LovePaper + lib/utils/lovegirl_theme.dart**（medium）：LovePaper 增加可选 material 参数：'paper' 档在 ClipRRect 内叠 assets/images/deco/paper_grain.png（Opacity 0.55、ImageRepeat.repeat，照抄 polaroid_frame.dart:258-269 的做法）+ 上下缘压暗/受光渐变（polaroid_frame.dart:218-236 同款）；阴影层在现有 cardShadow()（lovegirl_theme.dart:78-84 单层 0x1A000000 blur8）之外新增 cardShadowRest() 双层静置影（近硬影 0x40000000 blur3 offset(0,2) + 远环境影 0x26000000 blur22 offset(0,12)，数值取自 polaroid_frame.dart:23-26 的 kPolaroidRestShadows）。paper_grain 是灰阶低透明噪点（生成器 tools/gen_paper_grain.py:17-20，alpha 6-18），深浅两态通用无需分支；深色态双层黑影可见性需真机各验一遍。
   - 为什么：用户最满意的实体质感目前锁死在拍立得组件内部，而 LovePaper 已被 32 个页面文件使用（grep 统计），一处加参数即可让全部白卡获得'纸不是 UI'的观感，且深浅两态在一处收敛保证一致，符合用户'先方案后动手、不扩大范围'的习惯——纯加参数不迁移调用点。
   - 依据：lib/widgets/polaroid_frame.dart:23-26,218-269；lib/widgets/lovegirl_ui.dart:31-65；lib/utils/lovegirl_theme.dart:78-92；lib/screens/photo/photo_screen.dart:295-313（纸纹已有第二处应用先例）；assets/images/deco/paper_grain.png（ls 确认存在）
2. **lib/widgets/ticket_styles.dart（票根共享样式层）**（small）：①打孔缺口 notch 的 Color(0xFFFFFFFF)（:74-78）改为 context.lgBg——打孔应透出页面底色，深色模式下现在会浮出刺眼白圆片；②HorizontalTicketStub/VerticalPostcardTicket 容器硬编码 Color(0xFFFFFFFF)（:173、:297）改 context.lgPaper；明信片文字区 Color(0xFFF4F0E8)（:316）改 context.lgPaperWarm（深色态已映射 cardDark，lovegirl_theme.dart:313-314 现成）；③明信片文字区叠 paper_grain 纹与边缘受光线，向拍立得纸面对齐。
   - 为什么：票根是本 App 最强的实体隐喻，但四处硬编码浅色使其成为深色模式最刺眼的漏网点（违反'发布前深浅两态必过'红线）；孔洞色跟底色后才真正'像打出来的孔'，实体感与红线修复一举两得。
   - 依据：lib/widgets/ticket_styles.dart:74-78,169-181,294-317；lib/utils/lovegirl_theme.dart:313-314
3. **lib/widgets/lovegirl_ui.dart 的 _TicketBorderPainter（LoveTicketCard 边框）**（small）：_TicketBorderPainter（:446-498）目前只画 1px 渐变描边。增加第二层内描边：沿同一路径内缩 1px 画 1px 白高光（Colors.white alpha≈48）、内缩 3px 画极浅暗沿（lgSeparator alpha≈120），复用 _WindowBevel 的'深沿+高光=凹进去'配方（polaroid_frame.dart:282-301）；notch 半圆边缘同步。
   - 为什么：拍立得的'实体感'一半来自内凹 bevel；票根描边目前是一根平面线，加内压后厚卡纸的'分量'立现，改动只在 painter 内部，LoveTicketCard 的 13 个使用文件零迁移。
   - 依据：lib/widgets/lovegirl_ui.dart:98-125,446-498；lib/widgets/polaroid_frame.dart:281-301
4. **lib/widgets/lovegirl_ui.dart 新增 LoveBanner；调用点 home_screen.dart:673、anniversary_screen.dart:918-924**（small）：同语义三处三样式：home 白底 Colors.white（:671-679）、anniversary 固定浅粉 Color(0xFFFBF1F0)（:918-924，深色下粉底+米白字低对比）、travel_ticket_screen 另有 lgPaperWarm 变体（:401-415）。合并为 LoveBanner.error：lgPaperWarm 底 + paper_grain 纹 + lgSeparator 描边 + cardShadow，图标/文案/重试行为不变；重试钮包 PressableScale。
   - 为什么：两处深色漏网是 ask 勘察已点名的 high 级问题；'便签纸条'隐喻贴合奶油暖白，且消除同组件两套样式的维护分叉——修复实体感的同时收掉红线项。
   - 依据：lib/screens/home/home_screen.dart:671-679；lib/screens/anniversary/anniversary_screen.dart:918-924；lib/screens/travel/travel_ticket_screen.dart:401-415
5. **lib/widgets/lovegirl_ui.dart 的 LoveIconButton / LoveMenuRow / LovePill**（small）：grep 实测 PressableScale 全仓仅 2 处使用（home_screen 1 处 + LovePrimaryButton 1 处，motion.dart 4 处为定义本身）。LoveIconButton（:349-375）与 LoveMenuRow（:395-443）的 InkWell 只有 ripple 无下沉感——外包 PressableScale；更进一步的实体方案是 LovePaper 加 pressed 态：按住时 scale 0.97 且阴影 blur 8→5（'按下去影子收紧'比单纯缩放更像实体物件）。PressableScale 已内建 motionLevel=='off' 降级（motion.dart:112-117），无障碍兜底现成。
   - 为什么：用户认可的实体感=可按压的物件感；组件层一处接入，全 App 菜单行/图标钮统一获得按压反馈，无需逐页改动——这是'改法少、覆盖面大'的杠杆位。
   - 依据：lib/utils/motion.dart:98-132；lib/widgets/lovegirl_ui.dart:202-239,331-375,377-444
6. **lib/widgets/empty_state.dart**（medium）：仅改无插画分支（:64-66 的裸 Icon 64px lgTextMuted）：换一张轻量'空拍立得'——奶白小纸片（lgPaperWarm 底+paper_grain+缩小版双层影）、中央哑光内凹窗（复用 _WindowBevel 的深沿+1px 高光配方）、底边一条 Caveat 手写占位线、整体微歪 rotation≈-0.02（同 HandwrittenDate 的 :324-331 手法）；有 illustration 时的 IllusImg 分支保持不动（插画是已验收内容）。
   - 为什么：空态是每个模块首见面积最大的情绪面，一张微歪的空相框比 64px 灰图标更贴'回忆本'气质；直接把用户最爱的实体元素复用到最高频场景，改动限于一个组件的一个分支。
   - 依据：lib/widgets/empty_state.dart:56-87；lib/widgets/polaroid_frame.dart:281-301,324-331,358-367（Caveat 已注册使用）；lib/widgets/illus_image.dart（分支现状）
7. **lib/screens/countdown/countdown_screen.dart:275**（small）：卡内天数数字 fontWeight w300/20px 改 w900，与首页 hero 38/w900（home_screen.dart:404-408，且已套 RollingNumber）和纪念日 58/w900（anniversary_screen.dart:678）同一表达；颜色仍走 daysColor 不动。可顺带接 RollingNumber（motion.dart:76-96 已现成且带 motionLevel 降级）。
   - 为什么：倒计时数字 w300 在奶油底上发飘，与两处 w900 hero 形成'同一 App 两套数字语言'；数字印得实、才有'刻在纸面上'的实体重量感——这是半天级的一致性收口。
   - 依据：lib/screens/countdown/countdown_screen.dart:267-277；lib/screens/home/home_screen.dart:402-409；lib/screens/anniversary/anniversary_screen.dart:674-681；lib/utils/motion.dart:76-96
8. **lib/screens/travel/travel_ticket_screen.dart:423-429**（small）：:424-428 两处（Container 底色 + LoveTicketCard 的 color 参数）固定暖白 Color(0xFFFFF8F0) 改 context.lgPaperWarm；票面叠 paper_grain 与边缘受光线（同拍立得配方）。同页空态提示已用 lgPaperWarm（:401-415），同一屏统一。
   - 为什么：整张旅行票根页深色模式下是一大块固定暖白亮区，是票根隐喻页面里最大的深色漏网；且它是'保存/分享'的高光页，实体纸感价值密度最高。
   - 依据：lib/screens/travel/travel_ticket_screen.dart:401-415,423-436

### 方案C·布局与导航动线焕新
8 条候选全部锚定亲手核实的代码病灶，从导航保活、票根实体化到死模块收编，均为既有组件复用/重排、不动数据层与视觉语言，供用户拍板后分期施工。

1. **main.dart AppShell——五个底部 tab 的页面切换机制**（medium）：把 _buildCurrentPage() 的 switch（main.dart:155-182）改为 IndexedStack 保活五个 tab，并取消 _navigateToTab 里 _lifeSubTab=0 的强制归零（main.dart:122-127），让生活页记住上次子页签。唯一硬点：旅行页内嵌高德 PlatformView 目前只按内部 _viewIndex 门控（travel_main_screen.dart:246-256），保活后必须再叠加『本 tab 是否激活』的条件门，否则重蹈教训 17 的非激活原生视图浮上来。
   - 为什么：现状每次切 tab 整页重建：首页重跑 initState 里的回忆卡/TA近况/通知三个拉取（home_screen.dart:50-58），旅行页重新 refreshAll（travel_main_screen.dart:54-56），生活页 TabController 且回到第 0 页签。五 tab 高频横跳是导航动线层面收益最大的一项，且完全不动视觉语言；真机走查成本低（切 tab 巡一遍即可）。
   - 依据：lib/main.dart:122-127,155-182；lib/screens/home/home_screen.dart:47-59；lib/screens/travel/travel_main_screen.dart:246-256
2. **旅行模块第三视图「票根回忆」（travel_main_screen.dart:_buildTicketPage）**（medium）：把『纯白行卡+36px 小插画』列表（travel_main_screen.dart:523-567）重排为 2 列票根册网格：每张已打卡地点一张票根卡，复用库内现成实体隐喻组件——LoveTicketCard 打孔边（lovegirl_ui.dart:98-125）、LoveTicketDivider 虚线（lovegirl_ui.dart:127-158）、LoveBarcode 条码（lovegirl_ui.dart:160-200）；评分星从 LoveGirlTheme.orange（实为中性灰 #8E8E93，lovegirl_theme.dart:24，v3.37 转灰遗留）改暖色档；顶部『生成正式票根』入口保留。
   - 为什么：用户口味里实体质感是最高认可项（拍立得相纸返工被高度认可、票根隐喻保留），而票根回忆页目前是全 App 最不『票根』的一页；这案是纯重排+组件复用，不新增隐喻、不动数据层，深浅两态全走 lgPaper/lgSeparator 天然安全，正对『实体感』这个已被验证的偏好点。
   - 依据：lib/screens/travel/travel_main_screen.dart:456-571；lib/widgets/lovegirl_ui.dart:98-200；lib/utils/lovegirl_theme.dart:24
3. **倒计时模块与纪念日页的信息架构合并**（small）：两步：① lib/screens/countdown/ 整目录（countdown_screen.dart 330 行 + countdown_form.dart 262 行，SharedPreferences 'countdowns' 本地存储）已无任何引用（grep 全 lib/test 零命中），删除或明确归档；② 首页头部恋爱天数 hero（home_screen.dart:388-431）旁加一枚最近倒数小胶囊（如『距 认识1000天 还有 N 天』），点击进纪念日页；纪念日页 hero『下一个重要日子』（anniversary_screen.dart:585-697）继续作为唯一时间锚点页。
   - 为什么：同一『倒数』语义现在有两套实现（本地死码+服务器 anniversary 表），唯一活入口在『我的』tab 第三屏（profile_screen.dart:218-227），与『每天想看一眼还剩几天』的动机错位；首页天数本就是整屏视觉锚点，顺承展示最近倒数是零新概念的动线缩短，删死码同时降低后续维护歧义。
   - 依据：lib/screens/countdown/countdown_screen.dart（grep CountdownScreen 全仓库无外部引用，test/ 亦无）；lib/screens/anniversary/anniversary_screen.dart:585-697；lib/screens/profile/profile_screen.dart:218-227；lib/screens/home/home_screen.dart:388-431
4. **首页「本帮你账本/本周课程」生活面板（_LifeSummaryTicket）+ 卡片流分组**（small）：去掉写死的 fallback——home_screen.dart:1488-1500 里总支出/剩余预算/课程名/时间/教室/星期全部有硬编码兜底（¥1520、¥480、『设计心理学』『14:00』『教二楼 302』『周四』），改为接口无数据时整卡塌缩或出真实空态，有数据才渲染；顺带用 LoveSectionTitle 给卡片流加『今天/回忆/生活』分组锚点（TodayCareSection 已自带标题，其余卡没有）。
   - 为什么：没记账/没录课程时会看到『总支出 ¥1520、本周设计心理学』的假数字，比布局问题更伤信任；同时首页目前是 6 张同级卡线性堆叠（home_screen.dart:229-302）无扫视锚点，分组标题是信息密度重排里成本最低的一步，符合『先方案后动手』的小步节奏。
   - 依据：lib/screens/home/home_screen.dart:1486-1500,229-302
5. **我的页「回忆与管理」功能卡（profile_screen.dart:_buildFunctionZone）**（medium）：12 行 LoveMenuRow 单列（相册/美食手账/旅行票根/愿望兑换券/慢信/月度小报/年度报告/爱心豆/设置等，profile_screen.dart:303-411）重排为『回忆类 2 列图标格 + 管理类保留单列』；版本与诊断区（profile_screen.dart:414-446）维持底部不动。只动排布，不砍不并任何入口。
   - 为什么：这是全 App 最长的单列滚动卡，720×1600 测试机上要滑两屏才能到设置；回忆类（相册/手账/票根/慢信/月报）语义同族、图标化程度高，适合双列压缩。用户反感擅自扩大范围，此案是『分组+换排列』而非重构，功能集合一个不少，便于逐项验收。
   - 依据：lib/screens/profile/profile_screen.dart:303-446
6. **生活 tab 顶部头卡（life_screen.dart:_buildHeader）**（small）：现状是一整张 LoveTicketCard（约 90px：46px 贴纸图标+25px 标题+副标题+一个与下方页签完全重复的当前页签 pill，life_screen.dart:76-118），瘦身为一行轻量标题（去重复 pill 与副标题），省出的纵向空间还给五个子页签的长列表内容区。
   - 为什么：页签条（life_screen.dart:120-197）已完整表达『我在哪个子模块』，头卡里的 pill 是纯冗余装饰；生活五个子模块全是长列表，测试机上每省 60px 就少一次滚动。改动局限在一个私有方法，回滚成本几乎为零。
   - 依据：lib/screens/life/life_screen.dart:76-197
7. **旅行地点卡状态视觉——同屏两套 _statusColor 合一**（small）：合并 travel_main_screen.dart:895-906（清单卡用，wish=蜜桃 #F2704F）与 1730-1741（详情弹层用，wish=灰 #8E8E93）为单一来源；planned 用 LoveGirlTheme.planned #9E9AD1（lovegirl_theme.dart:61）替换两处硬编码 #9C27B0；因 wish 蜜桃与左滑删除红 #E95B4E 同屏（:420），wish 建议落 peachText #C9502E 深一档拉开色距。
   - 为什么：同一个『想去』地点在列表卡是暖桃、点开底部详情弹层变灰，用户可感知的不一致，也是仓库勘察标 high 的项；改动落在清单卡左缘色条+状态胶囊这个卡片信息层级上，属于组件层面的小手术，顺手消除蜜桃/功能红同屏的既有隐患（theme 注释自述需真机验证）。
   - 依据：lib/screens/travel/travel_main_screen.dart:895-906,1730-1741,420；lib/utils/lovegirl_theme.dart:20-23,59-61
8. **心情页导航层级——补『年视图』钻取（月↔年两级）**（medium）：现页只有 _currentMonth 逐月步进（_prevMonth/_nextMonth，mood_screen.dart:24,94-106），在月历头部加『年』级入口：4 列×12 月年视图，每格按该月记录密度着色（复用 _moodColors 低饱和体系），点月下钻回现有月历；弹层返回不丢层级。结构按 backlog 已勘定的 star_book 方案（MIT，可借结构）。
   - 为什么：『这一年我们过得怎么样』是情侣核心回看诉求，当前 UI 回看一年要连点 12 次；仓库自己的弹药库把心情可视化列为最大缺口、年视图列为可借结构（docs/reference-backlog.md 心情节多条 high），这是导航动线补全而非新功能堆叠，深色态沿用现有色板即可。
   - 依据：lib/screens/mood/mood_screen.dart:24,94-106；docs/reference-backlog.md:108,230-239

## 用户口味画像（评审依据）

用户口味画像（来自项目史，判断时必须参考）：
- 现行风格 v3.41「奶油暖白+蜜桃日出」：底 #FAF6F0、卡白浮起、暖炭字阶、蜜桃 #F2704F 双档点缀（正文用 peachText #C9502E 保对比度）、主按钮黑底白字；此前用户嫌纯冷白工具风"偏冷"
- 用户极喜欢实体质感细节（拍立得相纸返工：纸纹/内凹/光泽/实体阴影/比例锁，被用户高度认可）；反感平铺直叙的"UI 卡片式"实现
- 用户反感擅自扩大改动范围（只让改地图却动了纪念日被批评）；习惯"先方案后动手"——本次只出推荐清单，不改任何代码
- 老设备红线：荣耀 Android 10 不支持新 emoji，用户可见文案禁用新 emoji
- 深色模式是全局硬性要求：任何推荐必须考虑深浅两态