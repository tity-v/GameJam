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
	await _case_squeeze_in_pit()
	await _case_fire_from_plate()
	await _case_gear_gaps()
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

	# 先撤光再复位：循环版平台只要还有光就会重新起跑，
	# 带着 force=1 复位会当场又被推起来（读到 y=571 那种）
	sensor.set("force", 0)
	room.call("reset_mechanisms")
	await physics_frame
	expect(is_equal_approx(lift.position.y, 576.0), "R 之后平台回到底部（y=%.0f）" % lift.position.y)
	expect(is_equal_approx(lift.get("speed"), 0.0), "R 之后平台速度清零（%.0f）" % lift.get("speed"))
	expect(lift.get("phase") == 0, "R 之后平台进入 PARKED")
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
	print("--- 2. 平台从中层落回，砸到站在竖井里的玩家")
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
		if lift.position.y <= 353.0:
			top_frame = i
			break
	expect(top_frame > 0, "平台升到中层（用了 %d 帧）" % top_frame)
	expect(is_equal_approx(p.position.y, y0), "玩家站在井底没被平台带走（y=%.0f）" % p.position.y)

	# 断光 → 平台落回来，正好路过玩家的身体（玩家 532~576，平台板从中层 352~368 起）
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


# ------------------------------------- 人掉进井底凹槽、平台落回来把人夹住

## 上一版的死锁就在这里：井底凹槽（288~384，地面 608）只有 96×32，
## 玩家掉进去后，平台落回 576，板体 576~592 和地面之间只剩 16px，
## 而玩家判定高 44 —— 物理引擎只能把人按进地面 20px，然后跳跃/横移全部失效，
## 玩家只能自杀。改成单向板（从下方无碰撞）后，平台直接穿过人，人能跳上去。

func _case_squeeze_in_pit() -> void:
	print("--- 2b. 人掉进井底凹槽，平台落回来（曾经是死锁）")
	var room := await _mount(ROOM32)
	var p := room.get_node("Player") as CharacterBody2D
	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor") as Node2D

	# 平台先升到中层，把井底凹槽露出来
	sensor.set("force", 1)
	for i in 480:
		await physics_frame
		if lift.position.y <= 353.0:
			break
	expect(lift.position.y <= 353.0, "平台先升到中层，露出井底凹槽（y=%.0f）" % lift.position.y)

	# 人掉进凹槽
	p.position = Vector2(336, 590)
	p.velocity = Vector2.ZERO
	await _frames(20)
	var y_floor: float = p.position.y
	expect(absf(y_floor - 564.0) < 6.0, "玩家站进凹槽底（y=%.0f）" % y_floor)

	# 断光，平台从头上压下来
	sensor.set("force", -1)
	await _frames(200)
	print("   平台落回 %.0f，玩家 y=%.1f（改之前是 584.6，嵌进地面）" % [lift.position.y, p.position.y])
	expect(lift.position.y >= 575.0, "平台落回底部（y=%.0f）" % lift.position.y)
	expect(p.position.y < 572.0, "玩家没有被压进地面（y=%.1f）" % p.position.y)
	expect(not p.is_dead, "玩家没有被压死")

	# 单向板的意义：站在台子正下方原地起跳，应该穿上去落到台面上
	var x0: float = p.position.x
	_key(KEY_SPACE, true)
	await _frames(4)
	_key(KEY_SPACE, false)
	await _frames(50)
	print("   原地跳之后 x=%.0f y=%.0f（台面 576 → 人 y=532）" % [p.position.x, p.position.y])
	expect(p.position.y < 560.0, "从台子下面跳得上去（y=%.0f）" % p.position.y)
	expect(p.is_on_floor(), "跳上去之后站在台面上")
	expect(absf(p.position.x - x0) < 12.0, "原地起跳没有把人横着弹开（%.0fpx）" % absf(p.position.x - x0))

	# 再横着走出来（台面与地面齐平）
	_key(KEY_D, true)
	await _frames(44)
	_key(KEY_D, false)
	await _frames(20)
	print("   走出后 x=%.0f y=%.0f" % [p.position.x, p.position.y])
	expect(absf(p.position.x - x0) > 24.0, "能横着走出凹槽（%.0fpx）" % absf(p.position.x - x0))
	expect(not p.is_dead, "全程没有被压死")
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

	# 已知现象（不算测试失败）：
	# 光敏板在 x=400，平台在 x=336，两者错开是为了「虚影站在板上不动、光照着平台升」。
	# 代价是玩家也能站在 x≈420（板上、但不在平台上）打火，把平台 A 一路送到顶。
	# 这不构成捷径：平台到 352 时玩家还在底层 532，跳高 51px 够不着，只能看着电梯走掉。
	# 它反而是这关最早的一次教学——「你打火，它就走」，跟后面「必须留个人照着」是同一句话。
	print("   打火把平台 A 送到 y=%.0f（顶 352），玩家仍在底层，够不着 —— 教学，不是捷径" % peak)
	await _unmount(room)


# ---------------------------------------------------------------- 拿手电那段的两处断口

