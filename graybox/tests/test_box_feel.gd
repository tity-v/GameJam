extends SceneTree
## 箱子手感全量验证：双向推、站上不推、松手滑停、压板触发、平台承载。
## 手感用例跑在 base_level 模板自己铺的平地上；压板用例切回 chapter_02_room_05。

const TEMPLATE = preload("res://graybox/base_level.tscn")
const BOX = preload("res://graybox/box.tscn")

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		print("FAIL ", message)
		failed = true

func setup_player_left(player: CharacterBody2D, crate: RigidBody2D, offset := 2.0) -> void:
	var col := player.get_node("Collision") as CollisionShape2D
	var psize := (col.shape as RectangleShape2D).size
	var half: Vector2 = crate.box_size * 0.5
	player.global_position = Vector2(crate.global_position.x - half.x - psize.x - offset, crate.global_position.y + half.y - psize.y)

func setup_player_right(player: CharacterBody2D, crate: RigidBody2D, offset := 2.0) -> void:
	var col := player.get_node("Collision") as CollisionShape2D
	var psize := (col.shape as RectangleShape2D).size
	var half: Vector2 = crate.box_size * 0.5
	player.global_position = Vector2(crate.global_position.x + half.x + offset, crate.global_position.y + half.y - psize.y)

func settle(frames: int) -> void:
	for i in frames:
		await physics_frame

## 在 base_level 里铺一排实体地板（行 row，列 c0..c1），并摆好箱子与玩家。
func build_ground(room: Node, c0: int, c1: int, row: int) -> void:
	var world := room.get_node("World") as TileMapLayer
	for c in range(c0, c1 + 1):
		world.set_cell(Vector2i(c, row), 0, Vector2i(1, 0))

func run() -> void:
	var room := TEMPLATE.instantiate()
	root.add_child(room)
	current_scene = room
	await settle(2)
	var player := room.get_node("Player") as CharacterBody2D
	var mechanisms := room.get_node("Mechanisms")
	var crate := BOX.instantiate() as RigidBody2D
	crate.position = Vector2(600, 556)
	mechanisms.add_child(crate)
	# 地面顶在 y=576（cell 行 18），箱底 576、玩家底 576 站在同一平面上。
	build_ground(room, 16, 32, 18)
	await settle(20)

	# ---- ① 从左推 600 → 825：速度稳定 ~150，玩家不被弹停 ----
	var x0 := crate.global_position.x
	setup_player_left(player, crate)
	Input.action_press("move_right")
	var v_min := 9999.0
	var v_avg := 0.0
	var avg_n := 0
	for i in 90:
		await physics_frame
		if i > 30:
			v_min = minf(v_min, crate.linear_velocity.x)
			v_avg += crate.linear_velocity.x
			avg_n += 1
	Input.action_release("move_right")
	var pushed := crate.global_position.x - x0
	v_avg /= avg_n
	check(pushed > 170.0, "左推 1.5s 移动 %.1f px" % pushed)
	check(v_avg > 120.0 and v_avg < 220.0 and v_min > 90.0, "推时速度稳定（均值 %.0f，最低 %.0f）" % [v_avg, v_min])
	check(player.global_position.x > x0 + 100.0, "玩家跟随前进不被弹停")

	# ---- ② 松手滑停：短滑即停 ----
	x0 = crate.global_position.x
	var prev := x0
	var slide_frames := 0
	for i in 120:
		await physics_frame
		if absf(crate.global_position.x - prev) < 0.01:
			break
		prev = crate.global_position.x
		slide_frames += 1
	var slide := crate.global_position.x - x0
	check(slide_frames < 40 and slide > 5.0 and slide < 60.0, "松手滑行 %.1f px / %d 帧停" % [slide, slide_frames])

	# ---- ③ 同一平地推回（对称性）----
	x0 = crate.global_position.x
	setup_player_right(player, crate)
	Input.action_press("move_left")
	for i in 90:
		await physics_frame
	Input.action_release("move_left")
	pushed = x0 - crate.global_position.x
	check(pushed > 170.0, "右推 1.5s 推回 %.1f px" % pushed)

	# ---- ④ 站在箱子上不推 ----
	crate.global_position = Vector2(600, 556)
	crate.linear_velocity = Vector2.ZERO
	await settle(20)
	x0 = crate.global_position.x
	var col := player.get_node("Collision") as CollisionShape2D
	var psize := (col.shape as RectangleShape2D).size
	player.global_position = Vector2(crate.global_position.x - psize.x / 2, crate.global_position.y - 20.0 - psize.y)
	await settle(20)
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	check(absf(crate.global_position.x - x0) < 2.0, "站在箱子上按方向键箱子不动")

	# ---- ⑤ 移动平台：阻尼不冻结箱子 ----
	var platform := preload("res://graybox/platform.tscn").instantiate() as AnimatableBody2D
	platform.position = Vector2(400, 150)
	platform.end_offset = Vector2(160, 0)
	room.add_child(platform)
	await physics_frame
	var cargo_material := PhysicsMaterial.new()
	cargo_material.friction = 0.05
	crate.physics_material_override = cargo_material
	crate.global_position = Vector2(400, 122)
	crate.linear_velocity = Vector2.ZERO
	await settle(10)
	var px0 := platform.global_position.x
	var bx0 := crate.global_position.x
	for i in 60:
		await physics_frame
	var platform_moved := platform.global_position.x - px0
	var box_moved := crate.global_position.x - bx0
	check(platform_moved > 50.0, "平台自身移动 %.1f px" % platform_moved)
	check(absf(box_moved - platform_moved) < 5.0, "低摩擦箱子跟随平台（平台 %.1f px，箱子 %.1f px）" % [platform_moved, box_moved])

	# ---- ⑥ 真实关卡：把箱子推上 K 压板 ----
	change_scene_to_file("res://scenes/levels/chapter_02_room_05.tscn")
	var guard := 0
	while current_scene == null and guard < 600:
		await process_frame
		guard += 1
	room = current_scene
	player = room.get_node("Player") as CharacterBody2D
	crate = room.get_node("Mechanisms/Crate") as RigidBody2D
	crate.global_position = Vector2(1024, 204)
	crate.linear_velocity = Vector2.ZERO
	await settle(20)
	setup_player_left(player, crate)
	var plate := room.get_node("Mechanisms/K")
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
	Input.action_release("move_right")
	check(plate.active, "箱子推上 K 压板触发")

	print("BOX_FEEL_RESULT=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
