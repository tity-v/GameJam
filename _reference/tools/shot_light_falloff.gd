extends SceneTree
## 只拍玩家手电的衰减对比（清掉火把、冻结虚影，构图固定）。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_light_falloff.gd
##
## rx（全亮半径）保持不动——那是玩法参数，96 = 3 格。
## 只调 ry（归零半径）和 falloff（衰减曲线），看「由内向外减弱」该怎么配。

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
	# 火把会盖掉对比，清空
	room.get_node("Torches").clear()
	# 虚影会走过来撞人，冻住
	room.get_node("Specter").set_physics_process(false)
	room.get_node("Specter").set_process(false)
	# 高台顶面 480，身高 88
	_pin_player()
	for i in 50:
		await process_frame
	_pin_player()

	# n=名字 base=底光 fire=打火 f=falloff
	var cases := [
		{"n": "01_hard", "base": Vector2(40, 52), "fire": Vector2(96, 112), "f": 1.0},
		{"n": "02_wide", "base": Vector2(40, 90), "fire": Vector2(96, 150), "f": 1.0},
		{"n": "03_mid", "base": Vector2(40, 90), "fire": Vector2(96, 150), "f": 1.5},
		{"n": "04_deep", "base": Vector2(40, 90), "fire": Vector2(96, 150), "f": 2.2},
	]
	for c in cases:
		bo.falloff = c["f"]
		torch.radii = c["base"]
		_pin_player()
		for i in 6:
			await process_frame
		_save(OUT + "light_" + c["n"] + "_idle.png")
		torch.radii = c["fire"]
		_pin_player()
		for i in 6:
			await process_frame
		_save(OUT + "light_" + c["n"] + "_fire.png")

	print("LIGHT_SHOTS_DONE")
	quit()


func _pin_player() -> void:
	player.global_position = Vector2(880, 436)
	player.velocity = Vector2.ZERO


func _save(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", path)
		return
	img.save_png(path)
	print("saved ", path)
