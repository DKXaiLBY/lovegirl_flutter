# 4.4.2 清透玻璃与实体相纸 UI 验收

实施记录始于 2026-10-27，最终发布收尾核验于 2026-10-30。依据为用户确认的两张新材质参考图，以及本轮 [目标与验收标准](glass-paper-ui-20261027.md)。仅调整拍立得、票根、旅行相关展示与控件；没有迁移作品/草稿格式、修改服务端业务或更换其他页面的全局主题。

## 交付内容与视觉检查

| 检查点 | 实际实现及核验 |
|---|---|
| 清透按钮 | 透明底、背景采样、低模糊、轻微透镜放大和内外轮廓高光；真机照片背景与原生地图上均可透出背景。亮暗两态检查文字与图标，主行动保留不透明高对比色 |
| 拍立得 | 大张相纸、实际相邻作品叠放、薄侧边、接触/环境阴影、平滑光面及日期字样。滑动有细微倾斜，翻面有透视和表面光泽变化；背面记录与独立笔迹保留 |
| 原照片 | 6 张既有照片按相纸陈列，展示已有备注和日期；只构造显示用画布，没有批量创建新作品或改写原图 |
| 相纸与成像 | 完整双列相纸库、真实照片效果缩略预览、选中状态及强度控制；相纸、裁切和成像参数继续独立 |
| 票根 | 哑光纤维、细切边、齿孔、虚线与薄边；票面不被翻面按钮遮挡。详情分成票面、可读标题/日期/记录区、编辑/导出；记录弹层可查看完整文本 |
| 票根编辑 | 照片/文字/配色/背景分组；色块有清楚的勾选和轮廓。照片不足的模板显示所需数量并禁用，不向用户展示无反馈的选择 |
| 旅行 | 清透地图控件，地点照片缩略逻辑、逐日连线、编号、选中态与 48 逻辑像素排序手柄；交通弹层显示真实起终点与服务结果。无路线错误码在展示层转换为中文 |
| 触控/字号 | 自绘按钮和月份入口至少 48 逻辑像素。荣耀 1.15 倍系统字号核验底部滑杆和入口，单测覆盖 1.4 倍字号；修正旧设备底部系统区域对控件的影响 |
| 动效偏好 | 同时遵循系统关闭动画和 App 现有 `motion_level=off`；关闭后操作保留，装饰性过渡关闭。三模块没有增加常驻装饰 ticker |

上述判断来自运行画面、实际操作和源实现核对，不以样式数量、测试通过或生成参考图替代视觉检查。材质为 Flutter 中的视觉近似，不声称与生成图的光学表现逐像素相同。

## 修改清单

| 源码 | 改动目的 |
|---|---|
| `lib/widgets/rebuild_controls.dart` | 三模块共用的清透控件、可触控面积、反馈及现有减少动态偏好 |
| `lib/features/creations/creation_material.dart`、`creation_canvas.dart`、`creation_preview.dart` | 照片背景、相纸与票根材质、薄边和阴影、翻面与光泽 |
| `lib/features/creations/creation_gallery.dart` | 大张叠放、原照片陈列、票根详情与完整记录；修复新布局中控制器替换的灰色预览 |
| `lib/features/creations/creation_editor.dart`、`creation_camera.dart` | 编辑工具与模板层级、可选/不可选提示、安全区域和相机控件外观 |
| `lib/features/travel/journey_panel.dart`、`travel_screen.dart` | 既有地图控件、逐日清单、缩略图与交通结果的展示 |
| `test/glass_paper_ui_test.dart` | 本轮回归、窄屏字号、触控、动效偏好与动态增删列表检查 |
| `pubspec.yaml`、`lib/utils/constants.dart`、`CHANGELOG.md` | 4.4.2+187 版本及更新说明；没有新增依赖 |

## 实际设备与过程

