# LoveGirl 项目交接提示词（2026-10-16）

> 把本文全文作为第一条消息发给接手 AI 即可。本文不含任何密码/令牌——凭据一律向用户本人索取。

---

你现在是 **LoveGirl** 项目的开发负责人，从上一位 AI 助手手中接手。项目文件夹已交付给你。请严格按以下内容开始工作。

## 第一步（必做）

1. 完整阅读仓库根目录 **AGENTS.md**——这是项目记忆：全部模块、环境路径、18+条踩坑教训、发版规程、待办清单。之后任何操作前先对照它。
2. 阅读 **docs/DESIGN_SYSTEM.md**（视觉规范，注意文头 v4 修订声明）与 **docs/implementation/v4-ui-token-plan.md**（现行 v4 风格的 token 方案）。
3. 跑一遍基线：`flutter analyze`（应 0 问题）+ `flutter test`（应 61/61 全绿）。

## 项目一句话

情侣双人 App：Flutter 前端（3.27.4）+ Node/Express + MySQL（Docker，阿里云 ECS 47.121.119.191:3001）+ 高德地图 + 腾讯/阿里云 AI 能力。28 个模块（恋爱天数/纪念日/心情/旅行地图票根/厨房点单/相册拍立得/衣橱换装/爱心豆/慢信/月报……详见 AGENTS.md）。

## 当前状态（截至 2026-10-16）

- **线上版本 v4.0.1+181**（app_versions is_active=1；APK 备份在服务器 /opt/love-girl/apk-backups/v4.0.1.apk）
- **刚完成 v4 全量换装**：用户给了 8 张参考图（在 `docs/design/refs/v4-ui/`），全 App 换成「浅灰渐变底 + 软实体白卡（微渐变+双层柔影）+ 黑胶囊选中/主按钮 + 粉彩浅底分段 + 毛玻璃弹层」。commit 链 9b480bd → 2b07dc2 → c5fc01d → 8441f2e，已全部 push
- git 基线干净（master = origin/master）；工作区仅剩 docs/design/refs/ 根目录散落旧参考图未跟踪（无害）
- 测试账号：admin（密码 2026-10-16 刚重置，向用户要）、testgirl/testboy（强密码向用户要）。服务器数据只在 love_girl 库

## 环境速查（同一台机器，工具都在，但 PATH 里没有——全部用全路径）

**所有命令在 Git Bash 里执行**（cd 到仓库后）：

```bash
# ========= 全路径常量（每次会话先设好）=========
FLUTTER="D:\SoftwarePrograms\dev\flutter-sdk\bin\flutter.bat"
GIT="D:\SoftwarePrograms\01-开发工具\Git Setup\Git\cmd\git.exe"
ADB="D:\SoftwarePrograms\dev\android-sdk\platform-tools\adb.exe"

# ========= 基线校验（不需要 JAVA_HOME）=========
"$FLUTTER" analyze        # 应 0 问题
"$FLUTTER" test           # 应 61/61 全绿

# ========= 构建 APK（必须带 JAVA_HOME，Gradle 要 Java）=========
cd "D:\Projects\Personal\lovegirl"
JAVA_HOME="C:\Program Files\Java\jdk-17.0.3.1" "$FLUTTER" build apk --release
# 产物：build\app\outputs\flutter-apk\app-release.apk（~52MB，1-2 分钟）

# ========= git（PATH 里的 git 是死路径，必须全路径）=========
"$GIT" status && "$GIT" log --oneline -5
# 中文 commit 信息：UTF-8 文件 + git commit -F 文件（shell 直传中文会 GBK 乱码）

# ========= adb 真机（KOZ-AL00 荣耀，720×1600@2x，Android 10 无 GMS）=========
"$ADB" devices
"$ADB" install -r build/app/outputs/flutter-apk/app-release.apk
"$ADB" exec-out screencap -p > /tmp/shot.png   # 截图（先 Read 看是否黑屏，黑屏先 WAKEUP+keyevent 82）
# 底部 tab y≈1522（首页 x=96/旅行 202/健康 353/生活 495/我的 617 中心 x）
# 模拟器 AVD：lovegirl_api34（x86，高德地图/定位验不了，只能看 UI）

# ========= 服务器（SSH 免密已配，用系统 OpenSSH 不用 Git 自带的）=========
ssh root@47.121.119.191 '命令'
# 查库（密码不落盘，容器内环境变量取）：
ssh root@47.121.119.191 'docker exec lovegirl-mysql sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" love_girl -e \"SELECT ...\""'
# 复杂中文 SQL：UTF-8 文件 → scp 到 /tmp → docker cp 进容器 → mysql < 文件（直传中文必乱码）
```

**其他路径**：仓库 `D:\Projects\Personal\lovegirl`；`D:\lovegirl_build` 是 junction 别名（构建走它或真实路径均可）；Flutter 3.27.4（**Color 透明度用 `withValues(alpha:)`，`withOpacity` 已弃用**；`toARGB32()` 不存在）；EMUI 深色模式 adb 切不动（`cmd uimode` 无效），只能用户手动切。

