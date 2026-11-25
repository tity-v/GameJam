extends SceneTree
## 第三章原型的「对抗性」验收：不是验设计意图，是试着把它弄坏。
##
## 前四组测试（test_room31 / test_room32 / test_room32_loop）都在验
## 「按设计走能通关」。这一组反过来问：
##   1. 按 R 之后，铁栅 / 平台 / 预告虚影 真的回到初始状态了吗？
##   2. 平台落回底部时，站在竖井里的人会被怎么样？（砸、压穿地板、挤进墙）
##   3. 玩家不去死，而是站在光敏板上打火，会发什么？
##   4. 光敏板的 echo_radii 和黑幕的 echo_radii 是两份独立数据，会不同步吗？
##
##   godot --headless --path . --fixed-fps 60 -s res://_reference/tools/test_chapter3_edge.gd

const ROOM31 := "res://scenes/levels/chapter_03/room_31_proto.tscn"
const ROOM32 := "res://scenes/levels/chapter_03/room_32_proto.tscn"

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _case_32_reset()
	await _case_crush_by_lift()
	await _case_fire_from_plate()
	await _case_31_reset()
	await _case_real_R_32()
	await _case_real_R_31()
	_case_radii_sync()
	print("EDGE %d/%d" % [_pass, _pass + _fail])
	if _fail > 0:
		print("EDGE_FAIL %d" % _fail)
	quit()


# ---------------------------------------------------------------- 3-2 按 R

func _case_32_reset() -> void:
	print("--- 1. 3-2 按 R 复位平台")
	var room := await _mount(ROOM32)
	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor") as Node2D

	sensor.set("force", 1)
	for i in 240:
		await physics_frame
	var raised: float = lift.position.y
	expect(raised < 400.0, "强制点亮后平台升上去了（y=%.0f）" % raised)

	room.call("reset_mechanisms")
	await physics_frame
	expect(is_equal_approx(lift.position.y, 576.0), "R 之后平台回到底部（y=%.0f）" % lift.position.y)
	expect(is_equal_approx(lift.get("speed"), 0.0), "R 之后平台速度清零（%.0f）" % lift.get("speed"))

	# 关键：复位后不能自己又升起来（force 已经归零，底光推不动）
	sensor.set("force", 0)
	await _frames(30)
	expect(is_equal_approx(lift.position.y, 576.0), "复位后 30 帧内保持静止")

	# 复位不能是一次性的：再次给光，平台要能照常升
	sensor.set("force", 1)
	for i in 120:
		await physics_frame
	expect(lift.position.y < 500.0, "复位后还能再升（y=%.0f）" % lift.position.y)
	await _unmount(room)


# ------------------------------------------------- 平台落回时砸站在井底的人

func _case_crush_by_lift() -> void:
	print("--- 2. 平台从顶层落回，砸到站在竖井里的玩家")
	var room := await _mount(ROOM32)
	var p := room.get_node("Player") as CharacterBody2D
	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor") as Node2D

	# 站到光敏板右下侧：既在感应区里（能持续给光），又不在平台正上方（不会被带走）
	p.position = Vector2(420, 532)
	await _frames(8)
	var y0 := p.position.y

	sensor.set("force", 1)
	var top_frame := -1
	for i in 480:
		await physics_frame
		if lift.position.y <= 129.0:
			top_frame = i
			break
	expect(top_frame > 0, "平台升到顶层（用了 %d 帧）" % top_frame)
	expect(is_equal_approx(p.position.y, y0), "玩家站在井底没被平台带走（y=%.0f）" % p.position.y)

	# 断光 → 平台落回来，正好路过玩家的身体（玩家 532~576，平台板 128~144 起）
	sensor.set("force", -1)
	var worst_y := p.position.y
	var worst_dx := 0.0
	var died := false
	var max_overlap := 0.0
	for i in 420:
		await physics_frame
		worst_y = maxf(worst_y, p.position.y)
		worst_dx = maxf(worst_dx, absf(p.position.x - 420.0))
		if p.is_dead:
			died = true
			break
		# 只有在 x 上也重叠时，才算「板子压到人」——平台板 x 是 ±44，玩家宽 32
		var x_hit := minf(p.position.x + 32.0, lift.position.x + 44.0) \
			- maxf(p.position.x, lift.position.x - 44.0)
		if x_hit > 0.0:
			var overlap := minf(p.position.y + 44.0, lift.position.y + 16.0) \
				- maxf(p.position.y, lift.position.y)
			max_overlap = maxf(max_overlap, overlap)
	print("   落回后：玩家 y=%.1f（最差 %.1f）横移 %.1f 死亡 %s 压入 %.1fpx" \
		% [p.position.y, worst_y, worst_dx, died, max_overlap])
	expect(not died, "平台落回没有把玩家压死")
	expect(worst_y < 580.0, "玩家没有被压穿地板（最差 y=%.1f）" % worst_y)
	expect(worst_dx < 40.0, "玩家没有被横着挤飞（最大横移 %.1fpx）" % worst_dx)
	expect(max_overlap < 8.0, "平台板没有明显压进玩家身体（%.1fpx）" % max_overlap)
	expect(lift.position.y >= 575.0, "平台最终落回底部（y=%.1f）" % lift.position.y)
	await _unmount(room)


