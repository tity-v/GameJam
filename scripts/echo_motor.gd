extends "res://scripts/player.gd"
## 仅由录像逐物理帧驱动，使用和玩家相同的运动与承载逻辑。
func _ready() -> void:
	set_physics_process(false)

func rewind_motion(start_velocity: Vector2, motion: PackedFloat32Array) -> void:
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
