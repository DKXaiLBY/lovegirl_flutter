# -*- coding: utf-8 -*-
"""扫描旅行地图相关文件的结构：类/方法/控件关键字行号。"""
import io
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
FILES = [
    r"D:\Projects\Personal\lovegirl\lib\screens\travel\travel_amap_mode_screen.dart",
    r"D:\Projects\Personal\lovegirl\lib\widgets\travel_map_widget.dart",
]
PAT = re.compile(
    r"(^class |^  Widget |^  Future|void _|[A-Za-z_]+\(|cycleMapStyle|fitBounds|"
    r"_ensureLocationLayer|_primeLocationLayer|locateMe|标准地图|路线|查看全部|"
    r"新增地点|查看全局|onMapCreated|onLongPress|FloatingActionButton|bottomNavigationBar|"
    r"Stack\(|Positioned\()"
)
for f in FILES:
    print("=" * 20, f.split("\\")[-1])
    for i, line in enumerate(io.open(f, encoding="utf-8"), 1):
        s = line.rstrip()
        if PAT.search(s) and not s.strip().startswith("//"):
            print(i, s.strip()[:110])
