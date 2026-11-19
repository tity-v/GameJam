# -*- coding: utf-8 -*-
"""满速 +30% 后的曲线：地面凹形、空中直线（与 scripts/player.gd 的 _approach_speed 一致）。
地面加速 v = V*u^2，刹车 v = V*(1-u)^2；空中 p = 1，就是匀速变化。
"""
import os
from PIL import Image, ImageDraw

from plot_speed_curve import (SS, gradient, glow, dash_line, vtext, f, card,
                              YELLOW, AXIS, TXT, TXT_DIM)

VMAX = 273.0          # 210 * 1.3
ACCEL, FRICTION, AIR = 2730.0, 5460.0, 2355.0
POWER, AIR_POWER = 2.0, 1.0
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def shape(u, rising, p):
    u = max(0.0, min(1.0, u))
    return u ** p if rising else 1.0 - (1.0 - u) ** p


def profile(t_press, t_release, t_end=1.5):
    pts, t = [], 0.0
    while t <= t_end + 1e-9:
        if t < t_press:
            v = 0.0
        elif t < t_release:
            v = VMAX * shape((t - t_press) / (VMAX / ACCEL), True, POWER)
        else:
            v = VMAX * (1.0 - shape((t - t_release) / (VMAX / FRICTION), False, POWER))
        pts.append((t, v))
        t += 1 / 900.0
    return pts


def dashed_polyline(d, pts, color, width, dash=9, gap=8):
    """按弧长画虚线：pts 是已经换算好的像素点。"""
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


