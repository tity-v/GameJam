"""生成物块贴图 + Godot 物块场景。

贴图已改造成「九宫格源图」：小尺寸可平铺/可拉伸，不再由美术画准最终尺寸。
- 实心块：32x32，顶部 3px 亮线固定，其余拉伸 → 任意高度的平台顶边都不变粗
- 门/压力板：8x8 纯色，整块拉伸
- 出口：16x16，3px 边框固定 → 任意尺寸边框都不变形
- 尖刺：20x20 单元，用 TILE 模式横向重复，不拉伸

尺寸的唯一来源是场景里的 block_size（见 scripts/block.gd），
贴图尺寸和碰撞尺寸都从它派生，改一处即可。
"""
import os, zlib, struct, sys

# ---- 防覆盖保护：素材已是美术维护的正式资产，已存在就跳过，除非 --force ----
FORCE = "--force" in sys.argv
SKIPPED = []


def guard(path):
    if os.path.exists(path) and not FORCE:
        SKIPPED.append(os.path.relpath(path, ROOT))
        return False
    return True

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
sys.path.insert(0, REF)
from level01_data import *  # noqa

ASSETS = os.path.join(ROOT, "assets", "blocks")
BLOCKS = os.path.join(ROOT, "scenes", "blocks")
LEVELS = os.path.join(ROOT, "scenes", "levels")
for d in (ASSETS, BLOCKS, LEVELS):
    os.makedirs(d, exist_ok=True)


def write_png(path, w, h, rows):
    """rows: list[bytes] 长度 h，每行 w*4 字节 RGBA"""
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    if not guard(path):
        return
    with open(path, "wb") as f:
        f.write(png)


def solid_rows(w, h, fill, top, top_h=3):
    """顶部 top_h 行为亮线，其余为填充色。九宫格只需保留顶边，横向拉伸纯色不掉质量。"""
    body = bytes(fill) + b"\xff"
    line = bytes(top) + b"\xff"
    out = []
    for y in range(h):
        row = line if y < top_h else body
        out.append(row * w)
    return out


def flat_rows(w, h, color):
    px = bytes(color) + b"\xff"
    return [px * w for _ in range(h)]


def exit_rows(w, h, border, fill, bw=3):
    out = []
    for y in range(h):
        row = bytearray()
        for x in range(w):
            if x < bw or y < bw or x >= w - bw or y >= h - bw:
                row += bytes(border) + b"\xff"
            else:
                row += bytes(fill)
        out.append(bytes(row))
    return out


def spike_tile(seg_w, seg_h, color):
    """单个 20 宽的锯齿图块：底宽 20，顶点在顶部中心 (10, 0)。"""
    out = []
    for y in range(seg_h):
        t = y / max(1, seg_h - 1)          # 0 顶部 -> 1 底部
        half = t * 10.0
        cx = 10.0
        row = bytearray()
        for x in range(seg_w):
            if abs(x + 0.5 - cx) <= half:
                row += bytes(color) + b"\xff"
            else:
                row += b"\x00\x00\x00\x00"
        out.append(bytes(row))
    return out


# ---------------- 贴图 ----------------
# 每项: (key, node, 中文名, 默认宽, 默认高, 九宫格 margin 上下左右, 贴图规格)

g = SOLIDS[0]
wl = SOLIDS[1]
p = PLATES[0]
d = DOORS[0]
e = EXIT

# 实心块源图 32x32：顶部 3px 亮线
write_png(os.path.join(ASSETS, "solid_ground.png"), 32, 32,
          solid_rows(32, 32, SOLID_FILL, SOLID_TOP))
write_png(os.path.join(ASSETS, "solid_wall.png"), 32, 32,
          solid_rows(32, 32, SOLID_FILL, SOLID_TOP))
