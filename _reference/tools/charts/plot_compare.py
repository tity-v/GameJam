# -*- coding: utf-8 -*-
"""改动前后对比：地面起停 / 空中起步 / 空中反向与松手 / 跳跃。
“原来”= GitHub 上 c980182 之前的数值（210/1800/2200/1300/-510/1400）。
”
"""
import math
import os

from PIL import Image, ImageDraw

from plot_speed_curve import SS, gradient, glow, f, YELLOW, AXIS, TXT, TXT_DIM

OLD = (190, 200, 210)
NEW = YELLOW
ROUND = 2.0
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# 实测轨迹（headless）
JUMP_OLD = [0.0, 8.2, 15.9, 23.2, 30.2, 36.7, 42.9, 48.7, 54.1, 59.1, 63.7, 67.9,
            71.7, 75.2, 78.2, 80.9, 83.2, 85.1, 86.6, 87.7, 88.4, 88.7, 88.7, 88.2,
            87.4, 86.2, 84.6, 82.6, 80.2, 77.4, 74.2, 70.7, 66.7, 62.4, 57.7, 52.6,
            47.1, 41.2, 34.9, 28.2, 21.2, 13.7, 5.9, 0.0]
JUMP_NEW = [0.0, 9.8, 19.1, 28.0, 36.4, 44.4, 52.0, 59.2, 65.9, 72.2, 78.1, 83.5,
            88.5, 93.1, 97.2, 100.9, 104.2, 107.0, 109.4, 111.4, 113.0, 114.1,
            114.8, 115.1, 114.9, 114.3, 113.3, 111.8, 109.9, 107.6, 104.9, 101.7,
            98.1, 94.0, 89.6, 84.7, 79.3, 73.6, 67.4, 60.7, 53.7, 46.2, 38.3, 29.9,
            21.2, 11.9, 2.3, 0.0]


def dashed(d, pts, color, width, dash=9, gap=8):
    acc, on = 0.0, True
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        pos = 0.0
        while pos < seg:
            step = min((dash if on else gap) - acc, seg - pos)
            if on:
                xa = x0 + (x1 - x0) * pos / seg
                ya = y0 + (y1 - y0) * pos / seg
                xb = x0 + (x1 - x0) * (pos + step) / seg
                yb = y0 + (y1 - y0) * (pos + step) / seg
                d.line([(xa, ya), (xb, yb)], fill=color, width=width)
            pos += step
            acc += step
            if acc >= (dash if on else gap) - 1e-6:
                acc = 0.0
                on = not on


def panel(d, box, title, xmax, ymin, ymax, xticks, yticks, xlabel, ylabel, note=""):
    x0, y0, x1, y1 = box

    def X(t):
        return (x0 + t / xmax * (x1 - x0)) * SS

    def Y(v):
        return (y1 - (v - ymin) / (ymax - ymin) * (y1 - y0)) * SS

    f_small = f("msyh.ttc", 15 * SS)
    f_title = f("msyhbd.ttc", 21 * SS)

    d.text((x0 * SS, (y0 - 46) * SS), title, font=f_title, fill=TXT)
    if note:
        d.text((x1 * SS, (y0 - 44) * SS), note, font=f_small, fill=TXT_DIM, anchor="rt")

    for t in xticks:
        d.line([(X(t), Y(ymin)), (X(t), Y(ymax))], fill=(120, 175, 215, 30), width=1 * SS)
        d.text((X(t), (y1 + 8) * SS), f"{t:g}", font=f_small, fill=TXT_DIM, anchor="mt")
    for v in yticks:
        d.line([(X(0), Y(v)), (X(xmax), Y(v))], fill=(130, 185, 225, 38), width=1 * SS)
        d.text(((x0 - 10) * SS, Y(v)), f"{v:g}", font=f_small, fill=TXT_DIM, anchor="rm")

    d.line([(X(0), Y(ymin)), (X(0), Y(ymax))], fill=(210, 228, 240, 190), width=2 * SS)
    d.line([(X(0), Y(max(ymin, 0))), (X(xmax), Y(max(ymin, 0)))], fill=(210, 228, 240, 190), width=2 * SS)
    d.text(((x1) * SS, (y1 + 30) * SS), xlabel, font=f_small, fill=TXT_DIM, anchor="rt")
    d.text(((x0 - 46) * SS, (y0 - 8) * SS), ylabel, font=f_small, fill=TXT_DIM, anchor="rb")
    return X, Y


