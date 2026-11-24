#!/usr/bin/env python3
"""把「第一章，场景N.json」（关卡编辑器导出）转成 Godot .tscn。

JSON 结构：40x22 格，组件是矩形（格坐标，可带小数），类型只有
terrain / spawn / plate / door / exit。所有 links 都是空的，
压力板与门的配对靠说明文字里的规则推断（见 pair_plates_and_doors）。

转换规则：
1. 地形矩形按格取整（floor 顶边 / ceil 底边），填进 40x22 布尔网格
2. 瓦片按 9 宫格邻居选图（映射从现有 room_01 反推，全部 source=5）
3. 机关底边吸附到「解析后地形的顶面」，避免小数坐标导致的埋进地里
4. 坐标 = 格 * 32 像素

用法：
    python _reference/tools/import_scene_json.py <json目录> <输出目录>
"""
import base64
import json
import math
import os
import struct
import sys

TILE = 32
COLS = 40
ROWS = 22
SOURCE = 5  # solid 图集

def pick_tile(up, left, right, down):
    """按邻居选择图块，返回 (atlas_x, atlas_y)。

    映射从 room_01 的 World 数据反推：
        左上(5,2)  上(7,3)  右上(3,3)
        左(0,3)    中(6,5)  右(2,5)
        左下(0,2)  下(6,4)  右下(2,4)
    全部是四点多边形的实心碰撞，source 5。
    """
    if not up:
        if not left:
            return (5, 2)
        if not right:
            return (3, 3)
        return (7, 3)
    if not down:
        if not left:
            return (0, 2)
        if not right:
            return (2, 4)
        return (6, 4)
    if not left:
        return (0, 3)
    if not right:
        return (2, 5)
    return (6, 5)


def solid_grid(components):
    """把 terrain 矩形填成 40x22 布尔网格。"""
    g = [[False] * COLS for _ in range(ROWS)]
    for c in components:
        if c["type"] != "terrain":
            continue
        x0 = int(math.floor(c["x"]))
        y0 = int(math.floor(c["y"]))
        x1 = int(math.ceil(c["x"] + c["w"]))
        y1 = int(math.ceil(c["y"] + c["h"]))
        for y in range(max(0, y0), min(ROWS, y1)):
            for x in range(max(0, x0), min(COLS, x1)):
                g[y][x] = True
    return g


def encode_tiles(g):
    """按邻居选图并编码成 PackedByteArray 的 base64。"""
    cells = []
    for y in range(ROWS):
        for x in range(COLS):
            if not g[y][x]:
                continue
            up = y > 0 and g[y - 1][x]
            down = y < ROWS - 1 and g[y + 1][x]
            left = x > 0 and g[y][x - 1]
            right = x < COLS - 1 and g[y][x + 1]
            ax, ay = pick_tile(up, left, right, down)
            cells.append(struct.pack("<6H", x, y, SOURCE, ax, ay, 0))
    raw = b"\x00\x00" + b"".join(cells)
    return base64.b64encode(raw).decode(), len(cells)


