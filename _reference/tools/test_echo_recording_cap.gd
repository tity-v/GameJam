extends SceneTree
## 验证录制上限（`max_frames`）的行为：**保留最近的轨迹，而不是最初的那段**。
##
## 为什么值得单独一个测试：
## 原来写的是 `if _trail.size() < MAX_FRAMES: append`，满了就**静默停止追加**。
## 后果是活过 100 秒之后，虚影重放的是"这一生最初的 100 秒"，
## 尸体落在 100 秒前的位置，和真正的死亡点差出几百像素——
## 尖刺关那种"靠尸体垫脚"的解法会直接失效，而且没有任何报错，很难查。
##
## 这里把上限调成 60 帧（1 秒）来放大这个行为，断言两件事：
##   1. 虚影末帧 ≈ 死亡位置（误差 < 一帧位移）
##   2. 虚影首帧已经离出生点很远（说明窗口滚动了，不是从头开始录）

const ECHO_FRAMES_MAX := 60

var room: Node2D
var player: Node2D
var manager: Node2D


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


func run() -> void:
	room = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	manager = room.get_node("EchoManager")
	# 先调小上限，再让玩家开始走
	manager.max_frames = ECHO_FRAMES_MAX
	await frames(6)

	var spawn_x: float = player.global_position.x
	# 走 130 帧（> 上限 60 的两倍，保证滚动了至少一次）
	Input.action_press("move_right")
	await frames(130)
	Input.action_release("move_right")
	await physics_frame

	var death_pos: Vector2 = player.global_position
	var trail: PackedVector2Array = manager._trail
	check(trail.size() <= ECHO_FRAMES_MAX, "trail never exceeds max_frames (%d, got %d)" % [ECHO_FRAMES_MAX, trail.size()])
	check(trail.size() >= ECHO_FRAMES_MAX / 2, "trail keeps a full window after rolling (%d)" % trail.size())
	check(trail[trail.size() - 1].distance_to(death_pos) < 12.0,
		"last recorded frame is next to the death point (dx=%.1f)" % (trail[trail.size() - 1].x - death_pos.x))
	check(trail[0].x > spawn_x + 100.0,
		"first frame has rolled forward, not the spawn (x=%.1f vs spawn %.1f)" % [trail[0].x, spawn_x])

	# 真的死一次，看虚影拿到的轨迹是不是同一份（且落点在死亡处）
	player.die()
	await frames(3)
	check(manager.echo_count() == 1, "dying still spawns one echo")
	var echo: Node2D = manager._echoes[0]
	var last: Vector2 = echo.frames[echo.frames.size() - 1]
	check(last.distance_to(death_pos) < 12.0,
		"echo corpse lands at the death point, not 100s ago (dx=%.1f)" % (last.x - death_pos.x))

	print("ECHO_RECORDING_CAP_ALL_PASS")
	quit()
