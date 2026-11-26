extends SceneTree
## 光敏板可读性对比：待机 / 点亮 / 全景因果链。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_sensor.gd

const OUT := "res://build/shots/"
const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"

var room: Node
var lift: Node
var player: Node
var torch: Node
var sensor: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	lift = room.get_node("Lift")
	player = room.get_node("Player")
	torch = room.get_node("Player/Flashlight")
	sensor = room.get_node("Sensor")

	# 冻结平台与火把，只为了构图；玩法逻辑一概不动
	lift.set_physics_process(false)
	torch.set_process(false)
	torch.radii = Vector2(96, 150)

	# 场景 1：待机。玩家站到感应区右缘外（光心 x=462 > 460），光够亮但不触发，
	# 这时板是「暗的、还在呼吸」——正是玩家还没搞懂时看到的样子。
	sensor.set("force", 0)
	await _place(430.0, 446.0, false)
	await _save("sensor_a_idle")

	# 场景 2：点亮 + 平台正在上升（电流沿导轨往上跑）
	sensor.set("force", 1)
	await _place(430.0, 400.0, true)
	await _save("sensor_b_lit")

	# 场景 3：全景——把玩家自带光临时放大，看清「板 → 电缆 → 导轨 → 台」整条链
	sensor.set("force", 1)
	room.get_node("Blackout").set("personal_radii", Vector2(820, 480))
	room.get_node("Blackout").set("falloff", 1.0)
	await _place(300.0, 400.0, true)
	await _save("sensor_c_wide")
	print("SHOTS_DONE")
	quit()


func _place(lift_y: float, player_x: float, lit: bool) -> void:
	lift.position.y = lift_y
	for i in 10:
		await process_frame
		player.global_position = Vector2(player_x, 532)
		player.velocity = Vector2.ZERO
		lift.position.y = lift_y
		if lit:
			torch.radii = Vector2(96, 150)


func _save(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", name)
		return
	img.save_png(OUT + name + ".png")
	# 裁一块 420×300 放大 2 倍，方便看清装置细节
	var rect := Rect2i(280, 380, 420, 300)
	var crop := img.get_region(rect)
	crop.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT + name + "_zoom.png")
	print("saved ", name)