def snap_bottom(px, py, w, h, g):
    """把底边吸附到下方最近的实心格顶面。找不到就保持原样。"""
    col = int((px + w / 2.0) // TILE)
    if col < 0 or col >= COLS:
        return py
    bottom = py + h
    # 从底边所在行开始往下找（底边正好压格线时，从那一行算起）
    row = int(math.floor(bottom / TILE))
    if bottom % TILE == 0:
        row = int(bottom // TILE)
    for y in range(max(0, row), ROWS):
        if g[y][col]:
            return y * TILE - h
    return py


def pair_plates_and_doors(plates, doors, scene_index):
    """按场景说明里的规则配对。返回 {door_index: [plate_index, ...]}"""
    if not plates or not doors:
        return {i: [] for i in range(len(doors))}

    order_p = sorted(range(len(plates)), key=lambda i: (plates[i]["x"], plates[i]["y"]))
    order_d = sorted(range(len(doors)), key=lambda i: (doors[i]["x"], doors[i]["y"]))

    # 场景 2（1 门 2 板）：多块板共同控制同一扇门
    if len(doors) == 1:
        return {order_d[0]: order_p}

    # 场景 7（2 板 2 门，说明写明「左板控右门，右板控左门」）：交叉配对
    if scene_index == 7 and len(plates) == len(doors):
        return {order_d[i]: [order_p[len(order_p) - 1 - i]] for i in range(len(order_d))}

    # 场景 9 / 10：同 x 轴配对，配不上就按序一一对应
    by_x = {}
    for di in order_d:
        dx = doors[di]["x"]
        best = None
        best_gap = 1e9
        for pi in order_p:
            gap = abs(plates[pi]["x"] - dx)
            if gap < best_gap:
                best, best_gap = pi, gap
        if best is not None:
            by_x[di] = [best]
    used = set(p for v in by_x.values() for p in v)
    rest_p = [p for p in order_p if p not in used]
    rest_d = [d for d in order_d if d not in by_x]
    for i, di in enumerate(rest_d):
        by_x[di] = [rest_p[i % len(rest_p)]] if rest_p else []
    return by_x


def build_tscn(data, scene_index, root_name):
    comps = data["components"]
    g = solid_grid(comps)
    b64, n = encode_tiles(g)

    plates = [c for c in comps if c["type"] == "plate"]
    doors = [c for c in comps if c["type"] == "door"]
    exits = [c for c in comps if c["type"] == "exit"]
    spawns = [c for c in comps if c["type"] == "spawn"]

    plate_names = []
    for i, p in enumerate(plates):
        # 借用原始 name（A / 压力板），重名就加序号
        base = p.get("name") or "Plate"
        name = base if base not in plate_names else "%s%d" % (base, i + 1)
        plate_names.append(name)

    door_names = []
    for i, d in enumerate(doors):
        base = d.get("name") or "Gate"
        name = base if base not in door_names else "%s%d" % (base, i + 1)
        door_names.append(name)

    pairs = pair_plates_and_doors(plates, doors, scene_index)

    out = []
    out.append("[gd_scene format=3]")
    out.append("")
    out.append('[ext_resource type="PackedScene" path="res://scenes/levels/old_building/base.tscn" id="base"]')
    out.append('[ext_resource type="PackedScene" path="res://graybox/door.tscn" id="door"]')
    out.append('[ext_resource type="PackedScene" path="res://graybox/open_exit.tscn" id="exit"]')
    out.append('[ext_resource type="PackedScene" path="res://graybox/pressure_plate.tscn" id="plate"]')
    out.append("")
    out.append('[node name="%s" instance=ExtResource("base")]' % root_name)
    out.append("")
    out.append('[node name="World" parent="." index="2"]')
    out.append('tile_map_data = PackedByteArray("%s")' % b64)
    out.append("")

    for i, p in enumerate(plates):
        px = p["x"] * TILE
        py = p["y"] * TILE
        w = p["w"] * TILE
        h = p["h"] * TILE
        py = snap_bottom(px, py, w, h, g)
        out.append('[node name="%s" parent="Mechanisms" instance=ExtResource("plate")]' % plate_names[i])
        out.append("position = Vector2(%s, %s)" % (fmt(px), fmt(py)))
        out.append("block_size = Vector2(%s, %s)" % (fmt(w), fmt(h)))
        out.append("")

    for i, d in enumerate(doors):
        px = d["x"] * TILE
        py = d["y"] * TILE
        w = d["w"] * TILE
        h = d["h"] * TILE
        py = snap_bottom(px, py, w, h, g)
        out.append('[node name="%s" parent="Mechanisms" instance=ExtResource("door")]' % door_names[i])
        out.append("position = Vector2(%s, %s)" % (fmt(px), fmt(py)))
        out.append("block_size = Vector2(%s, %s)" % (fmt(w), fmt(h)))
        src = pairs.get(i) or []
        if src:
            paths = ", ".join('NodePath("../%s")' % plate_names[p] for p in src)
            out.append("plate_paths = Array[NodePath]([%s])" % paths)
        out.append("")

    for e in exits:
        px = e["x"] * TILE
        py = e["y"] * TILE
        w = e["w"] * TILE
        h = e["h"] * TILE
        py = snap_bottom(px, py, w, h, g)
        out.append('[node name="Exit" parent="Mechanisms" instance=ExtResource("exit")]')
        out.append("position = Vector2(%s, %s)" % (fmt(px), fmt(py)))
        out.append("block_size = Vector2(%s, %s)" % (fmt(w), fmt(h)))
        if door_names:
            out.append('door_path = NodePath("../%s")' % door_names[0])
        out.append("")

    if spawns:
        s = spawns[0]
        px = s["x"] * TILE
        py = (s["y"] + s["h"]) * TILE - 44.0
        py = snap_bottom(px, py, 32, 44, g)
        out.append('[node name="RespawnPoint" parent="."]')
        out.append("position = Vector2(%s, %s)" % (fmt(px), fmt(py)))
        out.append("")
        out.append('[node name="Player" parent="."]')
        out.append("position = Vector2(%s, %s)" % (fmt(px), fmt(py)))
        out.append("")

    return "\n".join(out) + "\n", n


def fmt(v):
    if abs(v - round(v)) < 1e-6:
        return str(int(round(v)))
    return ("%.3f" % v).rstrip("0").rstrip(".")


def main():
    src_dir = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    files = [f for f in os.listdir(src_dir) if f.endswith(".json")]
    def idx(f):
        digits = "".join(c for c in f if c.isdigit())
        return int(digits) if digits else 0
    files.sort(key=idx)

    for f in files:
        i = idx(f)
        with open(os.path.join(src_dir, f), encoding="utf-8") as fp:
            data = json.load(fp)
        root = "Tutorial%02d" % i
        text, n = build_tscn(data, i, root)
        dest = os.path.join(out_dir, "room_%02d.tscn" % i)
        with open(dest, "w", encoding="utf-8", newline="\n") as fp:
            fp.write(text)
        print("%s -> %s  格子 %d  %s" % (f, os.path.basename(dest), n, data.get("name", "")))


if __name__ == "__main__":
    main()
