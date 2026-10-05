# 开源参考弹药库（reference-backlog）

> 生成：2026-09-30 目标模式运行。11 个 GitHub 项目代码级精读，clone 基底 `D:\Projects\Personal\oss-refs\`（上游出处见各节）。
> 用途：LoveGirl 后续版本的**需求弹药库**——每条可借点标注【对应模块】【优先级】【移植难度】【可移植/仅启发】。实施前须走既有纪律（对抗审查→analyze 0+test 全绿→独立 commit）。
>
> **红线**：GPL/AGPL 项目（9/10/11 节）代码严禁任何形式移植，条目全部为【仅启发】；Apache-2.0 的 NOTICE 须保留（第 7 节）。

---

## 1. wardrobe（tandpfun/wardrobe）—— 生成式 AI 衣橱导入管线

- 定位：local-first AI 衣橱：上传照片→AI 逐件识别→生成"去人留衣"透明单品图→可选"本人穿着"样板照→人审入库→AI 搭配｜React 19 + Vite 6，无独立后端（AI 管线内嵌 dev server 插件）｜许可证实勘：**MIT 相符**（Open Wardrobe contributors 2026）
- 架构速记：无数据库——`data/library.json` 衣橱库 + `data/jobs/<uuid>/job.json` 作业 + `data/imported/*.png` 成品；`scripts/import-job-api.mjs`（711 行）为全部服务端逻辑

- **1.1 生成式"去人留衣"整衣重建（SegmentCloth 的对照方案）**：不做分割，让图像编辑模型把穿搭照"重建为无人、平铺、电商目录级"的完整单品。【衣橱·SegmentCloth 抠图链路】【高】【移植难度：低——prompt 与色键函数是纯文本/纯函数】【可移植】
  - 出处：`scripts/import-job-api.mjs` 的 `buildGarmentPrompt()`（用例声明/忠实度条款/构图/纯色背景/Avoid 清单/Critical 禁止色键入衣）、`chooseChromaKey()`（绿/品红/青三候选取欧氏距离最远，避免键掉衣服本色）
  - 说明：直接命中"人身照去人留衣"核心需求。建议阿里云钥匙就位后，用同一批真图做 SegmentCloth vs 生成式重建的 A/B 评测；prompt 全文与色键逻辑可照搬（OpenAI 兼容 `/images/edits` 协议，国内换支持图像编辑的模型即可）。
- **1.2 chroma 抠底后处理链 + 污染校验 + 失败兜底编辑器**：色键距离抠底（tolerance+80px 羽化）→despill→alpha 归一化居中装框 1024（占空比 0.88）→逐像素污染校验（strict >1 像素即报错）→失败保留原图+用户滑杆调 tolerance 实时预览（300ms 防抖）→cleanup-accept 收编。【衣橱·抠图后处理】【高】【低（sharp 逐像素逻辑可 1:1 翻译）】【可移植】
  - 出处：同文件 `processChromaBackground()`/`frameTransparentGarment()`/`verifyNoChromaSpill()`/`removeKeyedSpill()`
  - 说明：LoveGirl 现在"下载压 1200 png"即完事，无边缘质量校验；这套链路把"不满意只能重抠"升级为"本地微调救回"。`frameTransparentGarment` 的统一占空比装框让衣橱网格单品视觉尺寸一致。
- **1.3 三段式人审导入作业状态机（批量建档骨架）**：一次上传→视觉模型 strict JSON schema 识别 N 件（bbox 归一化 1000×1000、五类枚举、主色+副色 hex、≤4 tags、单图 ≤8 件）→crop→garment→modeled 三段，每段 pending/queued/processing/review/approved/rejected/failed+attempts，approve 触发下段；JSON 原子写（tmp+rename）+启动恢复。【衣橱·批量建档/换装白板前置】【高】【中（状态机可搬，持久化换 MySQL 表）】【可移植】
  - 出处：`scripts/import-job-api.mjs`（`generate()`/`stageState()`/`atomicJson()`/崩溃恢复段）
  - 说明：LoveGirl 目前"一图一表单手动建档"；此项目证明"一次 N 张→每件独立作业卡→逐张人审"可行，适合加一张 `wardrobe_import_jobs` 表复刻。
- **1.4 分桶主色提取 + 点图取样**：72×72 缩样、RGB/28 量化分桶取均值、去重取 5 色；点图取样螺旋扩环找第一个 alpha>96 像素。【衣橱·表单颜色字段/小程序衣橱】【中】【低（算法 40 行）】【可移植/仅启发】
  - 出处：`src/App.jsx` 的 `extractPalette()`/`sampleImageColor()`
  - 说明：LoveGirl 衣橱颜色筛选依赖手填；"抠图完成即自动提取主色供点选"能提填写率与筛选准确率，主色还喂给 1.1 的 prompt。
- **1.5 内容哈希幂等导入**：成品 PNG sha256→稳定 UUID 作为记录 id，同图重跑只更新不重复。【衣橱·批量去重】【中】【低】【可移植】
  - 出处：`.agents/skills/import-clothes/scripts/import-to-wardrobe.mjs`
- **1.6 Agent skill 批量建档 SOP + AI 搭配选型原则（仅启发）**：contact sheet 人工审图、manifest 状态机、"宁缺毋编"忠实度红线；搭配生成原则（同色系优先/对比色克制/一件 statement piece/廓形平衡/场景多样）。【衣橱·AI 搭配（未来）】【低】【—】【仅启发】
  - 出处：`.agents/skills/import-clothes/SKILL.md`、`.agents/skills/generate-outfits/SKILL.md`

**可移植文件清单（MIT）**：`scripts/import-job-api.mjs`（`buildGarmentPrompt/chooseChromaKey/processChromaBackground/frameTransparentGarment/verifyNoChromaSpill/atomicJson` 均为无依赖纯函数）；`src/App.jsx` 的 `extractPalette/sampleImageColor`；`src/import-flow.jsx`（导入 UI 状态机参考）；`.agents/skills/` 两份 SKILL.md。

**一行结论：用它的"生成式去人留衣 + chroma 后处理校验"对 SegmentCloth 做同图 A/B 评测并作为兜底链路——抠图痛点最直接的对照解。**

---

## 2. Rainbow-Cats-Personal-WeChat-MiniProgram（UxxHans）—— 情侣任务积分商城小程序

- 定位：微信云开发情侣互动：发布任务→对方完成得积分→积分买对方挂的"券"→仓库→使用（不可逆）→现实兑现｜原生小程序+云函数，无自建后端｜许可证实勘：**MIT 相符**｜体量小（自写约 1150 行+weui）
- 架构速记：openid 即身份（`getOpenId` 云函数），globalData 硬编码两人 openid；4 集合 MissionList/MarketList/StorageList/UserList；11 个薄封装云函数，集合名客户端传入

- **2.1 openid 即身份 + 双账号骨架**：零登录成本拿"我是谁/对方是谁"。【小程序版衣橱·登录骨架】【高】【低】【仅启发】
  - 出处：`miniprogram/app.js`、`pages/Market/index.js getUser()`
  - 说明：LoveGirl 小程序可沿用，但**勿照抄硬编码 openid**——用现有账号体系或 couples 映射集合做绑定。
- **2.2 任务→积分→商城→仓库→使用 五段闭环 + 防自利规则**：对方完成任务才加积分；余额校验→下架+扣分+入仓库；使用置 available:false 不可逆；不能完成自己的任务/买自己的商品、单笔积分上限。【兑换券/爱心豆玩法升级】【高】【低（玩法规则即文档）】【仅启发】
  - 出处：`pages/Mission/index.js finishMission()`、`pages/Market/index.js buyItem()/slideButtonTap()`、`pages/Account/index.js useItem()`
  - 说明：LoveGirl 兑换券缺"赚取"一环；这套闭环（尤其"使用不可逆+只能花在对方身上"）是爱心豆经济缺的对称性。**它的防自利只在客户端校验，移植必须下沉服务端。**
- **2.3 `db.command.inc()` 原子自增记账**：【爱心豆服务端记账】【中】【低】【仅启发】
  - 出处：`cloudfunctions/editCredit/index.js`（对应 mysql2 单条原子 UPDATE）
- **2.4 预设模板一键建档 + weui 左滑三键**：任务/商品内置 presets 数组（选中回填 title/desc）+录入校验；列表统一左滑三图标。【兑换券模板/小程序衣橱录入/旅行左滑（App 侧已同构）】【中】【低】【可移植（小程序侧 weui slideview）】
  - 出处：`pages/MarketAdd/index.js`（presets/校验）、各列表页 slideButtons
- **2.5 反面教材：无事务三连写 + 无积分流水**：购买=三个独立云函数顺序调用，任一失败即账实不符；只有余额无流水；集合名客户端传入有越权读风险。【兑换券/爱心豆服务端事务设计】【中】【—】【仅启发（负面）】
  - 出处：`pages/Market/index.js buyItem()`（214-221 行）、`cloudfunctions/getList/index.js`
  - 说明：LoveGirl 做"买券扣豆"必须单事务完成"扣豆+生成券+写流水"（who/what/when/amount 四要素）。订阅消息推送思路可借给慢信解锁/每日一问提醒。

**可移植文件清单（MIT）**：`MarketAdd` presets 结构与校验；`editCredit` 原子增量实现；`Account` 页骨架（约 164 行）。

**一行结论：2.2 的五段闭环+防自利规则，是兑换券/爱心豆从"单向北"升级"双向经济"的现成玩法蓝本（服务端补事务与流水）。**

---

## 3. 1024house（bbblackclark/1024house）—— 实勘不符，跳过深读

- 定位（自称）：可私有部署情侣/家庭空间｜Node+MongoDB｜LICENSE 名义 MIT
- **实勘不符**：仓库仅 5 文件 314 行（README/docker-compose/llms.txt/.gitignore/LICENSE），单提交。**无任何源码**——应用本体是阿里云私有镜像的闭源预构建 Docker 镜像，带 ACTIVATION_KEY 激活码+30 天试用，实为商业品部署壳。路由组织/纪念日数据模型/实时聊天均不可读。
- 仅存启发（非移植）：①自查 LoveGirl uploads 目录是否独立卷/独立备份面；②"默认账号环境变量注入"可自动化测试账号初始化，但**密码不得进 compose**（该 repo 把 123456 写进 yml，反面示例）。

**一行结论：无可借代码——"README 自称 MIT ≠ 源码开放"的实证；顺带触发一次 uploads 备份面自查。**

---

## 4. CoupleKitchen-uniapp —— 实勘：半成品单机点餐 UI

- 定位：uniapp 情侣厨房点餐界面 demo——**实勘不符（功能层面）**：无"双人互动/接单流"，实为单机店内扫码点餐 UI 半成品（api 全 mock、结算弹"待开发"占位图）；MIT 相符｜约 1400 行 Vue
- **Gap 结论**：LoveGirl 厨房模块（真实后端下单流+完整点单 UI）全面领先；对方零服务端贡献。差距提示仅两点：菜品无 SKU 规格、点餐页缺情绪化文案。

- **4.1 菜品 SKU"属性-DNA"规格模型**：`attribute: '[{"份量":"小"},{"口味":"辣"}]'` JSON 数组+值串接键反查 SKU。【厨房·菜品规格】【中】【低（形状照抄，Flutter 重写 UI）】【可移植（模型）】
  - 出处：`pages/home/index.vue` popupSku/selectAttributeValue、`api/categorys.js`
- **4.2 左类目右列表双向联动**：量 top/bottom 区间+滚动反查分类。【厨房点菜页联动】【低】【中】【仅启发】
  - 出处：`pages/home/index.vue` calcCategoryTop/handleFoodsScroll
- **4.3 购物车细节包**：减到 0 自动过滤+收起、清空二次确认、单规格直接 +/- 多规格才弹规格选择。【厨房 _CartBar/_CartSheet 对照】【低】【低】【仅启发】
  - 出处：`pages/home/index.vue` handleReduceNumForCart/clearShoppingCart
- **4.4 情侣文案层（成本≈0）**："公主/王子请点餐"、滚动情话 notice bar、"眼中景 碗中餐 身边人"。【厨房文案/空态】【中】【无】【可移植（纯文案）】
  - 出处：`pages/home/index.vue`、`pages/index/index.vue`、`pages/login/index.vue`

**一行结论：最有价值 = SKU 属性-DNA 规格模型，其次是零成本的情绪文案。**

---

## 5. IMAGDressing（muzishen）—— AAAI 2025 服装可控虚拟试穿（评估，不接码）

- 定位：扩散模型试穿（服装图→生成试穿图；与 LoveGirl 已上线"抠图"是两个任务）｜Python/PyTorch+diffusers｜代码 **Apache-2.0 相符**，但 **README 明示模型权重仅限非商用研究**
- 部署实勘：Gradio WebUI（api_name='IMAGDressing-v1'）/ CLI 5 变体 / ComfyUI 三方节点 / HF ZeroGPU demo（不稳定不可依赖）
- 接口形状：输入=服装图（必填）+人脸图（可选 IP-Adapter）+姿态图（可选 ControlNet）+prompt+6 引导系数+步数 20-50+seed；输出=512×640 RGB；人脸检不到直接报错
- 硬件实勘：fp16 实用 8-12GB 显存；CPU 回退单张按十分钟计——**LoveGirl 2核1.6G 不可行**

- **5.1 接入架构参考：服务器纯 broker + 外部 GPU 端点**【衣橱/换装·未来 AI 试穿延伸】【低（现阶段无需求）】【高】【仅启发】
  - 出处：`app.py`（api_name 暴露面）、`inference_IMAGdressing.py`
  - 未来路径：租时 GPU（AutoDL 4090 约 ¥2/时，30 步单张 5-10 秒）部署 Gradio/薄 FastAPI，服务器只做任务队列+结果转存；个人非商用不触权重红线
- **5.2 输入闸门模式**：固定尺寸归一（512/640/64 对齐）、关键输入存在性前置校验（检不到脸立即失败）、负面 prompt 服务端内置。【通用生成式 API 契约】【低】【低】【仅启发】
- **5.3 后处理换脸开关**：生成与换脸拆成两步开关（基础生成便宜快速，逼真度按需增值）。【低】【中】【仅启发】

**一行结论：自托管不可行；现阶段真实需求（抠衣服）已由 SegmentCloth 解决，本项目存档不接码。**

---

## 6. star_book（hashirshoaeb）—— 极简心情日历

- 定位：GitHub 贡献格风格心情记录+统计｜Flutter+Isar+bloc｜许可证实勘：**MIT 相符**
- 热力图实勘：**完全自绘零日历库**：CustomCalendar（ListView 按年倒序）→ GridView 4 列×12 月卡 → Row 手排日格；日格底色=SweepGradient(该日心情颜色数组)——一天多心情扇形扫掠

- **6.1 SweepGradient"一天多心情"色格**：不丢信息的热力上色。【mood·月历热力视图】【高】【低（纯 BoxDecoration 零新依赖）】【可移植（手法）】
  - 出处：`lib/presentation/screen/calendar/month_days.dart` getDayColors
- **6.2 心情数据模型形状**：`Mood{id,label,color:int}` 独立集合 + Journal 挂链接 + 渲染前聚合 `Map<Day, List<Mood>>`。【mood·数据层/服务器聚合】【高】【低】【可移植（模型）】
  - 出处：`lib/data/models/mood/mood.dart`、`journal.dart`、`mood_info.dart`
  - LoveGirl 对应：服务器 `GROUP BY DATE(created_at)` 一条 SQL 出整月聚合。
- **6.3 年→月→日三层钻取导航**：4×12 月卡年视图→月历→当日记录。【mood/回忆导航结构】【中】【低】【仅启发（结构）】
  - 出处：`custom_calendar.dart`/`calendar_view.dart`/`month_days.dart`（月内补空位 `day = 2 - firstWeekdayOfMonth` 技巧）
- **6.4 心情频次甜甜圈图**：【mood 统计/月报】【低】【低】【仅启发】（图表建议用 fl_chart 替代其 syncfusion，避免授权心智）
- **反面教材**：Date 格子逐格 BlocProvider+FutureBuilder 逐格查库（整月 30 格 30 次异步）——务必一次取整月同步下发。

**可移植文件清单（MIT，需摘依赖）**：`lib/presentation/utils/calendar.dart`（月份天数纯函数）；`mood/day.dart`（dayKey 编解码）；`mood_info.dart`/`mood_frequency.dart`（聚合逻辑约 40 行纯 Dart）。

**一行结论：SweepGradient 多心情色格 + 按日聚合形状——心情模块补"月历热力图"的最短路径，零新依赖。**

---

## 7. map-of-cn-mp（InfFlow）—— 情侣旅行回忆地图

- 定位：中国地图省份热力+足迹连线+照片回忆+AI 叙事小程序+PHP/MySQL 后端｜原生小程序约 8100 行｜许可证实勘：**Apache-2.0 相符，含 NOTICE（移植须保留）**
- 数据模型实勘（`php/schema.reference.sql`）：journeys{city/province/travel_date/season/weather/landmark/经纬度/cover_tone/title/intro}+子表照片/手记/标签 FK CASCADE；API 单端点聚合（IN 占位符批量取子表内存拼装）
- 地图实勘：省份多边形 `php/china-provinces.json`（582KB）+服务端等距抽稀每环 ≤160 点；省份按访问次数四档 alpha 着色；足迹按日期排序墨色虚线 polyline；marker 序号 label+callout；includePoints 自适应视野

- **7.1 省份热力多边形着色（计数→alpha 分阶）**："点亮中国"层。【旅行·高德叠加层】【高】【中（需 GeoJSON+抽稀；高德 polygon 支持带透明度 fillColor）】【可移植（数据+算法）】
  - 出处：`miniprogram/pages/index/index.js` provCount/heatAlpha/polygons 段、`php/provinces.php` downsample
  - LoveGirl travel_spots 已有城市/省份，聚合计数套同一 alpha 阶梯即可实现"已点亮 N/34 省"
- **7.2 足迹连线 polyline**：按 travel_date 排序取坐标连虚线。【旅行地图/票根 tab】【高】【低】【可移植】
  - 出处：同文件 routePoints/polyline 段（dottedLine: true）
- **7.3 "N 年前的今天"回忆弹层**：排除今年、按 MM-DD 匹配历史足迹/照片，命中弹"重看那天"。【首页/照片/旅行（photo_date 已就位）】【高】【低（约 30 行纯日期匹配）】【可移植】
  - 出处：同文件 checkTodayMemory
- **7.4 序号 marker + 半屏预览卡**：点 marker 先看摘要卡再决定进详情。【旅行 marker 交互】【中】【低】【仅启发】
  - 出处：同文件 onMarkerTap/markerPreview；配套定位失败四态文案与教训 16 兜底互补
- **7.5 省市二级联动 REGIONS 全量数据**：34 省→全部地级市映射。【travel_form 手动选城市】【中】【无（数据照搬）】【可移植（数据）】
  - 出处：`miniprogram/utils/regions.js`
- **7.6 成就徽章阈值组 + 数字滚动动画**：三省通行/五省点亮/十省纵横…+easeOutCubic 计数（`_animated` 门控防刷新重播）。【旅行统计/年度报告】【低】【低】【仅启发】

**可移植文件清单（Apache-2.0，保留 NOTICE）**：`php/china-provinces.json`；`php/schema.reference.sql`；`php/provinces.php` downsample 函数；`utils/regions.js`；index.js 的 heatAlpha/parseMD/validCoord/checkTodayMemory 纯函数段。

**一行结论：省份热力+足迹连线+"N 年前的今天"三件套，全部可叠在现有高德与现成数据上，情绪回报最高的一批。**

---

## 8. diaryvault（SankethBK）—— Flutter 多功能日记

- 定位：Quill 富文本/AES 加密/WebDAV 同步/语音附件/生物识别锁日记｜Flutter+sqflite+bloc+get_it（feature-first Clean Architecture）｜许可证实勘：**MIT 相符**（license.md）
- 语音实勘：**音频嵌入富文本**（flutter_sound 录音弹层+StreamBuilder 计时圆环→复制归档唯一文件名→flutter_quill embed 存 Delta JSON；播放 audioplayers）；另有 TTS 朗读
- 应用锁实勘：PIN sha256 存 flutter_secure_storage，验证通过免密恢复会话；指纹 local_auth 四态状态机；成败音效
- 搜索实勘：**sqflite LIKE 方案非 FTS**——保存时 Quill Delta `toPlainText()` 冗余纯文本列；查询 LIKE+日期区间+tags 反查，排除 deleted 与加密笔记

- **8.1 plain_text 冗余列轻量全文搜索**：【照片故事/慢信/心情 memo 文本检索】【高】【低】【可移植】
  - 出处：`lib/features/notes/data/datasources/local data sources/local_data_source.dart` searchNotes（L417-477）；`notes_bloc.dart` L197
  - 情侣级数据量（千条内）不需要 FTS：参数化 LIKE 即可，且"加密内容不可搜"应作为同款硬规则。注意其 WHERE 是字符串插值拼 SQL——反面教材，LoveGirl 一律参数化
- **8.2 PIN+生物识别双层锁与免密会话恢复**：【未来"隐私空间"（惊喜防误看锁定分区）】【中】【中低（local_auth+flutter_secure_storage 两新依赖）】【可移植（结构）】
  - 出处：`pin_auth_repository.dart`、`fingerprint_auth_repo.dart`（四态流）、`auth_session_bloc.dart`
  - 可抄三点：PIN 只存哈希；验证通过按 userId 恢复会话（情侣双账号尤其顺）；指纹失败四态分明
- **8.3 音频嵌入富文本的语音便签**：【照片故事 sheet/慢信·语音附件】【中】【中（未引入 quill 则退化为附件列表+播放器，更贴现有 UI）】【仅启发/可移植】
  - 出处：`audio_recorder_popup.dart`（几乎可直接搬）、`rich_text_editor.dart` _onAudioPickCallback
- **8.4 TTS 朗读笔记**：【慢信解锁日"读给你听"】【中】【低（flutter_tts+约 50 行）】【可移植】
  - 出处：`note_read_button.dart`
- **8.5 加密笔记安全细节**：解密缓存只驻内存、上锁即清空、加密内容排除搜索。【低】【—】【仅启发】

**可移植文件清单（MIT，按文件摘抄）**：`audio_recorder_popup.dart`；`pin_auth_repository.dart`+`fingerprint_auth_repo.dart`（替换其会话仓库）；`note_read_button.dart`；`search_highlight_color.dart`。

**一行结论：plain_text 冗余列+参数化 LIKE 的轻量全文搜索——各文本模块立刻可用，"加密内容不可搜"作同款硬规则。**

---

## 9. moodiary（ZhuJHua）—— 全功能日记【AGPL-3.0，仅启发】

- 定位：Flutter+Rust 本地日记（时间线/月历/关系图谱/全文+语义搜索/多媒体/端到端加密）｜模块化 monorepo（packages 三层约 599 个手写 dart，Rust 负责图片/分词/加密/图布局）｜许可证实勘：**AGPL-3.0 相符**

- **9.1 词数热力图"分位数定级"**：全量词数排序取 p25/p50/p75 四分位切四档；样本 <8 天退化为篇数定级——冷启动不难看。【心情可视化/月报】【高】【仅启发】
  - 思路：强度维度换成心情分值或当日心情条数，自适应分档渲染月历；纯客户端聚合。
- **9.2 时间线心情连线**：条目左侧心情色圆点，相邻条目间竖线在"上一条心情色→下一条心情色"间渐变——列表变情绪曲线。【心情记录列表】【高】【仅启发】
  - 思路：把"下一条的心情色"传给当前项，画两端渐变细线，无图表库；约半天的纯 UI 改造。
- **9.3 SQLite FTS5+bm25 全文搜索**：三触发器同步主表、标题权重 1.5/正文 1.0、highlight/snippet、搜索历史上限 12 条。【全 App 搜索】【中】【仅启发】
  - 思路：LoveGirl 在 MySQL 侧——全文索引或 LIKE+标题加权排序、服务端返回摘要切片、App 防抖+历史。
- **9.4 日历格"照片封面化"**：月历每格=当天首条日记首图铺满，纯文字日显标题预览，同日多篇加角标。【相册/心情月历】【中】【仅启发】
  - 思路：日历=时间维度相册封面墙；LoveGirl 已有 photo_date（v3.40 补齐），"情侣共同月历"数据基础齐了。

**一行结论：用"相邻条目心情色渐变连线"把心情列表零成本升级成情绪曲线，配合分位数定级热力月历进月报。**

---

## 10. Daily_You（Demizo）—— 每日一图日记【GPL-3.0，仅启发】

- 定位：每日一图+文字日记，强项 5 档心情刻度之上的统计图表与"每日回忆闪回"｜sqflite+provider，213 个 dart 文件扁平分包，可读性最好｜许可证实勘：**GPL-3.0 相符**（LICENSE.txt）

- **10.1 统计页"主体参数化"（StatsSubject）**：统计页抽象为密封类型（主体=心情/标签/数值追踪标签），趋势折线+按星期均值+分布对三类主体复用。【心情可视化/月报】【高】【仅启发】
  - 思路：图表抽象成"接收 (日期,数值) 点列+分桶策略+y 轴策略"的通用组件——同一张图可画心情/见面次数/打卡等未来指标，与月报统计图共用。
- **10.2 日期作种子的"每日闪回"**：回忆卡分时间型（N 年前今天/6 个月前/1 周）与随机型（好心情池抽/随机一天）；随机用"当天日期字符串做种子"并缓存选中 id——同一天稳定不跳变，第二天才换；可排除坏心情条目。【首页/回忆（情侣版"那年今天"）】【高】【仅启发】
  - 思路：确定性随机+偏好缓存，几十行纯函数；双人相册+心情+票根都是回忆池。
- **10.3 连击统计带"距上次坏日子 X 天"**：逆序遍历按日去重计数。【心情统计/月报】【中】【仅启发】
  - 思路：情侣场景可变双向关怀指标（"TA 已开心 X 天"）。
- **10.4 标签当追踪器**：标签可携带数值（如睡眠时长）画折线=免费习惯追踪。【心情记录扩展】【中】【仅启发】

**一行结论：日期作种子的确定性"每日闪回"——最小代码把相册/心情/票根变成每天一条的情侣回忆推送。**

---

## 11. storypad（theachoem）—— 年份路径富文本日记【GPL-3.0，仅启发】

- 定位：以年份为路径组织内容的多页富文本日记（Quill Delta），日历心情格/月度回顾块/草稿正文分离，ObjectBox｜约 774 个手写 dart，MVVM｜许可证实勘：**GPL-3.0 相符**

- **11.1 时间线内嵌"月度回顾块"**：每月故事间插"本月回顾"瓦片：写了 N 篇/媒体各几条/"覆盖 X/Y 天"；进行中月份用已过天数当分母、故事 <5 篇不显示、零值项不渲染。【月度小报·补"覆盖天数"维度】【高】【仅启发】
  - 思路：纯数据类承载"原始计数+呈现规则"：分母按是否完结切换、阈值门控显隐、零值跳过——呈现规则整套照抄为产品规则。
- **11.2 日历格心情表情轮播+点日即筛**：每格显示当天心情 emoji，多心情自动轮播（ValueNotifier 按奇偶日分组定时换）；点某天，下方列表立即只看这天——日历即筛选器。【心情月历（核心形态候选）】【高】【仅启发】
  - 思路：`Map<日, List<心情>>` 按月聚合+日历格 builder+换 filter 重建列表。
- **11.3 草稿与正文分离**：draftContent/latestContent 两份，列表取最新正文，草稿存在与否是列表状态标记。【慢信（未写完态）】【中】【仅启发】
  - 思路：同表两列+"有草稿"派生布尔，比草稿表轻。
- **11.4 三态路径+30 天倒计时回收站**：正式/归档/回收站枚举+时间戳+"X 天后自动清除"派生 getter。【衣橱软删/相册删除体验】【低】【仅启发】

**一行结论：时间线按月内嵌"覆盖 X/Y 天"回顾块（含进行中月份与零值不显示规则），是月度小报最自然的下一个统计维度。**

---

## 弹药库总表（按模块聚合）

### 心情（可视化=当前最大缺口）
| 条目 | 出处 | 优先级 |
|---|---|---|
| SweepGradient 多心情色格月历（点日下钻） | 6.1/11.2 | 高 |
| 时间线心情色渐变连线 | 9.2 | 高 |
| 分位数自适应定级热力 | 9.1 | 高 |
| 月度回顾块"覆盖 X/Y 天" | 11.1 | 高 |
| 通用 (日期,数值) 折线抽象 | 10.1 | 高 |
| "距上次坏日子 X 天"关怀指标 | 10.3 | 中 |
| 心情频次甜甜圈（fl_chart 实现） | 6.4 | 低 |

### 旅行
| 条目 | 出处 | 优先级 |
|---|---|---|
| 足迹连线 polyline（按日期串虚线） | 7.2 | 高 |
| "N 年前的今天"回忆弹层 | 7.3 | 高 |
| 省份热力 alpha 分阶（点亮中国） | 7.1 | 高（需 GeoJSON） |
| 序号 marker+半屏预览卡 | 7.4 | 中 |
| 省市二级联动数据 | 7.5 | 中 |
| 成就徽章阈值组+数字滚动 | 7.6 | 低 |

### 衣橱
| 条目 | 出处 | 优先级 |
|---|---|---|
| 生成式去人留衣 A/B 评测（对照 SegmentCloth） | 1.1 | 高 |
| chroma 后处理+污染校验+兜底编辑器 | 1.2 | 高 |
| 三段式人审批量建档状态机 | 1.3 | 高 |
| 分桶主色提取+点图取样 | 1.4 | 中 |
| 内容哈希幂等导入 | 1.5 | 中 |
| AI 搭配选型原则（prompt 化） | 1.6 | 低 |
| 菜品 SKU 属性-DNA 模型（厨房通用） | 4.1 | 中 |
| AI 试穿 broker 架构（远期存档） | 5.1 | 低 |

### 首页/回忆
| 条目 | 出处 | 优先级 |
|---|---|---|
| 日期作种子"每日闪回"（确定性回忆卡） | 10.2 | 高 |
| 日历格照片封面化月历 | 9.4 | 中 |
| 心情表情轮播+点日即筛 | 11.2 | 高 |
| 成就徽章+数字滚动 | 7.6 | 低 |

### 兑换券/爱心豆
| 条目 | 出处 | 优先级 |
|---|---|---|
| 五段闭环玩法（任务赚豆→商城→仓库→使用不可逆） | 2.2 | 高 |
| 服务端事务+四要素流水（反面教材反推） | 2.5 | 高 |
| 原子增量记账 | 2.3 | 中 |
| 预设模板一键建档+左滑三键 | 2.4 | 中 |

### 服务端/工程
| 条目 | 出处 | 优先级 |
|---|---|---|
| plain_text 冗余列轻量搜索 | 8.1 | 高 |
| FTS/bm25 形态（MySQL 侧化用） | 9.3 | 中 |
| PIN+生物识别隐私空间结构 | 8.2 | 中 |
| TTS 朗读（慢信解锁日） | 8.4 | 中 |
| 三态路径+倒计时回收站 | 11.4 | 低 |
| 生成式 API 输入闸门契约 | 5.2 | 低 |
| uploads 备份面自查 | 3 | 中 |

### 小程序版衣橱
| 条目 | 出处 | 优先级 |
|---|---|---|
| openid 即身份骨架（勿硬编码） | 2.1 | 高 |
| 预设模板建档+weui 左滑三键 | 2.4 | 中 |
| 主色提取+点图取样 | 1.4 | 中 |
| 情侣文案层 | 4.4 | 中 |

---

## 待拍板清单（本轮不实施）
1. **SegmentCloth vs 生成式去人留衣 A/B 评测**（1.1/1.2）——等阿里云钥匙激活后用真图评测；生成式 prompt/色键纯函数可直接搬
2. **衣橱批量建档状态机**（1.3，需新表 wardrobe_import_jobs）
3. **省份热力"点亮中国"**（7.1，需引入省份 GeoJSON 数据文件 582KB）
4. **AI 试穿 broker**（5.1，需外部 GPU 租时+权重非商用评估）
5. **隐私空间 PIN/生物识别**（8.2，两新依赖）
6. **兑换券双向经济闭环**（2.2/2.5，需服务端事务+流水表）
