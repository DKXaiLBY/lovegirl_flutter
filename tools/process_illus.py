# -*- coding: utf-8 -*-
"""
批次0素材处理：illus_gen 候选(33条x2) -> 白底转透明 -> 贴边检测选片 -> 裁边 -> 缩放 -> assets/images/illus/

选片规则（替代肉眼审图）：候选白转透明后检测主体是否触及图像边缘（贴边=豆包生成时裁切事故），
两张都不贴边选 _1，只有 _1 贴边选 _2，两张都贴边选贴边像素更少的一张并在报告中标记。
边缘 alpha 羽化：深色描边贴纸画风，靠近透明区的保留像素按明度折算半透明，消除白底残留光晕。
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.stdout.reconfigure(encoding="utf-8")

SRC = r"D:\Projects\Personal\lovegirl\assets\images\illus_gen"
DST = r"D:\Projects\Personal\lovegirl\assets\images\illus"
# ui_* 用图展示尺寸更大（启动页/页头），保留更高分辨率
BIG = {"illus_ui_boot", "illus_ui_couple", "illus_ui_kitchen", "illus_ui_timeline",
       "illus_ui_report", "illus_ui_lock"}
MAXDIM_BIG, MAXDIM_STD = 768, 512
WHITE_T = 242   # 近白阈值：min(R,G,B)
TINT_T = 12     # 近白允许的通道极差（容忍奶白/米白底）
BAND = 2        # 描边外侧羽化带宽（像素圈数）
PAD = 8         # 裁边保留留白


def load_rgb_alpha(path):
    im = Image.open(path).convert("RGBA")
    return np.array(im)


def background_mask(arr):
    """纯白底连通域：与图像边界连通的近白像素区。内部白色（云朵/花瓣/高光）被深描边隔开不受影响。"""
    rgb = arr[:, :, :3].astype(np.int16)
    mn = rgb.min(axis=2)
    mx = rgb.max(axis=2)
    whitish = (mn >= WHITE_T) & ((mx - mn) <= TINT_T)
    lab, n = ndimage.label(whitish)
    border = np.concatenate([lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]])
    border_labels = np.unique(border)
    border_labels = border_labels[border_labels != 0]
    return np.isin(lab, border_labels)


def apply_alpha(arr, bg):
    """背景置透明；靠近背景的保留像素按明度折算 alpha（描边深色→不透明，白色残晕→半透明）。"""
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    mn = arr[:, :, :3].astype(np.int16).min(axis=2)
    dark_alpha = np.clip((255 - mn) * 2, 0, 255).astype(np.uint8)
    work = bg.copy()
    for _ in range(BAND):
        band = ndimage.binary_dilation(work) & ~work
        alpha = np.where(band, np.minimum(alpha, dark_alpha), alpha)
        work |= band
    arr[:, :, 3] = alpha
    return arr


def edge_contact(arr):
    """透明化后 3px 边缘带内的不透明像素数（>0 即贴边裁切）。"""
    a = arr[:, :, 3]
    band = np.zeros_like(a, dtype=bool)
    band[:3, :] = True
    band[-3:, :] = True
    band[:, :3] = True
    band[:, -3:] = True
    return int(((a > 8) & band).sum())


def process(path, maxdim):
    arr = load_rgb_alpha(path)
    bg = background_mask(arr)
    arr = apply_alpha(arr, bg)
    contact = edge_contact(arr)
    ys, xs = np.where(arr[:, :, 3] > 8)
    if len(xs) == 0:
        return None, contact, (0, 0)
    x0, x1 = max(0, xs.min() - PAD), min(arr.shape[1], xs.max() + PAD)
    y0, y1 = max(0, ys.min() - PAD), min(arr.shape[0], ys.max() + PAD)
    im = Image.fromarray(arr[y0:y1, x0:x1])
    w, h = im.size
    scale = min(1.0, maxdim / max(w, h))
    if scale < 1.0:
        im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    return im, contact, (x1 - x0, y1 - y0)


def main():
    os.makedirs(DST, exist_ok=True)
    names = sorted({"_".join(f[:-4].split("_")[:-1])
                    for f in os.listdir(SRC) if f.endswith(".png")})
    report = []
    for name in names:
        cands = {}
        for suffix in ("1", "2"):
            p = os.path.join(SRC, "%s_%s.png" % (name, suffix))
            if os.path.exists(p):
                cands[suffix] = process(p, MAXDIM_BIG if name in BIG else MAXDIM_STD)
        if not cands:
            report.append((name, "MISSING", 0, 0, ""))
            continue
        # 选片：贴边少者优先；平手选 _1
        order = sorted(cands.items(), key=lambda kv: (kv[1][1], kv[0]))
        chosen, (im, contact, src_box) = order[0]
        if len(order) == 2 and order[0][1][1] > 0 and order[1][1][1] > 0:
            flag = "BOTH_EDGE_CROP"
        elif chosen == "2":
            flag = "USED_2"
        else:
            flag = ""
        out = os.path.join(DST, "%s.png" % name)
        # 扁平贴纸风 256 色量化，体积降 3-5 倍且视觉无损
        im = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                         dither=Image.Dither.NONE)
        im.save(out, optimize=True)
        kb = os.path.getsize(out) // 1024
        report.append((name, chosen, contact, kb, flag))
        print("%-28s 选_%s 贴边=%4d  %4dx%-4d %3dKB %s" %
              (name, chosen, contact, im.size[0], im.size[1], kb, flag))
    bad = [r for r in report if r[4] == "BOTH_EDGE_CROP" or r[1] in ("MISSING",)]
    print("\n共 %d 条；两张都贴边或缺失：%s" % (len(report), bad if bad else "无"))


if __name__ == "__main__":
    main()
