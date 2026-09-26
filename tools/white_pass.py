# -*- coding: utf-8 -*-
"""批次8 白色简洁：普通页面硬编码暖色 → 白/中性。票根内容页与爱心豆情感色保留。"""
import io

# (文件, 旧, 新, 说明)
edits = [
    (r"lib\screens\anniversary\anniversary_screen.dart",
     "color: const Color(0xFFFFF7F1),", "color: Colors.white,", "hero卡"),
    (r"lib\screens\anniversary\anniversary_screen.dart",
     "color: const Color(0xFFFFF3EE),", "color: const Color(0xFFFBF1F0),", "错误底浅红"),
    (r"lib\screens\home\home_screen.dart",
     "color: const Color(0xFFFFF3EE),", "color: Colors.white,", "每日一问卡"),
    (r"lib\screens\home\home_screen.dart",
     "(_SliceData(0.26, const Color(0xFFFFF3E8)))",
     "(_SliceData(0.26, const Color(0xFFF4F4F5)))", "饼图浅扇区"),
    (r"lib\screens\life\life_screen.dart",
     "color: const Color(0xFFF7FCF4),", "color: Colors.white,", "生活头卡"),
    (r"lib\screens\profile\profile_screen.dart",
     "color: const Color(0xFFFFFBF8),", "color: Colors.white,", "关系资料卡"),
    (r"lib\screens\profile\profile_screen.dart",
     "color: const Color(0xFFFFF7F1),", "color: Colors.white,", "回忆管理卡"),
    (r"lib\screens\travel\travel_amap_mode_screen.dart",
     "color: const Color(0xFFFFFCF8),", "color: Colors.white,", "空态卡x2"),
    (r"lib\screens\travel\travel_amap_mode_screen.dart",
     "color: const Color(0xFFFFF7EE),", "color: context.lgPaperWarm,", "信息格"),
    (r"lib\screens\travel\travel_amap_mode_screen.dart",
     "color: const Color(0xFFFFF4EC),", "color: const Color(0xFFF5F5F6),", "小通知底"),
    (r"lib\widgets\lovegirl_ui.dart",
     "this.color = const Color(0xFFE0D8D0),",
     "this.color = const Color(0xFFE2E2E2),", "票根分隔线中性"),
]
for p, old, new, note in edits:
    s = io.open(p, encoding="utf-8").read()
    n = s.count(old)
    s = s.replace(old, new)
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print("%-46s %-12s x%d" % (p.split("\\")[-1], note, n))
