extends SceneTree
## 从基础模板搭建临时房间，验证独立尺寸、保存重开及机关配置。

const TEMPLATE = preload("res://graybox/base_level.tscn")
const GROUND = preload("res://scenes/blocks/solid_ground.tscn")
const PLATE = preload("res://graybox/pressure_plate.tscn")
const DOOR = preload("res://graybox/door.tscn")
const EXIT = preload("res://graybox/exit.tscn")
const ECHO = preload("res://scenes/echo/echo.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		push_error(message)
		failed = true


func frames(count: int) -> void:
	for frame in count:
		await physics_frame


func add_piece(scene: PackedScene, parent: Node, scene_owner: Node, piece_name: String, point: Vector2) -> Node2D:
	var piece := scene.instantiate() as Node2D
	piece.name = piece_name
	piece.position = point
	parent.add_child(piece)
	piece.owner = scene_owner
	return piece


func run() -> void:
	var room := TEMPLATE.instantiate()
	var mechanisms := room.get_node("Mechanisms")
	var spawn := room.get_node("RespawnPoint") as Marker2D
	spawn.position.x = 210.0
	var terrain := room.get_node("Terrain")
	var step = add_piece(GROUND, terrain, room, "Step", Vector2(1024, 544))
	var wall = add_piece(GROUND, terrain, room, "Wall", Vector2(1160, 480))
	step.block_size = Vector2(94, 32)
	wall.block_size = Vector2(42, 96)
	var plate_a = add_piece(PLATE, mechanisms, room, "PlateA", Vector2(240, 564))
	var plate_b = add_piece(PLATE, mechanisms, room, "PlateB", Vector2(430, 564))
	plate_a.accepts_echo = false
	plate_b.accepts_player = false
	var door = add_piece(DOOR, mechanisms, room, "Door", Vector2(580, 416))
	var exit_piece = add_piece(EXIT, mechanisms, room, "Exit", Vector2(700, 510))
	check(not door._get_configuration_warnings().is_empty(), "门未配置时有提示")
	check(not exit_piece._get_configuration_warnings().is_empty(), "出口未配置时有提示")
	door.plate_paths.assign([NodePath("../PlateA")])
	door.safety_player = room.get_node("Player")
	exit_piece.door_path = NodePath("../Door")
	var scene := PackedScene.new()
	var scratch_path := ProjectSettings.globalize_path("res://build/graybox-kit-%d.tscn" % OS.get_process_id())
	var packed := scene.pack(room)
	var directory := DirAccess.make_dir_recursive_absolute(scratch_path.get_base_dir())
	if packed != OK or directory != OK or ResourceSaver.save(scene, scratch_path) != OK:
		room.free()
		push_error("无法保存临时验收场景")
		quit(1)
		return
	room.free()

	scene = ResourceLoader.load(scratch_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(scratch_path)
	if scene == null:
		push_error("无法重新打开临时验收场景")
		quit(1)
		return
	room = scene.instantiate()
	root.add_child(room)
	current_scene = room
	var player = room.get_node("Player")
	check(player.position.is_equal_approx(Vector2(210, 532)), "首次出生跟随移动后的标记")
	await frames(5)
	check(player.is_on_floor(), "模板地形具有实体碰撞")
	step = room.get_node("Terrain/Step")
	wall = room.get_node("Terrain/Wall")
	var step_shape: Vector2 = step.get_node("Collision").shape.size
	var wall_shape: Vector2 = wall.get_node("Collision").shape.size
	check(step_shape == Vector2(94, 32) and wall_shape == Vector2(42, 96), "保存重开后两个地形实例独立同步碰撞")
	var step_display: Vector2 = step.get_node("Patch").size
	var wall_display: Vector2 = wall.get_node("Patch").size
	check(step_display == step_shape and wall_display == wall_shape, "保存重开后地形显示尺寸正确")
	player.respawn()
	check(player.position.is_equal_approx(Vector2(210, 532)), "重生跟随同一个标记")

	mechanisms = room.get_node("Mechanisms")
	plate_a = mechanisms.get_node("PlateA")
	plate_b = mechanisms.get_node("PlateB")
	door = mechanisms.get_node("Door")
	exit_piece = mechanisms.get_node("Exit")
	check(door._get_configuration_warnings().is_empty() and exit_piece._get_configuration_warnings().is_empty(), "保存重开后机关接线有效")
	player.position.x = plate_a.position.x
	await frames(3)
	check(plate_a.active and door.opened and door.get_node("Collision").disabled, "单板持续门打开并禁用碰撞")
	player.position.x = door.position.x + 5.0
	await frames(3)
	check(not plate_a.active and not door.opened, "玩家进入门身后松开压板也立即关门")
	player.position.x = plate_b.position.x
	await frames(3)
	check(not door.opened and not door.get_node("Collision").disabled, "玩家离开后门关闭并恢复碰撞")
	check(not plate_b.active, "仅 Echo 压力板拒绝当前玩家")

	var echo = ECHO.instantiate()
	room.add_child(echo)
	echo.setup(PackedVector2Array([Vector2(plate_a.position.x, 532)]))
	echo.reset()  # 虚影只认 reset() 这一个登场入口：setup 只载入轨迹，不激活（HANDOVER §4.7）
	await frames(3)
	check(not plate_a.active, "仅玩家压力板拒绝 Echo")
	door.plate_paths.assign([NodePath("../PlateA"), NodePath("../PlateB")])
	echo.position.x = plate_b.position.x
	await frames(3)
	check(plate_b.active and not door.opened, "Echo 能踩板，但双板门在单板激活时保持关闭")
	player.position.x = plate_a.position.x
	await frames(3)
	check(door.opened, "两块板同时激活后开门")
	echo.position.x = exit_piece.position.x
	await frames(3)
	check(not door.opened and not plate_b.active and not room.won, "松开任意关联压板即关门")
	echo.position.x = plate_b.position.x
	await frames(3)
	check(door.opened, "再次同时踩住两块板可开门")
	# 保持两个压板都由 Echo 踩住，验证出口只接受玩家。
	plate_a.accepts_echo = true
	var echo_a = ECHO.instantiate()
	room.add_child(echo_a)
	echo_a.setup(PackedVector2Array([Vector2(plate_a.position.x, 532)]))
	echo_a.reset()
	var exit_echo = ECHO.instantiate()
	room.add_child(exit_echo)
	exit_echo.setup(PackedVector2Array([Vector2(exit_piece.position.x, 532)]))
	exit_echo.reset()
	await frames(3)
	check(door.opened and not room.won, "开启的出口不接受 Echo")
	player.position.x = exit_piece.position.x
	await frames(3)
	check(room.won, "当前玩家进入出口触发通关")
	quit(1 if failed else 0)
