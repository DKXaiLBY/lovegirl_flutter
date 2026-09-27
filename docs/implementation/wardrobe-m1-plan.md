# 电子衣柜 M1 施工方案

版本：v1.1（2026-09-27 对抗审查修复：3 P0 + 6 P1 + 10 P2 全闭合）
上游：docs/wardrobe-prd.md v1.0 + docs/wardrobe-interaction.md v1.0（§1 M1/M2 标注、§7 决策索引为唯一口径）
目标版本：v3.35.0+165（App）；服务器侧独立先行部署
纪律：本方案过对抗审查后才允许写代码；每批次 flutter analyze 0 问题 + test 全绿 + 独立 commit push

---

## 0. 范围与前置闸

### M1 范围（按交互文档标注）
P1 主页网格 / P2 添加单品流（含抠图+降级闸）/ P3 单品详情 / P4 编辑 / P5 组合搭配创建 / P6 实拍记录 / P7 穿搭时间线 / P9 穿搭详情 / P10 筛选面板+「今天」胶囊 / 多选（加入搭配·退役·删除）/ 单品两态（在柜·退役）/ 软删 / 穿着计数

### 明确不做（M2+，防蔓延）
P8 月历、P11 TA 视角（含 TA 胶囊）、在洗/收纳状态、细节多图、平铺视图、统计/闲置提醒、天气联动推荐、情侣装、购买渠道

### 前置闸（不阻塞开发，阻塞发布）
- **G1 素材**：illus_empty_wardrobe / illus_empty_outfit（豆包按 asset-prompts.md 第 34/35 条生成→转透明→1600px 入库 illus/）；icon_wardrobe 入口图标 + 角标 PNG（待确认橙点/已通过绿勾/**计划蓝钟**/实拍标/组合标/退役标，走 tools/generate_assets.py）。**开发期用现有插画占位，发布前必须替换**
- **G2 抠图实测**：三段闸 = 容器内安装+require 加载（musl 风险前置，**硬闸**）→ 3 张样图 benchmark（**硬闸**）→ 推理窗口主接口 P95 记录（记录+人工评估，无硬阈值）；前两段任一不过 → 服务端开关保持关，App 端隐藏抠图步骤（交互结构不变，降级闸兜底）

---

## 1. 服务器侧（批次 S1→S3，可独立先行部署）

### S1 基建
1. **live 快照 diff（教训 9）**：先从 live 拉当前代码快照与 server_fixes/ 对账，以 live 为基底做外科手术；改完回写 server_fixes/
2. **DB 迁移**：`wardrobe_tables.sql`（UTF-8 文件 scp → docker cp 进 lovegirl-mysql → 容器内执行，历史坑：Windows shell 发中文 GBK 乱码）：

