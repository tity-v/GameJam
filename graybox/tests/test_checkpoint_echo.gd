extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var room = preload("res://graybox/base_level.tscn").instantiate()
	var world: TileMapLayer = room.get_node("World")
	world.set_cell(Vector2i(7, 17), 3, Vector2i.ZERO, 2)
	root.add_child(room)
	current_scene = room
	for i in 5:
		await physics_frame
	var player = room.get_node("Player")
	var manager = room.get_node("EchoManager")
	Input.action_press("move_right")
	for i in 95:
		await physics_frame
	Input.action_release("move_right")
	assert(player.respawn_position.x > 200)
	player.die()
	assert(manager.echo_count() == 1)
	# 录像已生成后再放第二面旗，确保只有虚影会经过它。
	world.set_cell(Vector2i(9, 17), 3, Vector2i.ZERO, 2)
	await player.respawned
	var first_spawn: Vector2 = player.global_position
	var reached := false
	for i in 100:
		await physics_frame
		if player.respawn_position.x > first_spawn.x + 32:
			reached = true
			break
	assert(reached and player.global_position.is_equal_approx(first_spawn), "虚影触旗应更新存档，但不移动本体")
	var saved: Vector2 = player.respawn_position
	player.die()
	await player.respawned
	assert(player.global_position.is_equal_approx(saved), "本体应从虚影激活的旗帜重生")
	manager.reset_all()
	print("PASS 虚影触旗存档与本体重生")
	quit()