def build_ground():
    def curve(t_press, t_end, vmax, accel, friction, p):
        pts = []
        t = 0.0
        while t <= t_end:
            if t < t_press:
                v = 0.0
            elif t < 0.95:
                v = vmax * min(1.0, ((t - t_press) / (vmax / accel)) ** p)
            else:
                u = min(1.0, (t - 0.95) / (vmax / friction))
                v = vmax * (1.0 - u) ** p
            pts.append((t, v))
            t += 1 / 600.0
        return pts

    old = curve(0.15, 1.18, 210.0, 1800.0, 2200.0, 1.0)
    new = curve(0.15, 1.18, 273.0, 2730.0, 5460.0, 2.0)
    return old, new


def build_air():
    old = [(t / 600.0, 210.0 * min(1.0, (t / 600.0) / 0.16154)) for t in range(0, 70)]
    new = [(t / 600.0, 273.0 * min(1.0, (t / 600.0) / 0.11667)) for t in range(0, 70)]
    return old, new


def build_reverse():
    # 原来：+210 线性收到 -210（1300）
    old_rev = [(t / 600.0, 210.0 - 1300.0 * (t / 600.0)) for t in range(0, int(0.3231 * 600) + 1)]
    old_rev += [(0.3231, -210.0)]
    # 现在：+273 两帧归零，再 7 帧到 -273
    new_rev = [(t / 600.0, 273.0 - 8200.0 * (t / 600.0)) for t in range(0, int(0.0333 * 600) + 1)]
    t0 = 0.0333
    new_rev += [(t / 600.0, -273.0 * min(1.0, ((t / 600.0) - t0) / 0.11667))
                for t in range(int(t0 * 600), int((t0 + 0.11667) * 600) + 1)]
    # 松手
    old_rel = [(t / 600.0, 210.0 - 2200.0 * (t / 600.0)) for t in range(0, int(0.0955 * 600) + 1)]
    new_rel = [(t / 600.0, 273.0 - 400.0 * (t / 600.0)) for t in range(0, int(0.6825 * 600) + 1)]
    return old_rev, new_rev, old_rel, new_rel


