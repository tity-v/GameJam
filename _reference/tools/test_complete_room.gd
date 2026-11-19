extends SceneTree
## 通过真实按键走完房间，验证 Echo 足部触发、锁存、出口，以及 R 的「回到初始状态」
## （虚影 + 机关一起复位、场景不重载、门重新变成墙）。

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

	# --- 造一条踩在 A 上的回声 ---
	# 先按 R 把刚才「A→门→A」那段路从录制里清掉，否则回声重放的是整段来回，
	# 玩家走到 B 时它还在半路上（这条曾经真的把测试跑挂过）。
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(10)
	await walk_to(365)
	await frames(10)
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(85)
	check(room.get_node("EchoManager").echo_count() == 1, "E creates echo")
	await walk_to(665)
	check(room.get_node("PlateA").active, "echo feet press A")
	check(room.get_node("PlateB").active, "player presses B")
	check(room.get_node("Door").opened, "both plates open door")

	# --- R：虚影 + 机关一起回到初始状态，但场景不重载 ---
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(10)
	check(room.get_node("EchoManager").echo_count() == 0, "R clears all echoes")
	check(player.position.x < 140, "R sends player back to spawn")
	check(not player.is_dead, "R does not go through the death flow")
	check(not room.get_node("Door").opened, "R closes the door")
	check(not room.get_node("Door").get_node("Collision").disabled, "R re-enables door collision")
	check(not room.get_node("PlateA").active, "R releases plate A")
	check(not room.get_node("PlateB").active, "R releases plate B")
	check(room.is_inside_tree(), "R does not reload the scene")

	# 门必须真的又是墙：往右冲应该被挡在门外，而不是「看着关了却能穿」
	key(KEY_D, true)
	await frames(140)
	key(KEY_D, false)
	check(player.position.x < 850.0, "closed door blocks player again after R")

	# --- 再按一次 R 清掉刚才那段路，验证复位后这一关仍然可解 ---
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(10)
	player = room.get_node("Player")
	await walk_to(365)
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(85)
	check(room.get_node("EchoManager").echo_count() == 1, "R leaves the room solvable (new echo created)")
	await walk_to(665)
	await frames(20)
	check(room.get_node("Door").opened, "door opens again after re-solving")

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
