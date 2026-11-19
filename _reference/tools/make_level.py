"""生成第一关场景 level_01.tscn 与 project.godot（含主角实例与跟随相机）。

⚠️ 这两个文件已是"策划/编辑器维护"的正式资产。脚本默认 **拒绝覆盖**，
   要重建必须显式加 --force。改关卡请在 Godot 编辑器里改 level_01.tscn。
"""
import os, sys

# ---- 防覆盖保护：目标已存在就跳过，除非显式 --force ----
FORCE = "--force" in sys.argv
SKIPPED = []


def guard(path):
    """返回 True 表示可以写；已存在且没 --force 则跳过。"""
    if os.path.exists(path) and not FORCE:
        SKIPPED.append(os.path.relpath(path, ROOT))
        return False
    return True

REF = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REF)
sys.path.insert(0, REF)
from level01_data import *  # noqa

LEVELS = os.path.join(ROOT, "scenes", "levels")
os.makedirs(LEVELS, exist_ok=True)

L = []
L.append("[gd_scene load_steps=9 format=3]\n")
L.append('[ext_resource type="PackedScene" path="res://scenes/blocks/solid_ground.tscn" id="1_ground"]')
L.append('[ext_resource type="PackedScene" path="res://scenes/blocks/solid_wall.tscn" id="2_wall"]')
L.append('[ext_resource type="PackedScene" path="res://scenes/blocks/plate_off.tscn" id="3_plate"]')
L.append('[ext_resource type="PackedScene" path="res://scenes/blocks/door.tscn" id="4_door"]')
L.append('[ext_resource type="PackedScene" path="res://scenes/blocks/exit.tscn" id="5_exit"]')
L.append('[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="6_player"]')
L.append('[ext_resource type="Script" path="res://scripts/camera_follow.gd" id="7_cam"]')
L.append('[ext_resource type="Script" path="res://scripts/echo_manager.gd" id="8_echo"]')
L.append("")
L.append('[node name="Level01" type="Node2D"]')
L.append("")
L.append('[node name="Background" type="ColorRect" parent="."]')
L.append("offset_right = 1600.0")
L.append("offset_bottom = 720.0")
L.append("color = Color(%s, %s, %s, 1)" % tuple(f"{c/255:.6f}".rstrip("0").rstrip(".") if c else "0" for c in BG))
L.append("")

# 网格：x 每 80，y 100..560，色 (0.4,0.7,0.7,0.04)
L.append('[node name="Grid" type="Node2D" parent="."]')
L.append("")
n = 0
for x in range(0, int(WIDTH), GRID_STEP):
    L.append(f'[node name="VLine{x}" type="Line2D" parent="Grid"]')
    L.append(f"points = PackedVector2Array({x}, {GRID_TOP}, {x}, 560)")
    L.append("width = 1.0")
    L.append("default_color = Color(0.4, 0.7, 0.7, 0.04)")
    L.append("")
    n += 1

L.append('[node name="Solids" type="Node2D" parent="."]')
L.append("")
L.append('[node name="Ground" parent="Solids" instance=ExtResource("1_ground")]')
L.append(f"position = Vector2({SOLIDS[0][0]}, {SOLIDS[0][1]})")
L.append("")
L.append('[node name="Wall" parent="Solids" instance=ExtResource("2_wall")]')
L.append(f"position = Vector2({SOLIDS[1][0]}, {SOLIDS[1][1]})")
L.append("")

L.append('[node name="Plates" type="Node2D" parent="."]')
L.append("")
for i, p in enumerate(PLATES):
    tag = chr(65 + i)
    L.append(f'[node name="Plate{tag}" parent="Plates" instance=ExtResource("3_plate")]')
    L.append(f"position = Vector2({p[0]}, {p[1]})")
    L.append("")
    L.append(f'[node name="Label{tag}" type="Label" parent="Plates"]')
    L.append(f"offset_left = {p[0] + 5}.0")
    L.append(f"offset_top = {p[1] - 21}.0")
    L.append(f"offset_right = {p[0] + 25}.0")
    L.append(f"offset_bottom = {p[1] - 1}.0")
    L.append("theme_override_colors/font_color = Color(0.505882, 0.564706, 0.572549, 1)")
    L.append("theme_override_font_sizes/font_size = 15")
    L.append(f'text = "{tag}"')
    L.append("")

L.append('[node name="Doors" type="Node2D" parent="."]')
L.append("")
for i, d in enumerate(DOORS):
    L.append(f'[node name="Door{i}" parent="Doors" instance=ExtResource("4_door")]')
    L.append(f"position = Vector2({d[0]}, {d[1]})")
    L.append("")

L.append('[node name="Exit" parent="." instance=ExtResource("5_exit")]')
L.append(f"position = Vector2({EXIT[0]}, {EXIT[1]})")
L.append("")

# 出生点：原 level.spawn = (90,522)，玩家 28x38；这里只放一个空标记节点，方便以后挂玩家
L.append('[node name="RespawnPoint" type="Marker2D" parent="." groups=["respawn_point"]]')
L.append(f"position = Vector2({SPAWN[0]}, {SPAWN[1]})")
L.append("")
L.append('[node name="Player" parent="." instance=ExtResource("6_player")]')
L.append(f"position = Vector2({SPAWN[0]}, {SPAWN[1]})")
L.append("")
L.append('[node name="EchoManager" type="Node2D" parent="." groups=["echo_manager"]]')
L.append('script = ExtResource("8_echo")')
L.append('player_path = NodePath("../Player")')
L.append("")
L.append('[node name="Camera2D" type="Camera2D" parent="."]')
L.append("position = Vector2(640, 360)")
L.append("limit_left = 0")
L.append(f"limit_right = {int(WIDTH)}")
L.append("limit_top = 0")
L.append("limit_bottom = 720")
L.append("position_smoothing_enabled = true")
L.append("position_smoothing_speed = 8.0")
L.append('script = ExtResource("7_cam")')
L.append('target_path = NodePath("../Player")')
L.append("")

target = os.path.join(LEVELS, "level_01.tscn")
if guard(target):
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

# ---------------- project.godot ----------------
proj = f"""; Engine configuration file.
config_version=5

[application]

config/name="Your Past Self"
run/main_scene="res://scenes/levels/level_01.tscn"
config/features=PackedStringArray("4.7")

[autoload]

Hud="*res://scenes/ui/hud.tscn"
PauseMenu="*res://scenes/ui/pause_menu.tscn"

[display]

window/size/viewport_width={VIEWPORT[0]}
window/size/viewport_height={VIEWPORT[1]}
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
"""
INPUT_BLOCK = """[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
jump={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
die={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
reset_echoes={\n"deadzone": 0.2,\n"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)\n]\n}\n"""

if INPUT_BLOCK.strip():
    proj = proj.rstrip() + "\n\n" + INPUT_BLOCK

proj_target = os.path.join(ROOT, "project.godot")
if guard(proj_target):
    with open(proj_target, "w", encoding="utf-8", newline="\n") as f:
        f.write(proj)

if SKIPPED:
    print("已存在，跳过（要重建请加 --force）：", ", ".join(SKIPPED))
print("level_01.tscn ok, grid lines:", n, "plates:", len(PLATES), "doors:", len(DOORS))
