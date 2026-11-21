extends SceneTree
## 锁定「虚影的世界碰撞扫描必须和玩家同一套规则」。
##
## 这条规则是踩坑补上的：
##   玩家踩虚影跳上**单向台面**（tileset atlas 3,0，只有顶上 8px 实体）能穿上去，
##   但虚影重放同一段轨迹时会被台面底面顶住 —— 因为原来用
##   `direct_space_state.cast_motion()`，纯形状查询**不认 one_way**，
##   把单向台面当成了实心天花板。实测虚影头顶死卡在台面底面（y=520），
##   整条轨迹再也不动，观感就是「玩家过得去、虚影过不去」。
##
## 现在扫描走隐形 CharacterBody2D 的 move_and_collide(test_only)，
## 和玩家 move_and_slide 同源（body_test_motion）。本测试守三件事：
##   1. 单向台面：从下往上能穿过去（和玩家一致）
##   2. 单向台面：从上面落下仍然踩得住（不能因为修 bug 把它变透明）
##   3. 实心门/墙：照样挡得住（不能因为修 bug 让虚影穿墙）
##
## 场景用 chapter_01_room_04，它的地形刚好齐：
##   地面顶面 640；单向薄台 x640..768 实体只有 y512..520；关着的门在 x928。

const ROOM := "res://scenes/levels/chapter_01_room_04.tscn"
const ECHO := preload("res://scenes/echo/echo.tscn")

const GROUND_Y := 640.0
const SLAB_TOP := 512.0
const SLAB_BOTTOM := 520.0
const SLAB_X := 700.0
const DOOR_LEFT := 928.0

var room: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
	print("PASS ", message)


## 造一条站在原地不动的虚影（600 帧同一点 = 站着 10 秒）
func place_still_echo(pos: Vector2) -> Node2D:
	var trail := PackedVector2Array()
	for i in 600:
		trail.append(pos)
	var echo := ECHO.instantiate()
	room.add_child(echo)
	echo.setup(trail)
	echo.reset()
	echo.global_position = pos
	return echo


func run() -> void:
	room = load(ROOM).instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	await frames(10)

	# 单向薄台：确认地形本身是对的（形状查询不认 one_way，所以这里只查几何）
	var space: PhysicsDirectSpaceState2D = room.get_world_2d().direct_space_state
	var p := PhysicsShapeQueryParameters2D.new()
	p.shape = RectangleShape2D.new()
	(p.shape as RectangleShape2D).size = Vector2(2, 2)
	p.collision_mask = 1
	p.transform = Transform2D(0.0, Vector2(SLAB_X, SLAB_TOP + 4.0))
	check(space.intersect_shape(p, 1).size() > 0, "单向薄台实体在 y=512..520")

	# --- 1. 基准：玩家踩虚影跳上单向台面 ---
	var step := place_still_echo(Vector2(SLAB_X, GROUND_Y - 44.0))
	await frames(4)
	player.global_position = Vector2(SLAB_X, GROUND_Y - 88.0)  # 站在虚影头上（脚底 596）
	player.velocity = Vector2.ZERO
	await frames(10)
	check(player.is_on_floor(), "玩家能站在虚影头上")

	var trail := PackedVector2Array()
	Input.action_press("jump")
	var landed := false
	for i in 120:
		trail.append(player.global_position)
		await physics_frame
		if player.is_on_floor() and player.global_position.y + 44.0 < GROUND_Y - 48.0:
			trail.append(player.global_position)
			landed = true
			break
	Input.action_release("jump")
	await frames(6)
	var player_feet: float = player.global_position.y + 44.0
	check(landed, "玩家跳穿单向台面并落上去（脚底 %.1f）" % player_feet)
	check(absf(player_feet - SLAB_TOP) < 1.5, "玩家落点贴单向台面 y=%.0f" % SLAB_TOP)

	# --- 2. 同一段轨迹喂给虚影：必须一模一样地穿上去 ---
	var rep := ECHO.instantiate()
	room.add_child(rep)
	rep.setup(trail.duplicate())
	rep.reset()
	await frames(1)
	var min_y := 9999.0
	for i in trail.size() - 1:
		rep.advance(1.0 / 60.0)
		min_y = minf(min_y, rep.global_position.y)
	var err: float = rep.global_position.distance_to(trail[trail.size() - 1])
	var echo_feet: float = rep.global_position.y + 44.0
	print("  轨迹 %d 帧，虚影最高头顶 %.1f，终点 %s（应为 %s）" % [
		trail.size(), min_y, rep.global_position, trail[trail.size() - 1]])
	check(min_y < SLAB_BOTTOM, "虚影穿过了单向台面（头顶曾到 %.1f < 底面 %.0f）" % [min_y, SLAB_BOTTOM])
	check(err < 1.0, "虚影回放终点与轨迹终点重合（差 %.2f px）" % err)
	check(absf(echo_feet - SLAB_TOP) < 1.5, "虚影最后站在单向台面上（脚底 %.1f）" % echo_feet)

	# --- 3. 单向台面往下落：仍然踩得住，不能变透明 ---
	var fall_trail := PackedVector2Array()
	for i in 45:
		fall_trail.append(Vector2(SLAB_X, SLAB_TOP - 44.0 - 60.0 + i * 2.5))
	var faller := ECHO.instantiate()
	room.add_child(faller)
	faller.setup(fall_trail)
	faller.reset()
	await frames(1)
	for i in fall_trail.size() - 1:
		faller.advance(1.0 / 60.0)
	var fall_feet: float = faller.global_position.y + 44.0
	check(absf(fall_feet - SLAB_TOP) < 2.0,
		"虚影从上方落下时被单向台面接住（脚底 %.1f，台面 %.0f）" % [fall_feet, SLAB_TOP])

	# --- 4. 关着的门：照样挡得住（修 bug 不能让它穿墙） ---
	var door_trail := PackedVector2Array()
	for i in 80:
		door_trail.append(Vector2(DOOR_LEFT - 200.0 + i * 4.0, GROUND_Y - 44.0))
	var walker := ECHO.instantiate()
	room.add_child(walker)
	walker.setup(door_trail)
	walker.reset()
	await frames(1)
	for i in door_trail.size() - 1:
		walker.advance(1.0 / 60.0)
	var right_edge: float = walker.global_position.x + 32.0
	# 扫描形状比身体内缩 1px，所以身体右缘最多压到门面 1px，不能再往里
	check(right_edge < DOOR_LEFT + 2.0, "关着的门挡住虚影（右缘 %.1f，门左面 %.0f）" % [right_edge, DOOR_LEFT])
	check(right_edge > DOOR_LEFT - 8.0, "虚影停在门面上，不是提前很远停住（右缘 %.1f）" % right_edge)

	print("ECHO_ONEWAY_ALL_PASS")
	quit()
