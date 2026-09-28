# -*- coding: utf-8 -*-
"""拍立得相纸材质（路线 C 素材层）：可平铺细纸纹噪点 tile（透明底）。
用法：叠在相框上（Image.asset repeat），给"非纯白"的实体纸感。"""
import random
from PIL import Image

OUT = r'D:/Projects/Personal/lovegirl/assets/images/deco/paper_grain.png'
random.seed(7)
S = 144
img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
px = img.load()
for y in range(S):
    for x in range(S):
        r = random.random()
        if r < 0.5:
            continue
        # 深浅随机的小颗粒：约 3% 可见度
        v = random.randint(0, 255)
        a = random.randint(6, 18)
        px[x, y] = (v, v, v, a)
img.save(OUT)
print('grain tile saved', img.size)
