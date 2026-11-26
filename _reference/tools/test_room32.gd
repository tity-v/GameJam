extends SceneTree
## 3-2 的验收（手电 / 光判定 / 平台循环 / 火盆 / 虚影带手电）。
##
## 这一版的设计骨架换过一次，测试重点也跟着换了三件事：
##   1. 光分两种：**照明** 和 **供能**。每个人自带的光都是 72/100，只照明；
##      只有手电（120/180）和它点着的火盆才 `can_power`，才推得动光敏板。
##      所以「站到板旁边」不再等于「板会亮」——手里得有手电。
##   2. 平台从「跟光走」改成「有光就循环」：升 → 顶停 1.8s → **自动**降 → 底停 1.2s
##      → 还亮着就再升。「循环」只省掉操作，**上升过程必须持续有光**：
##      光一断当帧转下落。这一条是第一段谜题的支点，缺了就能自己点灯自己上车。
##   3. 虚影会带着死时的**同一支手电**重放，而且录到尾巴后原地站 7s。
##      第一段的解法就是「让它替我站在板旁边」。
##   4. 手电不在出生点旁边：在井 A 右侧 480px 的死路尽头，必须先去找。
##
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/test_room32.gd

const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"

## lift.gd 里的 Phase 顺序
const PARKED := 0
const RISING := 1
const TOP_WAIT := 2
const FALLING := 3
const BOTTOM_WAIT := 4

var _pass := 0
var _fail := 0
var _room: Node
var _p: CharacterBody2D
var _lamp: Node
var _lift: AnimatableBody2D
var _lift_b: AnimatableBody2D
var _sensor: Node
var _sensor_b: Node
var _brazier: Node
var _pickup: Area2D
var _mgr: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _frames(10)

	_p = _room.get_node("Player") as CharacterBody2D
	_lamp = _p.get_node("Flashlight")
	_lift = _room.get_node("Lift") as AnimatableBody2D
	_lift_b = _room.get_node("LiftB") as AnimatableBody2D
	_sensor = _room.get_node("Sensor")
	_sensor_b = _room.get_node("SensorB")
	_brazier = _room.get_node("Brazier")
	_pickup = _room.get_node("Pickup") as Area2D
	_mgr = _room.get_node("EchoManager")

	await _case_layout()
	await _case_flashlight()
	await _case_judge()
	await _case_cycle()
	await _case_brazier()
	await _case_echo()
	await _case_reset()

	print("ROOM32 %d/%d" % [_pass, _pass + _fail])
	if _fail > 0:
		print("ROOM32_FAIL %d" % _fail)
	quit()


# ------------------------------------------------------------------ 地形

func _case_layout() -> void:
	print("--- 1. 地形与初始状态")
	var world := _room.get_node("World") as TileMapLayer
	expect(world.get_used_cells().size() == 104, "地形 104 格")
	expect(world.get_cell_source_id(Vector2i(10, 18)) == -1, "竖井 A 底是凹槽")
	expect(world.get_cell_source_id(Vector2i(10, 19)) != -1, "凹槽有一格深的地面")
	expect(world.get_cell_source_id(Vector2i(18, 11)) != -1, "中层楼板左段")
	expect(world.get_cell_source_id(Vector2i(25, 11)) != -1, "中层悬挑台")
	expect(world.get_cell_source_id(Vector2i(21, 11)) == -1, "中层让出井 B")
	expect(world.get_cell_source_id(Vector2i(19, 4)) != -1, "顶层楼板铺到井 B 左壁")

	expect(is_equal_approx(_p.position.y, 532.0), "出生点站地面")
	expect(is_equal_approx(_lift.position.y, 576.0), "平台 A 停在底部")
	expect(is_equal_approx(_lift_b.position.y, 352.0), "平台 B 停在中层")
	expect(_lift.get("phase") == PARKED, "平台 A 开局是停着的")
	expect(not _sensor.call("is_lit"), "开局板 A 灭")
	expect(not _sensor_b.call("is_lit"), "开局板 B 灭")

	# 手电必须「要自己去找」：放在出生点一步之外的唯一路径上，
	# 玩家往右走一个动作就顺手捡了，等于开局发手电（旧版就是 x=200，距出生 88）。
	# 现在在板 A 之后 480px 的死路尽头，必须先碰壁再回头。
	var spawn := Vector2(112, 532)
	var away := _pickup.global_position.distance_to(spawn)
	expect(away > 700.0, "手电不在出生点旁边（距出生点 %.0f）" % away)
	expect(_pickup.global_position.x > _sensor.global_position.x + 400.0,
		"手电在板 A 之后更远的死路尽头（x=%.0f）" % _pickup.global_position.x)


# ------------------------------------------------------------------ 手电

