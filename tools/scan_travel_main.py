# -*- coding: utf-8 -*-
"""travel_main_screen 布局速查。"""
import io
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
src = io.open(
    r"D:\Projects\Personal\lovegirl\lib\screens\travel\travel_main_screen.dart",
    encoding="utf-8",
).read().splitlines()
for i, l in enumerate(src, 1):
    if re.search(
        r"Positioned|bottom:|height: [5-7][0-9]|FloatingTab|Stack|Scaffold|SafeArea|padding|embedded|TravelAmapModeScreen",
        l,
    ):
        print(i, l.rstrip()[:110])