## 发版规程（严格照做，全文见 AGENTS.md 与本地记忆 lovegirl-deploy-protocol）

1. 版本号两处同步：`pubspec.yaml` + `lib/utils/constants.dart`
2. 构建 → APK 备份 `scp` 到 `/opt/love-girl/apk-backups/v<版本>.apk`
3. 发布：APK scp 到服务器 /tmp → 服务器内 `curl -X POST http://localhost:3001/api/deploy/publish -H "x-deploy-token: $TOKEN" -F apk=@... -F version_name=... -F version_code=...`（**令牌只在服务器容器内 printenv 取，严禁出现在任何对话/文件/日志**）
4. 发布后必修正 app_versions 的 version_name/changelog（上传接口不更新这两字段）：UTF-8 SQL 文件 + CHAR(10) 拼接换行
5. 验证 `/api/version/check?version_code=<旧>` 返回 hasUpdate:true
6. 回滚四层：git revert / APK 备份 / app_versions is_active 切换 / 发版前 git tag

## 红线（违反任何一条都是事故）

1. **DEPLOY_TOKEN 三规**：只在服务器端取、不读取不展示不写文件
2. **密码/密钥不入仓库不入聊天**：admin 新密码、test 账号密码、腾讯/阿里云钥匙全部向用户本人索取
3. **老设备红线**：荣耀 Android 10 不支持 Emoji 13+（🫘🧋🔥🎉 等），用户可见文案禁用，用 PNG 图标或 SVG
4. **深色模式全局硬性要求**：任何 UI 改动必须深浅两态都成立（token 化，不写死亮色）
5. **GPL/AGPL 项目严禁任何代码移植**（弹药库 docs/reference-backlog.md 里有标注）
6. **改动范围纪律**：用户极度反感擅自扩大改动范围（有历史：只让改地图却动了纪念日被要求 revert）；先方案后动手，等用户拍板
7. **质量闸**：每次交付 `flutter analyze` 0 问题 + `flutter test` 全绿 + 独立 commit（一回滚点）；发布前真机深浅两态过一遍
8. **拍立得相框/票根样式/省份点亮地图/换装白板**是用户验收过的实体质感组件，非用户明确要求不许动

## 待办清单（按优先级）

1. **深色模式逐页走查**（v4 换装后未做过深色真机验证——发版红线欠账，需用户手动切深色后走查）
2. **v4 视觉微调可能继续**：用户对视觉极其挑剔（风格连续换了 5 轮才定 v4），如果用户再说"和参考图不像"，对照 `docs/design/refs/v4-ui/` 8 张图逐项抠，核心质感词是：**软实体卡（微渐变+大柔影）、疏朗行距、大标题、裸数字计数、浅灰胶囊选中、黑胶囊只给主按钮**
3. **阿里云钥匙待装**：用户把 ALIYUN_ACCESS_KEY_ID/SECRET 放进 /opt/love-girl/.env 后，衣服抠图（SegmentCloth）自动激活——重启验证 `/bg-status` object:true（详见 AGENTS.md S2 条目）
4. **腾讯密钥再轮换**：现行钥匙曾在聊天泄露过（用户已知）
5. **第二梯队功能待用户拍板**：心情标签联动旅行地点（需加 DB 列）/随机照片任意门/完整备份导出
6. travel_form 编辑回填旧值 bug（预先存在：_weather 从 mood 读但不落库）——修时注意 mood 清空风险
7. ParallaxAvatar idle ticker 无可见性门控（N 卡常驻，量小可接受）；gal Android≤9 相册写入静默失败

## 工作方式（用户的习惯，来自历史记忆）

- **先方案后动手**：收到需求先出结构化方案（根因+建议+是否动服务器+批次），等拍板再改代码；直接改会被批评
- **客观分析不迎合**：用户要独立判断，不要顺着说
- **发版前确认**：对外上传动作先向用户确认版本号与变更内容
- **验收标准高**：视觉类工作要"截图与参考肉眼难辨"，不是"结构对了"；物理质感（纸纹/阴影/渐变）是这个 App 的灵魂
- 用户可能分批发参考图/截图，附件可能是无扩展名文件（复制成 .jpg 再读）

## 近期大事记（帮助你理解上下文）

- 2026-09-30：v3.40-v3.42 三连发（拍立得立体感/换装白板/视差/左滑三键/奶油暖白风格/心情月历多心情/足迹线/省份点亮地图前身）
- 2026-10-13：W6 省份点亮地图完成（commit 59a1fb2，真机 6 省点亮验证通过）
- 2026-10-14~15：UI 风格探索 5 轮被否 → 用户给 8 张参考图 → v4.0.0+180 全量换装发布
- 2026-10-16：v4.1 走查修复 + 用户批"和参考图差距太大" → v4.2 软实体卡纠偏 → v4.0.1+181 发布（当前线上版）
