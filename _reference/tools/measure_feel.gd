extends SceneTree
## 手感量化探针：把「按下去到动起来」「刹得住吗」「跳多高多远」「空中还算不算数」逐帧量出来。
## 用法：
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/measure_feel.gd -- --preset=now
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/measure_feel.gd -- --preset=prop
## 输出统一为 "M <名字>=<值>"，方便脚本逐行 diff 两套参数的差异。

const PRESETS := {
	"now": {},
	# 折中：保留「慢起后快」的凹形，只把总时长压到 4~5 帧
	"soft": {
		"accel": 3600.0,
		"curve_power": 1.35,
		"air_accel": 2900.0,
		"air_friction": 550.0,
		"jump_cut": 0.45,
		"fall_gravity_mult": 1.25,
	},
	# 推荐：加速改直线（按了立刻有速度），刹车保留凹形；空中阻力加大、矮跳压到一个瓦片
	"crisp": {
		"accel": 3400.0,
		"curve_power": 1.0,
		"air_accel": 3400.0,
		"air_friction": 800.0,
		"jump_cut": 0.45,
		"fall_gravity_mult": 1.3,
	},
}

var lvl
var player


func _initialize() -> void:
	_run()


func _run() -> void:
	var preset := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preset="):
			preset = a.split("=")[1]

	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	for i in 30:
		await physics_frame

	if PRESETS.has(preset):
		for k in PRESETS[preset]:
			player.set(k, PRESETS[preset][k])

	print("P preset=%s max_speed=%.0f accel=%.0f friction=%.0f curve=%.2f air_accel=%.0f air_friction=%.0f air_turn_stop=%.0f" % [
		preset, player.max_speed, player.accel, player.friction, player.curve_power,
		player.air_accel, player.air_friction, player.air_turn_stop])
	print("P jump=%.0f gravity=%.0f cut=%.2f fall_mult=%.2f" % [
		player.jump_velocity, player.gravity, player.jump_cut, player.fall_gravity_mult])

	await _m_ground_start()
	await _m_ground_stop()
	await _m_ground_turn()
	await _m_air_drift()
	await _m_air_turn()
	await _m_jump_height()
	await _m_jump_distance()
	await _m_landing()
	await _m_run_stability()
	await _m_idle()

	quit()


# ---------- 地面 ----------

func _m_ground_start() -> void:
	await _reset()
	var x0: float = player.position.x
	var vxs: Array = []
	_key(KEY_D, true)
	for i in 14:
		await physics_frame
		vxs.append(player.velocity.x)
		if i == 0:
			_emit("start_dx1", player.position.x - x0)
		if i == 2:
			_emit("start_dx3", player.position.x - x0)
		if i == 5:
			_emit("start_dx6", player.position.x - x0)
	_key(KEY_D, false)
	var full: float = player.max_speed
	var f95 := _frames_to(vxs, full * 0.95)
	var f50 := _frames_to(vxs, full * 0.5)
	_emit("start_frames_50", f50)
	_emit("start_frames_95", f95)
	_emit("start_vx_f1", vxs[0])
	_emit("start_vx_f2", vxs[1])
	_emit("start_vx_f3", vxs[2])
	_emit("start_ramp_ratio", vxs[0] / maxf(vxs[5], 0.001))
	await _wait(2)


func _m_ground_stop() -> void:
	await _reset()
	_key(KEY_D, true)
	await _wait(16)
	_key(KEY_D, false)
	var x0: float = player.position.x
	var vxs: Array = []
	for i in 12:
		await physics_frame
		vxs.append(player.velocity.x)
	var f0 := _frames_to_le(vxs, 0.001)
	_emit("stop_frames", f0)
	_emit("stop_dx", player.position.x - x0)
	_emit("stop_vx_f1", vxs[0])
	await _wait(2)


func _m_ground_turn() -> void:
	await _reset()
	_key(KEY_D, true)
	await _wait(16)
	_key(KEY_A, true)
	_key(KEY_D, false)
	var vxs: Array = []
	for i in 20:
		await physics_frame
		vxs.append(player.velocity.x)
	_emit("turn_frames_zero", _frames_to_le(vxs, 0.0))
	_emit("turn_frames_full", _frames_to_le(vxs, -player.max_speed * 0.95))
	_key(KEY_A, false)
	await _wait(2)


# ---------- 空中 ----------

func _m_air_drift() -> void:
	await _reset()
	_key(KEY_D, true)
	await _wait(16)
	_key(KEY_SPACE, true)
	await _wait(2)
	_key(KEY_SPACE, false)
	await _wait(8)
	var x0: float = player.position.x
	_key(KEY_D, false)
	var frames := 0
	while frames < 180:
		await physics_frame
		frames += 1
		if player.is_on_floor():
			break
	_emit("air_drift_dx", player.position.x - x0)
	_emit("air_drift_frames", frames)
	await _wait(2)


