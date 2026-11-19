extends SceneTree
## 临时验证：虚影单向碰撞（侧面穿过 / 头顶站住 / 下方穿过）、门是实体、死亡留虚影与上限、站头上被带走。

const ECHO := preload("res://scenes/echo/echo.tscn")

var lvl
var player
var manager


func _initialize() -> void:
	_run()


func _run() -> void:
	await _fresh()
	print("=== 1. 虚影碰撞语义（静止虚影在 400,480 / 400,522） ===")
	var ghost_a := _add_static_echo(Vector2(400, 480))

	# 1a 从上方落下 → 应该踩在它头上（y = 480-38 = 442）
	player.global_position = Vector2(400, 300)
	player.velocity = Vector2.ZERO
	await _wait(70)
	print("[从上落下] y=%.1f (期望 442) on_floor=%s" % [player.global_position.y, player.is_on_floor()])

	# 1b 侧面走过同高度的虚影 → 应该穿过去
	ghost_a.queue_free()
	var ghost_b := _add_static_echo(Vector2(600, 522))
	player.global_position = Vector2(480, 522)
	player.velocity = Vector2.ZERO
	await _wait(10)
	_key(KEY_D, true)
	await _wait(60)
	_key(KEY_D, false)
	print("[侧面穿过] x=%.1f (虚影右边缘 628，期望 >628)" % player.global_position.x)

	# 1c 从下方跳 → 不应被挡（虚影底边 430，头顶能穿过 430~438 的薄片）
	ghost_b.queue_free()
	var ghost_c := _add_static_echo(Vector2(600, 430))
	player.global_position = Vector2(600, 522)
	player.velocity = Vector2.ZERO
	await _wait(10)
	var base_y: float = player.global_position.y
	_key(KEY_SPACE, true)
	var top := 9999.0
	for i in 40:
		await physics_frame
		top = minf(top, player.global_position.y)
	_key(KEY_SPACE, false)
	print("[下方跳穿] 最高 y=%.1f，跳高 %.1f px（没被薄片挡住才算正常）" % [top, base_y - top])
	ghost_c.queue_free()
	await _wait(40)

	print("=== 2. 中间的门是实体 ===")
	await _fresh()
	_key(KEY_D, true)
	await _wait(200)
	_key(KEY_D, false)
	print("[一路向右] x=%.2f (门左边 790，玩家宽 28，期望停在 762)" % player.global_position.x)

	print("=== 3. 死亡留虚影 + 上限 5 ===")
	await _fresh()
	print("[初始] 虚影数=%d" % manager.echo_count())
	for i in 6:
		# 走一段再死，让轨迹有内容
		_key(KEY_D, true)
		await _wait(20)
		_key(KEY_D, false)
		_key(KEY_E, true)
		await physics_frame
		_key(KEY_E, false)
		await _wait(95)  # 1.3s 死亡动画 + 复活
		print("  第 %d 次死亡后：虚影数=%d 帧数=%s" % [i + 1, manager.echo_count(), manager.echo_frames()])

	# 复活后虚影应该在重放（位置随时间变化）
	var p1 = manager.echo_positions()
	await _wait(30)
	var p2 = manager.echo_positions()
	print("[重放中] 30 帧后虚影是否移动：%s -> %s" % [p1[0], p2[0]])

	print("=== 4. 站在移动虚影头上会被带着走 ===")
	await _fresh()
	var trail := PackedVector2Array()
	for i in 200:
		trail.append(Vector2(300 + i * 2.0, 480))
	manager.call("_add_echo", trail)
	manager.get_child(manager.get_child_count() - 1).reset()
	player.global_position = Vector2(300, 442)
	player.velocity = Vector2.ZERO
	await _wait(40)
	var x_start: float = player.global_position.x
	var y_start: float = player.global_position.y
	await _wait(60)
	print("[被带走] x %.1f -> %.1f（虚影每秒右移 120px），y=%.1f（应还在 442）" % [
		x_start, player.global_position.x, player.global_position.y])

	quit()


func _fresh() -> void:
	if lvl != null and is_instance_valid(lvl):
		lvl.queue_free()
		await _wait(3)
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	manager = lvl.get_node("EchoManager")
	await _wait(30)


func _add_static_echo(pos: Vector2) -> Node2D:
	var e := ECHO.instantiate()
	lvl.add_child(e)
	e.setup(PackedVector2Array([pos, pos]))
	e.reset()  # setup 只是载入，reset 才是「登场」
	return e


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
