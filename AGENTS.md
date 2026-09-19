# AGENTS.md — LoveGirl 项目指南（新会话必读）

> 本文件是 AI 助手的项目记忆。新会话开始处理本项目时，先完整阅读本文件。

## 项目概况

**LoveGirl** — 情侣双人 App（Flutter 前端 + Node/Express 服务器 + MySQL）。
当前版本 v3.25.0+153。视觉风格：**灰白浮起卡片 + 黑色图标底座 + 荧光角标**（参考 "Explore AI Agents" 市场风格，品牌橘 #B85C38 已于 v3.25 退位）。

- 前端仓库：`D:\lovegirl_flutter`（git，remote = github.com/DKXaiLBY/lovegirl_flutter，master）
- 服务器：`root@47.121.119.191`（SSH 免密），LoveGirl 跑在 Docker（lovegirl-server / lovegirl-mysql / lovegirl-web），端口 3001
- 发布方式：`flutter build apk --release` → POST `/api/deploy/publish`（header `x-deploy-token: 123062bfa3d9e621940a2511a5eab7ef`，字段 apk/v/c/s/l）→ 修正 app_versions 表的 version_name/changelog（见下"发布坑"）

## 必读文档（按优先级）

1. `docs/DESIGN_SYSTEM.md` — 设计规范 v1.0（色板/字阶/圆角/组件/状态/文案/dark 红线/tokens）。**注意第 13 节不一致清单与 v3.25 后的现状差异**：品牌橘已退位（primary=#1A1A1A），色板中橘色标注以文档内说明为准
2. `docs/BACKLOG.md` — 待办：**翻页相册（用户明确要求下轮做，选型已完成）**、通知中心（暂缓）
3. `docs/implementation/v3.25-spec.md` 等 — 历史规格书（验收条款格式沿用）
4. `docs/design/lovegirl-ui-design-v1.html` — v1 设计稿（旧暖橘风，仅参考布局；新风格见下）

## 关键路径

| 内容 | 位置 |
|---|---|
| 设计 tokens（权威） | `lib/utils/lovegirl_theme.dart` |
| 版本号（两处都要改） | `pubspec.yaml` version + `lib/utils/constants.dart` versionName/versionCode |
| 图标/插图资源 | `assets/images/icons/`（41 图标×3 色 + 插图），生成器 `tools/generate_assets.py` |
| 图标组件 | `lib/widgets/app_icon.dart`（AppIcon，加载 `icon_<name>[_white|_grey].png`） |
| 服务器代码本地副本 | `server_fixes/`（travel.js/kitchen.js/beans 参考等，非完整工程） |
| 服务器完整代码快照 | `docs/server-snapshots-20260918.tar.gz`（服务器 /opt/love-girl/love-girl-server） |

## 构建 / 发布 / 测试

```bash
# 构建（debug 带自动登录；release 发布用，不带 dart-define）
JAVA_HOME="C:\Program Files\Java\jdk-17.0.3.1" "D:/flutter-sdk/bin/flutter.bat" build apk --release

# 测试账号（保留勿删）：admin/admin123（男友端）、testgirl（女友端）、testboy
# 服务器数据：MySQL 容器 lovegirl-mysql，库 love_girl，DB 密码在服务器 .env
```

- 每次交付：analyze 0 问题 + test 12/12 + 独立 commit push（回滚点）
- 发布后**必须修正** app_versions 表的 version_name/changelog（上传接口不更新 version_name，且 Windows shell 发中文会 GBK 乱码——用 UTF-8 SQL 文件 docker cp 进容器执行，历史坑）

## 经验教训（踩过的坑，勿重蹈）

1. **Material 图标批量替换为 PNG 有语法损坏风险**——用行级保守替换（`tools/replace_icons.py` v4 思路：仅单行、仅 size 参数、其余保留），勿用正则处理带 color 的复杂调用
2. **pubspec 资源目录声明**：`assets/images/` 需**显式列出子目录** `assets/images/icons/`，否则新子目录加载失败
3. **老设备 emoji 兼容**：荣耀 Android 10 不支持 Emoji 13+（🫘🧋 显示豆腐块）——用户可见文案禁用新 emoji，用图标 PNG
4. **图标命名前缀**：资源文件名带 `icon_` 前缀（icon_kitchen.png），AppIcon('kitchen') 组件内部拼前缀
5. **flutter analyze 是唯一可信校验**：批量文本替换后必跑；test 12 个断言覆盖首页/旅行/厨房/票根
6. **导航坐标**：这台测试机 720×1600@2x；底部 tab y=1522（首页 96/旅行 202/健康 353/生活 495/我的 617 中心 x）；返回键在 push 页面可能整页退出，优先用页面返回钮
7. **adb 截图偶发全黑**：先 WAKEUP+keyevent 82 唤醒
8. **风格基线**：灰白浮起（bg #F5F4F1/卡白/无描边浮起）、主行动黑底白字、图标=深色圆角方底座+白色线条 PNG、角标=高饱和小 pill。品牌橘仅剩情绪点缀（红心/回忆渐变）

## 待办 / 未竟

- 翻页相册（见 BACKLOG）
- 深色模式全局接线（用户确认过方向"光影通透"，token 已备）
- DESIGN_SYSTEM 第 13 节清单残余（圆角/字号游离值收敛）
- 动效 3 项依赖横滑轮播场景（方向锁定/落点预览/动画接管，PageView 自带）
- 服务器代码无 git（仅有 tar 快照）——建议未来建 server 仓库
