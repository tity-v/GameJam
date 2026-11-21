extends SceneTree
## 跳跃手感专项探针：把「按了多久才起跳」「提前按算不算数」「落地能不能立刻再跳」
## 「最小跳有多高」「顶点有没有悬停」逐帧量出来。
##
## 用法：
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/probe_jump.gd
## 输出统一为 "J <名字>=<值>"，便于和改后版本逐行 diff。
##
## 场景用 complete_room（40×22 瓦片地面，顶面 y=576，出生点 128,532），
## 因为它是真正的 TileMapLayer，能顺带测瓦片接缝有没有让 is_on_floor() 抖动。

const FLOOR_Y := 576.0
const SPAWN := Vector2(128, 532)

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

	print("J engine_ticks=%d" % Engine.physics_ticks_per_second)
	print("J params jump=%.0f gravity=%.0f cut=%.2f fall=%.2f coyote=%.2f buffer=%.2f" % [
		player.jump_velocity, player.gravity, player.jump_cut,
		player.fall_gravity_mult, player.coyote_time, player.jump_buffer])

	await _t_press_latency()
	await _t_input_latency()
	await _t_height_ladder()
	await _t_apex()
	await _t_land_now()
	await _t_rapid_rejump()
	await _t_prebuffer()
	await _t_hold_land()
	await _t_hold_on_ground()
	await _t_run_jump()
	await _t_coyote()
	await _t_seam()
	await _t_cut_sweep()

	quit()


# ---------- 0. 输入注入本身的延迟（用来校准 press_latency） ----------

func _t_input_latency() -> void:
	await _stand()
	_key(KEY_SPACE, true)
	var f_press := -1
	var f_just := -1
	var f_vel := -1
	for i in 6:
		await physics_frame
		if f_press < 0 and Input.is_action_pressed("jump"):
			f_press = i + 1
		if f_just < 0 and Input.is_action_just_pressed("jump"):
			f_just = i + 1
		if f_vel < 0 and player.velocity.y < 0.0:
			f_vel = i + 1
	_emit("input_frame_pressed", f_press)
	_emit("input_frame_just", f_just)
	_emit("input_frame_jumped", f_vel)
	_key(KEY_SPACE, false)
	await _until_land()

	# 换一种注入：action_press 直接改 action 状态，不走事件队列。
	# 两者差 1 帧，就说明 parse_input_event 的延迟是探针时序造成的，不是游戏的锅。
	await _stand()
	Input.action_press("jump")
	var f_vel2 := -1
	for i in 6:
		await physics_frame
		if f_vel2 < 0 and player.velocity.y < 0.0:
			f_vel2 = i + 1
	_emit("latency_via_action_press", f_vel2)
	Input.action_release("jump")
	await _until_land()


# ---------- 1. 按下到起跳的延迟 ----------

func _t_press_latency() -> void:
	await _stand()
	var y0: float = player.position.y
	_key(KEY_SPACE, true)

	# 从注入那帧算起，第几帧 vel.y 变负 / 位置开始上升
	var f_vel := -1
	var f_pos := -1
	for i in 10:
		await physics_frame
		if f_vel < 0 and player.velocity.y < 0.0:
			f_vel = i + 1
		if f_pos < 0 and player.position.y < y0 - 0.01:
			f_pos = i + 1
		if f_vel > 0 and f_pos > 0:
			break
	_emit("press_latency_vel", f_vel)
	_emit("press_latency_pos", f_pos)
	_emit("press_latency_ms", f_pos * 1000.0 / 60.0)
	_emit("first_frame_vy", player.velocity.y)
	_key(KEY_SPACE, false)
	await _until_land()


# ---------- 2. 按住的帧数 → 跳多高 ----------

func _t_height_ladder() -> void:
	for n in [1, 2, 3, 4, 6, 10, 99]:
		await _stand()
		var y0: float = player.position.y
		var hold: int = n if n < 99 else 40
		var top: float = y0
		_key(KEY_SPACE, true)
		# 按住的这段时间也要采样，否则会漏掉最高点
		for i in hold:
			await physics_frame
			top = minf(top, player.position.y)
		_key(KEY_SPACE, false)
		var frames := 0
		while frames < 200:
			await physics_frame
			frames += 1
			top = minf(top, player.position.y)
			if player.is_on_floor() and frames > 3:
				break
		var h: float = y0 - top
		var tag := "%df" % n if n < 99 else "all"
		_emit("height_hold_" + tag, h)
		_emit("height_tiles_" + tag, h / 32.0)


# ---------- 3. 顶点悬停 ----------

