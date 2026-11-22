extends SceneTree

var room: Node
var failed := false

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func put(id: String, pos: Vector2, parent: Node) -> Node2D:
	var item = load("res://graybox/%s.tscn" % id).instantiate()
	item.position = pos
	parent.add_child(item)
	return item

func check(value: bool, message: String) -> void:
	if not value: failed = true
	print("PASS " if value else "FAIL ", message)

func run() -> void:
	change_scene_to_file("res://graybox/base_level.tscn")
	await scene_changed
	room = current_scene
	var world := room.get_node("World") as TileMapLayer
	for row in range(13,18):
		world.set_cell(Vector2i(10,row), 3, Vector2i.ZERO, 3)
	var player = room.get_node("Player")
	var manager = room.get_node("EchoManager")
	await ticks(5)
	Input.action_press("move_right")
	await ticks(110)
	Input.action_release("move_right")
	check(player.position.x <= 289 and player.position.x >= 285, "本体被紫墙挡住")
	player.die()
	await player.respawned
	await ticks(110)
	var echo = manager._echoes[0]
	check(echo.position.x > 440 and echo.is_in_group("replay_ghost"), "原先贴墙的方向输入仍能让虚影穿墙")
	manager.reset_all()
	var crate = put("box",Vector2(263,554),room)
	var tag = put("color_recorder",Vector2.ZERO,crate)
	player.position = Vector2(208,532)
	await ticks(8)
	Input.action_press("move_right")
	await ticks(110)
	Input.action_release("move_right")
	check(crate.position.x <= 301, "实体箱子受墙阻挡")
	player.die()
	await player.respawned
	await ticks(110)
	var replay = tag.tracks[0].ghost.crate
	check(replay.global_position.x > 365 and replay.is_in_group("replay_ghost"), "箱子虚影重做推动并穿墙")
	manager.reset_all()
	var lift = put("platform",Vector2(190,465),room)
	lift.end_offset = Vector2(270,0)
	lift.speed_override = 160
	var lift_tag = put("color_recorder", Vector2.ZERO, lift)
	await ticks(102)
	check(lift.position.x < 274, "实体移动平台受墙阻挡")
	player.die()
	await player.respawned
	await ticks(85)
	check(lift_tag.tracks[0].ghost.position.x > 365, "平台虚影沿录制的路线穿墙")
	manager.reset_all()
	var support = put("platform",Vector2(800,400),room)
	support.end_offset = Vector2.ZERO
	player.position = Vector2(784,348)
	player.velocity = Vector2.ZERO
	await ticks(8)
	manager.clear_all()
	await ticks(48)
	check(player.is_on_floor() and player.position.y < 352, "录制时站在真实平台上")
	player.die()
	support.queue_free()
	await player.respawned
	await ticks(28)
	check(manager._echoes[0].position.y > 465, "重放相同静止操作时失去支撑会下落")
	quit(1 if failed else 0)
