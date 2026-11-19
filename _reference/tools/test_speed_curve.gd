extends SceneTree
## 临时验证：逐帧打印水平速度，确认起步 6 帧、刹停 3 帧、反向的 S 形曲线。
## 用法：godot --headless --path . -s _reference/tools/test_speed_curve.gd

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

	print("start x=%.1f on_floor=%s accel=%.0f friction=%.0f power=%.2f" % [
		player.position.x, player.is_on_floor(), player.accel, player.friction, player.curve_power])

	var x0: float = player.position.x
	_key(KEY_D, true)
	var line := "起步 vx:"
	for i in 9:
		await physics_frame
		line += " %.1f" % player.velocity.x
	print(line, "  | dx=%.1f" % (player.position.x - x0))

	var x1: float = player.position.x
	_key(KEY_D, false)
	var line2 := "刹停 vx:"
	for i in 7:
		await physics_frame
		line2 += " %.1f" % player.velocity.x
	print(line2, "  | dx=%.1f" % (player.position.x - x1))

	# 反向：先跑到满速，再按左
	await _wait(12)
	_key(KEY_D, true)
	await _wait(12)
	var line3 := "反向 vx:"
	_key(KEY_A, true)
	_key(KEY_D, false)
	for i in 16:
		await physics_frame
		line3 += " %.1f" % player.velocity.x
	print(line3)
	_key(KEY_A, false)
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
