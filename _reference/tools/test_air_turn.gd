extends SceneTree
## 临时验证：空中转向到底多快。起跳后在最高速时反向，逐帧打印 vx/vy/是否落地。
## 用法：godot --headless --path . -s _reference/tools/test_air_turn.gd

var lvl
var player


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	for i in 40:
		await physics_frame

	print("speed=%.0f air=%.0f power=%.2f air_power=%.2f" % [
		player.max_speed, player.air_accel, player.curve_power, player.air_curve_power])

	# 地面先跑到满速，再起跳保持向右，然后在空中反向
	_key(KEY_D, true)
	await _wait(20)
	print("满速 vx=%.1f" % player.velocity.x)

	_key(KEY_SPACE, true)
	await _wait(6)
	print("起跳 6 帧: vx=%.1f vy=%.1f on_floor=%s" % [player.velocity.x, player.velocity.y, player.is_on_floor()])

	var line := "空中按左:"
	_key(KEY_A, true)
	_key(KEY_D, false)
	for i in 18:
		await physics_frame
		line += " %.0f" % player.velocity.x
	print(line)
	print("18 帧后 vx=%.1f vy=%.1f on_floor=%s" % [player.velocity.x, player.velocity.y, player.is_on_floor()])

	_key(KEY_A, false)
	_key(KEY_SPACE, false)
	await _wait(5)
	quit()


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