func _m_air_turn() -> void:
	await _reset()
	_key(KEY_D, true)
	await _wait(16)
	_key(KEY_SPACE, true)
	await _wait(2)
	_key(KEY_SPACE, false)
	await _wait(6)
	_key(KEY_A, true)
	_key(KEY_D, false)
	var vxs: Array = []
	for i in 14:
		await physics_frame
		vxs.append(player.velocity.x)
	_emit("air_turn_frames_zero", _frames_to_neg(vxs))
	_key(KEY_A, false)
	while not player.is_on_floor():
		await physics_frame
	await _wait(2)


# ---------- 跳跃 ----------

func _m_jump_height() -> void:
	for hold in [1, 3, 8, 999]:
		var r: Array = await _do_jump(hold)
		var tag := "inf" if hold >= 999 else str(hold)
		_emit("jump_h_hold" + tag, r[0])
		_emit("jump_air_hold" + tag, r[1])
		_emit("jump_apex_hold" + tag, r[2])
		_emit("jump_land_vy_hold" + tag, r[3])


func _do_jump(hold: int) -> Array:
	await _reset()
	var y0: float = player.position.y
	var min_y := y0
	var frames := 0
	var apex_frame := 0
	var released := false
	var land_vy := 0.0
	_key(KEY_SPACE, true)
	while frames < 240:
		await physics_frame
		frames += 1
		if player.position.y < min_y:
			min_y = player.position.y
			apex_frame = frames
		if not released and frames >= hold:
			_key(KEY_SPACE, false)
			released = true
		if frames > 4 and player.is_on_floor():
			land_vy = player.velocity.y
			break
	if not released:
		_key(KEY_SPACE, false)
	await _wait(3)
	return [y0 - min_y, frames, apex_frame, land_vy]


func _m_jump_distance() -> void:
	# 助跑跳：跑到满速 → 起跳 → 全程按住方向 → 量「离地点到落地点」的水平距离
	await _reset()
	_key(KEY_D, true)
	await _wait(20)
	var x0: float = player.position.x
	_key(KEY_SPACE, true)
	var frames := 0
	while frames < 240:
		await physics_frame
		frames += 1
		if frames > 4 and player.is_on_floor():
			break
	_key(KEY_SPACE, false)
	_key(KEY_D, false)
	_emit("dashjump_dx", player.position.x - x0)
	_emit("dashjump_frames", frames)
	_emit("dashjump_tiles", (player.position.x - x0) / 32.0)
	await _wait(3)


func _m_landing() -> void:
	# 落地后立刻再跳：验证跳跃缓冲能不能吃掉「落地前预按」
	await _reset()
	_key(KEY_SPACE, true)
	await _wait(30)
	_key(KEY_SPACE, false)
	var frames := 0
	while frames < 240:
		await physics_frame
		frames += 1
		if player.is_on_floor():
			break
	# 落地那一帧按下跳跃，看接下来 3 帧内有没有起跳
	_key(KEY_SPACE, true)
	var hit := 0
	var vys: Array = []
	for i in 3:
		await physics_frame
		vys.append(player.velocity.y)
		if player.velocity.y < -50.0 and hit == 0:
			hit = i + 1
	_emit("land_rejump_frame", hit)
	_emit("land_rejump_vy1", vys[0])
	_key(KEY_SPACE, false)
	await _wait(3)


func _m_run_stability() -> void:
	# 满速跑 60 帧，看有没有被瓦片接缝「顿」一下（vx 掉出满速即卡边）
	await _reset()
	_key(KEY_D, true)
	await _wait(20)
	var min_vx: float = 9999.0
	var x0: float = player.position.x
	for i in 60:
		await physics_frame
		min_vx = minf(min_vx, player.velocity.x)
	_emit("run_min_vx", min_vx)
	_emit("run_dx60", player.position.x - x0)
	_key(KEY_D, false)
	await _wait(3)


func _m_idle() -> void:
	# 站定不动：位置应完全静止（瓦片接缝不该把人挤动）
	await _reset()
	var p0: Vector2 = player.position
	await _wait(60)
	_emit("idle_drift", player.position.distance_to(p0))


# ---------- 工具 ----------

func _reset() -> void:
	for k in [KEY_A, KEY_D, KEY_SPACE]:
		_key(k, false)
	player.respawn()
	await physics_frame
	await _wait(12)


func _emit(name: String, v) -> void:
	print("M %s=%s" % [name, str(snappedf(float(v), 0.01))])


func _frames_to(vxs: Array, target: float) -> int:
	for i in vxs.size():
		if vxs[i] >= target:
			return i + 1
	return -1


func _frames_to_neg(vxs: Array) -> int:
	return _frames_to_le(vxs, 0.0)


func _frames_to_le(vxs: Array, target: float) -> int:
	for i in vxs.size():
		if vxs[i] <= target:
			return i + 1
	return -1


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
