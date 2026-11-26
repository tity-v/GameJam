extends SceneTree
## 3-2 的完整闭环：活着去光敏板上站够时间 → 走进坑 → 复活上平台 → 虚影重放把他送到顶层。
## 这一条如果用假虚影验，就等于没验「录制→重放→驱动」这条链路。
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/test_room32_loop.gd

const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"
const STAND := 3.6

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(10)
	var p := room.get_node("Player") as CharacterBody2D
	var lift := room.get_node("Lift") as AnimatableBody2D
	var echoes := room.get_node("EchoManager")

	# ---- 第一次活着：走到光敏板附近站 3.6s，再一路走进右边的坑 ----
	# 判定已改成「光斑覆盖板」（板中心 x=492），所以活着时要站到板附近 x=460，
	# 让虚影重放时站在这里、光斑（半径 72）能覆盖到板。
	await _walk_to(p, 460.0, 600)
	await _frames(24)
	print("A 站到光敏板附近 x=%.1f y=%.1f" % [p.position.x, p.position.y])
	expect(absf(p.position.x - 460.0) < 30.0, "活着能走到光敏板附近")
	await _frames(int(STAND * 60.0))
	expect(is_equal_approx(lift.position.y, 576.0), "底光站在板上推不动平台")
	await _walk_to(p, 1200.0, 900)
	await _frames(2)
	expect(echoes.call("echo_count") >= 1, "死亡留下一条虚影")

	# ---- 复活：立刻往平台跑 ----
	# 等自然复活：`respawned` 信号会把虚影倒回第 0 帧，手动 reset_to_spawn 不会发这个信号。
	# 复活与虚影开局是同一帧，所以这一段不能有额外等待——多等 1s 平台就已经升走了。
	for i in 200:
		await physics_frame
		if not p.is_dead:
			break
	print("B 复活 x=%.1f echo=%d" % [p.position.x, echoes.call("echo_count")])
	await _walk_to(p, 330.0, 600)
	await _frames(20)
	print("C 上平台 x=%.1f y=%.1f lift=%.1f" % [p.position.x, p.position.y, lift.position.y])
	expect(absf(p.position.x - 336.0) < 40.0, "复活后能站到平台上")

	# 停在「到顶那一帧」再判人：平台到顶后虚影一走就往下掉，
	# 在循环外面判会读到「已经掉回底部」的状态（上一版就是这么误判的）。
	var top_reached := -1
	for i in 480:
		await physics_frame
		if lift.position.y <= 353.0:
			top_reached = i
			break
	print("D 到中层用了 %d 帧（%.1fs）lift=%.1f p.y=%.1f" % [top_reached, top_reached / 60.0, lift.position.y, p.position.y])
	expect(top_reached > 0, "虚影把平台 A 推到中层")
	expect(absf(p.position.y - 308.0) < 12.0, "玩家被带到中层（y=%.1f）" % p.position.y)

	# ---- 第一段到站：从中层平台跳到楼板（平台右缘 380，楼板左缘 416，差 36px） ----
	_key(KEY_D, true)
	await _frames(8)
	_key(KEY_SPACE, true)
	await _frames(6)
	_key(KEY_SPACE, false)
	await _frames(34)
	_key(KEY_D, false)
	await _frames(20)
	print("E 跳上中层楼板 x=%.1f y=%.1f on_floor=%s" % [p.position.x, p.position.y, p.is_on_floor()])
	expect(p.position.x > 400.0, "能跳到中层楼板（x>400）")

	# ---- 第二段：走到中层右端 → 走上平台 B → 打火点火盆 ----
	await _walk_to(p, 620.0, 400)
	expect(p.position.x > 560.0, "能走到中层右端")
	var lift_b := room.get_node("LiftB") as AnimatableBody2D
	expect(is_equal_approx(lift_b.position.y, 352.0), "平台 B 在中层等着")
	await _walk_to(p, 690.0, 200)
	await _frames(20)
	print("F 走上平台 B x=%.1f y=%.1f on_floor=%s" % [p.position.x, p.position.y, p.is_on_floor()])
	expect(absf(p.position.x - 688.0) < 40.0, "能走上平台 B")

	# 火把在 (704,330)，火盆在 (760,352)，差 60px —— 站台上就点得着。
	# 板 B 在 (880,341)，差 176px，自己打火永远点不着，只能靠火盆。
	_key(KEY_SHIFT, true)
	await _frames(4)
	_key(KEY_SHIFT, false)
	await _frames(130)
	expect(lift_b.position.y < 340.0, "火盆点着后平台 B 开始升（y=%.1f）" % lift_b.position.y)

	var b_top := -1
	for i in 300:
		await physics_frame
		if lift_b.position.y <= 129.0:
			b_top = i
			break
	print("G 到顶用了 %d 帧（%.1fs）liftB=%.1f p.y=%.1f" % [b_top, b_top / 60.0, lift_b.position.y, p.position.y])
	expect(b_top > 0, "火盆把平台 B 送到顶层")
	expect(absf(p.position.y - 84.0) < 12.0, "玩家被带到顶层（y=%.1f）" % p.position.y)

	# ---- 走到出口：全程往左，平台 B 与顶层楼板齐平，直接走下去 ----
	await _walk_to(p, 150.0, 600)
	print("H 到出口 x=%.1f y=%.1f on_floor=%s" % [p.position.x, p.position.y, p.is_on_floor()])
	expect(p.position.x < 300.0, "走到顶层楼板左侧（x<300）")
	# 碰到出口后 room_controller.complete() 会关掉玩家的物理，人悬在半空是正常的，
	# 所以这里判的是「通关」，不是「落地」。
	expect(room.get("won"), "碰到出口即通关")

	print("ROOM32LOOP %d/%d" % [_pass, _pass + _fail])
	if _fail > 0:
		print("ROOM32LOOP_FAIL %d" % _fail)
	quit()


func _walk_to(p: CharacterBody2D, x: float, limit: int) -> void:
	var right: bool = x > p.position.x
	Input.action_press("move_right" if right else "move_left")
	for i in limit:
		await physics_frame
		if p.is_dead:
			break
		if right and p.position.x >= x:
			break
		if not right and p.position.x <= x:
			break
	Input.action_release("move_right" if right else "move_left")


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func expect(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("PASS ", label)
	else:
		_fail += 1
		print("FAIL ", label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
