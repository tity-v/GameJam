extends SceneTree
## 3-2 的完整闭环（真实录制 → 重放 → 驱动，不用假虚影）：
##   捡手电 → 走到板旁站住 → 在板旁结束自己 → 复活跑上平台 →
##   虚影替他把板照着 → 平台升到中层 → 跳上楼板 → 走到平台 B →
##   手电引着火盆 → 平台 B 升到顶层 → 走出 → 通关
##
## 关键在「在板旁死」：虚影重放的末尾就是玩家死前站的位置，
## 它会在那里待机 7s 替玩家供光。死在别处（比如走进右边的坑）虚影也在别处，
## 板不会亮——这不是 bug，是这一关要玩家自己想到的事。
##
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/test_room32_loop.gd

const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"
const STAND := 2.4

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
	var lift_b := room.get_node("LiftB") as AnimatableBody2D
	var sensor := room.get_node("Sensor")
	var echoes := room.get_node("EchoManager")

	# ---- 1. 去死路尽头捡手电（x=1000，要走完整条底层）----
	await _walk_to(p, 1000.0, 700)
	await _frames(10)
	var lamp := p.get_node("Flashlight")
	expect(lamp.get("has_flashlight") == true, "在死路尽头捡到手电")

	# ---- 2. 走到板旁站住（这段会被录进虚影的轨迹里）----
	await _walk_to(p, 460.0, 400)
	await _frames(10)
	expect(absf(p.position.x - 460.0) < 24.0, "走到光敏板旁（x=%.0f）" % p.position.x)
	expect(sensor.call("is_lit"), "手电照着板 → 板亮")
	expect(lift.position.y < 570.0, "板一亮，平台就开始升（y=%.0f）" % lift.position.y)
	await _frames(int(STAND * 60.0))

	# 平台已经升上去了，玩家在原地够不着——只能靠虚影
	expect(lift.position.y < 500.0, "玩家站在板旁时平台已升走（y=%.0f）" % lift.position.y)

	# ---- 3. 在板旁结束自己 ----
	Input.action_press("die")
	await _frames(3)
	Input.action_release("die")
	await _frames(10)
	expect(echoes.call("echo_count") >= 1, "原地死亡留下虚影")

	# ---- 4. 复活，先上车、再等灯 ----
	# 虚影重放的是整条命：它得先跑到死路尽头、再走回来，才站到板旁。
	# 所以要反过来——玩家先站到台面上等，虚影一到位，台子就带着他升。
	for i in 240:
		await physics_frame
		if not p.is_dead:
			break
	print("B 复活 x=%.0f 虚影=%d" % [p.position.x, echoes.call("echo_count")])
	await _walk_to(p, 336.0, 400)
	print("C 到平台下方 x=%.0f y=%.0f lift=%.0f phase=%d" % [
		p.position.x, p.position.y, lift.position.y, lift.get("phase")])

	# 在凹槽里等它回到底部再跳。玩家站在台子正下方时，落回来的台板会直接从
	# 身上穿过去（单向板），所以「等」比「追」稳。
	var bottom_wait := -1
	for i in 600:
		await physics_frame
		if lift.position.y >= 575.0:
			bottom_wait = i
			break
	print("C2 等到平台回底 %d 帧 lift=%.0f phase=%d" % [bottom_wait, lift.position.y, lift.get("phase")])
	_key(KEY_SPACE, true)
	await _frames(6)
	_key(KEY_SPACE, false)
	await _frames(26)
	print("D 跳上平台 x=%.0f y=%.0f on_floor=%s lift=%.0f" % [
		p.position.x, p.position.y, p.is_on_floor(), lift.position.y])
	expect(p.position.y < 545.0, "从凹槽跳上台面（y=%.0f）" % p.position.y)

	# 等虚影走到板旁（它要重放整条命，最长 ~6s）
	var lit_frame := -1
	for i in 900:
		await physics_frame
		if sensor.call("is_lit"):
			lit_frame = i
			break
	print("D2 虚影到位、板亮（%d 帧）lift=%.0f p.y=%.0f" % [lit_frame, lift.position.y, p.position.y])
	expect(lit_frame >= 0, "虚影终于站到板旁（%.1fs）" % (lit_frame / 60.0))

	# ---- 5. 被送到中层，然后跳到楼板 ----
	var top_frame := -1
	for i in 600:
		await physics_frame
		if lift.position.y <= 353.0 and p.position.y < 360.0:
			top_frame = i
			break
	print("E 到中层 %d 帧 lift=%.0f p.y=%.0f" % [top_frame, lift.position.y, p.position.y])
	expect(top_frame > 0, "平台把玩家送到中层")
	expect(absf(p.position.y - 308.0) < 16.0, "玩家在中层台面上（y=%.0f）" % p.position.y)

	# 平台右缘 380 / 楼板左缘 416，差 36px：往右跳一下
	_key(KEY_D, true)
	await _frames(6)
	_key(KEY_SPACE, true)
	await _frames(6)
	_key(KEY_SPACE, false)
	await _frames(30)
	_key(KEY_D, false)
	await _frames(20)
	print("F 跳上楼板 x=%.0f y=%.0f on_floor=%s" % [p.position.x, p.position.y, p.is_on_floor()])
	expect(p.position.x > 400.0, "能跳到中层楼板（x=%.0f）" % p.position.x)

	# ---- 6. 走到平台 B，手电引着火盆 ----
	await _walk_to(p, 688.0, 500)
	await _frames(20)
	print("G 到平台 B x=%.0f y=%.0f on_floor=%s liftB=%.0f" % [
		p.position.x, p.position.y, p.is_on_floor(), lift_b.position.y])
	expect(absf(p.position.x - 688.0) < 40.0, "走上平台 B（x=%.0f）" % p.position.x)

	var brazier := room.get_node("Brazier")
	var brazier_lit := -1
	for i in 200:
		await physics_frame
		if brazier.get("can_power") == true:
			brazier_lit = i
			break
	expect(brazier_lit >= 0, "手电照到火盆 → 火盆着起来")
	# 引燃期间 can_power 一开始只有 60，火盆到板 B 是 130，要等它烧到满亮 140
	await _frames(60)
	expect(room.get_node("SensorB").call("is_lit"), "火盆烧旺后点亮板 B")

	# ---- 7. 平台 B 送到顶层，走出去 ----
	var b_top := -1
	for i in 400:
		await physics_frame
		if lift_b.position.y <= 129.0:
			b_top = i
			break
	print("H 到顶 %d 帧 liftB=%.0f p.y=%.0f" % [b_top, lift_b.position.y, p.position.y])
	expect(b_top > 0, "平台 B 送到顶层")
	expect(absf(p.position.y - 84.0) < 16.0, "玩家被带到顶层（y=%.0f）" % p.position.y)

	await _walk_to(p, 150.0, 700)
	print("I 到出口 x=%.0f y=%.0f" % [p.position.x, p.position.y])
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
