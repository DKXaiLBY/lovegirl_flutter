# -*- coding: utf-8 -*-
"""refs 参考图压缩：23 张 PNG → 560px JPG（防 Read 超时）"""
import os
from PIL import Image

SRC = r'D:/Projects/Personal/lovegirl/docs/design/refs'
DST = r'C:/Users/DKX/AppData/Local/Temp/lg_refs'
os.makedirs(DST, exist_ok=True)

for name in sorted(os.listdir(SRC)):
    if not name.lower().endswith('.png'):
        continue
    img = Image.open(os.path.join(SRC, name)).convert('RGB')
    w, h = img.size
    scale = min(1.0, 560.0 / max(w, h))
    if scale < 1.0:
        img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    out = os.path.join(DST, name.replace('.png', '.jpg'))
    img.save(out, 'JPEG', quality=80)
    print(os.path.basename(out), img.size)