func _case_gear_gaps() -> void:
	print("--- 8. 拿手电那段：两处断口 + 远处那团光")
	var room := await _mount(ROOM32)
	var world := room.get_node("World") as TileMapLayer
	var p := room.get_node("Player") as CharacterBody2D
	var pickup := room.get_node("Pickup") as Area2D
	var lamp := p.get_node("Flashlight")

	# 断口：**无底**。row 18 起一路空到地图外，掉下去由 kill_y(750) 判死。
	# 以前这里铺过一格坑底（32px 深、跳一下能爬回来），改无底之后要守住
	# 「下面真的一格都没有」——哪天有人心疼玩家补回坑底，这几条会红。
	for cell in [Vector2i(24, 18), Vector2i(25, 18), Vector2i(30, 18), Vector2i(31, 18)]:
		expect(world.get_cell_source_id(cell) == -1, "断口 %s 是空的" % str(cell))
	for cell in [Vector2i(24, 19), Vector2i(25, 19), Vector2i(30, 19), Vector2i(31, 19),
			Vector2i(24, 21), Vector2i(31, 21)]:
		expect(world.get_cell_source_id(cell) == -1, "断口 %s 下面也是空的（无底）" % str(cell))
	# 两处断口之间、以及最后一个断口之后，必须有能站人的实地
	for cell in [Vector2i(26, 18), Vector2i(29, 18), Vector2i(32, 18)]:
		expect(world.get_cell_source_id(cell) != -1, "落脚点 %s 是实的" % str(cell))

	# 开局那团光：手电躺在地上自带光晕，是玩家在黑暗里唯一看得见的东西。
	# 少了它，这一段就只剩「摸黑乱走」，没有「那边有东西」这个诱饵。
	expect(pickup.is_in_group("torch_light"), "手电开局就在 torch_light 组里（黑幕会画它的光圈）")
	var gr: Variant = pickup.get("radii")
	expect(gr is Vector2 and gr.x > 0.0, "手电自身光圈半径 %.0f > 0（远处看得见）" % (gr.x if gr is Vector2 else 0.0))
	expect(pickup.get("can_power") == false, "躺在地上的手电不供能")

	# 位置：必须在两处断口右侧——玩家得先跨过陷阱才拿得到
	expect(pickup.global_position.x > 1024.0, "手电在断口右侧（x=%.0f）" % pickup.global_position.x)
	var dist: float = pickup.global_position.x - p.global_position.x
	expect(dist > 700.0, "离出生点够远（%.0f px，走过去才叫「找」）" % dist)
	# 手电本身不能供能，所以它躺在那儿也不会把自己的板照亮
	expect(lamp.get("has_flashlight") == false, "开局手里没有手电")

	# 掉进断口 = 死，然后回到出生点。
	# 这里必须真按键走过去、不能传送：传送不会产生录制的输入帧，
	# `_trail` 只有 1 帧时 `EchoManager._add_echo` 会直接 return（见它的 size<2 判断），
	# 于是「虚影会不会掉进坑里」这件事根本验不到。
	var spawn_x: float = p.global_position.x
	var y_at_death := 0.0
	Input.action_press("move_right")
	for i in 600:
		await physics_frame
		if p.is_dead:
			y_at_death = p.global_position.y
			break
	Input.action_release("move_right")
	expect(p.is_dead, "一直往右走会掉进第一处断口并摔死")
	expect(y_at_death > 750.0, "死的时候已经掉到 kill_y 以下（y=%.0f）" % y_at_death)
	# 死的那一刻留下一条虚影——这是无底坑的代价，也是必须盯住的副作用：
	# 它不能变成「挂在坑里不散的鬼」，得和玩家一样吃 kill_y。
	expect(room.get_node("EchoManager").call("echo_count") == 1, "摔死留下 1 条虚影")

	# 死亡淡出 1.3s 后回出生点
	for i in 200:
		await physics_frame
		if not p.is_dead:
			break
	expect(not p.is_dead, "淡出结束后复活")
	# `_place_at_spawn()` 只改位置和速度，is_on_floor() 要等下一次 move_and_slide 才刷新
	await _frames(6)
	expect(absf(p.global_position.x - spawn_x) < 40.0,
		"回到出生点（%.0f → %.0f）" % [spawn_x, p.global_position.x])
	expect(p.is_on_floor(), "复活后站在实地上")

	# 虚影重放这段「一路往右」的录像，会掉进同一处断口。
	# 它也必须死——否则会有一个幽灵永远挂在坑底，黑幕还会给它画光圈。
	# 600 帧足够走完 656px + 坠落 + 淡出。
	await _frames(600)
	var stuck := 0
	for e in get_nodes_in_group("echo"):
		if e.is_active() and e.global_position.y > 740.0:
			stuck += 1
	expect(stuck == 0, "没有虚影挂在坑底（%d 条）" % stuck)

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
	# 撤光必须在按 R 之前：循环版平台只要还有光，复位完立刻重新起跑，
	# 读到的就不是「停在哪」而是「已经升了 5px」。
	sensor.set("force", 0)
	await _frames(2)
	await _frames(3)
	_key(KEY_R, false)
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
	print("--- 5. 虚影的光和主角的光是不是一样大")
	var room := (load(ROOM32) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(8)
	var p := room.get_node("Player") as CharacterBody2D
	var lamp := p.get_node("Flashlight")
	var echo := (load("res://scenes/echo/echo.tscn") as PackedScene).instantiate()
	room.add_child(echo)
	await _frames(2)

	var dim: Vector2 = echo.get("dim_radii")
	var lit: Vector2 = echo.get("lit_radii")
	expect(dim.is_equal_approx(lamp.get("radii")), "没拿手电时：虚影 %s = 主角 %s" % [dim, lamp.get("radii")])
	lamp.call("pick_up")
	expect(lit.is_equal_approx(lamp.get("radii")), "拿了手电后：虚影 %s = 主角 %s" % [lit, lamp.get("radii")])
	expect(lit.x > dim.x, "带手电比不带手电大一圈（%.0f > %.0f）" % [lit.x, dim.x])

	# 光一样大，但只有带手电的虚影能供能
	expect(echo.get("can_power") == false, "未登场/没手电的虚影不供能")
	root.remove_child(room)
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
