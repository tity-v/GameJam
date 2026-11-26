extends StaticBody2D
## 每帧的 x 是方向轴，y 的两个位分别表示按下和松开跳跃。
const Motor = preload("res://scripts/echo_motor.gd")
const TOP_HEIGHT := 8.0


## 虚影身上那盏灯。挂在身体中心（不是节点原点），因为 torch_light 组里的
## 光源按 global_position 参与距离判定，直接用 echo 原点的左上角会偏 16/22。
class Lamp extends Node2D:
	var radii := Vector2.ZERO
	var can_power := false


@export var body_size := Vector2(32,44):
	set(value):
		body_size = value.max(Vector2.ONE)
		if is_node_ready():
			fit_visuals()
@export var fade_duration := 1.3
@export var death_min_alpha := 0.18
## 没拿手电时它身上的光：和主角未拾取手电时完全一样（72/100），只是照明。
@export var dim_radii := Vector2(72, 100)
## 死时拿着手电：和玩家持手电时一样大（120/180），而且能供能。
@export var lit_radii := Vector2(120, 180)
## 录到最后一帧后在原地站多久再消散。**默认 0 = 放完就散**（第一到第三章一直如此）。
## 只有需要「虚影替你站着供光」的关卡才调它，由 EchoManager.echo_hold_duration
## 在建虚影时写进来（3-2 是 7 秒），不在这里给默认值——
## 否则第一章的虚影会莫名其妙多站 7 秒，像卡住。
##
## 为什么必须给固定窗口而不能指望玩家「死前多站两秒」：
## 平台升到中层要 2.34s，玩家复活后还得跑回来，录像长度完全不可控。
@export var hold_duration := 0.0

@onready var _body := $Body as Sprite2D
@onready var _cross := $Cross as Sprite2D
@onready var _top := $Top as CollisionShape2D
var frames := PackedVector2Array()
var frame_index := 0
var last_delta := Vector2.ZERO
var input_axis := 0.0
## 死时有没有拿着手电。有 → 光照大一圈且能激活机关（光敏板认 can_power）
var has_flashlight := false
## blackout.gd / light_sensor.gd 读这两个
var radii := Vector2.ZERO
var can_power := false
var _origin := Vector2.ZERO
var _initial_velocity := Vector2.ZERO
var _initial_motion := PackedFloat32Array()
var _motor := Motor.new()
var _hit := CollisionShape2D.new()
var _lamp: Lamp
var _active := false
var _fading := false
var _fade_time := 0.0
var _hold_time := 0.0

func _ready() -> void:
	preload("res://scripts/replay_rules.gd").mark_ghost(self)
	_motor.collision_layer = 0
	_motor.collision_mask = 5
	add_child(_motor)
	_motor.add_collision_exception_with(self)
	_hit.shape = RectangleShape2D.new()
	_motor.add_child(_hit)
	_lamp = Lamp.new()
	_lamp.position = body_size * 0.5
	add_child(_lamp)
	_lamp.add_to_group("torch_light")
	fit_visuals()
	_apply_light()
	_set_active(false)

func setup_actions(actions: PackedVector2Array, origin: Vector2, initial_velocity: Vector2, player: CharacterBody2D, motion := PackedFloat32Array(), flashlight := false) -> void:
	frames = actions
	_origin = origin
	_initial_velocity = initial_velocity
	_initial_motion = motion
	has_flashlight = flashlight
	_apply_light()
	for key in ["max_speed","accel","air_accel","friction","air_friction","air_turn_stop","curve_power","air_curve_power","gravity","jump_velocity","fall_gravity_mult","jump_cut","coyote_time","jump_buffer","max_fall_speed","kill_y"]:
		_motor.set(key, player.get(key))

## 光的大小与供能资格都由「手里有没有手电」决定，一处改全处生效。
## 淡出中的虚影不算供能：它正在消失，不该还压着机关。
func _apply_light() -> void:
	can_power = has_flashlight and _active and not _fading
	radii = lit_radii if has_flashlight else dim_radii
	if _lamp != null:
		_lamp.can_power = can_power
		_sync_lamp(1.0)

## 淡出时按剩余比例收光圈，直到 0——否则虚影已经不显示了，
## 它那圈光还留在原地。
func _sync_lamp(fade: float) -> void:
	if _lamp == null:
		return
	_lamp.radii = radii * fade if _active else Vector2.ZERO

func reset() -> void:
	global_position = _origin
	_motor.position = Vector2.ZERO
	_motor.rewind_motion(_initial_velocity, _initial_motion)
	frame_index = 0
	_fading = false
	_fade_time = 0
	_hold_time = 0
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
	_apply_light()

func advance(dt: float) -> void:
	if not _active: return
	var before := global_position
	if _fading:
		input_axis = 0
		_motor.move_after_death(dt)
		_fade_time += dt
		_body.modulate.a = lerpf(1.0, death_min_alpha, clampf(_fade_time / fade_duration, 0, 1))
		_sync_lamp(clampf(1.0 - _fade_time / fade_duration, 0.0, 1.0))
	elif frame_index < frames.size():
		var action := frames[frame_index]
		input_axis = action.x
		var flags := int(action.y)
		_motor.move_with_input(dt, input_axis, bool(flags & 1), bool(flags & 2), flags)
		frame_index += 1
	else:
		# 录到尾巴了：原地站住，走物理（避免悬空）但不给输入。
		# 这段就是「虚影替你在板旁边站着」的时间。
		input_axis = 0
		_hold_time += dt
		_motor.move_with_input(dt, 0.0, false, false)
		# hold_duration 为 0（绝大多数关卡）时当帧就走，不多留一帧——
		# 保持「放完立刻开始淡出」的老手感。
		if hold_duration <= 0.0 or _hold_time >= hold_duration:
			die()
	global_position = _motor.global_position
	_motor.position = Vector2.ZERO
	last_delta = global_position - before
	if global_position.y > _motor.kill_y:
		die()
	if _fading and _fade_time >= fade_duration:
		_set_active(false)

func die() -> void:
	if _fading:
		return
	_fading = true
	input_axis = 0
	_cross.show()
	_apply_light()

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

func animation_motor() -> CharacterBody2D:
	return _motor if _active and not _fading else null

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
