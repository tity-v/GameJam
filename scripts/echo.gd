extends StaticBody2D
## 每帧的 x 是方向轴，y 的两个位分别表示按下和松开跳跃。
const Motor = preload("res://scripts/echo_motor.gd")
const TOP_HEIGHT := 8.0
@export var body_size := Vector2(32,44):
	set(value):
		body_size = value.max(Vector2.ONE)
		if is_node_ready():
			fit_visuals()
@export var fade_duration := 1.3
@export var death_min_alpha := 0.18
@onready var _body := $Body as Sprite2D
@onready var _cross := $Cross as Sprite2D
@onready var _top := $Top as CollisionShape2D
var frames := PackedVector2Array()
var frame_index := 0
var last_delta := Vector2.ZERO
var input_axis := 0.0
var _origin := Vector2.ZERO
var _initial_velocity := Vector2.ZERO
var _initial_motion := PackedFloat32Array()
var _motor := Motor.new()
var _hit := CollisionShape2D.new()
var _active := false
var _fading := false
var _fade_time := 0.0

func _ready() -> void:
	preload("res://scripts/replay_rules.gd").mark_ghost(self)
	_motor.collision_layer = 0
	_motor.collision_mask = 5
	add_child(_motor)
	_motor.add_collision_exception_with(self)
	_hit.shape = RectangleShape2D.new()
	_motor.add_child(_hit)
	fit_visuals()
	_set_active(false)

func setup_actions(actions: PackedVector2Array, origin: Vector2, initial_velocity: Vector2, player: CharacterBody2D, motion := PackedFloat32Array()) -> void:
	frames = actions
	_origin = origin
	_initial_velocity = initial_velocity
	_initial_motion = motion
	for key in ["max_speed","accel","air_accel","friction","air_friction","air_turn_stop","curve_power","air_curve_power","gravity","jump_velocity","fall_gravity_mult","jump_cut","coyote_time","jump_buffer","max_fall_speed","kill_y"]:
		_motor.set(key, player.get(key))

func reset() -> void:
	global_position = _origin
	_motor.position = Vector2.ZERO
	_motor.rewind_motion(_initial_velocity, _initial_motion)
	frame_index = 0
	_fading = false
	_fade_time = 0
	input_axis = 0
	last_delta = Vector2.ZERO
	_body.modulate.a = 1
	_cross.hide()
	_set_active(not frames.is_empty())

func _set_active(on: bool) -> void:
	_active = on
	visible = on
	set_collision_layer_value(3, on)
	_top.set_deferred("disabled", not on)

func advance(dt: float) -> void:
	if not _active: return
	var before := global_position
	if not _fading:
		var action := frames[frame_index]
		input_axis = action.x
		var flags := int(action.y)
		_motor.move_with_input(dt, input_axis, bool(flags & 1), bool(flags & 2))
		frame_index += 1
	else:
		input_axis = 0
		_motor.move_after_death(dt)
		_fade_time += dt
		_body.modulate.a = lerpf(1.0, death_min_alpha, clampf(_fade_time / fade_duration, 0, 1))
	global_position = _motor.global_position
	_motor.position = Vector2.ZERO
	last_delta = global_position - before
	if frame_index >= frames.size() or global_position.y > _motor.kill_y:
		die()
	if _fade_time >= fade_duration:
		_set_active(false)

func die() -> void:
	_fading = true
	input_axis = 0
	_cross.show()

func is_active() -> bool:
	return _active

func is_gone() -> bool:
	return not _active

func body_rect() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, body_size)

func horizontal_intent() -> float:
	return input_axis * _motor.max_speed

func get_frame_delta() -> Vector2:
	return last_delta if _active else Vector2.ZERO

func fit_visuals() -> void:
	(_hit.shape as RectangleShape2D).size = body_size
	_hit.position = body_size / 2
	for s: Sprite2D in [_body, _cross]:
		if s == null or s.texture == null:
			continue
		if s.has_method("fit_to_body"):
			s.call("fit_to_body", body_size)
			continue
		var ts: Vector2 = s.texture.get_size()
		if ts.x <= 0.0 or ts.y <= 0.0:
			continue
		s.scale = Vector2(body_size.x / ts.x, body_size.y / ts.y)
	# 可踩薄片跟着身体宽度走：身体变宽而薄片不变，边缘就会踩空
	if _top != null and _top.shape is RectangleShape2D:
		var shape := _top.shape.duplicate() as RectangleShape2D
		shape.size = Vector2(body_size.x, TOP_HEIGHT)
		_top.shape = shape
		_top.position = Vector2(body_size.x * 0.5, TOP_HEIGHT * 0.5)
