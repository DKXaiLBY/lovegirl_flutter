# 电子衣柜 M2 施工方案（换装版："电子衣娃"）

版本：v1.1（2026-09-27 对抗审查修订：3 P0 + 9 P1 全闭合——抠图改"探针硬闸"定标、avatars 补 cutout、outfits 路由适配换装）
上游：docs/wardrobe-prd.md v2.0 + docs/wardrobe-interaction.md v1.0（§9 M2 增补）
方向依据：用户确认"数字人格+拍照抠图+过家家换装"；三案例研究（MIROIR 流程/WOO 拆衣/阿Fi不在钻取）
纪律：探针硬闸未过不写换装代码；每批次 analyze 0 + 现有断言全数回归 + 独立 commit push；**发版由用户逐次确认**

---

## 0. 范围与关键决策

### M2a 范围
1. 人像抠图先行：形象管理（上传/人像分割/设默认/删除）——API 已核实存在（腾讯云 bda SegmentPortraitPic）
2. 衣服抠图：**探针硬闸定标后实施**（见 S0）
3. 换装白板：槽位叠加/拖缩/位置记忆/一键合成保存（source=换装）
4. 换装穿搭进时间线/详情；存量单品补抠入口

### M2b（后续，本轮不做）
三层钻取浏览、AI 拆多件、穿搭人格卡、卡通兜底形象、抠图精修编辑、细节多图、月历、TA 视角

### 关键决策

**决策 1：抠图走云 API 分两个能力位，衣服抠图先探针后定标（修订 v1.1）**
- **人像分割（形象照）**：腾讯云人体分析 `SegmentPortraitPic`（bda.tencentcloudapi.com, 2020-03-24）**已核实存在**，返回透明图无需掩码合成；输入 base64≤5M、分辨率<2000×2000、**不支持 WEBP**（App 压缩产物固定 jpeg）。后付费约 0.1 元/次、每月 1000 次免费额度（以控制台实测为准）。
- **衣服抠图（物体/商品）**：~~腾讯云 tiia SegmentImage~~ **经核实不存在**（tiia 图像分析无任何分割接口）。候选路线（S0 探针硬闸实测定标）：
  - A. 腾讯云数据万象 CI `AIPicMatting`：质量好，但**强制依赖 COS 存储桶**（需开 COS+迁移上传链路或临时上传，架构级变更）
  - B. 阿里云视觉智能 `SegmentCommonImage`：支持 base64 直传、通用物体抠图，需阿里云账号+密钥
  - C. 端侧 u2netp（~4.5MB ONNX 内置 App）：零外部依赖零单张成本，但需引入 flutter onnxruntime 插件+预处理管线，工程量与机型兼容性风险最高
  - 定标标准：衣服平铺白底图抠图质量（边缘/镂空）+ 单价 + 接入成本；**探针结果与开通成本报用户拍板后再实施**。定标前换装白板**不施工**（依赖衣服抠图），人像/形象管理先行。
- **降级链路（写死）**：衣服抠图能力不可用 → 换装白板整体隐藏（/bg-status 能力位驱动），人像/形象管理不受影响。
- **计费口径修正（审查 P1-8）**：人像约 0.1 元/次+1000 次/月免费额度；衣服抠图单价以探针实测为准——"月成本可忽略"原表述作废，改为"探针后按预估月用量（≤3000 张）×单价 给出月成本数字报用户"。

**决策 2：换装=图层合成，不做姿势匹配/AI 生成**
- 合身感靠"槽位预设锚点+拖缩+位置记忆"；**位置记忆收敛承诺：同形象对位**（item_layout 按 件+形象 二级存），换形象回落该类别预设锚点（按形象记忆 M2b 再议）
- 形象照 M2a **建议全身照**（半身照会让类别锚点整体失准，P12 引导文案注明）

**决策 3：导出合成图固定白底 JPEG**（审查 P1-9）
- toImage 导出深浅两态底色不同的问题：白板画布底色**固定白**（不随主题），导出 JPEG q90（无透明需求，避开 10MB PNG 风险）；toImage 前必须等画布内网络图（形象/cutout）全部拍齐

---

## 1. 服务器侧（批次 S0→S2，先行部署）

### S0 抠图探针（硬闸，任何抠图代码前执行）
1. 人像分割探针：开通人体分析 → 探针脚本（node，bda SDK 子包）实测 SegmentPortraitPic：样张 3 张（全身照×2+半身照×1）记录质量/耗时/单价
2. 衣服抠图探针：按候选 A（需开 COS）/B（需阿里云账号）/C（端侧）逐个实测或评估——**A/B 需要用户开通对应云服务，探针报告含开通成本，交用户拍板**
3. 探针产出：路线定标报告（质量截图+单价表+接入工作量）→ 用户确认 → S2 按定标实现