# 纯色块源图 8x8
write_png(os.path.join(ASSETS, "door.png"), 8, 8, flat_rows(8, 8, DOOR))
write_png(os.path.join(ASSETS, "plate_off.png"), 8, 8, flat_rows(8, 8, PLATE_OFF))
# 出口源图 16x16：3px 边框 + 半透明内部
write_png(os.path.join(ASSETS, "exit.png"), 16, 16,
          exit_rows(16, 16, EXIT_BORDER, EXIT_FILL))
# 尖刺单元保持 20x20（平铺，不拉伸）
write_png(os.path.join(ASSETS, "spike_tile.png"), 20, 20, spike_tile(20, 20, SPIKE))

specs = [
    # key, 根节点名, 中文名, 默认 w, 默认 h, margins(t,r,b,l), patch 类型, 有无碰撞
    ("solid_ground", "SolidGround", "地面 Ground", g[2], g[3], (3, 0, 0, 0), "nine", True),
    ("solid_wall", "SolidWall", "左墙 Wall", wl[2], wl[3], (3, 0, 0, 0), "nine", True),
    ("plate_off", "PlateOff", "压力板 Plate (未激活)", p[2], p[3], (0, 0, 0, 0), "nine", False),
    ("door", "Door", "门 Door", d[2], d[3], (0, 0, 0, 0), "nine", True),
    ("exit", "LevelExit", "出口 Exit", e[2], e[3], (3, 3, 3, 3), "nine", False),
    ("spike_tile", "SpikeTile", "尖刺单元 Spike (20x20 平铺)", 20, 20, (0, 0, 0, 0), "tile", False),
]

for key, node, label, w, h, margins, patch, solid in specs:
    if patch == "tile":
        patch_decl = (
            f'[node name="Patch" type="TextureRect" parent="."]\n'
            f'size = Vector2({w}, {h})\n'
            f'texture = ExtResource("1_{key}")\n'
            f'stretch_mode = 1\n'          # 1 = TILE：横向重复而不是拉长
        )
    else:
        mt, mr, mb, ml = margins
        lines = [
            f'[node name="Patch" type="NinePatchRect" parent="."]',
            f'size = Vector2({w}, {h})',
            f'texture = ExtResource("1_{key}")',
        ]
        if mt:
            lines.append(f'patch_margin_top = {mt}')
        if mr:
            lines.append(f'patch_margin_right = {mr}')
        if mb:
            lines.append(f'patch_margin_bottom = {mb}')
        if ml:
            lines.append(f'patch_margin_left = {ml}')
        patch_decl = "\n".join(lines)

    head = (
        f'[gd_scene load_steps={4 if solid else 3} format=3]\n\n'
        f'[ext_resource type="Texture2D" path="res://assets/blocks/{key}.png" id="1_{key}"]\n'
        f'[ext_resource type="Script" path="res://scripts/block.gd" id="2_block"]\n'
    )

    sub = ""
    if solid:
        sub = (
            f'\n[sub_resource type="RectangleShape2D" id="1_shape"]\n'
            f'resource_local_to_scene = true\n'
            f'size = Vector2({w}, {h})\n'   # 每个实例独立一份，改一个不会串到同类
        )

    root_type = "StaticBody2D" if solid else "Node2D"
    body = (
        f'\n[node name="{node}" type="{root_type}"]\n'
        f'script = ExtResource("2_block")\n'
        f'block_size = Vector2({w}, {h})\n\n'
        f'{patch_decl}\n'
    )
    if solid:
        body += (
            f'\n[node name="Collision" type="CollisionShape2D" parent="."]\n'
            f'position = Vector2({w / 2}, {h / 2})\n'
            f'shape = SubResource("1_shape")\n'
        )

    tscn = head + sub + body
    tp = os.path.join(BLOCKS, f"{key}.tscn")
    if guard(tp):
        with open(tp, "w", encoding="utf-8", newline="\n") as f:
            f.write(tscn)

if SKIPPED:
    print("已存在，跳过 %d 个（要重建请加 --force）：" % len(SKIPPED))
print("贴图/物块场景:", len(specs))