- 荣耀畅玩20，KOZ-AL00，Android 10，720×1600，密度 2，原系统字号 1.15。用户明确要求后，后续均在该备用机完成；先前的模拟器画面不作为最终真机证据。
- 正常 `lib/main.dart` release 构建，无自动登录参数，沿用原测试会话，没有重置密码、切换账号或清空应用数据。
- 拍立得：原照片制作、标题/背面记录、前后独立手绘、撤销/重做、相纸库、成像缩略图、草稿恢复、收藏、再编辑、翻面及导出。
- 票根：选版式、导入受控测试照片、文字/日期、配色与背景渐变、收藏、详情、完整记录、翻面、再编辑与相册导出。
- 旅行：用两个既有地点建立个人 QA 行程，展开/收起清单、排序、真实街道地图与交通比较。验证驾车和公交真实距离/时长，步行距离限制与骑行无路线状态；没有提交共享 QA 行程。
- 亮暗模式均检查。验收结束恢复亮色、标准动效，未改变原网络与相机权限设置。
- 连续新增作品暴露了本轮控制器复用错误，导致灰色预览；先写出可复现的失败回归，再修复短暂挂接多个滚动视图的边界。真机再编辑与删除后，预览仍完整。

## 运行证据

完整原始证据保存在本机备份目录，未将用户照片截图提交到仓库：

