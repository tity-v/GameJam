extends SceneTree
## 3-2 的构图检查：一张全景（临时把玩家自带光放大，只为看清结构）+ 三张实际亮度。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_room32.gd

const OUT := "res://build/shots/"
const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"

var room: Node
var lift: Node
var lift_b: Node
var player: Node
var torch: Node
var bo: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	lift = room.get_node("Lift")
	lift_b = room.get_node("LiftB")
	player = room.get_node("Player")
	torch = room.get_node("Player/Torch")
	bo = room.get_node("Blackout")
	lift.set_physics_process(false)
	lift_b.set_physics_process(false)
	torch.set_process(false)

	# 结构图：先关黑幕，把地形与两套装置一次看清（黑幕的圆会把右侧的井 B 裁掉）
	bo.visible = false
	await _place(352.0, 532.0, Vector2(2, 2), 352.0)
	await _save("32_structure")
	bo.visible = true

	# 全景：把「玩家自带光」临时开到全房间，只为检查结构
	# 光心必须摆在房间中央（640），摆在出生点的话圆的右半边够不到井 B
	bo.personal_radii = Vector2(900, 520)
	bo.falloff = 1.0
	room.get_node("Sensor").set("force", 1)
	await _place(352.0, 532.0, Vector2(2, 2), 128.0)
	await _save("32_layout_top")
	# 全景的玩家位置要在中间，重拍一张（_place 固定把玩家放 336）
	for i in 14:
		await process_frame
		player.global_position = Vector2(640, 460)
		player.velocity = Vector2.ZERO
		lift.position.y = 352.0
		lift_b.position.y = 128.0
	await _save("32_layout_wide")

	room.get_node("Sensor").set("force", 0)
	bo.personal_radii = Vector2(2, 2)
	bo.falloff = 1.5
	# 三张实际亮度图：站位跟着关卡动线走，不是固定摆在平台 A 上
	await _place(576.0, 532.0, Vector2(96, 150), 352.0, 460.0)   # 底层：板 A 旁，看到平台在井里
	await _save("32_bottom")
	room.get_node("Sensor").set("force", 1)
	await _place(352.0, 308.0, Vector2(96, 150), 352.0, 560.0)   # 中层：看到井 B 与对面的火盆
	await _save("32_mid")
	await _place(352.0, 84.0, Vector2(96, 150), 128.0, 620.0)    # 顶层：站在井 B 口，平台已到顶
	await _save("32_top")
	print("SHOTS_DONE")
	quit()


func _place(lift_y: float, player_y: float, radii: Vector2,
		lift_b_y := 352.0, player_x := 336.0) -> void:
	lift.position.y = lift_y
	lift_b.position.y = lift_b_y
	torch.radii = radii
	for i in 14:
		await process_frame
		player.global_position = Vector2(player_x, player_y)
		player.velocity = Vector2.ZERO
		lift.position.y = lift_y
		lift_b.position.y = lift_b_y


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", path)
		return
	img.save_png(OUT + path + ".png")
	print("saved ", path)
