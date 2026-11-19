extends SceneTree
## 临时验证：空中松手后的滑行距离/帧数（惯性）。
## 用法：godot --headless --path . -s _reference/tools/test_air_drag.gd

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

	print("air_accel=%.0f air_friction=%.0f" % [player.air_accel, player.air_friction])
	_key(KEY_D, true)
	await _wait(20)
	_key(KEY_SPACE, true)
	await _wait(6)
	_key(KEY_SPACE, false)
	_key(KEY_D, false)
	var x0: float = player.position.x
	var line := "松手 vx:"
	var frames := 0
	for i in 60:
		await physics_frame
		frames += 1
		line += " %.0f" % player.velocity.x
		if absf(player.velocity.x) < 1.0:
			break
	print(line)
	print("滑行 %d 帧 / %.1f px, on_floor=%s" % [frames, player.position.x - x0, player.is_on_floor()])
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
