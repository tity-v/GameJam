extends "res://scripts/player.gd"
## 仅由录像逐物理帧驱动，使用和玩家相同的运动与承载逻辑。
func _ready() -> void:
	set_physics_process(false)

## 虚影能直接跨上多高的一格台阶。32 = 一个瓦片：正好是 3-2 井底那口凹槽的深度。
const STEP_UP := 32.0

## 被一格台阶挡住时自动跨上去。
##
## 为什么需要这条：录像里存的是**按键**，不是「跳过这个坑」这件事。
## 玩家从井口走进走出时，升降台正好停在井底（台面与地面齐平），他是一路平走过去的，
## 录像里自然没有跳；等虚影重放时台子升走了，井底变成 32px 深的凹槽，
## 虚影一头撞在凹槽侧壁上，之后就顶着墙原地站完剩下的时间——
## 既到不了板旁、也供不了光，第一段的解法直接断掉（`test_room32_loop` 复现过）。
##
## 换个思路是「别让玩家掉进去」，但井底凹槽是升降台藏身的地方，去掉它台面就
## 和地面重合，玩家会站在地板上而不是台面上，台子升起来带不动人。
## 所以凹槽留着，给虚影补一个「像人一样跨上去」的能力，水平进度不变、不会失同步。
func _after_move(axis: float) -> void:
	if absf(axis) < 0.01 or not is_on_floor() or not is_on_wall():
		return
	var static_wall := false
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().x) > 0.5 and hit.get_collider() is StaticBody2D:
			static_wall = true
	if not static_wall:
		return
	var dir := signf(axis)
	# 头顶得是空的，否则这是面高墙/低天花板，不许穿
	if test_move(global_transform, Vector2(0.0, -STEP_UP)):
		return
	var lifted := Transform2D(global_transform.get_rotation(), global_position + Vector2(0.0, -STEP_UP))
	# 抬上去之后前面得能走；还是墙就说明这不是台阶，是真墙
	if test_move(lifted, Vector2(dir * 8.0, 0.0)):
		return
	global_position.y -= STEP_UP

func rewind_motion(start_velocity: Vector2, motion: PackedFloat32Array) -> void:
	climbing = motion.size() > 9 and bool(motion[9])
	velocity = start_velocity
	_coyote = 0.0
	_buffer = 0.0
	_ramp_on = false
	_support = null
	if not motion.is_empty():
		_coyote = motion[0]
		_buffer = motion[1]
		_ramp_from = motion[2]
		_ramp_to = motion[3]
		_ramp_rate = motion[4]
		_ramp_power = motion[5]
		_ramp_dur = motion[6]
		_ramp_time = motion[7]
		_ramp_on = bool(motion[8])
