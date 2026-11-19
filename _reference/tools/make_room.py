#!/usr/bin/env python3
"""把 room_grid.py 的 40x22 布局写进房间场景的瓦片层。

做三件事：
  1. 生成三个 TileMapLayer 的 `tile_map_data`（二进制 = 2 字节头 + 每格 12 字节）
  2. 用它替换 .tscn 里 "Background 之后、RespawnPoint 之前" 那一段
  3. 顺手把 TileSet 的 ext_resource 指向 assets/tiles/tileset_32.tres

三个层的分工（顺序就是绘制顺序，先画的在下面）：
  Background        Polyline2D 底色，1280x704，只是垫底的一整块颜色
  Map_Placeholder   880 个空瓦片铺满整张地图，**无碰撞**。地图边界看得见、数得清
  World             地表/内层/墙体，有碰撞。玩家和虚影真正撞到的是这一层
  Decor             装饰，无碰撞，留给美术

用法：
    python _reference/tools/make_room.py --preview   # 只出预览图，不动场景
    python _reference/tools/make_room.py --force     # 真正写入 .tscn
"""
import base64
import os
import struct
import sys

from PIL import Image, ImageDraw

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_grid as G  # noqa: E402

TILESET_EXT = "res://assets/tiles/tileset_32.tres"
ATLAS_PNG = os.path.join(ROOT, "assets", "tiles", "placeholder_32.png")

ROOMS = {
    "scenes/levels/complete_room.tscn": "2_udwqk",
    "scenes/levels/office_build.tscn": "1_m2hwx",
}


def encode(cells):
    """cells: [(x, y, atlas_x, atlas_y), ...] -> Godot 的 PackedByteArray 文本。

    格式（对着引擎标定过，见 HANDOFF §关卡网格）：2 字节头部 + 每格 6 个 int16
    (x, y, source_id, atlas_x, atlas_y, alternative)，小端。
    """
    buf = bytearray(struct.pack("<H", 0))
    for x, y, ax, ay in cells:
        buf += struct.pack("<hhhhhh", x, y, 0, ax, ay, 0)
    return base64.b64encode(bytes(buf)).decode()


def layers():
    rows = G.grid()
    air, world, decor = [], [], []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            # 占位层不看图例：整张地图每格都先铺一个空瓦片，实体格再画在上面
            air.append((x, y, *G.TILE_OF["."]))
            if ch == G.AIR_CHAR:
                continue
            elif ch == G.DECOR_CHAR:
                decor.append((x, y, *G.TILE_OF[","]))
            else:
                world.append((x, y, *G.TILE_OF[ch]))
    return air, world, decor


def block(name, uid, cells, ext_id, collision):
    lines = [f'[node name="{name}" type="TileMapLayer" parent="." unique_id={uid}]']
    if cells:
        lines.append(f'tile_map_data = PackedByteArray("{encode(cells)}")')
    lines.append(f'tile_set = ExtResource("{ext_id}")')
    if not collision:
        lines.append("collision_enabled = false")
    return "\n".join(lines)


def room_block(ext_id):
    air, world, decor = layers()
    parts = [
        '[node name="Background" type="Polygon2D" parent="." unique_id=990606821]',
        "color = Color(0.60784316, 0.68235296, 0.7490196, 1)",
        f"polygon = PackedVector2Array(0, 0, {G.WIDTH}, 0, {G.WIDTH}, {G.HEIGHT}, 0, {G.HEIGHT})",
        "",
        block("Map_Placeholder", 250745962, air, ext_id, False),
        "",
        block("World", 1548126430, world, ext_id, True),
        "",
        block("Decor", 1987342032, decor, ext_id, False),
        "",
    ]
    return "\n".join(parts)


def patch(text, ext_id):
    start = text.index('[node name="Background"')
    end = text.index('[node name="RespawnPoint"')
    text = text[:start] + room_block(ext_id) + "\n" + text[end:]
    # TileSet 换成 32px 图集
    import re
    text = re.sub(r'\[ext_resource type="TileSet" path="[^"]+" id="' + ext_id + r'"\]',
                  f'[ext_resource type="TileSet" path="{TILESET_EXT}" id="{ext_id}"]', text)
    # 相机对准 704 高的房间中心
    text = text.replace("position = Vector2(640, 360)", f"position = Vector2({G.WIDTH // 2}, {G.HEIGHT // 2})")
    return text


def preview(path):
    """把布局 + 机关矩形合成一张设计预览图（1:1，1280x704）。"""
    atlas = Image.open(ATLAS_PNG).convert("RGBA")
    img = Image.new("RGBA", (G.WIDTH, G.HEIGHT), (155, 174, 189, 255))
    rows = G.grid()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            ax, ay = G.TILE_OF[ch]
            tile = atlas.crop((ax * G.TILE, ay * G.TILE, ax * G.TILE + G.TILE, ay * G.TILE + G.TILE))
            img.alpha_composite(tile, (x * G.TILE, y * G.TILE))
    d = ImageDraw.Draw(img)
    for name, x, y, w, h, _note in G.MECHS:
        d.rectangle([x, y, x + w - 1, y + h - 1], outline=(220, 90, 90, 255))
        d.text((x + 3, y + 1), name, fill=(180, 40, 40, 255))
    img.convert("RGB").save(path, optimize=True)
    print("写出", os.path.relpath(path, ROOT))

    # 同时放大左下角一块，方便看清瓦片细节（尖刺 + 地表 + 空瓦片）
    zoom = img.crop((0, G.HEIGHT - 64 * 3, 64 * 5, G.HEIGHT))
    zoom.resize((zoom.width * 3, zoom.height * 3), Image.NEAREST).save(
        os.path.join(ROOT, "_reference", "preview_grid_zoom.png"))


def main():
    if "--preview" in sys.argv:
        preview(os.path.join(ROOT, "_reference", "preview_grid_room.png"))
        return 0
    if "--force" not in sys.argv:
        print("这会重写场景里的瓦片层。确认要写就加 --force；只想看图加 --preview。")
        return 0
    for rel, ext_id in ROOMS.items():
        path = os.path.join(ROOT, rel)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(patch(text, ext_id))
        print(f"写入 {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
