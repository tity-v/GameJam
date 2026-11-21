extends SceneTree
## 锁定第三关（chapter_01_room_03）右侧高台的**高度契约**。
##
## 为什么要有这个测试：
##   这一关唯一的解法是「踩虚影垫脚上高台」。曾经的落差是 160px，
##   踩一条站地上的虚影满跳，脚底只到 480.9，离台面 480 差 **0.9px** ——
##   于是玩家在台边反复撞墙，看着像"虚影被平台卡住"。
##   降到 128px 后：裸跳仍然上不去（必须靠虚影），踩虚影后余量 31px。
##
## 任何人把顶面那一行瓦片加回去，或者把 Exit 挪回 384，这个测试都会红。
##
## 用法：godot --headless --path . --fixed-fps 60 -s res://_reference/tools/test_room03_ledge.gd

const ROOM := "res://scenes/levels/chapter_01_room_03.tscn"
## 左侧地面 y=640（row 20 顶边），台阶从 x=544（col 17）起
const GROUND_Y := 640.0
const LEDGE_X := 544.0
## 期望：台面 512（128px 落差），裸跳 115.1px 上不去，踩虚影 44+115.1 有余量
const EXPECT_LEDGE_Y := 512.0

var room: Node2D
var player: CharacterBody2D
var echo: Node2D
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	room = load(ROOM).instantiate()
	root.add_child(room)
	current_scene = room
	await physics_frame
	player = room.get_node("Player")

	check_terrain()
	check_exit_sits_on_ledge()
	await check_bare_jump_fails()
	await check_echo_boost_works()

	if failures == 0:
		print("\nROOM03_LEDGE_ALL_PASS")
		quit()
	else:
		print("\nROOM03_LEDGE_%d_FAIL" % failures)
		quit(1)


func ok(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
		print("FAIL ", message)


func check_terrain() -> void:
	print("== 地形 ==")
	var world: TileMapLayer = room.get_node("World")
	var top := 9999
	for c: Vector2i in world.get_used_cells():
		if c.x * 32 >= LEDGE_X:
			top = mini(top, c.y * 32)
	ok(top == int(EXPECT_LEDGE_Y), "右侧台面 y=%d（期望 %d，落差 %dpx）" % [top, int(EXPECT_LEDGE_Y), int(GROUND_Y) - top])
	# 台面到地面之间必须是实心，不能有缝
	var solid := true
	var y := top
	while y < int(GROUND_Y):
		if world.get_cell_source_id(Vector2i(30, y / 32)) == -1:
			solid = false
		y += 32
	ok(solid, "台体从 %d 到 %d 连续实心" % [top, int(GROUND_Y)])


func check_exit_sits_on_ledge() -> void:
	print("== 出口 ==")
	var exit_node: Node2D = room.get_node("Mechanisms/Exit")
	var bottom: float = exit_node.position.y + exit_node.block_size.y
	ok(is_equal_approx(bottom, EXPECT_LEDGE_Y), "Exit 底边 %.0f 贴台面 %.0f" % [bottom, EXPECT_LEDGE_Y])
	ok(exit_node.position.x + exit_node.block_size.x >= 1280.0 - 96.0, "Exit 靠右边界（x=%.0f）" % exit_node.position.x)


## 裸跳：脚底最高必须**明显**够不到台面，否则「必须靠虚影」的设计就失效了
func check_bare_jump_fails() -> void:
	print("== 裸跳 ==")
	player.global_position = Vector2(440, GROUND_Y - 44.0)
	player.velocity = Vector2.ZERO
	await frames(6)
	var min_feet := 9999.0
	var pressed := false
	for f in 70:
		press("move_right", true)
		if player.is_on_floor() and not pressed:
			press("jump", true)
			pressed = true
		await physics_frame
		min_feet = minf(min_feet, player.global_position.y + 44.0)
	press("jump", false)
	await frames(40)
	press("move_right", false)
	print("  脚底最高 %.1f，最终 %s" % [min_feet, player.global_position])
	ok(min_feet > EXPECT_LEDGE_Y + 8.0, "裸跳够不到台面（脚底 %.1f，台面 %.0f，差 %.1fpx）" % [min_feet, EXPECT_LEDGE_Y, min_feet - EXPECT_LEDGE_Y])
	ok(player.global_position.x < LEDGE_X - 32.0, "裸跳没有翻上台（x=%.1f）" % player.global_position.x)


## 踩虚影两段跳：必须能站上台面，且余量不小于 8px
func check_echo_boost_works() -> void:
	print("== 踩虚影垫脚 ==")
	echo = load("res://scenes/echo/echo.tscn").instantiate()
	room.add_child(echo)
	await physics_frame
	var pos := Vector2(496, GROUND_Y - 44.0)
	echo.setup(PackedVector2Array([pos, pos]))
	echo.reset()
	await frames(2)

	player.global_position = Vector2(pos.x - 90.0, GROUND_Y - 44.0)
	player.velocity = Vector2.ZERO
	await frames(4)

	var min_feet := 9999.0
	var state := 0
	for f in 220:
		press("move_right", true)
		match state:
			0:
				if player.global_position.x > pos.x - 50.0:
					press("jump", true)
					state = 1
			1:
				if support_is_echo():
					press("jump", false)
					state = 2
			2:
				press("jump", true)
				state = 3
		await physics_frame
		min_feet = minf(min_feet, player.global_position.y + 44.0)
	press("jump", false)
	# 先跑到台面中段就松手，确认「站得住」，别一路冲进出口
	for f in 60:
		await physics_frame
		if player.global_position.x > 700.0:
			break
	press("move_right", false)
	await frames(24)

	var feet: float = player.global_position.y + 44.0
	print("  脚底最高 %.1f，站定 %s（脚底 %.1f，floor=%s）" % [min_feet, player.global_position, feet, player.is_on_floor()])
	ok(min_feet < EXPECT_LEDGE_Y - 8.0, "踩虚影后脚底越过台面（最高 %.1f，台面 %.0f，余量 %.1fpx）" % [min_feet, EXPECT_LEDGE_Y, EXPECT_LEDGE_Y - min_feet])
	ok(player.global_position.x > LEDGE_X, "玩家站到了台面上（x=%.1f）" % player.global_position.x)
	ok(absf(feet - EXPECT_LEDGE_Y) <= 1.5, "站定脚底 %.1f 贴台面 %.0f" % [feet, EXPECT_LEDGE_Y])

	# 再一路向右，确认走到出口能通关
	press("move_right", true)
	for f in 200:
		await physics_frame
		if room.get("won") == true:
			break
	press("move_right", false)
	ok(room.get("won") == true, "走到出口触发通关（x=%.1f）" % player.global_position.x)


func support_is_echo() -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		if c.get_normal().y > -0.7:
			continue
		var b := c.get_collider()
		if b is Node2D and b.is_in_group("echo"):
			return true
	return false


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func press(action: String, down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)