func _t_apex() -> void:
	await _stand()
	_key(KEY_SPACE, true)
	var near_apex := 0
	var rise := 0
	var fall := 0
	var peak_vy := 0.0
	for i in 200:
		await physics_frame
		var vy: float = player.velocity.y
		if vy < 0.0:
			rise += 1
		else:
			fall += 1
		if absf(vy) < 50.0:
			near_apex += 1
		peak_vy = maxf(peak_vy, vy)
		if i > 3 and player.is_on_floor():
			break
	_key(KEY_SPACE, false)
	_emit("apex_frames_50", near_apex)
	_emit("rise_frames", rise)
	_emit("fall_frames", fall)
	_emit("land_vy", peak_vy)


# ---------- 4. 落地当帧 / 落地后按跳 ----------

func _t_land_now() -> void:
	# 先量一次满跳的滞空帧数，作为基准
	await _stand()
	_key(KEY_SPACE, true)
	await _wait(2)
	_key(KEY_SPACE, false)
	var air := 0
	while not player.is_on_floor() and air < 200:
		await physics_frame
		air += 1
	_emit("air_frames", air)

	# 落地后第 k 帧按跳，看能不能起跳
	for k in [0, 1, 2, 3]:
		await _stand()
		_key(KEY_SPACE, true)
		await _wait(2)
		_key(KEY_SPACE, false)
		while not player.is_on_floor():
			await physics_frame
		# 此刻刚落地（is_on_floor 为 true），等 k 帧再按
		await _wait(k)
		_key(KEY_SPACE, true)
		var ok := 0
		for i in 3:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = 1
				break
		_key(KEY_SPACE, false)
		_emit("land_press_%df" % k, ok)
		await _until_land()


# ---------- 4b. 极快点击 / 落地瞬间连按 ----------

func _t_rapid_rejump() -> void:
	# 同一帧内按下又松开（真人手速极限），看输入会不会被吞
	var same_frame_ok := 0
	for i in 5:
		await _stand()
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
		var ok := false
		for j in 3:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = true
		if ok:
			same_frame_ok += 1
		await _until_land()
	_emit("rapid_same_frame_ok", same_frame_ok)

	# 落地后立刻再按，连续 5 次
	var chain := 0
	for i in 5:
		await _until_land()
		_key(KEY_SPACE, true)
		var ok := false
		for j in 3:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = true
		_key(KEY_SPACE, false)
		if ok:
			chain += 1
	_emit("chain_rejump_ok", chain)
	await _until_land()


# ---------- 4c. 跑动中起跳，水平速度掉不掉 ----------

func _t_run_jump() -> void:
	await _stand()
	_key(KEY_D, true)
	await _wait(20)
	var vx0: float = player.velocity.x
	_key(KEY_SPACE, true)
	await physics_frame
	var vx1: float = player.velocity.x
	await physics_frame
	var vx2: float = player.velocity.x
	_key(KEY_SPACE, false)
	_key(KEY_D, false)
	await _wait(6)
	var vx3: float = player.velocity.x
	_emit("run_vx_before", vx0)
	_emit("run_vx_after1", vx1)
	_emit("run_vx_after2", vx2)
	_emit("run_vx_air_free", vx3)
	await _until_land()


# ---------- 5. 落地前提前按（缓冲窗口） ----------

func _t_prebuffer() -> void:
	# 基准：满跳到落地的总帧数
	await _stand()
	_key(KEY_SPACE, true)
	await _wait(2)
	_key(KEY_SPACE, false)
	var total := 0
	while not player.is_on_floor() and total < 200:
		await physics_frame
		total += 1
	_emit("fall_total", total)

	# 在落地前 n 帧按下（按 2 帧即松），落地后看有没有自动起跳
	for n in [2, 4, 6, 7, 8, 10, 14]:
		await _stand()
		_key(KEY_SPACE, true)
		await _wait(2)
		_key(KEY_SPACE, false)
		var left: int = total - int(n)
		if left < 1:
			left = 1
		await _wait(left)
		_key(KEY_SPACE, true)
		await _wait(2)
		_key(KEY_SPACE, false)
		var ok := 0
		for i in 8:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = 1
				break
		_emit("prebuf_%df" % n, ok)
		await _until_land()


# ---------- 6. 按住不放落地，会不会自动连跳 ----------

