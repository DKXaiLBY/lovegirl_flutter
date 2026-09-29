# LoveGirl 交接文档（2026-09-29，会话 sess_475553e7 → 下一会话）

> 新会话第一步：完整阅读 AGENTS.md + 本文档 + 记忆文件
> （lovegirl-v332-feedback-plan / lovegirl-deploy-protocol / user-workflow-objective-plan-first），
> 然后把本文档 §6「待用户拍板」的问题转达给用户，拿到答案后按路线图继续。

---

## 1. 当前状态

- **线上版本**：v3.39.0+176（2026-09-28 发布）。全部提交已推 GitHub（HEAD ≈ d2d5427）。
- **本会话（前一会话链）完成**：
  - 拍立得实体相纸复刻：正面四主题（classic 白框/tape 黑胶带/film 暗胶片/letter 红字信笺）+
    背面三款版式 1:1（tape 双印字带+白字留言 / letter 打字机印字+红字留言+褶皱纸 /
    film 左右竖排胶片印字+嵌照片负片）+ POD/信笺程序化质感纹理 +
    matchesGoldenFile 视觉验证法（教训 20）
  - 衣橱 MIROIR 化：P1 搜索框（品牌/类别/颜色模糊）+ 分类 chips（全部+8 类，预填
    filter 与 P10 联动）；P12 形象页双 Tab（照片库原图管理 / 数字形象抠图成果墙）
  - 安全清理（Mimosa L3 push 闸首次强制拦截后清理）：publish.py/_gen_build_bat.py/
    replace_icons.py 覆写弃用说明、amap doc 第三方 JS 删除、weather.js 输入校验、
    love_report.js IN 插值改固定 (?, ?) 双占位+pairIds（服务器 7b4be6f，smoke 200/400）
  - 旅行清单「记一个地点」移标题行；生活 5tab 纵排；票根透图/FAB 遮挡/定位兜底等
- **电子衣柜 6 步路线图**：Step1 去暖色 ✅ → Step2 拍立得复刻 ✅ → Step3 插画冷色提示词
  ✅（36-54 条已备，等用户豆包生成同名替换 illus/）→ Step4 MIROIR 化 ✅ →
  **Step5 换装白板（下一个主体工程，前置=衣服抠图定标）** → Step6 收集册/保存模板字体/E3

## 2. 关键文档与素材

| 内容 | 位置 |
|---|---|
| 衣柜 PRD v2.0 / 交互 v1.0(§9 换装) / M2 方案 v1.1 | docs/wardrobe-prd.md, wardrobe-interaction.md, implementation/wardrobe-m2-plan.md |
| 拍立得参考图（23 张：竞品功能 10 + 拍立得 7 + MIROIR 6） | docs/design/refs/ |
| 冷色插画提示词 36-54（19 张，用户豆包生成→同名替换 illus/） | docs/design/asset-prompts.md 底部 |
| 纹理生成器（纸纹/POD/信笺） | tools/gen_paper_grain.py, tools/gen_back_texture.py |
| 小程序版交接包（另一会话开发中） | D:\Projects\Personal\Online wardrobe\ |

## 3. 两大未达预期（用户本次痛点，技术分析已做，待拍板后施工）

### 3.1 数字形象（现状=静态抠图，用户期待 360° 旋转+腿部会动）
技术真相：单张正面照做不出可信真 3D；"腿动"=角色动画或 AI 视频（贵且不可控）。
- **候选路线（待用户拍板）**：①伪 3D 视差（人/背景分层+倾斜晃动，推荐，约一轮）
  ②姿势素材切换（多拍几套姿势照，换装白板里切换，缓）③AI 视频（不建议）
- 依赖：人像+背景双层分割（现有 bda 人像分割可复用，背景层需另抠或用纯色底）

### 3.2 拍立得立体感（现状=平面翻牌感，用户要实物厚贴感）
已实现：比例/纸纹/内凹/静态光泽/双层阴影。**仍缺的四项（Flutter 可做，推荐全做）**：
①厚度侧边（3D 透视倾斜时露出卡纸截面）②相纸微弯 ③动态光泽（高光随倾斜移动）
④落影随倾斜变形。预计一轮（photo_screen 翻面卡+PolaroidFrame 升级）。

## 4. 服务器与环境

- 服务器 root@47.121.119.191，Docker（lovegirl-server/mysql/web），bind mount 改码即生效
- 衣柜服务器 git：M1=6242c97、deploy 上限=7b4be6f 前、安全加固=7b4be6f；photo polaroid 路由已上线
- 腾讯云：bda SegmentPortraitPic 人像抠图已通（**参数名 Image + RspImgType:'base64'**，教训 19）；
  衣服抠图未定标（候选：CI AIPicMatting+COS / 阿里云 SegmentCommonImage / 端侧 u2netp）
- **用户腾讯云密钥已泄聊天，待用户自行轮换（勿在聊天收密钥）**
- compose 里 DEPLOY_TOKEN 明文待迁 .env（低优先）
- 构建环境：JAVA_HOME jdk-17.0.3.1 + flutter.bat；GitHub 直连间歇被墙（push 失败等几分钟重试）

## 5. 纪律（新会话必须遵守）

1. 方案先过对抗审查（Agent general-purpose 只读审查）再写代码；发版前用户确认
2. 每批次：analyze 0 + test 28/28 全绿 + 独立 commit push
3. 发布：服务器端脚本取 TOKEN（printenv）→ curl -F 上传 → app_versions 核验（UTF-8 字节）；
   完整规程=本地记忆 lovegirl-deploy-protocol
4. SQL 全内联字面量+参数数组；可变 IN 用固定 8 占位符补位；改 .js 先 node --check 再重启
5. 视觉验证：matchesGoldenFile --update-goldens 渲染 PNG 人工比对，用后即删（教训 20）
6. 老设备禁 emoji（教训 3）；DECIMAL 列字符串 tryParse（教训 18）
7. 部署 .js：scp→node 语法检查→restart→health；docker cp .js 会被 Mimosa 拦，用 stdin node -

## 6. 待用户拍板（新会话第一件事转达）

1. 数字形象旋转：伪 3D 视差（推荐）vs 真 3D（不建议）？
2. 腿部动作：姿势素材切换（缓，推荐）vs AI 视频（不建议）vs 不做？
3. 拍立得立体感四项（厚度侧边/微弯/动态光泽/落影层次）：全做（推荐）？
4. 排期：拍立得立体感先行、数字形象视差排换装白板后（推荐）？
5. 衣服抠图定标三候选（换装白板前置）：CI+COS / 阿里云 / 端侧——需报实测后拍板
6. 拍立得/衣橱 MIROIR 化 v3.39.0 真机验收反馈（含深浅两态）

## 7. 已知遗留

- illus 暖色插画重生成（提示词已备）+ 天气"晴"语义色
- 左滑升级（编辑/置顶，需 travel_spots 加 pinned 字段）待拍板
- DESIGN_SYSTEM.md 旧色板表已标废但正文未重写
- test/goldens 视觉验证法已验证（生成用后即删，不可入库）
