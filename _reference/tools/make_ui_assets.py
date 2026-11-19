"""生成 UI 用的两张/组贴图：玩家死亡叉号、暂停「继续」按钮的三种状态。

以前这两样是 _draw 里的矢量绘制，美术没法替换、尺寸也写死在代码里。
现在烘成 PNG：换图即换外观，尺寸由节点决定。

配色沿用原版（main.gd 的色板），所以换完画面和之前逐像素一致。
"""
import os, sys, zlib, struct

FORCE = "--force" in sys.argv
REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)

ACTORS = os.path.join(ROOT, "assets", "actors")
UI = os.path.join(ROOT, "assets", "ui")
for d in (ACTORS, UI):
    os.makedirs(d, exist_ok=True)

SS = 4  # 每像素 4x4 超采样，边缘不锯齿


class Canvas:
    """浮点 RGBA 画布，source-over 混合。"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    def blend(self, i, r, g, b, a):
        if a <= 0.0:
            return
        dst = self.px[i]
        out_a = a + dst[3] * (1.0 - a)
        if out_a <= 1e-6:
            return
        for k, v in enumerate((r, g, b)):
            dst[k] = (v * a + dst[k] * dst[3] * (1.0 - a)) / out_a
        dst[3] = out_a

    def fill(self, test, color, alpha=1.0):
        """test(x, y) -> bool，坐标是像素内的浮点子采样位置。"""
        r, g, b = color
        for y in range(self.h):
            for x in range(self.w):
                hits = 0
                for sy in range(SS):
                    for sx in range(SS):
                        if test(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS):
                            hits += 1
                if hits:
                    self.blend(y * self.w + x, r, g, b, alpha * hits / (SS * SS))

    def rows(self):
        out = []
        for y in range(self.h):
            row = bytearray()
            for x in range(self.w):
                p = self.px[y * self.w + x]
                row += bytes([round(c * 255) for c in p[:3]]) + bytes([round(p[3] * 255)])
            out.append(bytes(row))
        return out


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    if os.path.exists(path) and not FORCE:
        print("%s 已存在，跳过（要重建请加 --force）" % os.path.relpath(path, ROOT))
        return
    with open(path, "wb") as f:
        f.write(png)
    print("%s %dx%d" % (os.path.relpath(path, ROOT), w, h))


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    t = 0.0 if (vx * vx + vy * vy) == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / (vx * vx + vy * vy)))
    dx, dy = px - (ax + t * vx), py - (ay + t * vy)
    return (dx * dx + dy * dy) ** 0.5


def tri_test(p, q, r):
    """返回 point in triangle 的判定函数（同一侧法）。"""
    def sign(ax, ay, bx, by, cx, cy):
        return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy)

    def test(x, y):
        d1 = sign(x, y, p[0], p[1], q[0], q[1])
        d2 = sign(x, y, q[0], q[1], r[0], r[1])
        d3 = sign(x, y, r[0], r[1], p[0], p[1])
        neg = d1 < 0 or d2 < 0 or d3 < 0
        pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (neg and pos)
    return test


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ---------------- 玩家死亡叉号 ----------------
# 尺寸与 player.png 一致（28x38），player.gd 按碰撞体尺寸整体缩放它
CW, CH = 28, 38
c = Canvas(CW, CH)
CROSS = hexc("ef8b80")
c.fill(lambda x, y: seg_dist(x, y, 3, 5, 25, 32) <= 1.0, CROSS)
c.fill(lambda x, y: seg_dist(x, y, 25, 5, 3, 32) <= 1.0, CROSS)
write_png(os.path.join(ACTORS, "player_death_cross.png"), CW, CH, c.rows())

# ---------------- 暂停「继续」按钮 ----------------
# 92x92，与原 92x92 的节点尺寸 1:1，不需要缩放
BW = BH = 92
CX, CY = BW / 2.0, BH / 2.0
RADIUS = CY - 3.0
DISC = hexc("16202b")
RING_IDLE = hexc("40585f")
GLYPH_IDLE = hexc("d5dde0")
ACCENT = hexc("7be3b9")

S = RADIUS * 0.42
TRI = (
    (CX - S * 0.55, CY - S),
    (CX - S * 0.55, CY + S),
    (CX + S * 0.95, CY),
)
in_tri = tri_test(*TRI)


def circle_test(cx, cy, r_in, r_out):
    def test(x, y):
        d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
        return r_in <= d <= r_out
    return test


def render_button(ring, glyph, ring_w=2.0, disc= DISC):
    cv = Canvas(BW, BH)
    cv.fill(circle_test(CX, CY, 0.0, RADIUS), disc)
    cv.fill(circle_test(CX, CY, RADIUS - ring_w, RADIUS), ring)
    cv.fill(in_tri, glyph)
    return cv


write_png(os.path.join(UI, "continue_normal.png"), BW, BH,
          render_button(RING_IDLE, GLYPH_IDLE).rows())
write_png(os.path.join(UI, "continue_hover.png"), BW, BH,
          render_button(ACCENT, ACCENT).rows())
# 按下：环更粗、圆盘压暗一点，给一点"按进去"的手感
write_png(os.path.join(UI, "continue_pressed.png"), BW, BH,
          render_button(ACCENT, ACCENT, ring_w=3.0,
                        disc=tuple(ch * 0.82 for ch in DISC)).rows())