# --------------------------------------------- 玩家不去死，站在板上打火

func _case_fire_from_plate() -> void:
	print("--- 3. 玩家站在光敏板上打火（不站在平台上）")
	var room := await _mount(ROOM32)
	var p := room.get_node("Player") as CharacterBody2D
	var lift := room.get_node("Lift") as AnimatableBody2D

	p.position = Vector2(420, 532)
	await _frames(8)
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")

	var peak := 9999.0
	for i in 200:
		await physics_frame
		peak = minf(peak, lift.position.y)
	var rise := 576.0 - peak
	print("   打火把平台推了 %.0fpx（顶到 y=%.0f，中层 352）" % [rise, peak])

	# 已知漏洞（待拍板，不算测试失败）：
	# 光敏板在 x=400，平台在 x=336，两者错开是为了「虚影站在板上不动、光照着平台升」。
	# 代价是玩家也能站在 x≈420（板上、但不在平台上）一直打火，光心永远留在感应区里，
	# 平台就被一路推上去（实测 355px / 2.5s，火把烧完才停）。
	# 靠几何修不掉：虚影和玩家体型、站位完全相同，凡是虚影站得住又照得到的位置，
	# 玩家也站得住。要堵只能从「光源类型」上区分（打火不算），这是设计决定。
	if peak < 352.0:
		print("   （打火推不到中层，设计成立）")
	else:
		print("   ⚠ 打火把平台推过了中层——玩家会觉得「电梯自己跑了」，需要拍板怎么处理")
	await _unmount(room)


# ---------------------------------------------------------------- 3-1 按 R

func _case_31_reset() -> void:
	print("--- 4. 3-1 按 R 复位铁栅 / 预告虚影")
	var room := await _mount(ROOM31)
	var gate := room.get_node("Gate") as StaticBody2D
	var solid := gate.get_node("Solid") as CollisionShape2D
	var specter := room.get_node("Specter") as CharacterBody2D
	var start: Vector2 = specter.position

	gate.call("open")
	await _frames(100)
	expect(gate.get("opened"), "铁栅被打开了")
	expect(solid.disabled, "铁栅撤掉了碰撞")

	room.call("reset_mechanisms")
	await _frames(4)
	expect(not gate.get("opened"), "R 之后铁栅恢复关闭状态（opened=%s）" % gate.get("opened"))
	expect(is_equal_approx(gate.get("lift"), 0.0), "R 之后铁栅落回原位（lift=%.0f）" % gate.get("lift"))
	expect(not solid.disabled, "R 之后铁栅重新挡住玩家")

	expect(specter.position.distance_to(start) < 2.0,
		"R 之后预告虚影回到起点（偏移 %.0fpx）" % specter.position.distance_to(start))

	# 复位之后整条链路要能再跑一遍：门还能开、还能再关
	gate.call("open")
	await _frames(100)
	expect(gate.get("opened"), "R 之后铁栅还能被再次打开")
	expect(solid.disabled, "第二次打开同样撤掉碰撞")
	room.call("reset_mechanisms")
	await _frames(4)
	expect(not gate.get("opened") and not solid.disabled, "第二次复位同样干净")
	await _unmount(room)


