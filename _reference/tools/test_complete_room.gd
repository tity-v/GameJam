extends SceneTree
## 通过真实按键走完房间，验证 Echo 足部触发、锁存、出口及 R 重载。

var room: Node2D
var player: Node2D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func walk_to(x: float) -> void:
	var code := KEY_D if player.position.x < x else KEY_A
	key(code, true)
	for i in 360:
		await physics_frame
		if absf(player.position.x - x) < 7:
			break
	key(code, false)
	await frames(8)

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
	print("PASS ", message)

func run() -> void:
	room = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	await frames(10)
	check(player.is_on_floor(), "spawn on floor")
	await walk_to(365)
	check(room.get_node("PlateA").active, "player presses A")
	await walk_to(665)
	check(not room.get_node("Door").opened, "one player cannot open both plates")
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(8)
	room = current_scene
	player = room.get_node("Player")
	check(player.position.x < 140 and room.get_node("EchoManager").echo_count() == 0, "R restores spawn and clears recordings")
	await walk_to(365)
	await frames(240)
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(85)
	check(room.get_node("EchoManager").echo_count() == 1, "E creates echo")
	await walk_to(665)
	check(room.get_node("PlateA").active, "echo feet press A")
	check(room.get_node("PlateB").active, "player presses B")
	check(room.get_node("Door").opened, "both plates open door")

	# R 的新语义：只清虚影 + 回出生点，机关状态保留（门已经锁存开，不回收）
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(10)
	check(room.get_node("EchoManager").echo_count() == 0, "R clears all echoes")
	check(player.position.x < 140, "R sends player back to spawn")
	check(not player.is_dead, "R does not go through the death flow")
	check(room.get_node("Door").opened, "R keeps door open (level state untouched)")
	check(not room.get_node("PlateA").active, "cleared echo releases plate A")
	check(room.is_inside_tree(), "R does not reload the scene")

	await walk_to(665)
	key(KEY_D, true)
	await frames(125)
	key(KEY_D, false)
	check(room.won, "player physically passes door and reaches exit")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/images/complete-room-win.png")
	# 通关后 R 应被忽略（整关重来是 Replay 按钮的事）
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(10)
	check(room.won and room.get_node("Door").opened, "R after win is ignored, room not reloaded")
	# 模拟点 Replay：整关重来
	room.reset_room()
	await frames(20)
	room = current_scene
	player = room.get_node("Player")
	check(not room.won and not room.get_node("Door").opened and not room.get_node("PlateA").active, "Replay resets completion and latched mechanism")
	await walk_to(52)
	check(player.is_dead, "spikes kill player")
	await frames(90)
	check(not player.is_dead and player.position.x > 100, "hazard death respawns")
	print("COMPLETE_ROOM_ALL_PASS")
	quit()
