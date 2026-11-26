extends SceneTree
## 真实场景（火把 + 虚影在位）的照明 A/B 对照：
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_light_ab.gd
## A = 改动前 96/112 线性；B = 已采用 96/150 曲线 1.5。

const OUT := "res://build/shots/"

var room: Node
var bo: Node
var torch: Node
var player: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/chapter_03/room_31_proto.tscn")
	room = packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	bo = room.get_node("Blackout")
	player = room.get_node("Player")
	torch = room.get_node("Player/Flashlight")
	torch.set_process(false)
	# 虚影走到门口会挡住构图，冻在起点
	room.get_node("Specter").set_physics_process(false)
	room.get_node("Specter").set_process(false)
	_pin()
	for i in 50:
		await process_frame
	_pin()

	var cases := [
		{"n": "ab_before", "base": Vector2(40, 52), "fire": Vector2(96, 112), "f": 1.0},
		{"n": "ab_after", "base": Vector2(40, 90), "fire": Vector2(96, 150), "f": 1.5},
	]
	for c in cases:
		bo.falloff = c["f"]
		torch.radii = c["base"]
		_pin()
		for i in 6:
			await process_frame
		_save(OUT + c["n"] + "_idle.png")
		torch.radii = c["fire"]
		_pin()
		for i in 6:
			await process_frame
		_save(OUT + c["n"] + "_fire.png")

	print("AB_SHOTS_DONE")
	quit()


func _pin() -> void:
	player.global_position = Vector2(880, 436)
	player.velocity = Vector2.ZERO


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", path)
		return
	img.save_png(path)
	print("saved ", path)
