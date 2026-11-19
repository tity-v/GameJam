extends SceneTree
## 验证：虚影达到上限（5）后，新的一条顶掉**最早生成**的那条（先进先出）。

var lvl
var player
var manager


func _initialize() -> void:
	_run()


func _run() -> void:
	await _fresh()
	print("上限 = %d" % manager.max_echoes())

	for x in [100, 200, 300, 400, 500]:
		_add(Vector2(x, 480))
	await _wait(3)
	print("[满 5 条] 数量=%d x=%s" % [manager.echo_count(), _xs()])
	print("[子节点] EchoManager 子节点=%d（每条虚影一个）" % manager.get_child_count())

	_add(Vector2(600, 480))
	await _wait(3)
	print("[第 6 条] 数量=%d x=%s（期望 200/300/400/500/600，最早的 100 被清）" % [
		manager.echo_count(), _xs()])
	print("[子节点] 仍为 %d（被清的确实 free 了）" % manager.get_child_count())
	var bar := get_first_node_in_group("hud")
	if bar != null:
		var fl: Label = bar.get_node("Flash")
		print("[HUD 提示] %s（alpha=%.2f）" % [fl.text, fl.modulate.a])

	_add(Vector2(700, 480))
	_add(Vector2(800, 480))
	await _wait(3)
	print("[再连续加 2 条] 数量=%d x=%s（期望 400/500/600/700/800）" % [
		manager.echo_count(), _xs()])

	print("=== 尸体期（死亡淡出中）的虚影也参与上限 ===")
	await _fresh()
	for x in [100, 200, 300, 400, 500]:
		_add(Vector2(x, 480))
	# 轨迹 30 帧，等它播完就进入 1.3s 尸体淡出
	await _wait(45)
	var echoes := get_nodes_in_group("echo")
	print("[进入尸体期] 前两条 fading=%s/%s 数量=%d" % [
		echoes[0].get("_fading"), echoes[1].get("_fading"), manager.echo_count()])
	_add(Vector2(600, 480))
	await _wait(3)
	print("[尸体期再加一条] 数量=%d x=%s（仍不超 5）" % [manager.echo_count(), _xs()])

	print("=== 真实流程：连死 6 次，每次都保留最新一条 ===")
	await _fresh()
	for i in 6:
		# 每次死在不同的 x，方便区分谁被清
		player.global_position = Vector2(200 + i * 120, 522)
		player.velocity = Vector2.ZERO
		await _wait(6)
		_key(KEY_E, true)
		await physics_frame
		_key(KEY_E, false)
		await _wait(95)
		print("  第 %d 次死亡后：数量=%d 各虚影 x 范围=%s（ eldest 被顶掉才算对）" % [
			i + 1, manager.echo_count(), _span_xs()])

	quit()


func _add(pos: Vector2) -> void:
	var trail := PackedVector2Array()
	for i in 30:
		trail.append(pos)
	manager.call("_add_echo", trail)
	# _add_echo 里新虚影是隐藏的，测试里手动显示以便观察
	var e: Node2D = manager.get_child(manager.get_child_count() - 1)
	e.visible = true


func _xs() -> Array:
	var out := []
	for p in manager.echo_positions():
		out.append(int(p.x))
	return out


func _span_xs() -> Array:
	var out := []
	for e in get_nodes_in_group("echo"):
		if e.frames.size() > 0:
			out.append("%d~%d" % [int(e.frames[0].x), int(e.frames[e.frames.size() - 1].x)])
	return out


func _fresh() -> void:
	if lvl != null and is_instance_valid(lvl):
		lvl.queue_free()
		await _wait(3)
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	manager = lvl.get_node("EchoManager")
	await _wait(20)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
