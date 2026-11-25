extends SceneTree
## 3-2 光控升降台的验收。
##
## 这一关的全部手感都压在一条曲线上：有光加速上升 / 无光先刹车再下落。
## 所以测试不只看「能不能升到顶」，还要量三件事：
##   1. 玩家自己打火只能把平台推 60px 就断（离中层 140px，够不着）
##   2. 失光后平台还会往上滑一段才回头（惯性），不是立刻反向
##   3. 虚影站在光敏板上一路推到底，玩家被平台带到顶层

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
	expect(world.get_used_cells().size() == 89, "地形 89 格")
	expect(world.get_cell_source_id(Vector2i(10, 18)) == -1, "竖井底是凹槽（平台不跟地板同高）")
	expect(world.get_cell_source_id(Vector2i(10, 19)) != -1, "凹槽有一格深的地面")
	expect(world.get_cell_source_id(Vector2i(18, 11)) != -1, "中层楼板在竖井右侧")
	expect(world.get_cell_source_id(Vector2i(10, 11)) == -1, "竖井让开中层楼板")
	expect(world.get_cell_source_id(Vector2i(5, 4)) != -1, "顶层楼板存在")
	expect(world.get_cell_source_id(Vector2i(10, 4)) == -1, "竖井顶上没有楼板")
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

	# 感应区几何：站在台上的手电（352,554）要落在里面，升高 90px 后必须落在外面
	var area: Rect2 = sensor.call("zone_rect")
	expect(area.has_point(Vector2(352, 554)), "台上手电落在感应区")
	expect(not area.has_point(Vector2(352, 464)), "升高后手电离开感应区")
	expect(is_equal_approx(sensor.position.y, 576.0), "光敏板铺平地（虚影站得住、不进平台底板）")
	expect(world.get_cell_source_id(Vector2i(12, 18)) != -1, "光敏板那一格是平地")

	# ---- 玩家自己打火：只能推 60px 就断，够不着中层 ----
	p.position = Vector2(336, 532)
	await _frames(6)
	Input.action_press("fire")
	await _frames(4)
	Input.action_release("fire")
	var peak := 9999.0
	for i in 120:
		await physics_frame
		peak = minf(peak, lift.position.y)
	var rise := 576.0 - peak
	expect(rise > 40.0, "打火把平台推动了（%.0fpx）" % rise)
	expect(rise < 110.0, "打火自己够不着中层（只升 %.0fpx，离 352 还差 %.0fpx）" % [rise, 576.0 - rise - 352.0])

	# ---- 惯性：失光后还要往上滑一段，才回头 ----
	lift.call("reset_mechanism")
	await _frames(4)
	sensor.set("force", 1)
	await _frames(90)              # 升到巡航速度
	var fast: float = lift.get("speed")
	expect(fast > 130.0, "有光时到巡航速度 140")
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
	expect(coast > 15.0, "失光后仍上滑 %.1fpx（不是立刻反向）" % coast)
	expect(frames_up >= 12, "上滑持续 %.2fs" % (frames_up / 60.0))
	expect(turned > frames_up, "先滑到顶再下落")
	expect(turned > 0 and turned < 40, "回头发生在 %d 帧内（不拖泥带水）" % turned)

	await _frames(150)
	expect(is_equal_approx(lift.position.y, 576.0), "无光最终回到底部")
	expect(is_equal_approx(lift.get("speed"), 0.0), "落到底后停住")

	# ---- 虚影通道：站住不动就能一路推到顶 ----
	sensor.set("force", 0)
	var ghost := FakeEcho.new()
	ghost.add_to_group("echo")
	ghost.global_position = Vector2(384, 532)
	room.add_child(ghost)
	await _frames(4)
	expect(sensor.call("is_lit"), "虚影站上光敏板即点亮")

	p.position = Vector2(336, 532)
	await _frames(6)
	await _frames(320)
	expect(is_equal_approx(lift.position.y, 128.0), "虚影一路把平台推到顶层 128")
	expect(is_equal_approx(lift.get("speed"), 0.0), "到顶停住不再上升")
	await _frames(30)
	expect(absf(p.position.y - 84.0) < 8.0, "玩家被平台带到顶层（y≈84）")

	# 撤掉虚影：平台应带着人一起落回底部
	ghost.queue_free()
	await _frames(240)
	expect(is_equal_approx(lift.position.y, 576.0), "虚影消失后平台回落")
	expect(absf(p.position.y - 532.0) < 8.0, "玩家跟着平台回到地面")

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
