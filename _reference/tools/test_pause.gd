extends SceneTree
## 临时验证：ESC 暂停 → 全静止 → 点「继续」图标恢复。

var lvl
var player
var menu
var btn
var root_control


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	menu = root.get_node_or_null("PauseMenu")
	if menu == null:
		print("!! autoload PauseMenu 不存在")
		quit(1)
		return
	root_control = menu.get_node("Root")
	btn = menu.get_node("Root/ContinueButton")

	await _wait(20)
	print("[开始] paused=%s overlay=%s" % [paused, root_control.visible])

	# ---------- ESC 暂停 ----------
	_key(KEY_ESCAPE, true)
	await _wait(2)
	_key(KEY_ESCAPE, false)
	await _wait(2)
	print("[按 ESC] paused=%s overlay=%s" % [paused, root_control.visible])

	# ---------- 暂停中一切静止 ----------
	var p0: Vector2 = player.global_position
	var v0: Vector2 = player.velocity
	_key(KEY_D, true)
	await _wait(40)
	_key(KEY_D, false)
	print("[暂停中按 D 0.66s] 位移=(%.2f, %.2f) vel=(%.2f, %.2f) (应全 0)" % [
		player.global_position.x - p0.x, player.global_position.y - p0.y,
		player.velocity.x, player.velocity.y])

	_key(KEY_E, true)
	await _wait(2)
	_key(KEY_E, false)
	await _wait(10)
	print("[暂停中按 E] is_dead=%s (应 false，逻辑一起停)" % player.is_dead)

	# ---------- 点空白处不应恢复 ----------
	_click(Vector2(120, 620))
	await _wait(4)
	print("[点空白] paused=%s (应仍 true)" % paused)

	# ---------- 点「继续」图标 ----------
	var c: Vector2 = btn.get_global_rect().get_center()
	print("[按钮] rect=%s 中心=%s" % [btn.get_global_rect(), c])
	_click(c)
	await _wait(4)
	print("[点继续] paused=%s overlay=%s (应 false / false)" % [paused, root_control.visible])

	# ---------- 恢复后操作正常 ----------
	var x1: float = player.global_position.x
	_key(KEY_D, true)
	await _wait(30)
	print("[恢复后右移 0.5s] dx=%.1f vx=%.1f (应能动)" % [player.global_position.x - x1, player.velocity.x])
	_key(KEY_D, false)
	await _wait(20)

	# ---------- ESC 可反复开关 ----------
	_key(KEY_ESCAPE, true)
	await _wait(2)
	_key(KEY_ESCAPE, false)
	await _wait(2)
	print("[再按 ESC] paused=%s" % paused)
	_key(KEY_ESCAPE, true)
	await _wait(2)
	_key(KEY_ESCAPE, false)
	await _wait(2)
	print("[再按 ESC 恢复] paused=%s overlay=%s" % [paused, root_control.visible])

	quit()


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## 注意：headless 下 `Input.parse_input_event()` 送鼠标事件到不了 GUI（键盘可以），
## 必须直接 push_input 到根 Viewport —— 真实鼠标点击走的也是这条路径。
func _click(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	for is_down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = is_down
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev, true)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