def main():
    W, H = 1680, 1360
    img = gradient(W * SS, H * SS)
    img = glow(img, (-200 * SS, 150 * SS, 1200 * SS, 800 * SS), (24, 92, 140), 50)
    d = ImageDraw.Draw(img, "RGBA")

    d.text((80 * SS, 46 * SS), "改动前后对比：所有动过的曲线", font=f("msyhbd.ttc", 42 * SS), fill=TXT)
    d.text((82 * SS, 112 * SS),
           "灰虚线 = 原版（210 / 1800 / 2200 / 1300 / -510 / 1400）　黄线 = 现在（273 / 2730 / 5460 / 2355 / -610 / 1550）",
           font=f("msyh.ttc", 19 * SS), fill=TXT_DIM)

    # ---- 地面 ----
    X, Y = panel(d, (120, 210, 820, 650), "① 地面：起步 + 刹停",
                 1.2, 0, 300, [0, 0.3, 0.6, 0.9, 1.2], [0, 70, 140, 210, 273],
                 "秒", "速度 px/s", "按住 → 松手")
    old, new = build_ground()
    dashed(d, [(X(t), Y(v)) for t, v in old], OLD + (220,), 4 * SS, 9 * SS, 8 * SS)
    d.line([(X(t), Y(v)) for t, v in new], fill=NEW + (255,), width=6 * SS, joint="curve")
    d.text((X(0.29), Y(285)), "6 帧到 273", font=f("msyhbd.ttc", 17 * SS), fill=NEW)
    d.text((X(0.30), Y(60)), "原来 7 帧到 210", font=f("msyh.ttc", 16 * SS), fill=OLD)
    d.text((X(1.06), Y(150)), "3 帧\n停", font=f("msyhbd.ttc", 16 * SS), fill=NEW)
    d.text((X(0.70), Y(40)), "原来 6 帧停", font=f("msyh.ttc", 16 * SS), fill=OLD)

    # ---- 跳跃 ----
    X, Y = panel(d, (900, 210, 1600, 650), "② 跳跃：高度",
                 52, 0, 135, [0, 10, 20, 30, 40, 50], [0, 40, 80, 120],
                 "帧", "高度 px", "按住不放")
    d.line([(X(i), Y(h)) for i, h in enumerate(JUMP_OLD)], fill=OLD + (230,), width=4 * SS,
           joint="curve")
    d.line([(X(i), Y(h)) for i, h in enumerate(JUMP_NEW)], fill=NEW + (255,), width=6 * SS,
           joint="curve")
    d.text((X(3.5), Y(128)), "现在 115.1px / 47 帧", font=f("msyhbd.ttc", 16 * SS), fill=NEW)
    d.text((X(3.5), Y(111)), "原来 88.7px / 44 帧", font=f("msyh.ttc", 16 * SS), fill=OLD)

    # ---- 空中起步 ----
    X, Y = panel(d, (120, 800, 820, 1200), "③ 空中：起步",
                 0.19, 0, 300, [0, 0.05, 0.10, 0.15], [0, 70, 140, 210, 273],
                 "秒", "速度 px/s", "空中按方向")
    old, new = build_air()
    dashed(d, [(X(t), Y(v)) for t, v in old], OLD + (220,), 4 * SS, 9 * SS, 8 * SS)
    d.line([(X(t), Y(v)) for t, v in new], fill=NEW + (255,), width=6 * SS, joint="curve")
    d.text((X(0.118), Y(286)), "7 帧到 273", font=f("msyhbd.ttc", 17 * SS), fill=NEW)
    d.text((X(0.128), Y(100)), "原来 10 帧到 210", font=f("msyh.ttc", 16 * SS), fill=OLD)

    # ---- 空中反向 + 松手 ----
    X, Y = panel(d, (900, 800, 1600, 1200), "④ 空中：反向 / 松手",
                 0.72, -300, 300, [0, 0.2, 0.4, 0.6], [-273, 0, 273],
                 "秒", "速度 px/s", "实线=反向　点线=松手")
    old_rev, new_rev, old_rel, new_rel = build_reverse()
    dashed(d, [(X(t), Y(v)) for t, v in old_rev], OLD + (200,), 4 * SS, 8 * SS, 7 * SS)
    dashed(d, [(X(t), Y(v)) for t, v in old_rel], OLD + (140,), 3 * SS, 4 * SS, 8 * SS)
    d.line([(X(t), Y(v)) for t, v in new_rev], fill=NEW + (255,), width=5 * SS, joint="curve")
    dashed(d, [(X(t), Y(v)) for t, v in new_rel], (240, 170, 60, 210), 3 * SS, 4 * SS, 9 * SS)
    d.text((X(0.16), Y(-200)), "9 帧", font=f("msyhbd.ttc", 15 * SS), fill=NEW)
    d.text((X(0.36), Y(-175)), "原来 19 帧", font=f("msyh.ttc", 15 * SS), fill=OLD)
    d.text((X(0.42), Y(90)), "松手：0.68s 滑 93px", font=f("msyhbd.ttc", 15 * SS),
           fill=(240, 190, 110))
    d.text((X(0.115), Y(252)), "原来松手 0.10s 急停", font=f("msyh.ttc", 15 * SS), fill=OLD)

    d.text((80 * SS, 1258 * SS),
           "所有曲线都来自 headless 逐帧实测；原版数值取自 actor.gd（210 / 1800 / 2200 / 1300 / -510 / 1400）。",
           font=f("msyh.ttc", 18 * SS), fill=(146, 176, 202))
    d.text((80 * SS, 1296 * SS),
           "跳跃图里两条曲线的顶点差 26px，落地差 3 帧；空中反向的“2+7 帧”= 2 帧刹到 0，再用 7 帧加速到反方向满速。",
           font=f("msyh.ttc", 18 * SS), fill=(146, 176, 202))

    out = os.path.join(OUT_DIR, "对比_全部.png")
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(out, quality=95)
    print("saved", out)


if __name__ == "__main__":
    main()
