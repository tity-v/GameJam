# -*- coding: utf-8 -*-
"""按参考图的样式，绘制 YourPastSelf / GameJam 项目的水平加减速曲线。
数值来源：scripts/player.gd（与 scripts/platformer/actor.gd 一致）
  SPEED=210, ACCEL=1800, AIR_ACCEL=1300, FRICTION=2200, 60 fps
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

SS = 2  # 超采样倍数
FONTS = r"C:\Windows\Fonts"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ---------- 参数 ----------
VMAX = 210.0
ACCEL = 1800.0
AIR_ACCEL = 1300.0
FRICTION = 2200.0
FPS = 60.0

# ---------- 配色 ----------
BG_TOP = (10, 24, 38)
BG_BOT = (19, 46, 67)
YELLOW = (255, 199, 28)
RED = (196, 78, 92)
GREEN = (54, 166, 116)
AXIS = (238, 245, 250)
TXT = (236, 243, 249)
TXT_DIM = (150, 184, 212)
CARD = (16, 38, 57)


def f(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size))


def gradient(w, h):
    img = Image.new("RGB", (w, h), BG_TOP)
    d = ImageDraw.Draw(img)
    for y in range(h):
        k = y / max(1, h - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * (k ** 0.85)) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img.convert("RGBA")


def glow(img, box, color, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse(box, fill=color + (alpha,))
    from PIL import ImageFilter
    layer = layer.filter(ImageFilter.GaussianBlur(90 * SS))
    return Image.alpha_composite(img, layer)


def dash_line(d, p0, p1, fill, width, dash=10, gap=9):
    x0, y0 = p0
    x1, y1 = p1
    length = math.hypot(x1 - x0, y1 - y0)
    if length == 0:
        return
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    t = 0.0
    while t < length:
        e = min(t + dash, length)
        d.line([(x0 + ux * t, y0 + uy * t), (x0 + ux * e, y0 + uy * e)],
               fill=fill, width=width)
        t = e + gap


def arrow(d, p_from, p_to, fill, width):
    d.line([p_from, p_to], fill=fill, width=width)
    ang = math.atan2(p_to[1] - p_from[1], p_to[0] - p_from[0])
    L = 12 * SS
    for s in (-0.42, 0.42):
        d.line([p_to, (p_to[0] - L * math.cos(ang + s), p_to[1] - L * math.sin(ang + s))],
               fill=fill, width=width)


def vtext(base, xy, text, font, fill, angle=90):
    bbox = font.getbbox(text)
    w, h = bbox[2] - bbox[0] + 8, bbox[3] - bbox[1] + 8
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((4 - bbox[0], 4 - bbox[1]), text, font=font, fill=fill)
    tmp = tmp.rotate(angle, expand=True, resample=Image.BICUBIC)
    base.alpha_composite(tmp, (int(xy[0]), int(xy[1])))


def velocity_profile(t_press, t_release, accel, friction, t_end=1.5, dt=1 / 900.0):
    pts = []
    v = 0.0
    t = 0.0
    while t <= t_end + 1e-9:
        if t < t_press:
            v = 0.0
        elif t < t_release:
            v = min(VMAX, accel * (t - t_press))
        else:
            v = max(0.0, VMAX - friction * (t - t_release))
        pts.append((t, v))
        t += dt
    return pts


def frame_press(accel, dt=1 / 60.0):
    """60fps 下的真实逐帧速度（move_toward 是线性、每帧一步）"""
    vs = []
    v = 0.0
    while v < VMAX - 1e-6:
        v = min(VMAX, v + accel * dt)
        vs.append(v)
    return vs


def text(d, xy, s, font, fill):
    d.text((xy[0] * SS, xy[1] * SS), s, font=font, fill=fill)


def card(d, box, radius=14):
    d.rounded_rectangle([c * SS for c in box], radius=radius * SS, fill=CARD + (235,),
                        outline=(58, 96, 128, 210), width=2 * SS)


# =====================================================================
# 图 1：当前项目曲线
# =====================================================================
def chart_current():
    W, H = 1500, 900
    img = gradient(W * SS, H * SS)
    img = glow(img, (-200 * SS, 220 * SS, 1100 * SS, 700 * SS), (24, 92, 140), 60)
    d = ImageDraw.Draw(img, "RGBA")

    L, R, T, B = 185, 1420, 168, 640
    PW, PH = R - L, B - T
    XMAX, YMAX = 1.5, 280.0

    def X(t):
        return (L + t / XMAX * PW) * SS

    def Y(v):
        return (B - v / YMAX * PH) * SS

    # 网格
    n = 0
    t = 0.0
    while t <= XMAX + 1e-9:
        major = abs(t * 2 - round(t * 2)) < 1e-6 or abs((t * 10) % 5) < 1e-6
        col = (140, 195, 235, 62) if major else (120, 175, 215, 30)
        d.line([(X(t), Y(0)), (X(t), Y(YMAX))], fill=col, width=(2 if major else 1) * SS)
        t += 0.1
    v = 0.0
    while v <= YMAX + 1e-9:
        major = int(round(v)) % 70 == 0
        col = (140, 195, 235, 55) if major else (120, 175, 215, 28)
        d.line([(X(0), Y(v)), (X(XMAX), Y(v))], fill=col, width=(2 if major else 1) * SS)
        v += 35.0

    # 坐标轴
    d.line([(X(0), Y(0)), (X(0), Y(YMAX))], fill=AXIS, width=4 * SS)
    d.line([(X(0), Y(0)), (X(XMAX), Y(0))], fill=AXIS, width=4 * SS)
    d.line([(X(XMAX), Y(YMAX)), (X(XMAX), Y(0))], fill=(160, 195, 225, 90), width=1 * SS)

    # 刻度
    f_tick = f("msyh.ttc", 17 * SS)
    f_axis = f("ariblk.ttf", 40 * SS)
    for tv in (0.0, 0.3, 0.6, 0.9, 1.2, 1.5):
        d.line([(X(tv), Y(0)), (X(tv), Y(0) + 7 * SS)], fill=(170, 200, 225, 170), width=2 * SS)
        d.text((X(tv), (B + 10) * SS), f"{tv:.1f}s", font=f_tick,
               fill=TXT_DIM, anchor="mt")
    for vv in (0.0, 70.0, 140.0, 210.0):
        d.text(((L - 12) * SS, Y(vv)), f"{vv:.0f}", font=f_tick, fill=TXT_DIM, anchor="rm")

    d.text(((L - 12) * SS, (T - 26) * SS), "px/s", font=f_tick, fill=TXT_DIM, anchor="rm")

    vtext(img, (30 * SS, (T + B) / 2 * SS - 80 * SS), "Speed", f_axis, AXIS, 90)
    d = ImageDraw.Draw(img, "RGBA")
    d.text(((R - 8) * SS, (B + 46) * SS), "Time", font=f_axis, fill=AXIS, anchor="rt")

    # 关键时间
    t_press, t_release = 0.20, 1.10
    t_full = VMAX / ACCEL
    t_stop = VMAX / FRICTION

    # 竖直虚线
    for tv in (t_press, t_release):
        dash_line(d, (X(tv), Y(0)), (X(tv), Y(YMAX)), YELLOW + (120,), 2 * SS)
    dash_line(d, (X(t_release + t_stop), Y(0)), (X(t_release + t_stop), Y(YMAX)),
              (225, 232, 238, 70), 2 * SS)

    lbl = f("msyhbd.ttc", 18 * SS)
    d.text((X(t_press) + 9 * SS, Y(268)), "按下", font=lbl, fill=(255, 214, 120), anchor="lb")
    d.text((X(t_release) + 9 * SS, Y(268)), "松手", font=lbl, fill=(255, 214, 120), anchor="lb")
    d.text((X(t_release + t_stop) + 7 * SS, Y(165)), "停住", font=lbl,
           fill=(205, 218, 230), anchor="lm")

    # 参考：软刹车
    soft = velocity_profile(0, t_release, ACCEL, 1000.0)
    soft = [(tv, 0 if tv < t_press else (min(VMAX, ACCEL * (tv - t_press)) if tv < t_release
                                         else max(0.0, VMAX - 1000.0 * (tv - t_release))))
            for tv, _ in soft]

    def poly(pts, fill, width, overlay=True):
        xy = [(X(tv), Y(vv)) for tv, vv in pts]
        d.line(xy, fill=fill, width=width * SS, joint="curve")

    # 空中加速（红，虚线）
    air = [(tv, 0 if tv < t_press else (min(VMAX, AIR_ACCEL * (tv - t_press)) if tv < t_release
                                        else max(0.0, VMAX - FRICTION * (tv - t_release))))
           for tv, _ in velocity_profile(0, t_release, ACCEL, FRICTION)]
    xy = [(X(tv), Y(vv)) for tv, vv in air]
    # 手绘虚线折线
    for i in range(len(xy) - 1):
        if i % 6 < 3:
            d.line([xy[i], xy[i + 1]], fill=RED + (235,), width=4 * SS)

    # 软刹（绿）
    poly(soft, GREEN + (225,), 5)

    # 当前（黄）
    cur = velocity_profile(t_press, t_release, ACCEL, FRICTION, t_end=1.42)
    cur = [(tv, 0 if tv < t_press else (min(VMAX, ACCEL * (tv - t_press)) if tv < t_release
                                        else max(0.0, VMAX - FRICTION * (tv - t_release))))
           for tv, _ in cur]
    poly(cur, YELLOW, 7)

    # 60fps 逐帧点
    for k, vv in enumerate(frame_press(ACCEL), start=1):
        tv = t_press + k / FPS
        d.ellipse([X(tv) - 4 * SS, Y(vv) - 4 * SS, X(tv) + 4 * SS, Y(vv) + 4 * SS],
                  fill=(40, 32, 8), outline=YELLOW, width=2 * SS)
    for k in range(1, 6):
        vv = max(0.0, VMAX - FRICTION * k / FPS)
        tv = t_release + k / FPS
        d.ellipse([X(tv) - 4 * SS, Y(vv) - 4 * SS, X(tv) + 4 * SS, Y(vv) + 4 * SS],
                  fill=(40, 32, 8), outline=YELLOW, width=2 * SS)

    # 曲线标注
    f_note = f("msyhbd.ttc", 19 * SS)
    d.text((X(0.30), Y(234)), "地面 1800（当前）", font=f_note, fill=YELLOW, anchor="lm")
    d.text((X(0.40), Y(180)), "空中 1300", font=f_note, fill=RED, anchor="lm")
    d.text((X(1.235), Y(105)), "软刹 1000", font=f_note, fill=GREEN, anchor="lm")

    # 头部
    f_title = f("msyhbd.ttc", 40 * SS)
    f_sub = f("msyh.ttc", 20 * SS)
    d.text((66 * SS, 44 * SS), "你项目里的移动曲线", font=f_title, fill=TXT)
    d.text((66 * SS, 100 * SS),
           "player.gd  L16–L22 ｜ SPEED 210 ｜ ACCEL 1800 ｜ AIR_ACCEL 1300 ｜ FRICTION 2200 ｜ 60 fps",
           font=f_sub, fill=TXT_DIM)

    # 底部数据卡
    chips = [
        ("起步 0 → 210", "0.117s ｜ 7 帧 ｜ 位移 12px", YELLOW),
        ("巡航", "210 px/s ｜ 横穿 1280 屏 = 6.1s", (150, 205, 240)),
        ("刹停 210 → 0", "0.095s ｜ 6 帧 ｜ 位移 10px", YELLOW),
    ]
    cw, gap = 430, 34
    x0 = 66
    for i, (head, val, col) in enumerate(chips):
        bx = x0 + i * (cw + gap)
        card(d, (bx, 748, bx + cw, 828), 16)
        d.line([((bx + 16) * SS, 764 * SS), ((bx + 16) * SS, 812 * SS)], fill=col + (255,), width=4 * SS)
        d.text(((bx + 34) * SS, 758 * SS), head, font=f("msyh.ttc", 18 * SS), fill=TXT_DIM)
        d.text(((bx + 34) * SS, 786 * SS), val, font=f("msyhbd.ttc", 22 * SS), fill=col)

    d.text((66 * SS, 854 * SS),
           "12px 只有 0.43 个身位（角色宽 28px），所以在游戏里看到的是“瞬间起步、瞬间停住”，不是斜坡。",
           font=f("msyh.ttc", 19 * SS), fill=(146, 176, 202))

    out = os.path.join(OUT_DIR, "移动曲线_当前.png")
    img = img.resize((W, H), Image.LANCZOS)
    img.convert("RGB").save(out, quality=95)
    print("saved", out)


# =====================================================================
# 图 2：调参对比
# =====================================================================
def chart_presets():
    W, H = 1600, 860
    img = gradient(W * SS, H * SS)
    d = ImageDraw.Draw(img, "RGBA")

    L1, R1, L2, R2 = 130, 790, 890, 1550
    T, B = 220, 720
    PH = B - T

    f_title = f("msyhbd.ttc", 38 * SS)
    f_sub = f("msyh.ttc", 19 * SS)
    f_panel = f("msyhbd.ttc", 24 * SS)
    f_lbl = f("msyhbd.ttc", 17 * SS)
    f_tick = f("msyh.ttc", 16 * SS)

    d.text((66 * SS, 44 * SS), "改 ACCEL / FRICTION，曲线会变成什么样", font=f_title, fill=TXT)
    d.text((66 * SS, 104 * SS),
           "满速固定 210 px/s；横轴 = 按下（左）/ 松手（右）之后经过的秒数。黄色是项目当前值。",
           font=f_sub, fill=TXT_DIM)

    def panel(L, R, title, xmax, ymax, vr=(0.0, 0.45), names=None):
        PW = R - L
        d.rounded_rectangle([(L - 26) * SS, (T - 58) * SS, (R + 26) * SS, (B + 62) * SS],
                            radius=18 * SS, fill=(14, 32, 49, 190),
                            outline=(56, 92, 124, 160), width=2 * SS)
        d.text(((L + 6) * SS, (T - 44) * SS), title, font=f_panel, fill=TXT)
        d.text(((L - 10) * SS, (T - 14) * SS), "px/s", font=f_tick, fill=TXT_DIM, anchor="rm")

        def X(t):
            return (L + t / xmax * PW) * SS

        def Y(v):
            return (B - v / ymax * PH) * SS

        t = 0.0
        while t <= xmax + 1e-9:
            d.line([(X(t), Y(0)), (X(t), Y(ymax))], fill=(120, 175, 215, 28), width=1 * SS)
            t += xmax / 10
        for vv in (0, 70, 140, 210):
            d.line([(X(0), Y(vv)), (X(xmax), Y(vv))], fill=(140, 195, 235, 45), width=1 * SS)
            d.text(((L - 10) * SS, Y(vv)), f"{vv}", font=f_tick, fill=TXT_DIM, anchor="rm")
        dash_line(d, (X(0), Y(VMAX)), (X(xmax), Y(VMAX)), (255, 255, 255, 55), 1 * SS, 7, 7)
        d.line([(X(0), Y(0)), (X(0), Y(ymax))], fill=(210, 228, 240, 200), width=2 * SS)
        d.line([(X(0), Y(0)), (X(xmax), Y(0))], fill=(210, 228, 240, 200), width=2 * SS)
        for i in range(6):
            tv = xmax * i / 5
            d.text((X(tv), (B + 8) * SS), f"{tv:.2f}", font=f_tick, fill=TXT_DIM, anchor="mt")
        d.text((X(xmax / 2), (B + 40) * SS), "秒", font=f_tick, fill=TXT_DIM, anchor="mt")
        return X, Y

    # ---------------- 左：accel ----------------
    accels = [(2400.0, "2400"), (1800.0, "1800"), (1300.0, "1300"), (900.0, "900"), (600.0, "600")]
    X, Y = panel(L1, R1, "起步：ACCEL（player.gd L18）", 0.45, 250.0)
    for a, name in accels:
        t_full = VMAX / a
        pts = [(t / 400.0, min(VMAX, a * t / 400.0)) for t in range(0, int(0.45 * 400) + 1)]
        col = YELLOW if a == ACCEL else (86, 156, 205)
        wdt = 6 if a == ACCEL else 4
        d.line([(X(t), Y(v)) for t, v in pts], fill=col + (245,), width=wdt * SS, joint="curve")
    # 当前值的肩点标记
    d.ellipse([X(ACCEL and VMAX / ACCEL) - 5 * SS, Y(VMAX) - 5 * SS,
               X(VMAX / ACCEL) + 5 * SS, Y(VMAX) + 5 * SS], fill=(30, 26, 8), outline=YELLOW, width=2 * SS)
    # 图例
    ly = 112
    for a, name in accels:
        col = YELLOW if a == ACCEL else (86, 156, 205)
        d.line([(X(0.245), Y(ly)), (X(0.275), Y(ly))], fill=col + (255,),
               width=(5 if a == ACCEL else 4) * SS)
        d.text((X(0.285), Y(ly)), f"{name}  →  {VMAX / a:.2f}s · {VMAX ** 2 / (2 * a):.0f}px",
               font=f_lbl, fill=(235, 242, 248) if a == ACCEL else TXT_DIM, anchor="lm")
        ly -= 21

    # ---------------- 右：friction ----------------
    frics = [(3200.0, "3200"), (2200.0, "2200"), (1600.0, "1600"), (1200.0, "1200"), (800.0, "800")]
    X, Y = panel(L2, R2, "刹停：FRICTION（player.gd L22）", 0.34, 250.0)
    for fr, name in frics:
        pts = [(t / 400.0, max(0.0, VMAX - fr * t / 400.0)) for t in range(0, int(0.34 * 400) + 1)]
        col = YELLOW if fr == FRICTION else (86, 156, 205)
        wdt = 6 if fr == FRICTION else 4
        d.line([(X(t), Y(v)) for t, v in pts], fill=col + (245,), width=wdt * SS, joint="curve")
    ly = 205
    for fr, name in frics:
        col = YELLOW if fr == FRICTION else (86, 156, 205)
        d.line([(X(0.205), Y(ly)), (X(0.228), Y(ly))], fill=col + (255,),
               width=(5 if fr == FRICTION else 4) * SS)
        d.text((X(0.236), Y(ly)), f"{name}  →  {VMAX / fr:.2f}s · {VMAX ** 2 / (2 * fr):.0f}px",
               font=f_lbl, fill=(235, 242, 248) if fr == FRICTION else TXT_DIM, anchor="lm")
        ly -= 25

    # 底部提示
    d.rounded_rectangle([66 * SS, 790 * SS, 1550 * SS, 844 * SS], radius=14 * SS,
                        fill=(22, 48, 70, 220), outline=(60, 98, 130, 160), width=2 * SS)
    d.text((88 * SS, 807 * SS),
           "换算：到满速时间 = 210 ÷ 参数，位移 = 210×210 ÷ (2×参数)。参数越小坡道越长：600 要 21 帧，2400 只要 5 帧。",
           font=f("msyh.ttc", 18 * SS), fill=(200, 218, 232))

    out = os.path.join(OUT_DIR, "移动曲线_调参对比.png")
    img = img.resize((W, H), Image.LANCZOS)
    img.convert("RGB").save(out, quality=95)
    print("saved", out)


if __name__ == "__main__":
    chart_current()
    chart_presets()
    for a in (600, 900, 1300, 1800, 2400):
        print(f"accel {a}: t={VMAX/a:.3f}s frames={VMAX/a*60:.1f} d={VMAX**2/(2*a):.1f}px")
    for fr in (800, 1200, 1600, 2200, 3200):
        print(f"friction {fr}: t={VMAX/fr:.3f}s frames={VMAX/fr*60:.1f} d={VMAX**2/(2*fr):.1f}px")
