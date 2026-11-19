"""生成主角贴图（28x38 白色方块 + 2px 描边，对应原游戏 draw_rect 的玩家配色）。"""
import os, sys, zlib, struct

FORCE = "--force" in sys.argv

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
sys.path.insert(0, REF)
from level01_data import *  # noqa

ACTORS = os.path.join(ROOT, "assets", "actors")
os.makedirs(ACTORS, exist_ok=True)

W, H = 28, 38
FILL = (240, 250, 230)   # Color(0.94, 0.98, 0.9)
EDGE = (219, 251, 255)   # dbfbff
BORDER = 2


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


rows = []
for y in range(H):
    row = bytearray()
    for x in range(W):
        edge = x < BORDER or y < BORDER or x >= W - BORDER or y >= H - BORDER
        row += bytes(EDGE if edge else FILL) + b"\xff"
    rows.append(bytes(row))

out = os.path.join(ACTORS, "player.png")
if os.path.exists(out) and not FORCE:
    print("player.png 已存在，跳过（要重建请加 --force）")
else:
    write_png(out, W, H, rows)
    print("player.png", W, "x", H)
