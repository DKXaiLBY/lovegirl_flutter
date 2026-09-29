# -*- coding: utf-8 -*-
"""拍立得背面质感纹理生成（v3.38.3）：
1) polaroid_back_dark.png  —— 黑色 POD 药囊层：云状深浅+四角药囊压痕+细噪点+微反光
2) polaroid_back_cream.png —— 米白信笺：纸纤维+褶皱痕+微黄不均匀
输出 720x880（比例≈88:107 的 8 倍缩小），使用时铺满背面。
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = r'D:/Projects/Personal/lovegirl/assets/images/deco'
W, H = 720, 880
os_mkdir = None


def cloud_base(base_rgb, blobs, blur, seed):
    """多层随机椭圆模糊叠加 → 云状不均匀底"""
    random.seed(seed)
    layer = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(layer)
    for _ in range(blobs):
        cx, cy = random.randint(-80, W + 80), random.randint(-80, H + 80)
        rx, ry = random.randint(120, 320), random.randint(120, 320)
        v = random.randint(-26, 26)
        if v == 0:
            continue
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=max(0, 128 + v * 4))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base = Image.new('RGB', (W, H), base_rgb)
    # 亮度贴图偏移：中心亮度±
    px = base.load()
    lp = layer.load()
    for y in range(H):
        for x in range(W):
            delta = (lp[x, y] - 128) // 12
            r, g, b = px[x, y]
            px[x, y] = (
                max(0, min(255, r + delta)),
                max(0, min(255, g + delta)),
                max(0, min(255, b + delta)),
            )
    return base


def add_noise(img, amount, alpha_lo, alpha_hi, seed):
    """细噪点（灰度小颗粒）"""
    random.seed(seed)
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = overlay.load()
    for y in range(H):
        for x in range(W):
            if random.random() < 0.35:
                v = random.randint(0, 255)
                a = random.randint(alpha_lo, alpha_hi)
                px[x, y] = (v, v, v, a)
    img = img.convert('RGBA')
    img.alpha_composite(overlay)
    return img


def pod_indents(img):
    """四角药囊压痕：4 个大椭圆更暗区域（显影药囊压在背面留下的痕）"""
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    spots = [(W * 0.20, H * 0.16, 150, 120), (W * 0.78, H * 0.24, 140, 130),
             (W * 0.24, H * 0.82, 155, 125), (W * 0.76, H * 0.78, 150, 135)]
    for cx, cy, rx, ry in spots:
        for i in range(3):
            rr = (rx - i * 18, ry - i * 16)
            d.ellipse([cx - rr[0], cy - rr[1], cx + rr[0], cy + rr[1]],
                      fill=(0, 0, 0, 26 - i * 7))
    overlay = overlay.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(overlay)
    return img


def gloss(img):
    """亮面塑料反光：左上→右下两道斜向高光"""
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.polygon([(0, 0), (W * 0.55, 0), (0, H * 0.45)], fill=(255, 255, 255, 14))
    d.polygon([(W, H), (W * 0.5, H), (W, H * 0.5)], fill=(255, 255, 255, 9))
    overlay = overlay.filter(ImageFilter.GaussianBlur(24))
    img.alpha_composite(overlay)
    return img


def creases(img, seed):
    """信笺褶皱：2-3 条不规则斜线（一亮一暗成对）"""
    random.seed(seed)
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for _ in range(3):
        x0 = random.randint(-60, W)
        y0 = random.randint(0, H // 3)
        dx = random.randint(60, 200)
        dy = H - y0 + random.randint(-80, 80)
        ang = math.atan2(dy, dx)
        lw = random.randint(6, 16)
        d.line([x0, y0, x0 + dx, y0 + dy], fill=(255, 255, 252, 60), width=lw)
        d.line([x0 + lw, y0, x0 + dx + lw, y0 + dy],
               fill=(150, 140, 120, 34), width=lw // 2)
    overlay = overlay.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(overlay)
    return img


# ---------- 1) 黑色 POD 背面 ----------
img = cloud_base((23, 23, 26), blobs=26, blur=90, seed=11).convert('RGBA')
img = pod_indents(img)
img = add_noise(img, 1, 4, 12, seed=21)
img = gloss(img)
img.convert('RGB').save(OUT_DIR + r'/polaroid_back_dark.png', 'PNG')
print('polaroid_back_dark.png done')

# ---------- 2) 米白信笺背面 ----------
img = cloud_base((246, 242, 233), blobs=22, blur=80, seed=33).convert('RGBA')
img = creases(img, seed=44)
img = add_noise(img, 1, 3, 10, seed=55)
# 边缘微暗（相纸四边）
edge = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(edge)
d.rectangle([0, 0, W, H], outline=(120, 110, 95, 40), width=10)
edge = edge.filter(ImageFilter.GaussianBlur(14))
img.alpha_composite(edge)
img.convert('RGB').save(OUT_DIR + r'/polaroid_back_cream.png', 'PNG')
print('polaroid_back_cream.png done')
