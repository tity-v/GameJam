extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func piece(id: String, room: Node, pos: Vector2):
	var node = load("res://graybox/%s.tscn" % id).instantiate()
	node.position = pos
	room.add_child(node)
	return node
func run() -> void:
	change_scene_to_file("res://graybox/base_level.tscn")
	await scene_changed
	var room := current_scene
	var player = room.get_node("Player")
	var manager = room.get_node("EchoManager")
	var portal = piece("portal",room,Vector2(200,540))
	var other = piece("portal",room,Vector2(600,540))
	portal.destination = other
	other.destination = portal
	player.global_position = portal.position - Vector2(16,22)
	portal._physics_process(0.016)
	assert(not portal.enabled)
	other._physics_process(0.016)
	assert(other.enabled and player.position.x > 500)
	manager._record_input(1.0, false, false)
	assert(manager._trail[-1] == Vector2.RIGHT)
	var echo = preload("res://scenes/echo/echo.tscn").instantiate()
	room.add_child(echo)
	var entry: Vector2 = portal.position - Vector2(16,22)
	echo.setup_actions(PackedVector2Array([Vector2.RIGHT,Vector2.RIGHT]),entry,Vector2.ZERO,player)
	echo.reset()
	portal._physics_process(0.016)
	assert(echo.position.is_equal_approx(entry))
	portal.reset_mechanism()
	portal._physics_process(0.016)
	assert(echo.position.x > 500 and not portal.enabled)
	other._physics_process(0.016)
	assert(echo.position.x > 500)
	var plate = piece("pressure_plate",room,Vector2(800,564))
	var box = piece("box",room,Vector2(820,544))
	plate._physics_process(0.016)
	assert(plate.active)
	var light: float = box.mass
	box.box_size *= 2
	assert(is_equal_approx(box.mass, 4*light))
	var lever = piece("lever",room,Vector2(300,570))
	player.position = Vector2(270,534)
	Input.action_press("move_right")
	lever._physics_process(0.1)
	assert(not lever.active)
	Input.action_release("move_right")
	player.position.x = 305
	Input.action_press("move_left")
	for i in 12: lever._physics_process(0.016)
	Input.action_release("move_left")
	assert(lever.active)
	var mirrored = piece("lever",room,Vector2(500,570))
	mirrored.scale.x = -1
	player.position = Vector2(452,534)
	Input.action_press("move_right")
	for i in 12: mirrored._physics_process(0.016)
	Input.action_release("move_right")
	assert(mirrored.active)
	var door = piece("door",room,Vector2(900,500))
	door.plate_paths.assign([door.get_path_to(lever)])
	door._physics_process(0.016)
	assert(door.opened)
	var platform = piece("platform",room,Vector2.ZERO)
	platform.start_point = portal
	platform.end_point = other
	platform.speed_override = 100
	platform.reset_mechanism()
	platform._physics_process(5.0)
	assert(platform.distance == 500)
	var tag = piece("color_recorder",platform,Vector2.ZERO)
	await process_frame
	tag._physics_process(0.016)
	tag.finish_track()
	tag.rewind()
	tag._physics_process(0.016)
	assert(tag.tracks.size() == 1 and tag.tracks[0].ghost.visible)
	assert(tag.tracks[0].ghost.collision_layer == platform.collision_layer)
	var plate_tag = piece("color_recorder",plate,Vector2.ZERO)
	await process_frame
	plate_tag.reset_mechanism()
	plate.active = true
	plate_tag._physics_process(0.016)
	plate_tag.finish_track()
	plate_tag.rewind()
	plate_tag.tracks[0].ghost._physics_process(0.016)
	assert(not plate.active and plate_tag.tracks[0].ghost.active)
	door.plate_paths.assign([door.get_path_to(plate)])
	door._physics_process(0.016)
	assert(door.opened)
	plate_tag.reset_mechanism()
	door._physics_process(0.016)
	assert(not door.opened)
	tag.reset_mechanism()
	assert(tag.tracks.is_empty())
	var exit_piece = piece("exit",room,player.position)
	exit_piece._physics_process(0.016)
	assert(room.won)
	print("INTERACTIVE_PARTS_PASS")
	quit()
