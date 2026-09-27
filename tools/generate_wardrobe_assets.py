# -*- coding: utf-8 -*-
"""电子衣柜素材生成器（M1）：
- icon_wardrobe 三色变体（192 网格线条，同 generate_assets.py 风格）
- 6 个状态/来源角标 PNG（48px，彩色实心，深浅底均可读）
输出到 assets/images/icons/（pubspec 已声明该目录）。
"""
import os
from PIL import Image, ImageDraw

OUT = r'D:/Projects/Personal/lovegirl/assets/images/icons'
SS = 4

os.makedirs(OUT, exist_ok=True)

# ---------------- 图标（192 网格，三色，同主生成器约定） ----------------
S = 192
W = S * SS
LW = 15 * SS
COLORS = {'': (26, 26, 26, 255), '_white': (255, 255, 255, 255), '_grey': (142, 142, 147, 255)}


def canvas(w):
    img = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def P(pts, ss):
    return [(x * ss, y * ss) for x, y in pts]


def line(d, pts, c, w, ss):
    p = P(pts, ss)
    d.line(p, fill=c, width=w, joint='curve')
    for x, y in p:
        r = w / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)


def circle(d, cx, cy, r, c, w, ss):
    d.ellipse([(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss],
              outline=c, width=w)


def dot(d, cx, cy, r, c, ss):
    d.ellipse([(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss], fill=c)


def rrect(d, x, y, w_, h_, r, c, lw, ss):
    d.rounded_rectangle([x * ss, y * ss, (x + w_) * ss, (y + h_) * ss],
                        radius=r * ss, outline=c, width=lw)


def i_wardrobe(d, c):
    # 柜体
    rrect(d, 46, 42, 100, 112, 12, c, LW, SS)
    # 中缝
    line(d, [(96, 50), (96, 146)], c, LW, SS)
    # 两个门把手
    dot(d, 84, 96, 6, c, SS)
    dot(d, 108, 96, 6, c, SS)
    # 柜脚
    line(d, [(58, 154), (58, 164)], c, LW, SS)
    line(d, [(134, 154), (134, 164)], c, LW, SS)


for suffix, color in COLORS.items():
    img, d = canvas(W)
    i_wardrobe(d, color)
    img = img.resize((S, S), Image.LANCZOS)
    img.save(os.path.join(OUT, f'icon_wardrobe{suffix}.png'))
    print('icon_wardrobe' + suffix)

# ---------------- 角标（48px 实心彩色） ----------------
BS = 48
BW = BS * SS

ORANGE = (231, 162, 93, 255)    # 待确认（theme orange）
GREEN = (76, 175, 80, 255)      # 已通过（与 travel 状态绿统一）
PLANNED = (158, 154, 209, 255)  # 计划（theme planned）
GREY = (142, 142, 147, 255)     # 来源/退役中性灰
WHITE = (255, 255, 255, 255)


def badge(name, painter):
    img, d = canvas(BW)
    painter(d)
    img = img.resize((BS, BS), Image.LANCZOS)
    img.save(os.path.join(OUT, name + '.png'))
    print(name)


def p_pending(d):
    dot(d, 24, 24, 15, ORANGE, SS)


def p_approved(d):
    dot(d, 24, 24, 17, GREEN, SS)
    line(d, [(15, 24), (21, 31), (33, 16)], WHITE, 10, SS)


def p_planned(d):
    dot(d, 24, 24, 17, PLANNED, SS)
    circle(d, 24, 24, 10, WHITE, 6, SS)
    line(d, [(24, 24), (24, 17)], WHITE, 6, SS)
    line(d, [(24, 24), (29, 28)], WHITE, 6, SS)


def p_src_photo(d):
    rrect(d, 7, 15, 34, 24, 5, GREY, 9, SS)
    circle(d, 24, 27, 7, GREY, 9, SS)
    line(d, [(17, 15), (19, 9), (29, 9), (31, 15)], GREY, 8, SS)


def p_src_combo(d):
    for (x, y) in [(9, 9), (26, 9), (9, 26), (26, 26)]:
        rrect(d, x, y, 13, 13, 3, GREY, 8, SS)


def p_retired(d):
    rrect(d, 8, 10, 32, 9, 2, GREY, 8, SS)
    rrect(d, 11, 21, 26, 18, 3, GREY, 8, SS)
    line(d, [(19, 27), (29, 27)], GREY, 7, SS)


badge('badge_pending', p_pending)
badge('badge_approved', p_approved)
badge('badge_planned', p_planned)
badge('src_photo', p_src_photo)
badge('src_combo', p_src_combo)
badge('badge_retired', p_retired)
print('WARDROBE_ASSETS_DONE')
