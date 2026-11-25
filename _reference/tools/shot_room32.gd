extends SceneTree
## 3-2 的构图检查：一张全景（临时把玩家自带光放大，只为看清结构）+ 三张实际亮度。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_room32.gd

const OUT := "res://build/shots/"
const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"

var room: Node
var lift: Node
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
	player = room.get_node("Player")
	torch = room.get_node("Player/Torch")
	bo = room.get_node("Blackout")
	lift.set_physics_process(false)
	torch.set_process(false)

	# 全景：把「玩家自带光」临时开到全房间，只为检查结构
	bo.personal_radii = Vector2(760, 420)
	bo.falloff = 1.0
	room.get_node("Sensor").set("force", 1)
	await _place(576.0, 532.0, Vector2(2, 2))
	await _save("32_layout_top")

	room.get_node("Sensor").set("force", 0)
	bo.personal_radii = Vector2(2, 2)
	bo.falloff = 1.5
	await _place(576.0, 532.0, Vector2(96, 150))
	await _save("32_bottom")
	room.get_node("Sensor").set("force", 1)
	await _place(352.0, 308.0, Vector2(96, 150))
	await _save("32_mid")
	await _place(128.0, 84.0, Vector2(96, 150))
	await _save("32_top")
	print("SHOTS_DONE")
	quit()


func _place(lift_y: float, player_y: float, radii: Vector2) -> void:
	lift.position.y = lift_y
	torch.radii = radii
	for i in 14:
		await process_frame
		player.global_position = Vector2(336, player_y)
		player.velocity = Vector2.ZERO
		lift.position.y = lift_y


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", path)
		return
	img.save_png(OUT + path + ".png")
	print("saved ", path)