def main():
    W, H = 1500, 1010
    img = gradient(W * SS, H * SS)
    img = glow(img, (-200 * SS, 220 * SS, 1100 * SS, 650 * SS), (24, 92, 140), 55)
    d = ImageDraw.Draw(img, "RGBA")

    L, R, T, B = 185, 1420, 160, 545
    PW, PH = R - L, B - T
    XMAX, YMAX = 1.5, 300.0

    def X(t):
        return (L + t / XMAX * PW) * SS

    def Y(v):
        return (B - v / YMAX * PH) * SS

    t = 0.0
    while t <= XMAX + 1e-9:
        major = abs((t * 10) % 5) < 1e-6
        d.line([(X(t), Y(0)), (X(t), Y(YMAX))],
               fill=(140, 195, 235, 58) if major else (120, 175, 215, 30), width=(2 if major else 1) * SS)
        t += 0.1
    v = 0.0
    while v <= YMAX + 1e-9:
        major = int(round(v)) % 70 == 0
        d.line([(X(0), Y(v)), (X(XMAX), Y(v))],
               fill=(140, 195, 235, 55) if major else (120, 175, 215, 26), width=(2 if major else 1) * SS)
        v += 30.0

    d.line([(X(0), Y(0)), (X(0), Y(YMAX))], fill=AXIS, width=4 * SS)
    d.line([(X(0), Y(0)), (X(XMAX), Y(0))], fill=AXIS, width=4 * SS)
    d.line([(X(XMAX), Y(YMAX)), (X(XMAX), Y(0))], fill=(160, 195, 225, 90), width=1 * SS)

    f_tick = f("msyh.ttc", 17 * SS)
    f_axis = f("ariblk.ttf", 40 * SS)
    for tv in (0.0, 0.3, 0.6, 0.9, 1.2, 1.5):
        d.text((X(tv), (B + 10) * SS), f"{tv:.1f}s", font=f_tick, fill=TXT_DIM, anchor="mt")
    for vv in (0.0, 70.0, 140.0, 210.0, 273.0):
        d.text(((L - 12) * SS, Y(vv)), f"{vv:.0f}", font=f_tick, fill=TXT_DIM, anchor="rm")
    d.text(((L - 12) * SS, (T - 26) * SS), "px/s", font=f_tick, fill=TXT_DIM, anchor="rm")
    vtext(img, (30 * SS, (T + B) / 2 * SS - 80 * SS), "Speed", f_axis, AXIS, 90)
    d = ImageDraw.Draw(img, "RGBA")
    d.text(((R - 8) * SS, (B + 34) * SS), "Time", font=f_axis, fill=AXIS, anchor="rt")

    t_press, t_release = 0.20, 1.10
    t_acc, t_stop = VMAX / ACCEL, VMAX / FRICTION

    for tv in (t_press, t_release):
        dash_line(d, (X(tv), Y(0)), (X(tv), Y(YMAX)), YELLOW + (110,), 2 * SS)

    lbl = f("msyhbd.ttc", 18 * SS)
    d.text((X(t_press) + 9 * SS, Y(268)), "按下", font=lbl, fill=(255, 214, 120), anchor="lb")
    d.text((X(t_release) + 9 * SS, Y(268)), "松手", font=lbl, fill=(255, 214, 120), anchor="lb")

    for (x0, y0, x1, y1) in ((t_press, 0, t_press + t_acc, VMAX),
                             (t_release, VMAX, t_release + t_stop, 0)):
        dash_line(d, (X(x0), Y(y0)), (X(x1), Y(y1)), (200, 210, 220, 150), 2 * SS, 8, 8)
    d.text((X(0.225), Y(200)), "直线", font=lbl, fill=(178, 192, 204), anchor="lm")
    d.text((X(1.115), Y(150)), "直线", font=lbl, fill=(178, 192, 204), anchor="lm")

    d.line([(X(t), Y(v)) for t, v in profile(t_press, t_release)],
           fill=YELLOW + (255,), width=7 * SS, joint="curve")

    for k in range(1, 7):
        cx, cy = X(t_press + k / 60.0), Y(VMAX * shape(k / 6.0, True, POWER))
        d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS],
                  fill=(40, 32, 8), outline=YELLOW, width=2 * SS)
    for k in range(1, 3):
        cx, cy = X(t_release + k / 60.0), Y(VMAX * (1 - shape(k / 3.0, False, POWER)))
        d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS],
                  fill=(40, 32, 8), outline=YELLOW, width=2 * SS)

    f_note = f("msyhbd.ttc", 19 * SS)
    d.text((X(0.33), Y(282)), "凹形：慢起，后段越走越快", font=f_note, fill=YELLOW, anchor="lm")
    d.text((X(1.175), Y(70)), "凹形：先掉速再收", font=f_note, fill=YELLOW, anchor="lm")
    d.text((X(0.19), Y(120)), "6 帧", font=f_note, fill=(255, 214, 120), anchor="rm")
    d.text((X(1.155), Y(228)), "3 帧", font=f_note, fill=(255, 214, 120), anchor="lm")

    d.text((66 * SS, 40 * SS), "满速 273（+30%）· 地面 6 帧凹形 / 3 帧凹形",
           font=f("msyhbd.ttc", 40 * SS), fill=TXT)
    d.text((66 * SS, 98 * SS),
           "player.gd ｜ SPEED 273 ｜ ACCEL 2730 ｜ AIR 2355 ｜ FRICTION 5460 ｜ CURVE_POWER 2.0 ｜ AIR_POWER 1.0",
           font=f("msyh.ttc", 20 * SS), fill=TXT_DIM)

    # ---------------- 空中小图 ----------------
    PT, PB = 690, 885
    PX0, PX1 = 210, 800
    d.rounded_rectangle([(L - 26) * SS, (PT - 50) * SS, (R + 26) * SS, (PB + 40) * SS],
                        radius=18 * SS, fill=(14, 32, 49, 190), outline=(56, 92, 124, 160), width=2 * SS)
    d.text(((PX0 + 6) * SS, (PT - 38) * SS), "空中起步 0 → 273（7 帧）：改成直线", font=f("msyhbd.ttc", 24 * SS), fill=TXT)

    tx_max = 0.122

    def AX(t):
        return (PX0 + t / tx_max * (PX1 - PX0)) * SS

    def AY(v):
        return (PB - v / 300.0 * (PB - PT)) * SS

    for i in range(8):
        tv = tx_max * i / 7
        d.line([(AX(tv), AY(0)), (AX(tv), AY(300))], fill=(120, 175, 215, 30), width=1 * SS)
    for vv in (0.0, 70.0, 140.0, 210.0, 273.0):
        d.line([(AX(0), AY(vv)), (AX(tx_max), AY(vv))], fill=(140, 195, 235, 45), width=1 * SS)
        d.text(((PX0 - 10) * SS, AY(vv)), f"{vv:.0f}", font=f_tick, fill=TXT_DIM, anchor="rm")
    d.line([(AX(0), AY(0)), (AX(0), AY(300))], fill=(210, 228, 240, 200), width=2 * SS)
    d.line([(AX(0), AY(0)), (AX(tx_max), AY(0))], fill=(210, 228, 240, 200), width=2 * SS)

    for pt, col in ((AIR_POWER, YELLOW), (POWER, (196, 206, 216))):
        if pt == POWER:
            pts = [(AX(u * 7 / 60.0), AY(VMAX * shape(u, True, pt))) for u in [i / 40 for i in range(41)]]
            dashed_polyline(d, pts, col + (215,), 4 * SS, 10 * SS, 9 * SS)
        else:
            pts = [(AX(k / 60.0), AY(VMAX * shape(k / 7.0, True, pt))) for k in range(0, 8)]
            d.line(pts, fill=col + (255,), width=6 * SS, joint="curve")
    for k in range(1, 8):
        cx, cy = AX(k / 60.0), AY(VMAX * shape(k / 7.0, True, AIR_POWER))
        d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS],
                  fill=(40, 32, 8), outline=YELLOW, width=2 * SS)

    d.text((AX(tx_max * 0.02), (PB + 14) * SS), "0", font=f_tick, fill=TXT_DIM)
    d.text((AX(tx_max) - 40 * SS, (PB + 14) * SS), "0.12s", font=f_tick, fill=TXT_DIM)
    d.text(((PX1 + 40) * SS, (PT + 30) * SS), "黄线：现在（直线）", font=f_note, fill=YELLOW)
    d.text(((PX1 + 40) * SS, (PT + 62) * SS), "灰虚线：之前（凹形，第 1 帧只加 4px/s）", font=f_note, fill=(196, 206, 216))
    d.text(((PX1 + 40) * SS, (PT + 104) * SS), "第 1 帧速度：4 → 39 px/s", font=f("msyh.ttc", 19 * SS), fill=TXT_DIM)
    d.text(((PX1 + 40) * SS, (PT + 134) * SS), "地面那条凹形曲线没动，只换了空中的形状。", font=f("msyh.ttc", 19 * SS), fill=TXT_DIM)

    # 底部数据卡
    chips = [
        ("起步 0 → 273", "0.10s ｜ 6 帧 ｜ 位移 9px", YELLOW),
        ("刹停 273 → 0", "0.05s ｜ 3 帧 ｜ 位移 5px", YELLOW),
        ("空中 0 → 273", "0.12s ｜ 7 帧 ｜ 直线", (150, 205, 240)),
    ]
    cw, gap = 430, 34
    x0 = 66
    for i, (head, val, col) in enumerate(chips):
        bx = x0 + i * (cw + gap)
        card(d, (bx, 932, bx + cw, 1004), 16)
        d.line([((bx + 16) * SS, 944 * SS), ((bx + 16) * SS, 996 * SS)], fill=col + (255,), width=4 * SS)
        d.text(((bx + 34) * SS, 938 * SS), head, font=f("msyh.ttc", 18 * SS), fill=TXT_DIM)
        d.text(((bx + 34) * SS, 962 * SS), val, font=f("msyhbd.ttc", 22 * SS), fill=col)

    out = os.path.join(OUT_DIR, "移动曲线_新版.png")
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(out, quality=95)
    print("saved", out)
    print("ground:", [round(VMAX * shape(k / 6, True, POWER), 1) for k in range(1, 7)])
    print("air:", [round(VMAX * shape(k / 8, True, AIR_POWER), 1) for k in range(1, 9)])


if __name__ == "__main__":
    main()
