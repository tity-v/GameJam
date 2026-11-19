# -*- coding: utf-8 -*-
"""跳跃曲线（Height vs Time）。数据来自 headless 实测：
   godot --headless --path _review_GameJam -s _reference/tools/test_jump_curve.gd
jump_velocity -510, gravity 1400, jump_cut 0.65, 60fps。
"""
import os
from PIL import Image, ImageDraw

from plot_speed_curve import (SS, gradient, glow, dash_line, vtext, f, card,
                              YELLOW, AXIS, TXT, TXT_DIM)

FULL = [0.0, 9.8, 19.1, 28.0, 36.4, 44.4, 52.0, 59.2, 65.9, 72.2, 78.1, 83.5, 88.5, 93.1,
        97.2, 100.9, 104.2, 107.0, 109.4, 111.4, 113.0, 114.1, 114.8, 115.1, 114.9, 114.3,
        113.2, 111.6, 109.5, 107.0, 104.0, 100.5, 96.5, 92.1, 87.2, 81.8, 76.0, 69.6, 62.8,
        55.6, 47.8, 39.6, 30.9, 21.8, 12.1, 2.0, 0.0]
TAP = [0.0, 9.8, 15.7, 21.2, 26.2, 30.8, 35.0, 38.7, 42.1, 44.9, 47.4, 49.4, 51.0, 52.2, 52.9,
        53.2, 53.1, 52.5, 51.4, 49.8, 47.8, 45.3, 42.3, 38.9, 35.0, 30.6, 25.7, 20.4, 14.6,
        8.3, 1.5, 0.0]