### S1 表结构与迁移（wardrobe_m2_tables.sql，UTF-8 文件 docker cp）
```sql
ALTER TABLE wardrobe_outfits
  MODIFY source ENUM('实拍','组合','换装') NOT NULL;  -- ENUM 尾部追加，小表瞬时

ALTER TABLE wardrobe_items
  ADD COLUMN bg_removed TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN cutout_url VARCHAR(500) DEFAULT NULL,
  ADD COLUMN item_layout JSON DEFAULT NULL;  -- {"<avatarId>":{nx,ny,scale}} 按件+形象

CREATE TABLE IF NOT EXISTS wardrobe_avatars (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  image_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500) DEFAULT NULL,
  cutout_url VARCHAR(500) DEFAULT NULL,     -- 人像抠图结果（审查 P0-2）
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_deleted (user_id, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### S2 路由增量（routes/wardrobe.js，全部遵循内联 SQL+参数数组+固定 8 占位符惯例）
1. **outfits 路由适配 source='换装'（审查 P0-3）**：
   - POST：白名单加'换装'；日期闸：换装同组合（≤今天+90）；photo 必填（合成图）；件数闸换装 1~8（单件连衣裙合法）
   - PUT：换图分支对 source IN ('实拍','换装') 放行；日期闸同 POST
   - 保存流程：换装 photo_url=合成图，status 默认待确认（组合语义），计数同口径
2. **GET 增列（审查 P1-2）**：GET /items 与 /items/:id SELECT 补 `bg_removed, cutout_url, item_layout`；App 端 _asInt/_asDouble 健壮解析（教训 18）
3. **换图失效链（审查 P1-3）**：PUT /items/:id 换图时同事务置 `bg_removed=0, cutout_url=NULL, item_layout=NULL` 并 removeFilesQuiet 旧 cutout 文件；DELETE /items 清理 cutout 文件；avatars 软删同理
4. **抠图代理**：`POST /api/wardrobe/bg-remove`（升级 M1 占位）：multipart image + `kind=person|object`
   - kind=person：bda SegmentPortraitPic（base64 直传）
   - kind=object：按 S0 定标实现（AIPicMatting+COS / 阿里云 / 未定标前返回 503 "衣服抠图服务未就绪"）
   - 开关：env `WARDROBE_CUTOUT_ON=1`（统一命名，替代 M1 的 WARDROBE_BG_ON，审查 P1-5）；`GET /bg-status` 返回结构化能力位 `{enabled, person, object}`（object 位由定标结果驱动）
   - 护栏：单飞队列 1 并发、超时 15s、每用户每日 50 次（内存计数，重启清零可接受——审查 P2-1）、计费人工看账单
   - SDK：按产品子包引入（`tencentcloud-sdk-nodejs-bda` 等，避免全量包，审查 P2-3）；密钥服务器 .env（SecretId/Key），日志/错误消息脱敏
5. **avatars CRUD**：GET /avatars、POST /avatars（multipart，可选同请求完成人像抠图）、PATCH /avatars/:id/default（事务内先清后设）、DELETE（软删+清文件）、PUT /avatars/:id/cutout（审查 P0-2）
6. **items/:id/cutout**：PUT 保存 cutout_url/bg_removed/item_layout（App 端抠图完成后回写）

---

## 2. App 侧（批次 A1→A4）

### A1 形象管理（P12）
- 入口：穿搭段「+」菜单列举项"我的数字形象"（不写序号，审查 P2-4）；换装白板无形象时中央引导
- 添加：拍照/相册 → **保持原比例仅压缩 1600 jpeg**（统一口径，审查 P2-2；引导文案建议全身照）→ POST /avatars → 自动 person 抠图 → 失败 toast 可重试
- 列表：默认角标/设默认/删除（二次确认）；换装白板底图优先默认形象，**无默认回退最新一张**（审查 P2-8）
- models 加 WardrobeAvatar（fromJson 健壮解析）；provider avatars 动作

### A2 衣服抠图接入（含存量补抠，审查 P1-6）
- P2/P4 保存成功后：/bg-status.object=true 时自动调 bg-remove(kind=object) → 回写 items/:id/cutout；失败静默保留原图
- **P3 详情加"生成抠图/重新抠图"入口**：存量单品与抠图失败件的补抠路径（M2a 范围；"精修编辑"仍 M2b）
- App 端 bg-status 解析结构化能力位（enabled/person/object）

### A3 换装白板（P13，核心）
- 入口：穿搭段「+」→"换装试穿"；组合详情"在形象上试穿"（preselect 含无 cutout 件时裁掉并 toast，审查 P2-7）
- **能力闸**：/bg-status.object=false → 白板入口隐藏（降级链路）
- 画布：白底固定（不随主题，审查 P1-9），逻辑尺寸 ≤1080 宽；形象底图 fit 画布
- 图层 z 序：形象 < 下装(裤/裙) < 上装/连体 < 外套 < 鞋/包/配饰
- **槽位互斥矩阵（三文档统一口径，审查 P1-7）**：
  | 槽位 | 冲突规则 |
  |---|---|
  | 上身 | 上装 与 连体装 互斥（连体=上+下合一，同时清除下装） |
  | 下身 | 裤装 与 裙装 互斥；与连体装互斥 |
  | 外套 | 与一切共存 |
  | 鞋/包 | 各 1 件 |
  | 配饰 | ≤3 件 |
- 交互（按审查 P2-9 简化）：**onScaleStart/Update/End 单回调**统一处理拖动+双指缩放（选中图层才有手势）；M2a 砍掉画布平移（画布恒 fit）
- 位置记忆：item_layout 按 `{avatarId:{nx,ny,scale}}`；首次按类别预设锚点（上装 0.5,0.32 / 裤 0.5,0.62 / 裙 0.5,0.55 / 外套 0.5,0.30 / 鞋 0.5,0.88 / 包 0.72,0.55 / 配饰 0.5,0.12，scale=衣服宽/画布宽 0.55）；**换形象回落预设锚点**（同形象才对位）
- 合成保存：**等画布内全部网络图加载完成**（loading 态，审查 P1-4）→ RepaintBoundary.toImage(pixelRatio 按画布宽≤2160px 预算) → **JPEG q90 白底** → createOutfit(source='换装', wornDate 默认今天可改未来≤+90, itemIds, filePath) → 状态=待确认 → 回 P7

### A4 时间线/详情适配
- source=换装：复用 src_combo 来源角标（专属标 M2b）；P7 封面/P9 大图用合成图；P9 关联单品同组合渲染
- wear_count 语义：换装通过计"搭过"与组合同口径（决策记录承认妥协，审查 P2-5；P3 文案按来源区分 M2b）

---

## 3. 测试与发布

- 单测：item_layout 按 avatarId 的存取与回落、槽位互斥矩阵、合成参数组装、Avatar fromJson；现有断言全数回归（审查 P2-6）
- 服务器 smoke：bg-remove 能力位/限流/密钥缺失降级；avatars CRUD+默认唯一性；source='换装' 全链路（POST 闸/PUT 换图/状态流转计数/删除回退）；换图后 cutout 失效链
- 深浅两态：换装白板与导出图（白底固定不受主题影响）、全模块走查（发布红线，审查 P1-9）
- 发布：用户逐次确认；app_versions 修正流程见本地记忆 lovegirl-deploy-protocol

## 4. 风险清单

| # | 风险 | 对策 |
|---|---|---|
| R1 | 衣服抠图三条候选均不理想（质量/成本/开通门槛） | S0 探针硬闸：实测数据交用户拍板；未定标前白板不施工，人像/形象先行 |
| R2 | 密钥泄漏 | .env 不入库；日志脱敏；错误不回显内部 |
| R3 | 抠图质量差（发丝/镂空） | "重试一次"+保留原图可跳过；质量不满意不强制 |
| R4 | 白板手势复杂度 | 单回调拖+缩；砍画布平移；不做旋转/手动层级 |
| R5 | 合成内存 | 画布 ≤1080 逻辑宽 + pixelRatio 像素预算 ≤2160px；JPEG 导出 |
| R6 | ENUM ALTER 锁表 | 个人级小表瞬时完成 |
| R7 | 云 API 限流/超时拖垮主接口 | 单飞队列+1 并发+15s 超时+每日 50 次/用户 |
| R8 | 网络图未加载完成即合成（白图/缺层） | 保存前 loading 等待 precacheImage 全部完成（审查 P1-4） |
| R9 | 换形象对位失真 | 位置记忆收敛"同形象对位"，换形象回落预设锚点；按形象精调 M2b |

## 5. 用户配合点（探针阶段）
- 腾讯云：开通"人体分析"（人像分割，有免费额度）——形象管理先行必须
- 衣服抠图定标三选一：A 开 COS（腾讯云）/ B 开阿里云账号 / C 端侧方案（无需开通但工期+风险）——探针报告出来后拍板

## 6. 不做清单（防蔓延）
AI 试穿生成（VTON）、真 3D/伪 3D 展示、旋转/手动层级排序、换装模板/贴纸商城、卡通形象生成（M2b 静态兜底）、推荐/电商、按形象精调布局（M2b）。
