# -*- coding: utf-8 -*-
"""扫 lib/ 下硬编码的暖色（批次8 白色简洁需清的散点）。"""
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
# 暖白/暖米/暖杏/暖分隔（白简洁 pass 的清除对象）；情感橘/红/绿不在列
PAT = re.compile(
    r"Color\(0xFF(FFF[0-9A-F]{3}|FF[0-9A-F]{2}[0-9A-F]F[0-9A-F]|F7FCF4|F0D[0-9A-F]{2}"
    r"|E0D8D0|EAE4DC|F6EFE8|F0F5EC|FFF5EC|FFF8F3)\)"
)
hits = {}
for dp, dns, fns in os.walk(r"D:\Projects\Personal\lovegirl\lib"):
    for fn in fns:
        if not fn.endswith(".dart"):
            continue
        p = os.path.join(dp, fn)
        for i, line in enumerate(io.open(p, encoding="utf-8"), 1):
            if PAT.search(line):
                hits.setdefault(os.path.relpath(p, r"D:\Projects\Personal\lovegirl"), []).append((i, line.strip()[:100]))
total = 0
for f in sorted(hits):
    print("====", f)
    for i, l in hits[f]:
        print(i, l)
    total += len(hits[f])
print("TOTAL", total)
