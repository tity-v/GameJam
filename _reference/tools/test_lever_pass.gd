extends SceneTree
## 锁定「拨过的拉杆不再挡人」这条契约。
##
## 曾经的 bug（用户描述为「主角能过拉杆、虚影过不了」）：
##   玩家拨杆 → 碰撞体禁用 → 玩家趁禁用期间穿过去 → 走远后 `touching` 变 false
##   → 碰撞体重新启用。玩家自己已经过去了，看不见问题；
##   但虚影是**之后**才重放这条轨迹的，它到杆前面时杆又立起来了，被卡在原地。
##
## 现在的规则：杆是开关，拨过去就躺着，碰撞体保持禁用，直到 `reset_mechanism()`（R）复位。
##
## 四条断言，缺一条都可能把 bug 放回来：
##   1. 杆未拨时是实体（不能为了"让虚影过"把碰撞体整个删掉）
##   2. 玩家拨杆后碰撞体禁用
##   3. 玩家走远后碰撞体**仍然**禁用（这就是当初漏掉的一步）
##   4. 虚影重放同一段能穿过去，且不会把杆误拨回去
##   5. R 复位后重新变成实体

const ROOM := "res://scenes/levels/chapter_01_room_03.tscn"
const ECHO := preload("res://scenes/echo/echo.tscn")
## room_03 的杆在 (992,573)，地形顶 576；玩家 32×44，脚底贴地时 origin y = 532
const LEVER_X := 992.0
const START_X := 1040.0

var room: Node2D
var player: CharacterBody2D
var lever: Node2D
var actions := PackedVector2Array()
var capturing := false
var rec_origin := Vector2.ZERO
var rec_velocity := Vector2.ZERO
var rec_motion := PackedFloat32Array()


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


func _on_movement_input(axis: float, pressed: bool, released: bool) -> void:
	if capturing:
		actions.append(Vector2(axis, int(pressed) | (int(released) << 1)))


func build() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
		room = null
	room = load(ROOM).instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	lever = room.get_node("Mechanisms/Lever")
	player.hide()  # 先藏起来，避免未激活时被机关当成"站在那里的人"


func _collision_disabled() -> bool:
	return (lever.get_node("Collision") as CollisionShape2D).disabled


func run() -> void:
	# ---------- 1 未拨的杆是实体 ----------
	build()
	await frames(3)
	check(not _collision_disabled(), "未拨动的拉杆是实体（会挡住人）")

	# 直接问物理：从杆右侧往左探 60px，会不会撞上东西。
	# （滑行法不成立：虚影松手后地面摩擦一帧就把速度吃光了，走不到杆前。）
	player.global_position = Vector2(1030, 532)
	player.velocity = Vector2.ZERO
	await frames(2)
	check(player.test_move(player.global_transform, Vector2(-60, 0)),
		"未拨杆时从右侧向左移动 60px 会被挡住")
	check(not lever.active, "虚影没按方向键，不会拨动杆")

	# ---------- 2 玩家拨杆并穿过去 ----------
	build()
	await frames(3)
	player.show()
	player.global_position = Vector2(START_X, 532)
	player.velocity = Vector2.ZERO
	await frames(6)

	actions = PackedVector2Array()
	rec_origin = player.global_position
	rec_velocity = player.velocity
	rec_motion = player.capture_motion()
	capturing = true
	player.movement_input.connect(_on_movement_input)

	Input.action_press("move_left")
	var flipped_at := -1
	for f in 120:
		await physics_frame
		if lever.active and flipped_at < 0:
			flipped_at = f
		# 一直走到杆左侧 60px 以上，确实"穿过去了"
		if player.global_position.x < LEVER_X - 60.0:
			break
	Input.action_release("move_left")
	capturing = false
	await frames(6)

	check(flipped_at >= 0, "玩家推杆把杆拨过去了")
	check(player.global_position.x < LEVER_X - 40.0,
		"玩家穿到了杆左侧（x=%.1f，杆 %.0f）" % [player.global_position.x, LEVER_X])
	check(_collision_disabled(), "拨动后杆的碰撞体被禁用")

	# ---------- 3 走远之后仍然禁用（这条就是当初的 bug） ----------
	await frames(30)
	check(_collision_disabled(),
		"玩家走远、无人碰触后杆的碰撞体**仍然**禁用（%d 帧后复查）" % 30)

	# ---------- 4 虚影重放同一段能穿过去 ----------
	var passed := actions.size()
	player.hide()
	player.global_position = Vector2(100, 532)
	await frames(4)

	var ghost: Node2D = ECHO.instantiate()
	room.add_child(ghost)
	await physics_frame
	ghost.setup_actions(actions.duplicate(), rec_origin, rec_velocity, player, rec_motion)
	ghost.reset()
	await frames(1)
	for i in passed + 10:
		await physics_frame
		ghost.advance(1.0 / 60.0)
	check(ghost.global_position.x < LEVER_X - 40.0,
		"虚影重放同一段能穿过杆（停在 %.1f，玩家当时 %.1f）" % [
			ghost.global_position.x, player.global_position.x])
	check(lever.active, "虚影穿过时没有把杆误拨回去")

	# ---------- 5 R 复位后重新变成实体 ----------
	lever.reset_mechanism()
	await frames(2)
	check(not _collision_disabled(), "reset_mechanism 后杆恢复成实体")

	print("\nALL_LEVER_PASS_OK")
	quit()
