extends SceneTree
## 验证：R 重置全部虚影、重置后录制从当下重来、暂停中 R 无效、底部 HUD 在位。

var lvl
var player
var manager


func _initialize() -> void:
	_run()


func _run() -> void:
	await _fresh()

	print("=== 1. HUD 是否挂上（autoload） ===")
	var hud := root.get_node_or_null("Hud")
	print("[Hud] 节点=%s" % (hud != null))
	var bar := get_first_node_in_group("hud")
	print("[条] 在组 hud=%s 尺寸=%s" % [bar != null, (bar as Control).size if bar else Vector2.ZERO])
	print("[项目输入] reset_echoes=%s / die=%s" % [
		InputMap.has_action("reset_echoes"), InputMap.has_action("die")])

	print("=== 2. 造 3 条虚影后按 R ===")
	await _seed_echoes(3)
	print("[按 R 前] 虚影数=%d 位置=%s" % [manager.echo_count(), manager.echo_positions()])
	_key(KEY_R, true)
	await physics_frame
	_key(KEY_R, false)
	await _wait(4)
	print("[按 R 后] 虚影数=%d" % manager.echo_count())
	if bar != null:
		var fl: Label = bar.get_node("Flash")
		print("[HUD 反馈] %s（alpha=%.2f）" % [fl.text, fl.modulate.a])

	print("=== 3. 重置后这一轮的录制是否从出生点重来 ===")
	await _fresh()
	# 先跑到 x≈500（前面这段路不该出现在重置后的虚影里）
	player.global_position = Vector2(500, 522)
	player.velocity = Vector2.ZERO
	await _wait(6)
	_key(KEY_R, true)
	await physics_frame
	_key(KEY_R, false)
	await _wait(2)
	var x_reset: float = player.global_position.x
	print("[R 后人位置] x=%.1f（出生点 %.1f，应基本重合）" % [x_reset, player.respawn_position.x])
	# 重置后继续往右跑半秒再死
	_key(KEY_D, true)
	await _wait(30)
	_key(KEY_D, false)
	await _die_and_wait()
	var echo := _first_echo()
	if echo != null:
		print("[虚影首帧] x=%.1f（应从重置点 %.1f 附近开始，差值应 < 60）" % [
			echo.frames[0].x, x_reset])
		print("[虚影末帧] x=%.1f（死亡位置，应 > 重置点）" % echo.frames[echo.frames.size() - 1].x)
	else:
		print("[虚影首帧] 没有虚影 —— 异常")

	print("=== 4. 暂停中按 R 不应生效 ===")
	await _fresh()
	await _seed_echoes(2)
	_key(KEY_ESCAPE, true)
	await physics_frame
	_key(KEY_ESCAPE, false)
	await _wait(3)
	print("[暂停中] paused=%s 虚影数=%d" % [paused, manager.echo_count()])
	_key(KEY_R, true)
	await physics_frame
	_key(KEY_R, false)
	await _wait(3)
	print("[暂停中按 R] 虚影数=%d（应保持 2）" % manager.echo_count())
	_key(KEY_ESCAPE, true)
	await physics_frame
	_key(KEY_ESCAPE, false)
	await _wait(3)

	print("=== 5. 重置后玩家仍能正常操作 ===")
	_key(KEY_D, true)
	await _wait(30)
	_key(KEY_D, false)
	print("[重置后移动] dx=%.1f vx=%.1f" % [player.velocity.x, player.global_position.x])
	print("[R 不触发死亡] is_dead=%s" % player.is_dead)

	print("=== 6. R 与死亡上限 5 共存 ===")
	await _fresh()
	for i in 6:
		await _die_and_wait()
	print("[死 6 次] 虚影数=%d（上限 5）" % manager.echo_count())
	_key(KEY_R, true)
	await physics_frame
	_key(KEY_R, false)
	await _wait(4)
	print("[再按 R] 虚影数=%d" % manager.echo_count())

	quit()


func _seed_echoes(n: int) -> void:
	for i in n:
		var trail := PackedVector2Array()
		for f in 40:
			trail.append(Vector2(300 + f * 2.0 + i * 40.0, 480))
		manager.call("_add_echo", trail)
	await _wait(2)


func _first_echo() -> Node:
	var echoes := get_nodes_in_group("echo")
	if echoes.is_empty():
		return null
	return echoes[0]


func _die_and_wait() -> void:
	_key(KEY_E, true)
	await physics_frame
	_key(KEY_E, false)
	await _wait(95)


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
