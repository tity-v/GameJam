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
## 两个断口（768~832 / 960~1024）现在是**无底**的：掉下去 = 一次死亡 + 从出生点
## 重走，所以「一路按着跳」那种糊过去的写法不能用了。起跳点按实测给：
## 满速起跳水平距离 123px（不松跳跃键），断口 64px 宽。
##   右走：745 起跳落 868；920 起跳落 1047（正好落在手电上）
##   左走：1030 起跳落 912；850 起跳落 732
## 少跳一处、或起跳点偏 60px 以上，结果就是摔死；这几条数字是探针实拍出来的。
const GAPS_RIGHT := [745.0, 920.0]
const GAPS_LEFT := [1030.0, 850.0]

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

	# ---- 1. 去死路尽头捡手电（x=1050，要走完整条底层）----
	await _walk_to(p, 1050.0, 700, GAPS_RIGHT)
	await _frames(10)
	var lamp := p.get_node("Flashlight")
	expect(lamp.get("has_flashlight") == true, "在死路尽头捡到手电")

	# ---- 2. 走到板旁站住（这段会被录进虚影的轨迹里）----
	await _walk_to(p, 460.0, 400, GAPS_LEFT)
	# hop 会把玩家一路跳着送过来，松手时人还在空中；要等他落地站定再断言。
	# 光斑判定是贴地的扁椭圆（见 scripts/light_reach.gd），跳在空中的光是照不到
	# 脚下那块板的——这正是「隔着一层楼板够不着」的同一条规则。
	for i in 120:
		await physics_frame
		if sensor.call("is_lit"):
			break
	expect(absf(p.position.x - 460.0) < 24.0, "走到光敏板旁（x=%.0f）" % p.position.x)
	expect(sensor.call("is_lit"), "手电照着板 → 板亮")
	# 玩家从手电那边走回来时**路过**板 A 就点亮过它一轮，平台已经跑完一圈
	# 停在底部等待（phase=BOTTOM_WAIT，底部停留 1.2s）。所以要等够一整圈。
	for i in 180:
		await physics_frame
		if lift.position.y < 570.0:
			break
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
	print("D1 玩家=(%.0f,%.0f) 虚影=%s 板心=%s lit=%s lift=%.0f" % [
		p.position.x, p.position.y, str(echoes.call("echo_positions")),
		str(sensor.call("_plate_center")), sensor.call("is_lit"), lift.position.y])
	var lit_frame := -1
	for i in 900:
		await physics_frame
		if sensor.call("is_lit"):
			lit_frame = i
			break
	print("D2 虚影到位、板亮（%d 帧）lift=%.0f p.y=%.0f" % [lit_frame, lift.position.y, p.position.y])
	expect(lit_frame >= 0, "虚影终于站到板旁（%.1fs）" % (lit_frame / 60.0))

	# ---- 5. 被送到中层，然后跳到楼板 ----
	# 窗口要留够：虚影得先走完整条死路（去 1050 再回 460，约 8s）、站定，
	# 平台才能开始一次不被打断的 2.24s 上升。
	var top_frame := -1
	for i in 1500:
		await physics_frame
		if i % 120 == 0:
			print("   e f%4d lit=%s phase=%d lift=%.0f 虚影=%s" % [
				i, sensor.call("is_lit"), lift.get("phase"), lift.position.y,
				str(echoes.call("echo_positions"))])
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
	print("F2 出发前 liftB=%.0f litB=%s 火盆=%.0f" % [
		lift_b.position.y, room.get_node("SensorB").call("is_lit"), room.get_node("Brazier").get("radii").x])
	await _walk_to(p, 688.0, 500)
	print("F3 走路中 liftB=%.0f litB=%s 火盆=%.0f" % [
		lift_b.position.y, room.get_node("SensorB").call("is_lit"), room.get_node("Brazier").get("radii").x])
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


## 往右/左走到某个 x。hop=true 时「在断口区一落地就起跳」：
## 拿手电那段路上有两个 2 格宽的断口（768~832、960~1024），作者只靠 72px 微光
## 根本看不见，真人走到那儿也是一路摸黑连跳过去的。
##
## **只在断口区跳**（730~1050）不是图省事：跳出这个范围就一路飞 118px，
## 在板 A 旁边刹不住车，会飘过去 90 多像素站到平台 A 上——那样留下的虚影
## 站在台面上，平台一升就把它带走，它的光一离开板就灭，第一段直接无解。
func _walk_to(p: CharacterBody2D, x: float, limit: int, jumps: Array = []) -> void:
	var right: bool = x > p.position.x
	# jumps 传进来的是 const 数组（只读），pop_front 会静默失败，
	# 于是同一个起跳点反复触发、人一路乱跳进下一个断口。必须复制一份再消耗。
	var pending: Array = jumps.duplicate()
	Input.action_press("move_right" if right else "move_left")
	for i in limit:
		await physics_frame
		if p.is_dead:
			print("DIAG 摔死 x=%.1f y=%.1f f=%d 目标=%.0f 剩余起跳点=%s" % [
				p.position.x, p.position.y, i, x, str(pending)])
			break
		# pending 是「到这儿就该起跳」的坐标，按前进方向排队消耗。
		# 右走按升序、左走按降序给，起跳点都是实拍出来的（见文件头）。
		if not pending.is_empty() and p.is_on_floor():
			var trigger: float = float(pending[0])
			if (right and p.position.x >= trigger) or (not right and p.position.x <= trigger):
				pending.pop_front()
				await _jump()
		if right and p.position.x >= x:
			break
		if not right and p.position.x <= x:
			break
	Input.action_release("move_right" if right else "move_left")


func _jump() -> void:
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")


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
