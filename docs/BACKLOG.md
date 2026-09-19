# LoveGirl 产品待办（Backlog）

## 翻页相册（flipbook）—— A/B 对比页已就绪，待真机择优
- 状态：对比 demo 已进主干（2026-09-19），从云端相册右上角"翻页书"入口进入
- 页面：`lib/screens/photo/photo_flipbook_screen.dart`，底部分段切换 A/B 引擎，同批照片对比
  - A = book_page_flip：摊开书跨页 + 3D 卷页，预解码位图（targetWidth 720 控 atlas）
  - B = page_flip：单页翻动，widget 直接当页（CachedNetworkImage，无需预解码）
- 选型变化（2026-09-19）：**turnable_page（原候选②）出局**——TPPL 专有许可证禁止未经书面许可的一切使用；替补 **page_flip**（MIT，0.2.5+1）进对比
- 下一步：真机对比手感择优 → 删除落选引擎与切换 UI → 加"手动挑选 + 排序"选片功能
- 设计语言：借"create-photo-flipbook-ui" skill 的纸感/硬壳封面/书脊阴影（借魂不借壳，勿用 WebView）
- 隐私约束：不让 AI 挑选用户私密照片，选片排序全由用户手动

## 通知中心（铃铛+历史通知列表）
- 状态：暂不做（2026-09-18 用户意见：核心场景已有红点+首页提示条）
- 触发条件：用户觉得需要翻历史通知时再做；服务器 notifications 表和接口已就绪

## 其他备忘
- 测试账号 testgirl/testboy 长期保留（持续更新需要测试闭环），发布前不删
- 服务器垃圾清理与每日备份：2026-09-18 勘察进行中（见 docs/server-audit-20260918.md）
