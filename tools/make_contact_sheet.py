# -*- coding: utf-8 -*-
"""质检拼图：把 assets/images/illus 全部素材分别合成到暖纸底/深色底，各输出一张网格大图。"""
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
DST = r"D:\Projects\Personal\lovegirl\assets\images\illus"
OUT = r"D:\Projects\Personal\lovegirl\tools"
CELL, COLS = 170, 6
BGS = {"light": (255, 248, 243), "dark": (42, 36, 33)}

files = sorted(f for f in os.listdir(DST) if f.endswith(".png"))
rows = (len(files) + COLS - 1) // COLS
for tag, bg in BGS.items():
    sheet = Image.new("RGB", (COLS * CELL, rows * CELL), bg)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(DST, f)).convert("RGBA")
        im.thumbnail((CELL - 14, CELL - 14))
        x = (i % COLS) * CELL + (CELL - im.size[0]) // 2
        y = (i // COLS) * CELL + (CELL - im.size[1]) // 2
        sheet.paste(im, (x, y), im)
    out = os.path.join(OUT, "illus_sheet_%s.jpg" % tag)
    sheet.save(out, quality=82)
    print(out, sheet.size, len(files), "items")
