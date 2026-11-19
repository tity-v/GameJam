#!/usr/bin/env python3
"""生成 32x32 占位瓦片图集 + TileSet 资源（关卡网格的地基）。

产物：
  assets/tiles/placeholder_32.png    4x2 共 8 格，每格 32x32
  assets/tiles/tileset_32.tres       tile_size=32，实心格带 ±16 的物理多边形

为什么要有这个图集：
  以前房间用的是 16px 的美术图集 + 节点 scale=2，等于"画的时候按 32 摆，实际
  贴图是 16"，美术拿到的规格和引擎里的坐标差一倍，改一次图就错一次位。
  现在图集本身就是 32x32、节点 scale=1，**一个瓦片 = 32 像素 = 一个网格单位**，
  像素坐标除以 32 就是格子坐标。

图例（atlas 坐标 → 名字 → 碰撞）：
  (0,0) solid_top   地面表层：顶部 3px 高光，实心
  (1,0) solid_fill  地面内层：无高光，实心
  (2,0) solid_wall  墙体：右侧加深，实心
  (3,0) one_way     单向薄板：只有上部 8px，one_way 碰撞（可上不可下）
  (0,1) air         空瓦片：透明 + 极淡格线，**无碰撞**，用来铺满整张地图
  (1,1) decor       装饰板：半透明，无碰撞
  (2,1) spawn_mark  出生点标记：无碰撞

空瓦片（air）是这套网格的关键：整张 40x22 地图都用它铺满，所以"地图边界"
不是靠画一块底色猜出来的，而是 880 个格子里实实在在的瓦片。策划/美术在编辑器
里能直接数格子，游戏里它淡到几乎看不见。

用法：
    python _reference/tools/make_grid_tiles.py           # 已有产物则跳过
    python _reference/tools/make_grid_tiles.py --force   # 重新生成
"""
import os
import sys

from PIL import Image

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
OUT_DIR = os.path.join(ROOT, "assets", "tiles")
PNG = os.path.join(OUT_DIR, "placeholder_32.png")
TRES = os.path.join(OUT_DIR, "tileset_32.tres")

TILE = 32
COLS, ROWS = 4, 2

# 与 assets/office_white/office_atlas_16.png 同一套配色（浅灰蓝的办公室白）
SURFACE = (174, 185, 199)
SURFACE_HI = (230, 236, 243)
SURFACE_LO = (141, 153, 168)
FILL = (165, 175, 189)
WALL = (134, 145, 161)
INK = (39, 54, 68)

FORCE = "--force" in sys.argv


