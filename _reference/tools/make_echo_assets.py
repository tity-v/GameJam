"""生成虚影（回声）的贴图：body 半透明方块 + cross 死亡叉号。

规格（与 scripts/echo.gd 的 SIZE 一致，1:1 不缩放）：
    echo_body.png   28x38  填充 rgba(84,174,255,66) 边 rgba(84,174,255,217) 2px，顶边更亮
    echo_cross.png  28x38  透明底 + 红叉 rgba(241,103,103,230) 2px，位置对齐 body

颜色来源：原游戏 draw_rect 的 "54aeff"（alpha 0.26 填充 / 0.85 描边）与 "f16767" 叉号。
"""
import os, sys, zlib, struct

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
OUT = os.path.join(ROOT, "assets", "echo")
os.makedirs(OUT, exist_ok=True)

FORCE = "--force" in sys.argv

W, H = 28, 38
FILL = (84, 174, 255, 66)     # 0.26
EDGE = (84, 174, 255, 217)    # 0.85
EDGE_TOP = (84, 174, 255, 242)  # 顶部亮线 0.95
BORDER = 2
CROSS = (241, 103, 103, 230)  # f16767 / 0.9


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    if os.path.exists(path) and not FORCE:
        print(f"{os.path.basename(path)} 已存在，跳过（要重建请加 --force）")
        return
    open(path, "wb").write(png)
    print(f"{os.path.basename(path)} {w}x{h}")


# ---- body ----
rows = []
for y in range(H):
    row = bytearray()
    for x in range(W):
        on_border = x < BORDER or y < BORDER or x >= W - BORDER or y >= H - BORDER
        if not on_border:
            row += bytes(FILL)
        elif y < BORDER:
            row += bytes(EDGE_TOP)   # 顶边亮一条，暗示"这面能站"
        else:
            row += bytes(EDGE)
    rows.append(bytes(row))
write_png(os.path.join(OUT, "echo_body.png"), W, H, rows)

# ---- cross：与 player.gd 的叉号同一组坐标 (3,5)-(25,32) ----
pts = []
x0, y0, x1, y1 = 3, 5, 25, 32


def line(ax, ay, bx, by):
    steps = max(abs(bx - ax), abs(by - ay)) * 4
    for i in range(steps + 1):
        t = i / steps
        pts.append((ax + (bx - ax) * t, ay + (by - ay) * t))


line(x0, y0, x1, y1)
line(x1, y0, x0, y1)

rows = []
for y in range(H):
    row = bytearray()
    for x in range(W):
        # 到任一采样点距离 < 1.0 → 着色，等效 2px 线宽
        hit = any((px - (x + 0.5)) ** 2 + (py - (y + 0.5)) ** 2 < 1.0 for px, py in pts)
        row += bytes(CROSS if hit else (0, 0, 0, 0))
    rows.append(bytes(row))
write_png(os.path.join(OUT, "echo_cross.png"), W, H, rows)
