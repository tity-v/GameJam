extends SceneTree
## 门会不会关在玩家身上？
##
## 门是「松开任一压板就关」。如果此刻玩家正站在门洞里，门一关就和玩家的碰撞体重叠——
## 而 CharacterBody2D 一旦被 StaticBody2D 包住，横向完全推不动（实测按住方向键 130 帧
## x 一个像素都不变，y 一直上下被挤），除了按 R 没有别的出路。
## 所以 puzzle_door 在关门前会看一眼门口：有人就等，人走了再关。
##
## 这条断言守的是「不软锁」，不是「门必须立刻关」——放松板后门晚半秒关是允许的。

const ECHO := preload("res://scenes/echo/echo.tscn")

var room: Node2D
var player: Node2D
var door: Node2D
var collision: CollisionShape2D


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
	print("PASS ", message)


func run() -> void:
	room = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	door = room.get_node("Door")
	collision = door.get_node("Collision")
	await frames(10)

	check(not door.opened and not collision.disabled, "door starts closed and solid")

	# 摆成「两块板刚松开、门还是开的」那一瞬：停掉门自己的检测，免得它立刻关回去
	door.set_physics_process(false)
	door.opened = true
	collision.set_deferred("disabled", true)
	await frames(4)
	check(collision.disabled, "door is open before the player steps in")

	# 玩家站进门洞正中（门 rect 是 832..896 × 416..576）
	player.global_position = Vector2(848, 532)
	await frames(4)
	# 交回门自己的检测：两块板都没踩，它想关，但门口有人
	door.set_physics_process(true)
	await frames(10)
	check(door.opened, "door stays open while the player stands in the doorway")
	check(collision.disabled, "door collision stays off while the player is inside")

	# 关键一步：原来这里 x 一动不动（被门夹住），现在应该能走出去
	key(KEY_D, true)
	await frames(150)
	key(KEY_D, false)
	check(player.global_position.x > 900.0, "player can walk out of a closing door instead of being stuck")

	# 人出去了，门该补关
	await frames(10)
	check(not door.opened, "door closes once the doorway is clear")
	check(not collision.disabled, "cleared doorway gets its collision back")

	# 关上的门必须真的又是墙
	player.global_position = Vector2(800, 532)
	await frames(4)
	key(KEY_D, true)
	await frames(120)
	key(KEY_D, false)
	check(player.global_position.x < 832.0, "closed door blocks the player again")

	# 虚影不顶门：一条停在门口的轨迹不能把门永久撑开
	door.set_physics_process(false)
	door.opened = true
	collision.set_deferred("disabled", true)
	await frames(4)
	door.set_physics_process(true)
	var ghost := ECHO.instantiate()
	room.add_child(ghost)
	ghost.setup(PackedVector2Array([Vector2(848, 532), Vector2(848, 532)]))
	ghost.reset()
	await frames(10)
	check(not door.opened, "an echo inside the doorway does not hold the door open")

	print("DOOR_SAFETY_ALL_PASS")
	quit()
