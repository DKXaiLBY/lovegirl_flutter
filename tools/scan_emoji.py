# -*- coding: utf-8 -*-
"""扫描 lib/ 下 dart 文件中的 emoji 使用点，输出 file:line 清单。"""
import os, re, io, sys

sys.stdout.reconfigure(encoding="utf-8")
root = r"D:\Projects\Personal\lovegirl\lib"
# 常见 emoji 区段：箭头/符号、装饰符号、VS16、补充符号区
pat = re.compile(u"[\u2190-\u2BFF\uFE0F\U0001F000-\U0001FAFF]")

hits = {}
for dp, dns, fns in os.walk(root):
    for fn in fns:
        if not fn.endswith(".dart"):
            continue
        p = os.path.join(dp, fn)
        for i, line in enumerate(io.open(p, encoding="utf-8"), 1):
            if pat.search(line):
                rel = os.path.relpath(p, root)
                hits.setdefault(rel, []).append((i, line.strip()[:120]))

if not hits:
    print("NO_EMOJI_FOUND")
for f in sorted(hits):
    print("====", f)
    for i, l in hits[f][:15]:
        print(i, l)
    if len(hits[f]) > 15:
        print("... 共 %d 处" % len(hits[f]))
