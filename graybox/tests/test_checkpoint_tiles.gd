extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var room = preload("res://graybox/base_level.tscn").instantiate()
	var world: TileMapLayer = room.get_node("World")
	world.set_cell(Vector2i(7, 17), 3, Vector2i.ZERO, 2)
	world.set_cell(Vector2i(11, 17), 3, Vector2i.ZERO, 1)
	root.add_child(room)
	current_scene = room
	await frames(5)
	var actor = room.get_node("Player")
	var manager = room.get_node("EchoManager")
	var initial: Vector2 = actor.respawn_position
	Input.action_press("move_right")
	for i in 130:
		await physics_frame
		if actor.is_dead:
			break
	Input.action_release("move_right")
	var saved: Vector2 = actor.respawn_position
	assert(actor.is_dead and saved.x > initial.x and saved.x < 256)
	assert(manager.echo_count() == 1 and manager._echoes[0]._origin == saved)
	await actor.respawned
	assert(actor.global_position == saved and manager._echoes[0].global_position == saved)
	await frames(8)
	actor.die()
	assert(manager.echo_count() == 2 and manager._echoes[1]._origin == saved)
	manager.reset_all()
	assert(actor.global_position == initial and manager.echo_count() == 0)
	print("PASS 瓦片存档、尖刺死亡、两次虚影起点、R 复位")
	quit()
