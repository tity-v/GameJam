extends SceneTree
## 3-2 光控升降台的验收。
##
## 这一关的全部手感都压在一条曲线上：有光加速上升 / 无光先刹车再下落。
## 所以测试不只看「能不能升到顶」，还要量三件事：
##   1. 判定是「光斑覆盖到板」不是「光心在感应区」——站平台左缘（x=336）打火
##      光斑够不到板，推不动（堵死作弊缝）；站板附近（x=460）打火才推得动，
##      但 2.5s 只够升约 170px 到 y≈406，够不着中层 352
##   2. 失光后平台还会往上滑一段才回头（惯性），不是立刻反向
##   3. 虚影站在板附近持续照一路推到底，玩家被平台带到顶层

const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"

var _pass := 0
var _fail := 0


## 假虚影：只实现光敏板会问到的四个成员，用来单独验「虚影通道」，
## 不必把整条录制/重放链路拉进来。
class FakeEcho extends Node2D:
	var fade_duration := 1.3
	var _fade_time := 0.0
	func is_active() -> bool: return true
	func body_rect() -> Rect2: return Rect2(global_position, Vector2(32, 44))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(8)

	var world := room.get_node("World") as TileMapLayer
	expect(world.get_used_cells().size() == 104, "地形 104 格")
	expect(world.get_cell_source_id(Vector2i(10, 18)) == -1, "竖井底是凹槽（平台不跟地板同高）")
	expect(world.get_cell_source_id(Vector2i(10, 19)) != -1, "凹槽有一格深的地面")
	expect(world.get_cell_source_id(Vector2i(18, 11)) != -1, "中层楼板在竖井 A 右侧")
	expect(world.get_cell_source_id(Vector2i(10, 11)) == -1, "竖井 A 让开中层楼板")
	expect(world.get_cell_source_id(Vector2i(5, 4)) != -1, "顶层楼板存在")
	# 双井之后顶层楼板一路铺到竖井 B 左壁（列 19 = 640），平台 B 升到 128 才踏得出去
	expect(world.get_cell_source_id(Vector2i(19, 4)) != -1, "顶层楼板铺到竖井 B 左壁")
	expect(world.get_cell_source_id(Vector2i(21, 4)) == -1, "竖井 B 顶上开口")
	# 竖井 B：列 20~22（640~736），从中层 352 直通顶层 128
	expect(world.get_cell_source_id(Vector2i(21, 11)) == -1, "竖井 B 贯通中层")
	expect(world.get_cell_source_id(Vector2i(21, 8)) == -1, "竖井 B 中段是空的")
	expect(world.get_cell_source_id(Vector2i(25, 11)) != -1, "井 B 对面有悬挑台（火盆与板 B 站得住）")
	expect(world.get_cell_source_id(Vector2i(35, 18)) == -1, "右侧有死亡坑")

	var black := room.get_node("Blackout") as TileMapLayer
	expect(black.get_used_cells().size() == 880, "黑幕铺满 40×22")

	var p := room.get_node("Player") as CharacterBody2D
	await _frames(4)
	expect(is_equal_approx(p.position.y, 532.0), "出生点站地面")
	expect(p.is_on_floor(), "出生即落地")

	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor") as Node2D
	expect(is_equal_approx(lift.position.y, 576.0), "平台停在底部 576")
	expect(is_equal_approx(lift.get("speed"), 0.0), "开局静止")
	expect(not sensor.call("is_lit"), "底光 40 推不动光敏板")

	# 感应区几何：只用于「走近触发引导」，判定不再用感应区（用光斑覆盖板）
	var area: Rect2 = sensor.call("zone_rect")
	expect(area.has_point(Vector2(352, 554)), "台上手电落在感应区")
	expect(not area.has_point(Vector2(352, 464)), "升高后手电离开感应区")
	expect(is_equal_approx(sensor.position.y, 576.0), "光敏板铺平地（虚影站得住、不进平台底板）")
	expect(world.get_cell_source_id(Vector2i(12, 18)) != -1, "光敏板那一格是平地")

	# ---- 判定：光斑覆盖板，不是光心在感应区 ----
	# 站平台左缘（x=336）打火，光斑右缘 336+96=432 < 板中心 492，够不到 -> 推不动
	p.position = Vector2(336, 532)
	await _frames(6)
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")
	var peak_left := 9999.0
	for i in 120:
		await physics_frame
		peak_left = minf(peak_left, lift.position.y)
	expect(576.0 - peak_left < 10.0, "站平台左缘打火推不动（光斑够不到板，作弊缝已堵）")

	# ---- 玩家站板附近打火：能推，但 2.5s 只够到 y≈406，够不着中层 352 ----
	lift.call("reset_mechanism")
	await _frames(4)
	p.position = Vector2(460, 532)
	var torch := p.get_node("Torch") as Node2D
	torch.set("cooling", 0.0)      # 清掉上一段打火的冷却，否则这次打火被拦下
	await _frames(6)
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")
	var peak := 9999.0
	for i in 120:
		await physics_frame
		peak = minf(peak, lift.position.y)
	var rise := 576.0 - peak
	expect(rise > 60.0, "站板附近打火把平台推动了（%.0fpx）" % rise)
	expect(peak > 352.0, "打火自己够不着中层（只到 y=%.0f，离中层 352 差 %.0fpx）" % [peak, peak - 352.0])

	# ---- 惯性：失光后还要往上滑一段，才回头 ----
	lift.call("reset_mechanism")
	await _frames(4)
	sensor.set("force", 1)
	await _frames(90)              # 升到巡航速度
	var fast: float = lift.get("speed")
	expect(fast > 90.0, "有光时到巡航速度 100")
	var y_at_cut: float = lift.position.y
	sensor.set("force", -1)        # 掐光
	var lowest := y_at_cut
	var frames_up := 0
	var turned := -1
	for i in 120:
		await physics_frame
		if lift.position.y < lowest:
			lowest = lift.position.y
			frames_up = i + 1
		elif turned < 0 and lift.position.y > lowest + 0.5:
			turned = i + 1
	var coast := y_at_cut - lowest
	# up_speed=100 时刹车距离 = 100²/(2×420) ≈ 11.9px，滑行 ≈ 14 帧（0.238s）
	expect(coast > 8.0, "失光后仍上滑 %.1fpx（不是立刻反向）" % coast)
	expect(frames_up >= 10, "上滑持续 %.2fs" % (frames_up / 60.0))
	expect(turned > frames_up, "先滑到顶再下落")
	expect(turned > 0 and turned < 35, "回头发生在 %d 帧内（不拖泥带水）" % turned)

	await _frames(150)
	expect(is_equal_approx(lift.position.y, 576.0), "无光最终回到底部")
	expect(is_equal_approx(lift.get("speed"), 0.0), "落到底后停住")

	# ---- 虚影通道：站住不动就能一路推到顶 ----
	sensor.set("force", 0)
	var ghost := FakeEcho.new()
	ghost.add_to_group("echo")
	ghost.global_position = Vector2(460, 532)
	room.add_child(ghost)
	await _frames(4)
	expect(sensor.call("is_lit"), "虚影站板附近即点亮")

	p.position = Vector2(336, 532)
	await _frames(6)
	await _frames(460)
	# 双井之后平台 A 只跑底层→中层：576 → 352，把玩家送到中层就交班
	expect(is_equal_approx(lift.position.y, 352.0), "虚影把平台 A 推到中层 352")
	expect(is_equal_approx(lift.get("speed"), 0.0), "到中层停住不再上升")
	await _frames(30)
	expect(absf(p.position.y - 308.0) < 8.0, "玩家被平台 A 带到中层（y≈308）")

	# 撤掉虚影：平台应带着人一起落回底部
	ghost.queue_free()
	await _frames(240)
	expect(is_equal_approx(lift.position.y, 576.0), "虚影消失后平台回落")
	expect(absf(p.position.y - 532.0) < 8.0, "玩家跟着平台回到地面")

	# ---- 第二段：井 B（中层 → 顶层），供光源是火盆不是玩家 ----
	var lift_b := room.get_node("LiftB") as AnimatableBody2D
	var sensor_b := room.get_node("SensorB") as Node2D
	var brazier := room.get_node("Brazier") as Node2D
	expect(is_equal_approx(lift_b.position.y, 352.0), "平台 B 停在中层 352")
	expect(not sensor_b.call("is_lit"), "板 B 开局是灭的")

	# 先把火盆屏蔽，单验一件事：玩家自己站上平台 B 打火，点不着板 B。
	# 火把在 (704,330)，板 B 板心 (880,341)，差 176px > 打火半径 96。
	brazier.set("force", -1)
	p.position = Vector2(688, 308)
	torch.set("cooling", 0.0)
	await _frames(10)
	Input.action_press("fire")
	await _frames(3)
	Input.action_release("fire")
	await _frames(40)
	expect(not sensor_b.call("is_lit"), "站平台 B 打火点不着板 B（光斑差 56px）")
	expect(is_equal_approx(lift_b.position.y, 352.0), "板 B 没亮，平台 B 不动")

	# 放开火盆：再打一次火，火盆点着，1.2s 引燃后板 B 亮，平台 B 开始升
	brazier.set("force", 0)
	torch.set("cooling", 0.0)
	await _frames(2)
	Input.action_press("fire")
	await _frames(3)
	Input.action_release("fire")
	await _frames(20)
	expect(brazier.get("lit"), "火盆被点着了")
	await _frames(70)
	expect(sensor_b.call("is_lit"), "火盆的光点亮了板 B（板 B 距火盆 120）")

	# 平台 B 跑 224px（352→128），巡航 100 约 2.3s，给足 240 帧
	await _frames(240)
	expect(is_equal_approx(lift_b.position.y, 128.0), "火盆把平台 B 送到顶层 128")
	expect(absf(p.position.y - 84.0) < 8.0, "玩家被平台 B 带到顶层（y≈84）")

	# R 键：火盆得灭、板 B 跟着灭，平台 B 回落——否则重来一次会被"卡在上面"
	brazier.call("reset_mechanism")
	await _frames(6)
	expect(not brazier.get("lit"), "R 之后火盆灭了")
	expect(not sensor_b.call("is_lit"), "R 之后板 B 跟着灭")
	lift_b.call("reset_mechanism")
	await _frames(200)
	expect(is_equal_approx(lift_b.position.y, 352.0), "平台 B 回落到中层 352")

	print("ROOM32 %d/%d" % [_pass, _pass + _fail])
	if _fail > 0:
		print("ROOM32_FAIL %d" % _fail)
	quit()


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