func _case_flashlight() -> void:
	print("--- 2. 手电：拾取前后是两种光")
	expect(_lamp.get("has_flashlight") == false, "开局没有手电")
	expect(_lamp.get("radii") == Vector2(72, 100), "没手电时照明 72/100（和虚影一样大）")
	expect(_lamp.get("can_power") == false, "没手电时不能供能")

	# 走到地上的那支手电上
	_p.position = Vector2(1050, 532)
	await _frames(20)
	expect(_lamp.get("has_flashlight") == true, "碰到就捡起来（不需要按键）")
	expect(_lamp.get("radii") == Vector2(120, 180), "捡到后照明 120/180")
	expect(_lamp.get("can_power") == true, "捡到后才能供能")
	expect(_pickup.visible == false, "地上那支不见了")
	expect(_pickup.get("taken") == true, "拾取物记下了状态")


# ------------------------------------------------------------------ 光判定

func _case_judge() -> void:
	print("--- 3. 判定：站在板旁边不等于板会亮，手里得有手电")
	# 拿手电站板旁：亮
	_p.position = Vector2(460, 532)
	await _frames(10)
	expect(_sensor.call("is_lit"), "拿手电站板旁 → 板 A 亮")

	# 拿手电站平台上：灭（手电 120 够不到板心 492，堵死自己送自己上去）
	_p.position = Vector2(336, 532)
	await _frames(10)
	expect(not _sensor.call("is_lit"), "拿手电站平台上 → 板 A 灭（差 21px，自己送不上去）")

	# R 回初始、这时没手电，站同一个位置必须还是灭
	_mgr.call("reset_all")
	await _frames(10)
	expect(_lamp.get("has_flashlight") == false, "R 之后手电回到地上")
	_p.position = Vector2(460, 532)
	await _frames(10)
	expect(not _sensor.call("is_lit"), "没手电站板旁 → 板 A 仍然是灭的（光只照明，不供能）")

	# 重新捡起来，后面几段都要用
	_p.position = Vector2(1050, 532)
	await _frames(20)
	expect(_lamp.get("has_flashlight"), "重新捡回手电")


# ------------------------------------------------------------------ 循环

func _case_cycle() -> void:
	print("--- 4. 有光就循环：升 → 顶停 → 降 → 底停 → 再升")
	# 站到板旁持续供光，平台开始跑
	_p.position = Vector2(460, 532)
	await _frames(150)
	expect(_lift.position.y <= 353.0, "有光 → 升到中层 352（y=%.0f）" % _lift.position.y)
	expect(_lift.get("phase") == TOP_WAIT, "到顶转顶部停留")
	expect(is_equal_approx(_lift.get("speed"), 0.0), "顶部停住")

	await _frames(120)
	expect(_lift.get("phase") == FALLING or _lift.position.y > 353.0,
		"顶停约 1.8s 后开始自动下降（y=%.0f）" % _lift.position.y)

	await _frames(90)
	expect(_lift.position.y >= 575.0, "降回底部（y=%.0f）" % _lift.position.y)
	expect(_lift.get("phase") == BOTTOM_WAIT or _lift.get("phase") == PARKED, "到底转底部停留")

	# 底停之后光还在 → 自己再升一圈（这是「循环」与「跟光走」的分界线）
	var rose_again := false
	for i in 200:
		await physics_frame
		if _lift.position.y < 520.0:
			rose_again = true
			break
	expect(rose_again, "光还在，底部停完自己又升上去（不需要重新照）")

	# 失光：**当帧**转下落，不再继续往上爬。
	# 这是「自己点灯 → 跑回井口追台子」这条白嫖路的唯一阀门；
	# 换回「失光也跑完这一圈」立刻能白嫖到中层（probe_selfsolo.gd 复现过）。
	_sensor.set("force", -1)
	await _frames(4)
	expect(_lift.get("phase") == FALLING, "上升中失光 → 当帧转下落")
	var y_cut: float = _lift.position.y
	await _frames(24)
	expect(_lift.position.y > y_cut + 2.0,
		"失光后不再继续上升（%.0f → %.0f）" % [y_cut, _lift.position.y])

	# 落回底部，绝不停在半空
	await _frames(400)
	expect(_lift.get("phase") == PARKED, "失光后停在底部并进入 PARKED")
	expect(is_equal_approx(_lift.position.y, 576.0), "最终 y=576，没有停在半空")
	_sensor.set("force", 0)


# ------------------------------------------------------------------ 火盆