```sql
CREATE TABLE wardrobe_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  image_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500) DEFAULT NULL,
  category VARCHAR(20) NOT NULL,          -- 8 类白名单由应用层校验
  temperature VARCHAR(10) DEFAULT NULL,   -- 四档白名单
  occasions JSON DEFAULT NULL,            -- 服务器实测 MySQL 8.0.46，JSON 可用
  styles JSON DEFAULT NULL,
  extra_images JSON DEFAULT NULL,         -- M2 细节多图启用，M1 不写
  color VARCHAR(20) DEFAULT NULL,
  brand VARCHAR(60) DEFAULT NULL,
  price DECIMAL(10,2) DEFAULT NULL,
  status ENUM('在柜','退役') NOT NULL DEFAULT '在柜',
  favorite TINYINT(1) NOT NULL DEFAULT 0, -- 预留无 UI
  wear_count INT NOT NULL DEFAULT 0,
  deleted_at DATETIME DEFAULT NULL,       -- 软删
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_deleted (user_id, deleted_at),
  INDEX idx_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE wardrobe_outfits (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  worn_date DATE NOT NULL,
  source ENUM('实拍','组合') NOT NULL,
  photo_url VARCHAR(500) DEFAULT NULL,    -- 实拍
  item_ids JSON DEFAULT NULL,             -- 实拍关联与组合均存
  status ENUM('待确认','已通过') NOT NULL DEFAULT '待确认',
  note VARCHAR(300) DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_date (user_id, worn_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

3. **图片上传**：复用 photos 的 multer + sharp 缩略图模式；新目录 `uploads/wardrobe/`（入 gitignore，同 uploads）；抠图产物存 webp alpha（1600px）+ 缩略 400px

### S2 业务路由（新文件 routes/wardrobe.js，app.js 挂载 /api/wardrobe）
- `GET /items`：本人全量（含 deleted_at IS NULL 过滤），App 端筛选分组（个人级数据量，不做服务端 JSON 筛选）
- `POST /items`：multipart（image 必填 + 字段）；校验 category 必填∈8 类、temperature∈4 档、occasions/styles/color∈枚举白名单、品牌≤20 字、价格≥0 两位小数；生成缩略图
- `PUT /items/:id`：编辑/换图（换图重走缩略图+可选抠图；旧图文件事务提交后清理）
- `PATCH /items/:id/status`：在柜⇄退役（两态）
- `GET /items/:id`：详情 + `outfit_refs_count`（供删除弹窗"影响 N 条搭配"）
- `DELETE /items/:id`：**软删**（UPDATE deleted_at=NOW()）；图片文件删除放**事务提交后**执行（失败仅记日志，不影响软删生效）
- `GET /outfits`：本人全量；**item_ids 由服务端解析为条目摘要数组**（id/category/brand/thumbnail_url），已删条目返回 `{deleted:true, category}`——P7/P9 灰占位"已删除·{类型}"的数据来源；P3 关联穿搭列表由客户端按 item_ids 反查推导，不加接口
- `POST /outfits`：组合（item_ids 2~8、均属本人、未软删**且 status='在柜'**、worn_date 2000-01-01~今天+90）｜实拍（photo 必填、worn_date 2000-01-01~今天）；默认状态：组合=待确认、实拍=已通过（实拍保存时若带 item_ids，同事务对关联单品 wear_count+1）；备注≤200 字；上传 fileFilter 拒绝一律返 **400**（勿复制现网 500 旧病）
- `PUT /outfits/:id`：编辑日期/备注/关联单品（新增件同样校验在柜）/换图（实拍，旧图文件事务提交后清理）；item_ids 差量变化时按差量条件更新 wear_count（仅对已通过记录生效）
- `PATCH /outfits/:id/status`：**条件更新** `UPDATE ... SET status=? WHERE id=? AND user_id=? AND status=?`（旧值），affected=0 → 409；同一事务内：进入已通过 → 关联单品 wear_count+1，离开已通过 → -1（`WHERE id IN(...) AND deleted_at IS NULL`）
- `DELETE /outfits/:id`：若已通过，同事务 wear_count-1
- 鉴权：全部 requireAuth + user_id 隔离；**M1 不开 TA 授权**（P11 是 M2）
- **smoke 验证清单（发布闸执行）**：curl 序列覆盖四条计数路径（实拍+1 / PATCH 条件更新 ±1 / PUT 差量 / DELETE -1）+ 重复提交幂等，每步后 SQL 断言 wear_count 期望值，结果记入施工记录
- 部署：预先写好部署 sh 脚本走 scp（Mimosa 拦截规避，先例 deploy_travel_photos.sh）→ docker restart lovegirl-server → 服务器 git commit（写成脚本执行）

### S3 抠图（独立可关，最后接入）
1. 技术路线：**onnxruntime-node + u2net.onnx**（纯 Node）。**开工前先验证**：服务器容器为 node:18-alpine（musl），而 onnxruntime-node 预编译二进制是 glibc——先在容器内 `npm install onnxruntime-node` + require 加载验证；**失败即改侧车路线**（独立 glibc 容器跑推理服务、主容器 HTTP 调用，或 rembg Python 容器），不留到 G2 才发现。模型文件 ~170MB 放 `/opt/love-girl/models/`，**不进 git**
2. `POST /api/wardrobe/bg-remove`：输入原图 → 输出 1600px webp alpha URL；**单飞队列**（同一时间仅 1 个推理任务，其余排队/拒绝）
3. **降级闸**：env `WARDROBE_BG_ON` 总开关 + 运行时进程级降级（OOM 或连续失败 3 次 → 置降级标记，仅压缩返回原图；人工或定时恢复）
4. **G2 实测**：部署后跑 3 张样图记录耗时/内存；超时阈值按实测定（建议 15-30 秒），实测不过 → 开关保持关、App 隐藏抠图步骤
5. 内存与 CPU 护栏：推理前检查 available 内存（实测仅 ~871MB），低于阈值直接返回降级；限核运行（taskset/renice）防推理占满 2 核拖垮聊天/上传主接口
6. 孤儿清理：抠图任务带归属（user_id/item_id），DELETE /items 与流程中断时回收临时文件与队列残留任务

---

## 2. App 侧（批次 A1→A5）

### A1 模块骨架
- 生活 tab 入口：按 life_screen.dart 实况（标题卡 + TabController 4 子页签）**新增第 5 子页签「衣橱」**（PRD §8 授权按空间定形态）；改 TabController length 时评估现有 4 子页状态保活影响
- `wardrobe_module_screen`：全屏页 + 顶部分段「衣橱｜穿搭」（复用 lovegirl_ui 风格自绘，不引第三方）+ 右上「+」按分段弹二选一 bottom sheet；PopScope：根页返回=回生活 tab，二级页左上角页内返回钮（教训 6）
- models（WardrobeItem/WardrobeOutfit + json 解析）、wardrobe_api（dio 复用现有 token 注入）、`wardrobe_provider`（items/outfits/筛选状态；筛选会话内保留，退出模块重置）
- 空态：EmptyState + IllusImg 占位（现有插画）

### A2 衣橱线
- P2 添加流：image_picker（已有）→ **新增 image_cropper**（1:1 裁剪）→ **新增 flutter_image_compress**（长边 1600）→ 上传 →（抠图步骤，S3 就绪前隐藏）→ 表单（类型必填+记忆上次选择存 shared_preferences；状态字段不出现）→ 保存回 P1 滚动定位
- P1 网格：8 类分组、空节隐藏、节内添加时间倒序；筛选按钮 → P10；今天胶囊（复用 /api/weather 同接口重拉，失败隐藏）
- P3 详情（底部「加入搭配」→ P5 预选、退役置灰 /「标记为」）+ 关联穿搭列表（客户端按 outfits.item_ids 推导）/ P4 编辑（换图重走裁剪；删除红字+引用数弹窗）
- 状态：退役（P3「标记为」/多选），退役不进默认网格（筛选器可勾选查看）、加入搭配置灰

### A3 穿搭线
- P5 组合创建：选件面板（在柜全量，按类型分节）+ 底部托盘（≤8）+ ≥2 校验 + 日期（默认今天，未来=计划，≤今天+90）+ 备注
- P6 实拍：拍照/选图（原比例）+ 日期上限今天 + 可选关联单品（仅"在柜"）→ 保存即已通过 → 回 P7 置顶
- P7 时间线：计划中（未来，日期升序）/今天/昨天/本周更早/更早分组；来源标+状态标 PNG；长按菜单按状态裁剪；「+」二选一
- P9 详情：通过/改回待确认/继续编辑/删除（二次确认）；已删除单品灰占位不可点

### A4 筛选与多选
- P10 半屏面板：温度/类型/场合/风格/颜色/**状态（仅在柜/退役两态，M1 就有——退役单品靠它可见）**；条件胶囊可单删；0 结果+清除筛选
- 多选：跨类型分组；加入搭配（选区含退役置灰；超 8 件保存置灰提示）/退役/删除；系统返回键先退多选

### A5 收尾
- 抠图步骤接入（默认开可跳过、失败 toast 保留原图、重抠）
- 素材替换（G1）：空态插画、icon_wardrobe、角标 PNG
- 深色模式全页过一遍（发布红线）；图片全部走 thumbnail_url + cached_network_image

---

## 3. 测试与发布

- **单测**：现有 21 断言不回退；新增 wardrobe model 解析、状态机计数差量单测、P1 分组/筛选逻辑单测
- **走查**：模拟器全流程（衣柜无原生地图依赖，x86 可验）；真机深浅两色
- **发布顺序**：S1/S2 服务器先上（新增路由零破坏）→ G2 实测 → App `flutter build apk --release` → POST `/api/deploy/publish`（header x-deploy-token 现取，勿入库）→ **修 app_versions 表 version_name/changelog**（UTF-8 SQL 文件 docker cp，CHAR(10) 换行）
- **回滚点**：每批次独立 commit push；服务器 wardrobe.js 独立文件，app.js 摘挂载即可秒级下线；DB 新表不影响存量

## 4. 风险清单

| # | 风险 | 对策 |
|---|---|---|
| R1 | U2Net 内存（总 1.6G / available ~871MB）或 musl 加载失败 | S3 开工前容器加载验证 + G2 三段实测闸 + 降级：开关关=功能隐藏，交互结构不变 |
| R2 | image_cropper/flutter_image_compress 老设备兼容 | 选维护活跃插件；荣耀 Android 10（uCrop）+ 720×1600 测试机真机回归 |
| R3 | ~~MySQL<5.7 无 JSON 类型~~ 已排除 | 实测 MySQL 8.0.46，JSON 列无兼容问题 |
| R4 | uploads 磁盘增长 | webp 压缩（~100-300KB/张）+缩略图；上线后关注 df |
| R5 | 生活 tab 放不下第五入口 | PRD §8 已授权按空间定形态（入口卡/子页签） |
| R6 | wear_count 并发双击 | 条件更新+事务+affected 行数校验（S2 已定） |
| R7 | 推理占满 2 核拖垮全服（同机跑全部业务） | 限核/错峰运行；G2 记录推理窗口内主接口 P95 |
