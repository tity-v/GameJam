extends SceneTree
## 跳跃参数敏感度扫描：轻点高度 vs jump_cut、滞空 vs 下落重力倍率。
## 用法：godot --headless --path . --fixed-fps 60 -s _reference/tools/sweep_jump.gd

var lvl
var player


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	for i in 30:
		await physics_frame

	print("SWEEP cut")
	for cut in [0.35, 0.40, 0.45, 0.50, 0.55, 0.65]:
		player.jump_cut = cut
		var r: Array = await _jump(1)
		print("S cut=%.2f tap_h=%.1f tap_air=%d" % [cut, r[0], r[1]])

	player.jump_cut = 0.45
	print("SWEEP fall")
	for fm in [1.0, 1.1, 1.3, 1.5, 1.7]:
		player.fall_gravity_mult = fm
		var r: Array = await _jump(999)
		print("S fall=%.2f full_h=%.1f full_air=%d" % [fm, r[0], r[1]])
	quit()


func _jump(hold: int) -> Array:
	player.respawn()
	await physics_frame
	for i in 12:
		await physics_frame
	var y0: float = player.position.y
	var min_y := y0
	var frames := 0
	var released := false
	_key(KEY_SPACE, true)
	while frames < 240:
		await physics_frame
		frames += 1
		min_y = minf(min_y, player.position.y)
		if not released and frames >= hold:
			_key(KEY_SPACE, false)
			released = true
		if frames > 4 and player.is_on_floor():
			break
	if not released:
		_key(KEY_SPACE, false)
	for i in 3:
		await physics_frame
	return [y0 - min_y, frames]


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
