extends SceneTree
## 3-1 打火教学关（room_31_proto）的验收。
##
## 这一关的设计前提是「不打火也能过」，所以测试里刻意不点灯先走一遍；
## 打火只验证它确实把半径从 40 抬到 96、2.5s 后回落、冷却期按了无效。
## 虚影与铁栅用时间推进验，不靠肉眼。

const ROOM := "res://scenes/levels/chapter_03/room_31_proto.tscn"

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(8)

	var world := room.get_node("World") as TileMapLayer
	expect(world.get_used_cells().size() == 250, "地形 250 格")

	var black := room.get_node("Blackout") as TileMapLayer
	expect(black.get_used_cells().size() == 880, "黑幕铺满 40×22")
	# 玩家自带光被压到 2px（这一关只给手电），但虚影的光必须独立存活——
	# 两者原来共用 personal_radii，虚影会被一起关掉。
	expect(black.get("personal_radii").x <= 4.0, "玩家自带光已关闭（只靠手电）")
	expect(black.get("echo_radii").x >= 60.0, "虚影照亮半径独立于玩家")

	var gate := room.get_node("Gate") as StaticBody2D
	expect(not gate.get("opened"), "开局铁栅是关的")

	var p := room.get_node("Player") as CharacterBody2D
	expect(is_equal_approx(p.position.y, 532.0), "出生点站地面（576-44）")
	expect(p.is_on_floor(), "出生即落地")

	var torch := room.get_node("Player/Torch")
	var dim: Vector2 = torch.get("radii")
	expect(dim == Vector2(40.0, 90.0), "底光 40")
	expect(dim.y - dim.x >= 40.0, "底光有柔边（不硬切）")

	Input.action_press("fire")
	await _frames(3)
	Input.action_release("fire")
	await _frames(2)
	var lit: Vector2 = torch.get("radii")
	expect(lit.x > 90.0, "打火半径到 96")
	expect(lit.y - lit.x >= 50.0, "打火柔边 54px，由内向外渐隐")
	expect(torch.get("fire_count") == 1, "打火计数 1")

	await _frames(160)
	expect(torch.get("radii").x < 50.0, "2.5s 后回到底光")

	var before: int = torch.get("fire_count")
	Input.action_press("fire")
	await _frames(3)
	Input.action_release("fire")
	await _frames(2)
	expect(torch.get("fire_count") == before, "冷却期内按了不生效")

	# 不打火也能跳上 96px 台面（这一关的容错底线）
	p.position = Vector2(544, 532)
	await _frames(16)
	_key(KEY_D, true)
	await _frames(8)
	_key(KEY_SPACE, true)
	await _frames(12)
	_key(KEY_SPACE, false)
	await _frames(70)
	_key(KEY_D, false)
	expect(absf(p.position.y - 436.0) < 4.0, "裸跳能上 480 台面")
	expect(p.position.x > 608.0, "落点在台上（x>608）")

	var spec := room.get_node("Specter") as CharacterBody2D
	await _frames(300)
	expect(spec.get("halted"), "虚影走到 stop_x 停下")
	expect(spec.position.x >= 1088.0, "虚影停在出口旁")
	expect(gate.get("opened"), "虚影触发铁栅升起")
	expect(gate.get("lift") >= 199.0, "铁栅抬满 200px")
	expect(gate.get_node("Solid").disabled, "铁栅撤掉碰撞")
	expect(spec.get("radii").x < 120.0, "虚影停下后收光（仍在照路）")

	# 掉出地图要回**自己的**起点。这里曾经有 bug：虚影继承了 player 的
	# reset_to_spawn()，而 respawn_position 指向玩家出生点（x=112），
	# 虚影会从地图另一头重新出现。
	var home: Vector2 = spec.get("_start")
	spec.set("halted", false)
	spec.global_position = Vector2(800.0, 800.0)
	await _frames(2)
	expect(absf(spec.global_position.x - home.x) < 20.0, "虚影掉出地图回自己起点")

	print("ROOM31 %d/%d" % [_pass, _pass + _fail])
	if _fail > 0:
		print("ROOM31_FAIL %d" % _fail)
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


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
