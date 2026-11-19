extends SceneTree
## 验证碰撞调试层：框范围、脚底线/可踩线位置、F1 开关

var lvl: Node
var player: CharacterBody2D
var manager: Node
var dbg: Node2D


func _initialize() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	manager = lvl.get_node("EchoManager")
	dbg = player.get_node("HitboxDebug")
	_run()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _run() -> void:
	await _wait(5)

	var pr: Rect2 = dbg.call("_rect")
	print("=== 玩家调试框 ===")
	print("  rect = %s  （碰撞 shape 28x38，节点原点在左上角，所以应是 0,0,28,38）" % pr)
	print("  脚底线（局部 y）= %.1f  世界 y = %.2f" % [pr.end.y, player.global_position.y + pr.end.y])
	print("  贴地 = %s（脚底线应正好等于地面顶面 560）" % player.is_on_floor())

	# 造一条长轨迹的虚影，方便观察
	var trail := PackedVector2Array()
	for i in 600:
		trail.append(Vector2(400, 522))
	manager.call("_add_echo", trail)
	await _wait(2)
	var echoes := get_nodes_in_group("echo")
	var echo: Node2D = echoes[echoes.size() - 1]
	echo.visible = true
	echo.global_position = Vector2(400, 522)
	await _wait(1)

	var edbg: Node2D = echo.get_node("HitboxDebug")
	var er: Rect2 = edbg.call("_rect")
	print("\n=== 虚影调试框 ===")
	print("  rect = %s  （薄片 28x8）" % er)
	print("  可踩线（局部 y）= %.1f  世界 y = %.2f" % [er.position.y, echo.global_position.y + er.position.y])
	print("  薄片底（局部 y）= %.1f" % er.end.y)

	# 玩家站到虚影头上，看两条线是否重合
	player.global_position = Vector2(400, echo.global_position.y - pr.size.y)
	player.velocity = Vector2.ZERO
	await _wait(12)
	print("\n=== 踩上去 ===")
	print("  玩家脚底线 y = %.2f" % (player.global_position.y + pr.end.y))
	print("  虚影可踩线 y = %.2f" % (echo.global_position.y + er.position.y))
	print("  偏差 = %.2f px（0 = 完全重合）" % absf(
		(player.global_position.y + pr.end.y) - (echo.global_position.y + er.position.y)))
	print("  贴地 = %s" % player.is_on_floor())

	print("\n=== F1 开关 ===")
	print("  切换前：玩家框 visible=%s  虚影框 visible=%s" % [dbg.visible, edbg.visible])
	_key(KEY_F1)
	await _wait(3)
	print("  按一次：玩家框 visible=%s  虚影框 visible=%s" % [dbg.visible, edbg.visible])
	_key(KEY_F1)
	await _wait(3)
	print("  再按一次：玩家框 visible=%s  虚影框 visible=%s" % [dbg.visible, edbg.visible])

	print("\n=== 改尺寸后是否跟着变 ===")
	var col := player.get_node("Collision") as CollisionShape2D
	var sh := col.shape as RectangleShape2D
	sh.size = Vector2(56, 76)
	col.position = Vector2(28, 38)
	await _wait(3)
	print("  改成 56x76 后 rect = %s（框应立刻变）" % dbg.call("_rect"))

	quit()
