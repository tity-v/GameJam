extends SceneTree
## 验证：虚影播完轨迹后在场上多留 1.3 秒（对齐玩家 death_duration），
## 这 1.3 秒里尸体仍是实体、能站，叉号不跟着淡，时间到才消失并关碰撞。

const ECHO := preload("res://scenes/echo/echo.tscn")

var lvl
var player
var manager


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== 1. 轨迹 60 帧，之后应再活 1.3s（78 帧） ===")
	await _fresh()
	var echo := _make_echo(Vector2(400, 480), 60)
	# 同步把玩家放到虚影头顶（442 = 480 - 38），整段时间都踩在尸体上
	player.global_position = Vector2(400, 442)
	player.velocity = Vector2.ZERO

	var fade_start := -1
	var gone_frame := -1
	var alpha_at_fade := 0.0
	var alpha_last := 0.0
	var on_floor_during_fade := true
	var y_before_gone := 0.0
	var y_after_gone := 0.0

	for i in 240:
		await physics_frame
		var fading: bool = echo.get("_fading")
		var gone: bool = echo.get("_gone")
		if fade_start < 0 and fading:
			fade_start = i
			alpha_at_fade = echo.get_node("Body").modulate.a
			print("[进入死亡] 第 %d 帧（轨迹 60 帧，期望 ≈60）alpha=%.2f 玩家 on_floor=%s y=%.1f" % [
				i, alpha_at_fade, player.is_on_floor(), player.global_position.y])
		if fade_start >= 0 and not gone:
			if not player.is_on_floor():
				on_floor_during_fade = false
			alpha_last = echo.get_node("Body").modulate.a
			y_before_gone = player.global_position.y
		if gone_frame < 0 and gone:
			gone_frame = i
			print("[消失] 第 %d 帧，死亡持续 %d 帧（期望 ≈78 = 1.3s）末 alpha=%.2f" % [
				i, i - fade_start, alpha_last])
			y_before_gone = player.global_position.y
		if gone_frame >= 0 and i >= gone_frame + 20:
			y_after_gone = player.global_position.y
			break

	print("[尸体上站立] 整个死亡期内始终 on_floor=%s（应为 true，说明碰撞还开着）" % on_floor_during_fade)
	print("[消失后下坠] y %.1f -> %.1f（应明显变大，说明碰撞已关）" % [y_before_gone, y_after_gone])
	print("[叉号不随方块淡] 末 alpha=%.2f（Body 淡到 0.18，Cross 节点 modulate 恒为 1）" % alpha_last)

	print("=== 2. 真实流程：死一次留虚影，重放完再活 1.3s ===")
	await _fresh()
	_key(KEY_D, true)
	await _wait(60)
	_key(KEY_D, false)
	await _die_and_wait()
	var e := _first_echo()
	if e == null:
		print("没有虚影 —— 异常")
		quit()
		return
	var total: int = e.frames.size()
	print("[虚影] 轨迹 %d 帧（≈%.2f 秒），玩家活着约 1.5 秒" % [total, total / 60.0])
	var fade_at := -1
	var gone_at := -1
	for i in 400:
		await physics_frame
		if fade_at < 0 and e.get("_fading"):
			fade_at = i
		if gone_at < 0 and e.get("_gone"):
			gone_at = i
			break
	print("[时间轴] 重放 %d 帧后进入死亡，死亡 %d 帧后消失（期望 78）" % [
		fade_at, gone_at - fade_at])

	print("=== 3. 虚影淡出期间玩家仍可踩跳 ===")
	await _fresh()
	var e3 := _make_echo(Vector2(400, 480), 30)
	player.global_position = Vector2(400, 300)
	player.velocity = Vector2.ZERO
	# 等它播完 30 帧并进入死亡，此时玩家应该已经站在尸体上
	await _wait(70)
	print("[死亡期] fading=%s 玩家 y=%.1f on_floor=%s" % [
		e3.get("_fading"), player.global_position.y, player.is_on_floor()])
	var base_y: float = player.global_position.y
	_key(KEY_SPACE, true)
	var top := 9999.0
	for i in 30:
		await physics_frame
		top = minf(top, player.global_position.y)
	_key(KEY_SPACE, false)
	print("[从尸体上起跳] 跳高 %.1f px（>0 说明尸体提供了起跳面）" % (base_y - top))

	quit()


## 必须走 manager._add_echo：只有登记进 _echoes 的虚影才会被每帧 advance
func _make_echo(pos: Vector2, frames: int) -> Node2D:
	var trail := PackedVector2Array()
	for i in frames:
		trail.append(pos)
	manager.call("_add_echo", trail)
	var e: Node2D = manager.get_child(manager.get_child_count() - 1)
	e.visible = true
	return e


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
