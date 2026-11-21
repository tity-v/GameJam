extends SceneTree
## 跳跃高度档位扫描：回答「把 jump_velocity 抬高能不能改善手感」。
##
## 用法：
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/sweep_height.gd
##
## 每个初速测四组读数：
##   full      按住不放的满跳高度（脚底上升量）
##   tap1/3/6  按住 1/3/6 帧松手的高度（1/3 帧约等于人手轻点、6 帧是明显短按）
##   f64       达到 2 格（64px）所需的最少按住帧数；f96 是 3 格
## 最后一档额外跑「能否跳过示例房间的门」实测，用来确定高度上限。

const FLOOR_Y := 576.0
const SPAWN := Vector2(128, 532)
const DOOR_LEFT := 832.0
const DOOR_RIGHT := 896.0
const DOOR_TOP := 416.0

var lvl
var player


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	for i in 40:
		await physics_frame

	print("H 当前 jump=%.0f cut=%.2f gravity=%.0f" % [player.jump_velocity, player.jump_cut, player.gravity])

	# --door：只跑「能否跳过门」的实测，用于确认高度上限
	if "--door" in OS.get_cmdline_user_args():
		for j in [610, 660, 680, 700, 712, 720]:
			await _door_test(float(j), "j=%.0f" % j)
		quit()
		return

	# --curve：只画「按住时长 → 高度」曲线（现状 vs 建议），用于判断临界点位置
	if "--curve" in OS.get_cmdline_user_args():
		await _curve(610.0, 0.65, "现状")
		await _curve(680.0, 0.45, "建议")
		quit()
		return

	# 先扫 cut 固定在 0.65（现状）和 0.50（上一轮建议），看高度档位怎么变
	for cut in [0.65, 0.50]:
		player.jump_cut = cut
		for j in [610, 630, 645, 660, 680, 700, 720]:
			await _measure(j, cut)

	# 再扫「抬高高度 + 压低松手系数」的组合，找能上 128 台又不让轻点逼近 2 格的窗口
	for pair in [[660, 0.45], [680, 0.42], [680, 0.45], [700, 0.42], [700, 0.45]]:
		await _measure(pair[0], pair[1])

	player.jump_cut = 0.65
	await _door_test(610.0, "现状")
	await _door_test(660.0, "抬到4.2格")
	await _door_test(720.0, "抬到5格")
	await _door_test(760.0, "明显过头")

	quit()


## 按住 1..14 帧的高度曲线，一行一个点
func _curve(j: float, cut: float, label: String) -> void:
	player.jump_velocity = -j
	player.jump_cut = cut
	for n in range(1, 15):
		var h: float = await _height(n)
		print("C %s hold=%d h=%.1f tiles=%.2f" % [label, n, h, h / 32.0])


func _measure(j: float, cut: float) -> void:
	player.jump_velocity = -j
	player.jump_cut = cut
	var full: float = await _height(99)
	var t1: float = await _height(1)
	var t3: float = await _height(3)
	var t6: float = await _height(6)
	var f64: int = await _min_frames(64.0)
	var f96: int = await _min_frames(96.0)
	var f128: int = await _min_frames(128.0)
	print("H cut=%.2f j=%.0f full=%6.2f(%4.2ft) tap1=%5.1f tap3=%5.1f tap6=%5.1f f64=%2d f96=%2d f128=%2d" % [
		cut, j, full, full / 32.0, t1, t3, t6, f64, f96, f128])


## 按住 hold 帧（99 表示按到顶）后松手，返回脚底最大上升量
func _height(hold: int) -> float:
	await _stand()
	var y0: float = player.position.y
	_key(KEY_SPACE, true)
	if hold < 99:
		await _wait(hold)
		_key(KEY_SPACE, false)
	var top := y0
	var frames := 0
	while frames < 200:
		await physics_frame
		frames += 1
		top = minf(top, player.position.y)
		if frames > 4 and player.is_on_floor():
			break
	_key(KEY_SPACE, false)
	await _until_land()
	return y0 - top


## 达到目标高度最少要按住几帧（1..14，都达不到返回 -1）
func _min_frames(target: float) -> int:
	for n in range(1, 15):
		var h: float = await _height(n)
		if h >= target:
			return n
	return -1


## 贴门起跳：能不能从左侧越过去？返回越过情况
func _door_test(j: float, label: String) -> void:
	player.jump_velocity = -j
	# 站在门左侧 40px 处，向右跑 + 按住跳，跑 150 帧
	await _reset_to(Vector2(DOOR_LEFT - 72.0, FLOOR_Y - 44.0))
	await _wait(10)
	var min_feet := 9999.0
	var max_x: float = player.position.x
	_key(KEY_D, true)
	_key(KEY_SPACE, true)
	for i in 150:
		await physics_frame
		min_feet = minf(min_feet, player.position.y + 44.0)
		max_x = maxf(max_x, player.position.x)
	_key(KEY_D, false)
	_key(KEY_SPACE, false)
	await _until_land()
	# 脚底越过门顶 = 有可能站上去；x 越过门右侧 = 真的过来了
	var pass_top := min_feet < DOOR_TOP
	var pass_x := max_x > DOOR_RIGHT
	print("D %s j=%.0f 脚底最高=%.1f(门顶%.0f) 最远x=%.1f 越顶=%s 过门=%s" % [
		label, j, min_feet, DOOR_TOP, max_x, "是" if pass_top else "否", "是" if pass_x else "否"])


# ---------- 工具（与 probe_jump.gd 一致） ----------

func _stand() -> void:
	await _reset_to(SPAWN)
	await _wait(12)


func _reset_to(p: Vector2) -> void:
	for k in [KEY_A, KEY_D, KEY_SPACE]:
		_key(k, false)
	player.velocity = Vector2.ZERO
	player.global_position = p
	await physics_frame


func _until_land() -> void:
	var g := 0
	while not player.is_on_floor() and g < 240:
		await physics_frame
		g += 1
	await _wait(3)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