# ------------------------------------------------- 真实按 R（走输入链路）

func _case_real_R_32() -> void:
	print("--- 6. 3-2 真的按一下 R（走 _unhandled_input → reset_all）")
	var room := await _mount(ROOM32)
	var p := room.get_node("Player") as CharacterBody2D
	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor") as Node2D
	var echoes := room.get_node("EchoManager")
	var spawn := p.position

	p.position = Vector2(336, 532)
	sensor.set("force", 1)
	await _frames(90)
	expect(lift.position.y < 480.0, "按 R 之前平台已经离地（y=%.0f）" % lift.position.y)
	# 玩家 position 是「头顶左上角」，脚在 y+44，所以站台面上时 p.y ≈ 台面 - 44
	expect(absf(p.position.y + 44.0 - lift.position.y) < 8.0, "玩家站在平台上（脚 %.0f / 台面 %.0f）" % [p.position.y + 44.0, lift.position.y])

	_key(KEY_R, true)
	await _frames(3)
	_key(KEY_R, false)
	# 真实场景里 R 之后虚影已经被清掉、板上没光；这里把强制光也撤掉，
	# 否则平台复位完会立刻被这束人造光重新推起来，读到的就不是「停在哪」。
	sensor.set("force", 0)
	await _frames(8)

	expect(p.position.distance_to(spawn) < 2.0, "R 把玩家送回出生点（%.0f,%.0f）" % [p.position.x, p.position.y])
	expect(is_equal_approx(lift.position.y, 576.0), "R 把平台送回底部（y=%.0f）" % lift.position.y)
	expect(int(echoes.call("echo_count")) == 0, "R 清掉了场上的虚影")
	await _unmount(room)


func _case_real_R_31() -> void:
	print("--- 7. 3-1 真的按一下 R（预告虚影 + 铁栅一起回初始）")
	var room := await _mount(ROOM31)
	var p := room.get_node("Player") as CharacterBody2D
	var gate := room.get_node("Gate") as StaticBody2D
	var solid := gate.get_node("Solid") as CollisionShape2D
	var specter := room.get_node("Specter") as CharacterBody2D
	var spawn := p.position
	var start: Vector2 = specter.position

	# 等预告虚影走完全程（delay 0.9s + 约 7s 路程）
	var walked := false
	for i in 720:
		await physics_frame
		if gate.get("opened"):
			walked = true
			break
	expect(walked, "预告虚影走到头、把铁栅打开了")
	await _frames(100)
	expect(solid.disabled, "铁栅碰撞已撤（玩家能走过去）")

	_key(KEY_R, true)
	await _frames(3)
	_key(KEY_R, false)
	await _frames(8)

	expect(p.position.distance_to(spawn) < 2.0, "R 把玩家送回出生点")
	expect(not gate.get("opened"), "R 把铁栅关回去了")
	expect(not solid.disabled, "R 之后铁栅重新挡人")
	expect(specter.position.distance_to(start) < 2.0, "R 把预告虚影送回起点（偏移 %.0fpx）" % specter.position.distance_to(start))

	# 复位之后整关要能再走一遍：虚影重新出发 → 再开门
	var moved := false
	for i in 180:
		await physics_frame
		if specter.position.x > start.x + 20.0:
			moved = true
			break
	expect(moved, "R 之后预告虚影重新出发")
	await _unmount(room)


# ------------------------------------------------------- 两份 echo_radii

func _case_radii_sync() -> void:
	print("--- 5. 光敏板与黑幕的虚影半径是否同步")
	var room := (load(ROOM32) as PackedScene).instantiate()
	var black := room.get_node("Blackout")
	var sensor := room.get_node("Sensor")
	var a: Vector2 = black.get("echo_radii")
	var b: Vector2 = sensor.get("echo_radii")
	expect(a.is_equal_approx(b), "两处 echo_radii 一致（黑幕 %s / 光敏板 %s）" % [a, b])
	room.free()


# ---------------------------------------------------------------- 工具

func _mount(path: String) -> Node:
	var room := (load(path) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(10)
	return room


func _unmount(room: Node) -> void:
	root.remove_child(room)
	room.queue_free()
	await _frames(3)


func expect(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("PASS ", label)
	else:
		_fail += 1
		print("FAIL ", label)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
