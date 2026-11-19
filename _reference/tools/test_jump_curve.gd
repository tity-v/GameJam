extends SceneTree
## 临时验证：跳跃高度 / 滞空帧数，按“按住跳跃键 N 帧”逐档测，并导出两条轨迹。
## 用法：godot --headless --path . -s _reference/tools/test_jump_curve.gd

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

	print("jump=%.0f gravity=%.0f cut=%.2f" % [player.jump_velocity, player.gravity, player.jump_cut])
	for hold in [1, 2, 3, 4, 6, 8, 12, 20, 999]:
		var r = await _jump(hold)
		print("按住 %3s 帧: 高度 %6.1f px  滞空 %2d 帧" % [str(hold if hold < 999 else "∞"), r[0], r[1]])

	var full = await _jump(999, true)
	print("TRAJ_FULL=" + ",".join(full[2].map(func(v): return "%.1f" % v)))
	var tap = await _jump(1, true)
	print("TRAJ_TAP=" + ",".join(tap[2].map(func(v): return "%.1f" % v)))
	quit()


func _jump(hold: int, dump := false) -> Array:
	player.respawn()
	await _wait(12)
	var y0: float = player.position.y
	var min_y: float = y0
	var frames := 0
	var released := false
	var seq: Array = []
	_key(KEY_SPACE, true)
	while frames < 240:
		await physics_frame
		frames += 1
		min_y = minf(min_y, player.position.y)
		seq.append(y0 - player.position.y)
		if not released and frames >= hold:
			_key(KEY_SPACE, false)
			released = true
		if frames > 3 and player.is_on_floor():
			break
	if not released:
		_key(KEY_SPACE, false)
	await _wait(3)
	return [y0 - min_y, frames, seq if dump else []]


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
