extends SceneTree
## 临时验证脚本：用真实 InputEventKey 走 InputMap → 检查移动/撞墙/跳高/空中转向。

var lvl
var player


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")

	print("actions: ", InputMap.has_action("move_left"), InputMap.has_action("move_right"), InputMap.has_action("jump"))

	await _wait(40)
	print("[站立] y=%.1f on_floor=%s x=%.1f" % [player.position.y, player.is_on_floor(), player.position.x])

	var x0: float = player.position.x
	_key(KEY_D, true)
	await _wait(30)
	print("[右移 0.5s] dx=%.1f vx=%.1f" % [player.position.x - x0, player.velocity.x])
	await _wait(30)
	print("[右移 1.0s] dx=%.1f vx=%.1f" % [player.position.x - x0, player.velocity.x])
	_key(KEY_D, false)
	await _wait(20)
	print("[松手 0.33s] vx=%.1f (应趋近 0)" % player.velocity.x)

	# 一路向左撞墙
	_key(KEY_A, true)
	var min_x := 9999.0
	for i in 120:
		await physics_frame
		min_x = minf(min_x, player.position.x)
	_key(KEY_A, false)
	await _wait(10)
	print("[撞左墙] 最左 x=%.2f vx=%.1f (墙右边缘 x=0，应停在 0)" % [min_x, player.velocity.x])

	# 短跳：按 1 帧就松
	await _wait(20)
	var base_y: float = player.position.y
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	var short_top := 9999.0
	for i in 60:
		await physics_frame
		short_top = minf(short_top, player.position.y)
	print("[短跳] 高度 %.1f px" % (base_y - short_top))

	await _wait(30)

	# 长跳：按住
	base_y = player.position.y
	_key(KEY_SPACE, true)
	var long_top := 9999.0
	for i in 60:
		await physics_frame
		long_top = minf(long_top, player.position.y)
	_key(KEY_SPACE, false)
	print("[长跳] 高度 %.1f px" % (base_y - long_top))
	print("[跳高比] %.2f" % ((base_y - short_top) / maxf(1.0, base_y - long_top)))

	await _wait(40)

	# 空中转向：先站到场地中间，起跳后立刻按左
	player.position.x = 600.0
	player.velocity = Vector2.ZERO
	await _wait(20)
	base_y = player.position.y
	_key(KEY_SPACE, true)
	await _wait(4)
	var x1: float = player.position.x
	var vx_before: float = player.velocity.x
	_key(KEY_A, true)
	await _wait(20)
	print("[空中转向] vx %.1f -> %.1f, dx=%.1f (应变成负值)" % [vx_before, player.velocity.x, player.position.x - x1])
	_key(KEY_A, false)
	_key(KEY_SPACE, false)
	await _wait(60)
	print("[落地] y=%.1f on_floor=%s" % [player.position.y, player.is_on_floor()])

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