`D:\Projects\codex\lovegirl-ui-backups\20261027-glass-paper\`

| 证据 | 文件 |
|---|---|
| 相纸、原照片与字号 | `honor/30-187-looks-clearance.png`、`honor/75-final-original-photo-papers.png` |
| 键盘与文字编辑 | `honor/10-qa-keyboard-title.png`、`honor/57-ticket-title-input.png`、`honor/58-ticket-record-saved.png` |
| 票根详情、记录与导出 | `honor/66-final-ticket-loaded.png`、`honor/70-final-ticket-record-sheet.png`、`qa-export-verification.json` |
| 独立配色/背景 | `ticket-color-ui-verification.json`：改票面颜色与渐变时，照片区域像素相同，外部工作台像素始终为 RGB(231,233,237) |
| 旅行与真实路线 | `honor/87-final-journey-expanded.png`、`honor/88-final-route-comparison.png`、`honor/92-final-journey-reordered.png` |
| 暗色与无路线中文 | `honor/103-dark-journey-expanded.png`、`honor/105-final-dark-ticket.png`、`honor/110-dark-photo-explicit-back.png`、`honor/113-final-chinese-route-state.png` |
| 动态与偏好 | `honor/111-polaroid-flip-intermediate.png`、`honor/motion-raw/`、`honor/134-motion-off-selected.png`、`honor/135-motion-off-controls-still-work.png`、`honor/136-standard-motion-restored.png` |
| 灰色预览回归 | `pager-regression-before.log` 确认多滚动视图错误；`pager-regression-after.log` 及实际增删后的预览截图确认修复 |

设备未提供 `screenrecord` 命令，采用原始截图序列检查透视中间态。没有完成原生全帧率基准；当前账号未绑定伴侣，本轮不声称完成两部物理手机的双端 UI 联调。路线数据是测试当时服务返回的结果，不写成固定示例数值。

## 数据保护与清理

| 原有内容 | 验收前后结果 |
|---|---|
| 照片 6 条，ID32–37 | SHA256 `55f6b34adfe786bdf873762bab7388f5b5017cf152d514689e04ac434b4f8f7a` 一致 |
| 地点 8 条 | SHA256 `88ecf1354b0fe08d418a3b95787fae0b5962afb46d9a4cd64e601880e49fa449` 一致 |
| 原作品记录 ID5/7 | SHA256 `25e0a8d824addb455489cd46b66b08101c0c9677773dee3645b783b31f06057e` 一致 |
| 原照片草稿 1 份 | “未完成的回忆 / 旧纸折痕 / 2026-10-26 18:19” 保留，核对界面信息与数量，未声称读取私有文件做字节校验 |
| 原票根草稿 1 份 | “未完成的回忆 / 横向纪念 / 2026-10-26 18:19” 保留 |

本轮 QA 作品 9/10/11 经正常界面软删，活动 QA 作品为 0；仅清理这三条测试作品的 6 个来源/预览文件，预先核对无其他作品或原照片引用。删除个人 QA 行程、两份 QA 编辑草稿及本轮新增的 3 个手机媒体条目，保留原有草稿与旧测试文件。相关清理与散列核对见 `qa-cleanup-verification.json`、`qa-server-media-cleanup.json` 和 `qa-device-media-cleanup.json`。

## 构建与发布

- 编译源码：`4c2a43f4d44d0c17bd4a2aedd85d707e880ff7d6`。
- 版本：4.4.2+187。完整 Flutter 测试 **159 项通过**，analyze **0 问题**。
- 正式包：56,941,355 字节；SHA256 `04bbecf1e65af99cfb46711e88a42b9b3fb794725657911ede30787b4269d5bc`，MD5 `9d2c5093fdf86fbc727276a0828b59cb`。
- 已正式发布至现有服务器，版本名称/版本码、文件大小、MD5、激活状态与中文 6 行 changelog 均核对正确，不强制更新。
- 公网完整下载文件、服务器正式备份及荣耀备用机实际安装包的 SHA256 一致。184/185/186 的 `hasUpdate=true`，187 的 `hasUpdate=false`；2026-10-30 再查仍成立。
- 编译源码 tag 为 `v4.4.2`；实施分支 `codex/glass-paper-ui` 已推送并快进远端 `master`。后续验收文档提交不改变该编译产物。
- 发布证据：备份目录中的 `release-187-published.json`、`release-187-public-verification.json`、`release-187-final-verification.json` 和 `honor-installed-apk-match.json`。发布后原数据查询结果仍与基线一致。
- 正式新旧 APK 与上一版发布元数据均保留并重新校验；仅移除本轮 3 个未发布候选包及容器内临时上传副本，保留正式下载文件。

## 回滚

- 源码基线：`0f9949493f19e4e1fc6e2b6bd73c83d6abfce2d3`，本地及远端分支 `backup/ui-before-glass-paper-20261027`。
- 完整 bundle 与原 APK：同级备份目录 `source-before-ui.bundle`、`v4.4.1-186.apk`。bundle 已通过 verify，原包 SHA256 为 `ebacaff77572e83baaf3906774117313da0b9b7a9edcd635bd61dd40eee52c86`。
- 服务器原包：`/opt/love-girl/apk-backups/v4.4.1.apk`。元数据备份随发布保留。
- 客户端正式回退采用基线源码构建更高版本码的修复包，保留应用数据；不对手机执行卸载或清数据，不回退数据库。后续源码如有新改动，先在回滚分支处理冲突并验证，避免覆盖别的工作。

本记录是这轮三模块材质与布局 UI 的验收，不是全 App 换装、旧全部参考页面逐像素复刻或所有历史功能审计的完成声明。

## 目标完成核对（2026-10-30）

| 原要求 | 完成依据 |
|---|---|
| 先备份并建立验收标准 | 目标文档及实施前基线分支、完整 bundle、旧 APK；收尾再做 bundle verify 和旧包散列核对 |
| 清透玻璃、光面相纸、纸质票根 | 上述运行截图与确认参考图逐项核对；光面与哑光分离，控件透出实际背景，动态中间态保留 |
| 只做相关三模块 UI | 基线至最终源码差异已核对；模型、草稿格式、API 服务、行程控制器、后端副本、依赖锁及全局主题均未修改 |
| 可读性、触控、适配及反馈 | 荣耀亮暗与 1.15 倍字号截图、真实按压/翻面/排序和键盘操作；360 宽及 1.4 字号、48 触控与关闭动态回归 |
| 原有流程与数据 | 制作/再编辑/翻面/草稿/导出及地图操作实测；159 项完整测试/analyze0；发布后原数据再查询、原两份草稿保留 |
| 发布与升级核验 | 正式版本 187 激活；旧版升级 true/新版 false，中文说明正确，公网完整下载与备份及真机安装包散列相同 |
| 交付与可回滚 | 本文修改清单、原始截图目录、源码与旧 APK 回滚说明；已记录设备/帧率/双端边界 |