func _case_brazier() -> void:
	print("--- 5. 火盆：手电照到就着，烧完就灭")
	expect(_brazier.get("lit") == false, "火盆开局是灭的")
	expect(_brazier.get("can_power") == false, "灭着的火盆不供能")
	expect(not _sensor_b.call("is_lit"), "板 B 跟着灭")

	# 站到平台 B 上（手电到火盆 64px）
	_p.position = Vector2(688, 308)
	await _frames(20)
	expect(_brazier.get("phase") == 1 or _brazier.get("lit"), "手电照到火盆 → 引燃")
	await _frames(70)
	expect(_brazier.get("can_power") == true, "引燃 1.2s 后满亮（can_power）")
	expect(_brazier.get("radii").x > 120.0, "满亮半径 %.0f > 火盆到板 B 的 120" % _brazier.get("radii").x)
	expect(_sensor_b.call("is_lit"), "火盆点亮板 B")

	# 平台 B 开始升（循环）
	await _frames(150)
	expect(_lift_b.position.y <= 129.0, "平台 B 升到顶层 128（y=%.0f）" % _lift_b.position.y)

	# 玩家被带到顶层
	await _frames(30)
	expect(absf(_p.position.y - 84.0) < 10.0, "玩家被平台 B 带到顶层（y=%.0f）" % _p.position.y)

	# 挪到顶层楼板中段（注意别放到 x=140：那是出口，碰到会直接通关、
	# 玩家物理被关掉，后面整段录制都不再增长）。
	_p.position = Vector2(320, 84)
	await _frames(430)
	expect(_brazier.get("lit") == false, "人离开后燃料烧完，火盆灭了")
	expect(not _sensor_b.call("is_lit"), "板 B 跟着灭")


# ------------------------------------------------------------------ 虚影

func _case_echo() -> void:
	print("--- 6. 虚影带着死时的同一支手电")
	# 让录制原点对齐当前位置，否则虚影会从出生点重演
	_mgr.call("reset_all")
	_p.position = Vector2(1050, 532)
	await _frames(16)
	expect(_lamp.get("has_flashlight"), "先把地上那支捡回来")

	# ---- 6a 没手电就死 ----
	_p.position = Vector2(460, 532)
	_mgr.call("clear_all")
	_lamp.call("reset_mechanism")          # 卸下手电，模拟「先死再捡」
	await _frames(20)
	_p.call("die")
	await _frames(6)
	var e1 := _last_echo()
	expect(e1 != null, "死亡留下虚影")
	expect(e1.get("has_flashlight") == false, "没手电死的虚影不带光")
	expect(e1.get("can_power") == false, "它不能供能")
	_p.call("respawn")
	await _frames(90)
	expect(not _sensor.call("is_lit"), "虚影手里没光，板 A 不亮")

	# ---- 6b 带手电死 ----
	_lamp.call("pick_up")
	_p.position = Vector2(460, 532)
	_mgr.call("clear_all")
	await _frames(20)
	_p.call("die")
	await _frames(6)
	var e2 := _last_echo()
	expect(e2.get("has_flashlight") == true, "带手电死的虚影也拿着手电")
	expect(e2.get("radii") == Vector2(120, 180), "虚影的光和持手电的玩家一样大")
	_p.call("respawn")
	await _frames(60)
	# can_power 要等它登场（_active）之后才成立：未登场、正在淡出的虚影都不供能
	expect(e2.get("can_power") == true, "虚影登场后能供能")
	expect(_sensor.call("is_lit"), "虚影替玩家站在板旁 → 板 A 亮")

	# ---- 6c 录到尾巴后原地待机 7s ----
	var held := 0
	for i in 600:
		await physics_frame
		if _sensor.call("is_lit"):
			held += 1
	print("   虚影供光持续 %.1fs（待机 7s，要求 ≥ 5s）" % (held / 60.0))
	expect(held > 300, "虚影站定供光 ≥ 5s，够玩家复活跑一趟")
	expect(not _sensor.call("is_lit"), "虚影消散后板 A 灭")


# ------------------------------------------------------------------ R 复位

func _case_reset() -> void:
	print("--- 7. R 把一切打回初始")
	_mgr.call("reset_all")
	await _frames(10)
	expect(_lamp.get("has_flashlight") == false, "手电回地上")
	expect(_pickup.visible == true, "地上那支又出现了")
	expect(_lift.get("phase") == PARKED, "平台 A 停机")
	expect(_lift.get("phase") == PARKED and is_equal_approx(_lift.position.y, 576.0), "平台 A 回底部")
	expect(_brazier.get("lit") == false, "火盆灭了")
	expect(not _sensor.call("is_lit"), "板 A 灭")
	expect(not _sensor_b.call("is_lit"), "板 B 灭")


# ------------------------------------------------------------------ 工具

func _last_echo() -> Node:
	var found: Node = null
	for c in _mgr.get_children():
		if c.is_in_group("echo"):
			found = c
	return found


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
