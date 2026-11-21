extends SceneTree
## 「方向即空间」的契约断言。规则见 docs/关卡切换方案.md §7。
##
## 只锁两件事：
## 1) 相邻房间的出口边，必须等于下一间「进入边」的对侧。
##    从右边出去却从中间冒出来，玩家不会读成「转场不好看」，会读成 bug。
## 2) 什么时候滑动、什么时候切黑，必须是可断言的纯逻辑，不能靠 if-else 巧合。

const Session = preload("res://frontend/glue/session.gd")
const CATALOG = preload("res://frontend/db/catalog.tres")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")

## 房间恒定 40×22 格 × 32px，正好一屏。
const ROOM_W := 1280.0
const ROOM_H := 704.0

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		print("FAIL ", message)

func opposite(edge: String) -> String:
	match edge:
		"left": return "right"
		"right": return "left"
		"top": return "bottom"
		"bottom": return "top"
	return ""

## 按房间中线划分。四间房的出口都在右半、出生点都在左半，所以中线足够。
func edge_of(point: Vector2) -> String:
	if point.x < ROOM_W * 0.5:
		return "left"
	if point.x > ROOM_W * 0.5:
		return "right"
	return "top" if point.y < ROOM_H * 0.5 else "bottom"

## 出口是一个左上角定位的方块，判定区是 position + block_size。
func exit_center(room: Node) -> Vector2:
	var exit := room.find_child("Exit", true, false) as Node2D
	if exit == null:
		return Vector2(-1, -1)
	var size: Vector2 = exit.get("block_size")
	return exit.position + size * 0.5

func spawn_point(room: Node) -> Vector2:
	var marker := room.find_child("RespawnPoint", true, false) as Node2D
	return marker.position if marker != null else Vector2(-1, -1)

func run() -> void:
	var levels: Array = CATALOG.levels
	var rooms := {}
	for index in levels.size():
		var path := str(levels[index].get("scene", ""))
		if path.is_empty():
			continue
		var packed = load(path) as PackedScene
		check(packed != null, "%s 能加载" % path)
		if packed == null:
			continue
		var room := packed.instantiate()
		rooms[index] = room
		check(exit_center(room) != Vector2(-1, -1), "%s 有 Exit 节点" % path)
		check(spawn_point(room) != Vector2(-1, -1), "%s 有 RespawnPoint" % path)

	# 1) 边配对：出口边 == 下一间进入边的对侧
	for index in rooms.keys():
		var next_index: int = index + 1
		if not rooms.has(next_index):
			continue
		var out_edge := edge_of(exit_center(rooms[index]))
		var in_edge := edge_of(spawn_point(rooms[next_index]))
		check(out_edge == opposite(in_edge),
			"第 %d 间 %s 出 → 第 %d 间从 %s 进" % [index + 1, out_edge, next_index + 1, in_edge])

	# 2) 第一间房必须有进入边（从菜单进去要先站对位置）
	if rooms.has(0):
		check(edge_of(spawn_point(rooms[0])) == "left", "第一间房从左侧入场")

	for room in rooms.values():
		room.free()

	# 3) 转场类型是纯函数，逐个场景断言
	var session = Session.new()
	session.flow.setup(CATALOG.levels)
	check(session.transition_kind(0, 1) == "slide", "同章顺序推进 = 滑动")
	check(session.transition_kind(4, 5) == "cut", "跨章 = 切黑")
	check(session.transition_kind(3, 1) == "cut", "跳关（非相邻）= 切黑")
	check(session.transition_kind(2, 2) == "cut", "重试同一间 = 切黑")
	check(session.transition_kind(-1, 0) == "cut", "从菜单进入 = 切黑")
	check(session.transition_kind(0, 6) == "cut", "越过多间 = 切黑")

	# 目录里写 "link": "cut" 可以强制切断
	session.flow.levels[1]["link"] = "cut"
	check(session.transition_kind(1, 2) == "cut", "目录 link=cut 覆盖自动推断")
	session.flow.levels[1].erase("link")
	check(session.transition_kind(1, 2) == "slide", "去掉 link 后恢复滑动")

	check(is_equal_approx(session.SLIDE_TIME, 0.24), "滑动 0.24s")
	check(is_equal_approx(session.CUT_FADE, 0.10), "切黑半程 0.10s")
	check(session.transition_plan(0, 1).kind == "slide", "plan 同章为 slide")
	check(session.transition_plan(4, 5).kind == "cut", "plan 跨章为 cut")
	check(is_equal_approx(float(session.transition_plan(4, 5).time), 0.20), "plan 切黑总时长 0.20s")
	session.free()

	# 4) 玩家侧：转场锁必须能自动解除，否则 0.24s 会变成永久不能动
	var player = PLAYER_SCENE.instantiate()
	check(player.has_method("lock_input"), "玩家有 lock_input")
	player.call("lock_input", 0.2)
	check(player.input_locked, "lock_input(0.2) 立即上锁")
	player.call("lock_input", 0.0)
	check(not player.input_locked, "lock_input(0) 立即解锁")
	player.free()

	if failures > 0:
		printerr("TRANSITION_FAILURES ", failures)
		quit(1)
		return
	print("TRANSITION_ALL_PASS")
	quit()
