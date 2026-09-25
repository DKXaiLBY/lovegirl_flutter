# -*- coding: utf-8 -*-
"""扫描 photo_screen.dart / polaroid_card.dart 结构。"""
import io
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
FILES = [
    r"D:\Projects\Personal\lovegirl\lib\screens\photo\photo_screen.dart",
    r"D:\Projects\Personal\lovegirl\lib\widgets\polaroid_card.dart",
]
for f in FILES:
    print("=" * 20, f.split("\\")[-1], io.open(f, encoding="utf-8").read().count("\n") + 1, "lines")
    src = io.open(f, encoding="utf-8").read().splitlines()
    for i, l in enumerate(src, 1):
        s = l.rstrip()
        if re.match(r"^\s*(class |Widget build|Future|void _|[A-Z][A-Za-z]* _?\w+\()", s) and not s.strip().startswith("//"):
            if re.match(r"^\s*(class |  Widget |  Future|  void |  const |  final )", s) or s.startswith("class "):
                print(i, s.strip()[:100])