def jitter(x, y, amp=3):
    """确定性噪点：同一个 (x, y) 永远同一个偏移，重跑脚本不会改图。
    按 2x2 像素一块取噪，看起来是颗粒质感而不是电视雪花。"""
    h = ((x // 2) * 73856093) ^ ((y // 2) * 19349663)
    return ((h >> 8) % (amp * 2 + 1)) - amp


def shade(c, d, alpha=255):
    return tuple(max(0, min(255, v + d)) for v in c) + (alpha,)


def noise_px(base, x, y, amp=3):
    return shade(base, jitter(x, y, amp))


def solid_top(x, y):
    """地表：顶部 3px 亮边 + 竖格线（横格线由那条亮边自己承担）。"""
    if x == 0:
        return INK + (44,)
    if y <= 3:
        return noise_px(SURFACE_HI, x, y, 2)
    if y == TILE - 1:
        return shade(SURFACE_LO, 0)
    return noise_px(SURFACE, x, y)


def solid_fill(x, y):
    if y == 0 or x == 0:
        return INK + (44,)
    return noise_px(FILL, x, y)


def solid_wall(x, y):
    if y == 0 or x == 0:
        return INK + (40,)
    if x >= TILE - 2:
        return shade(WALL, -22)
    return noise_px(WALL, x, y)


def one_way(x, y):
    """单向板：上面 8px 是板，下面是空的。"""
    if y > 7:
        return (0, 0, 0, 0)
    if y == 0:
        return shade(SURFACE_LO, 10, 160)
    if y <= 2:
        return noise_px(SURFACE_HI, x, y, 2)
    return noise_px(SURFACE, x, y)


def air(x, y):
    """空瓦片：1px 极淡格线 + 四角 2x2 点，铺满地图时能数格子，玩起来几乎看不见。"""
    corner = (x < 2 or x > TILE - 3) and (y < 2 or y > TILE - 3)
    if corner:
        return INK + (76,)
    if x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1:
        return INK + (40,)
    return (0, 0, 0, 0)


def decor(x, y):
    if x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1:
        return INK + (34,)
    return INK + (14,)


def spawn_mark(x, y):
    """出生点标记：中心十字，方便在编辑器里对位。"""
    if (10 <= y <= 21 and 15 <= x <= 16) or (10 <= x <= 21 and 15 <= y <= 16):
        return INK + (120,)
    return (0, 0, 0, 0)


# atlas 坐标 -> 绘制函数（顺序决定图集里哪格是什么）
TILES = [
    ((0, 0), "solid_top", solid_top, True),
    ((1, 0), "solid_fill", solid_fill, True),
    ((2, 0), "solid_wall", solid_wall, True),
    ((3, 0), "one_way", one_way, "one_way"),
    ((0, 1), "air", air, False),
    ((1, 1), "decor", decor, False),
    ((2, 1), "spawn_mark", spawn_mark, False),
]


def build_png():
    img = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))
    px = img.load()
    for (cx, cy), _name, fn, _collision in TILES:
        for y in range(TILE):
            for x in range(TILE):
                px[cx * TILE + x, cy * TILE + y] = fn(x, y)
    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(PNG)
    print(f"写出 {os.path.relpath(PNG, ROOT)}  {img.size[0]}x{img.size[1]}")


def polygon_cell(half=16):
    """碰撞多边形写的是**瓦片局部坐标**（以瓦片中心为原点），不是图集绝对坐标。
    所以每个格子都是同一份 ±16，跟它排在图集第几列无关——写成 cx*32 就会整块偏移。"""
    return f"PackedVector2Array({-half}, {-half}, {half}, {-half}, {half}, {half}, {-half}, {half})"


def build_tres():
    lines = ['[gd_resource type="TileSet" format=3]', ""]
    lines.append('[ext_resource type="Texture2D" path="res://assets/tiles/placeholder_32.png" id="1_atlas"]')
    lines.append("")
    lines.append('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_grid"]')
    lines.append('texture = ExtResource("1_atlas")')
    lines.append(f"texture_region_size = Vector2i({TILE}, {TILE})")
    for (cx, cy), _name, _fn, collision in TILES:
        lines.append(f"{cx}:{cy}/0 = 0")
        if collision is True:
            lines.append(f"{cx}:{cy}/0/physics_layer_0/polygon_0/points = {polygon_cell()}")
        elif collision == "one_way":
            # 只覆盖顶部 8px（局部坐标 -16..-8），并标 one_way：能往上穿，站上去不会掉
            pts = "PackedVector2Array(-16, -16, 16, -16, 16, -8, -16, -8)"
            lines.append(f"{cx}:{cy}/0/physics_layer_0/polygon_0/points = {pts}")
            lines.append(f"{cx}:{cy}/0/physics_layer_0/polygon_0/one_way = true")
    lines.append("")
    lines.append("[resource]")
    lines.append(f"tile_size = Vector2i({TILE}, {TILE})")
    lines.append("physics_layer_0/collision_layer = 1")
    lines.append('sources/0 = SubResource("TileSetAtlasSource_grid")')
    lines.append("")
    with open(TRES, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"写出 {os.path.relpath(TRES, ROOT)}  tile_size={TILE}  格子数={len(TILES)}")


def main():
    if os.path.exists(PNG) and os.path.exists(TRES) and not FORCE:
        print("产物已存在，跳过（要重建加 --force）")
        print("  ", os.path.relpath(PNG, ROOT))
        print("  ", os.path.relpath(TRES, ROOT))
        return 0
    build_png()
    build_tres()
    return 0


if __name__ == "__main__":
    sys.exit(main())