func _t_hold_land() -> void:
	await _stand()
	_key(KEY_SPACE, true)
	# 一直按住：跳一次、落地，然后看落地后有没有再弹起来
	var rejumped := 0
	var was_air := false
	for i in 200:
		await physics_frame
		if not player.is_on_floor():
			was_air = true
		elif was_air:
			was_air = false
			# 落地当帧往后看几帧，真跳起来才算「自动连跳」
			for j in 3:
				await physics_frame
				if player.velocity.y < 0.0:
					rejumped = 1
					break
			break
	_key(KEY_SPACE, false)
	_emit("hold_land_autojump", rejumped)
	await _until_land()


# ---------- 7. 站在地上按住不放，能跳几次 ----------

func _t_hold_on_ground() -> void:
	await _stand()
	_key(KEY_SPACE, true)
	var jumps := 0
	var was_air := false
	for i in 120:
		await physics_frame
		if not player.is_on_floor():
			if not was_air:
				jumps += 1
			was_air = true
		else:
			was_air = false
	_key(KEY_SPACE, false)
	_emit("hold_ground_jumps_120f", jumps)
	await _until_land()


# ---------- 8. 土狼时间：走出平台边缘后第几帧还能跳 ----------

func _t_coyote() -> void:
	var plat := _make_platform(Vector2(360, 392), Vector2(96, 16))
	var best := 0
	for n in range(1, 13):
		_reset_to(Vector2(320, 348))
		await _wait(10)
		_key(KEY_D, true)
		# 跑到离地那一帧
		var left_ground := false
		for i in 90:
			await physics_frame
			if not player.is_on_floor():
				left_ground = true
				break
		_key(KEY_D, false)
		if not left_ground:
			break
		await _wait(n - 1)
		_key(KEY_SPACE, true)
		var ok := false
		for i in 2:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = true
		_key(KEY_SPACE, false)
		if ok:
			best = n
		await _until_land()
	_emit("coyote_max_frames", best)
	_emit("coyote_max_ms", best * 1000.0 / 60.0)
	plat.queue_free()
	await physics_frame


# ---------- 9. 瓦片接缝：跑动时 is_on_floor() 抖不抖 ----------

func _t_seam() -> void:
	_reset_to(SPAWN)
	await _wait(10)
	var off := 0
	var total := 0
	var min_vy := 0.0
	var max_vy := 0.0
	_key(KEY_D, true)
	for i in 120:
		await physics_frame
		total += 1
		if not player.is_on_floor():
			off += 1
			min_vy = minf(min_vy, player.velocity.y)
			max_vy = maxf(max_vy, player.velocity.y)
	_key(KEY_D, false)
	_emit("seam_offground_frames", off)
	_emit("seam_total_frames", total)
	_emit("seam_off_vy_range", max_vy - min_vy)

	# 在若干 x 位置从静止起跳，看有没有「按了不跳」
	var fails := 0
	var tries := 0
	for x in range(128, 320, 8):
		_reset_to(Vector2(x, SPAWN.y))
		await _wait(6)
		_key(KEY_SPACE, true)
		var ok := false
		for i in 3:
			await physics_frame
			if player.velocity.y < 0.0:
				ok = true
			# 若第 2 帧还没起跳，说明这一帧输入没被吃掉才怪
		_key(KEY_SPACE, false)
		tries += 1
		if not ok:
			fails += 1
		await _until_land()
	_emit("seam_jump_tries", tries)
	_emit("seam_jump_fails", fails)


# ---------- 10. 扫描 jump_cut：轻点到底能跳多高 ----------

func _t_cut_sweep() -> void:
	var orig: float = player.jump_cut
	for cut in [0.46, 0.50, 0.55, 0.65]:
		player.jump_cut = cut
		var out := "S cut=%.2f" % cut
		for hold in [1, 2, 3, 4, 5, 6, 8, 10, 14, 20]:
			var h: float = await _height_for(hold)
			out += " f%d=%.1f" % [hold, h]
		print(out)
	player.jump_cut = orig


func _height_for(hold: int) -> float:
	await _stand()
	var y0: float = player.position.y
	var top: float = y0
	_key(KEY_SPACE, true)
	for i in hold:
		await physics_frame
		top = minf(top, player.position.y)
	_key(KEY_SPACE, false)
	var frames := 0
	while frames < 200:
		await physics_frame
		frames += 1
		top = minf(top, player.position.y)
		if player.is_on_floor() and frames > 3:
			break
	return y0 - top


# ---------- 工具 ----------

func _stand() -> void:
	_reset_to(SPAWN)
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


func _make_platform(center: Vector2, size: Vector2) -> Node2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	lvl.add_child(body)
	return body


func _emit(name: String, v) -> void:
	if v is int:
		print("J %s=%d" % [name, v])
	else:
		print("J %s=%.2f" % [name, snappedf(float(v), 0.01)])


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