BLUE = (120, 190, 235)
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def main():
    W, H = 1500, 950
    img = gradient(W * SS, H * SS)
    img = glow(img, (-200 * SS, 200 * SS, 1100 * SS, 700 * SS), (24, 92, 140), 50)
    d = ImageDraw.Draw(img, "RGBA")

    L, R, T, B = 185, 1420, 180, 745
    PW, PH = R - L, B - T
    XMAX, YMAX = 56.0, 130.0

    def X(t):
        return (L + t / XMAX * PW) * SS

    def Y(h):
        return (B - h / YMAX * PH) * SS

    for i in range(0, 47):
        major = i % 10 == 0
        col = (140, 195, 235, 55) if major else (120, 175, 215, 26)
        d.line([(X(i), Y(0)), (X(i), Y(YMAX))], fill=col, width=(2 if major else 1) * SS)
    for h in range(0, 101, 10):
        major = h % 20 == 0
        d.line([(X(0), Y(h)), (X(XMAX), Y(h))],
               fill=(140, 195, 235, 55) if major else (120, 175, 215, 26),
               width=(2 if major else 1) * SS)

    d.line([(X(0), Y(0)), (X(0), Y(YMAX))], fill=AXIS, width=4 * SS)
    d.line([(X(0), Y(0)), (X(XMAX), Y(0))], fill=AXIS, width=4 * SS)
    d.line([(X(XMAX), Y(YMAX)), (X(XMAX), Y(0))], fill=(160, 195, 225, 90), width=1 * SS)

    f_tick = f("msyh.ttc", 17 * SS)
    f_axis = f("ariblk.ttf", 40 * SS)
    for t in (0, 10, 20, 30, 40, 50):
        d.text((X(t), (B + 10) * SS), f"{t}", font=f_tick, fill=TXT_DIM, anchor="mt")
    for h in (0, 20, 40, 60, 80, 100, 120):
        d.text(((L - 12) * SS, Y(h)), f"{h}", font=f_tick, fill=TXT_DIM, anchor="rm")
    d.text(((L - 12) * SS, (T - 26) * SS), "px", font=f_tick, fill=TXT_DIM, anchor="rm")
    vtext(img, (30 * SS, (T + B) / 2 * SS - 90 * SS), "Height", f_axis, AXIS, 90)
    d = ImageDraw.Draw(img, "RGBA")
    d.text(((R - 8) * SS, (B + 36) * SS), "Time", font=f("ariblk.ttf", 34 * SS), fill=AXIS, anchor="rt")
    d.text(((L + 2) * SS, (B + 40) * SS), "单位：帧", font=f_tick, fill=TXT_DIM, anchor="lt")

    # 落地虚线 + 竖排标注（参考图同款）
    dash_line(d, (X(47), Y(0)), (X(47), Y(YMAX)), YELLOW + (150,), 2 * SS)
    vtext(img, (X(47) - 36 * SS, Y(84)), "47 frames", f("msyhbd.ttc", 22 * SS), (255, 214, 120), -90)
    d = ImageDraw.Draw(img, "RGBA")

    # 轻点 1 帧的轨迹
    tap_pts = [(X(i), Y(h)) for i, h in enumerate(TAP)]
    dashed_polyline(d, tap_pts, BLUE + (210,), 4 * SS, 9 * SS, 8 * SS)

    # 按住不放
    pts = [(X(i), Y(h)) for i, h in enumerate(FULL)]
    d.line(pts, fill=YELLOW + (255,), width=7 * SS, joint="curve")

    # 顶点
    ax, ay = X(23), Y(115.1)
    d.ellipse([ax - 5 * SS, ay - 5 * SS, ax + 5 * SS, ay + 5 * SS],
              fill=(40, 32, 8), outline=YELLOW, width=2 * SS)
    dash_line(d, (X(0), ay), (ax, ay), (255, 255, 255, 70), 1 * SS, 7, 7)

    f_note = f("msyhbd.ttc", 19 * SS)
    d.text((X(24.2), Y(126)), "顶点 115.1px ｜ 23 帧", font=f_note, fill=YELLOW, anchor="lm")
    d.text((X(27.0), Y(74)), "按住：47 帧落地", font=f_note, fill=YELLOW, anchor="lm")
    d.text((X(31.0), Y(10)), "轻点 1 帧", font=f_note, fill=BLUE, anchor="lm")

    d.text((66 * SS, 44 * SS), "跳跃曲线：一个 115.1px 的抛物线", font=f("msyhbd.ttc", 40 * SS), fill=TXT)
    d.text((66 * SS, 102 * SS),
           "jump_velocity -610 ｜ gravity 1550 ｜ 下落 ×1.1 ｜ jump_cut 0.65 ｜ 60 fps ｜ 实测来自 headless 逐帧记录",
           font=f("msyh.ttc", 20 * SS), fill=TXT_DIM)

    chips = [
        ("按住不放", "115.1px ｜ 47 帧 ｜ 0.78s", YELLOW),
        ("轻点 1 帧", "53.2px ｜ 32 帧 ｜ 0.53s", BLUE),
        ("按 6 帧", "77.8px ｜ 37 帧 ｜ 0.62s", (150, 205, 240)),
    ]
    cw, gap = 430, 34
    x0 = 66
    for i, (head, val, col) in enumerate(chips):
        bx = x0 + i * (cw + gap)
        card(d, (bx, 824, bx + cw, 904), 16)
        d.line([((bx + 16) * SS, 840 * SS), ((bx + 16) * SS, 888 * SS)], fill=col + (255,), width=4 * SS)
        d.text(((bx + 34) * SS, 834 * SS), head, font=f("msyh.ttc", 18 * SS), fill=TXT_DIM)
        d.text(((bx + 34) * SS, 862 * SS), val, font=f("msyhbd.ttc", 22 * SS), fill=col)

    d.text((66 * SS, 922 * SS),
           "上升 1550、下落 1550×1.1=1705：下落半程短 1 帧，落地比上升快 5%，顶点略偏前（23 / 47 帧）。",
           font=f("msyh.ttc", 19 * SS), fill=(146, 176, 202))

    out = os.path.join(OUT_DIR, "跳跃曲线.png")
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(out, quality=95)
    print("saved", out)


def dashed_polyline(d, pts, color, width, dash=9, gap=8):
    import math
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


if __name__ == "__main__":
    main()
