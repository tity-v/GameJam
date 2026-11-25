extends Sprite2D
## 默认角色的待机、眨眼和走路动画；自定义贴图仍保留原两帧眨眼逻辑。
##
## **美术换角色改场景里 Sprite 的 texture（或调 set_art），不要改这个脚本里的常量。**
## 睁眼帧 = 场景里给的贴图；闭眼帧 = blink_texture（不填就用内置的 blink.png）。
## 之前这里每帧硬写 texture = 常量，导致「把新 png 拖到 Sprite 上」完全没反应。

const DEFAULT_OPEN = preload("res://assets/actors/office_character/idle.png")
const DEFAULT_BLINK = preload("res://assets/actors/office_character/blink.png")
const IDLE_FRAMES = [
	preload("res://assets/actors/office_character/idle_01.png"),
	preload("res://assets/actors/office_character/idle_02.png"),
	preload("res://assets/actors/office_character/idle_03.png"),
	preload("res://assets/actors/office_character/idle_04.png"),
]
const IDLE_CENTER_X = [220.0, 220.0, 215.0, 215.0]
const WALK_FRAMES = [
	preload("res://assets/actors/office_character/walk_01.png"),
	preload("res://assets/actors/office_character/walk_02.png"),
	preload("res://assets/actors/office_character/walk_03.png"),
	preload("res://assets/actors/office_character/walk_04.png"),
	preload("res://assets/actors/office_character/walk_05.png"),
	preload("res://assets/actors/office_character/walk_06.png"),
]
const WALK_CENTER_X = [220.0, 220.0, 210.0, 230.0, 230.0, 220.0]
const WALK_VISIBLE_HEIGHT = [410.0, 400.0, 410.0, 400.0, 400.0, 410.0]
const JUMP_FRAMES = [
	preload("res://assets/actors/office_character/jump_01.png"),
	preload("res://assets/actors/office_character/jump_02.png"),
	preload("res://assets/actors/office_character/jump_03.png"),
	preload("res://assets/actors/office_character/jump_04.png"),
	preload("res://assets/actors/office_character/jump_05.png"),
	preload("res://assets/actors/office_character/jump_06.png"),
	preload("res://assets/actors/office_character/jump_07.png"),
	preload("res://assets/actors/office_character/jump_08.png"),
	preload("res://assets/actors/office_character/jump_09.png"),
]
# 原图自身也画了腾空位移；固定缩放，以躯干中心和靴底对齐物理角色。
const JUMP_ANCHORS = [
	Vector2(210, 480), Vector2(210, 470), Vector2(198, 420),
	Vector2(209, 420), Vector2(220, 450), Vector2(224, 470),
	Vector2(264, 480), Vector2(266, 480), Vector2(267, 480),
]

@export var blink_texture: Texture2D
@export var echo_tint := false
@export var blink_interval := 3.0
@export var blink_duration := 0.15
@export var walk_fps := 7.0
## 44 单位碰撞高度对应 48 单位外观，底部对齐（头发/装饰允许伸出碰撞框）。
@export var visual_height_ratio := 48.0 / 44.0

var _open: Texture2D
var _blink: Texture2D
var elapsed := 0.0
var _walk_time := 0.0
var _airborne := false
var _show_landing := false
var _landing_time := 0.0
var _body_size := Vector2(32, 44)

func _ready() -> void:
	_open = texture if texture != null else DEFAULT_OPEN
	if blink_texture != null:
		_blink = blink_texture
	elif _open == DEFAULT_OPEN:
		_blink = DEFAULT_BLINK
	else:
		_blink = _open  # 自定义美术没给闭眼帧：不眨眼，保持这一张
	texture = _open
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if echo_tint:
		self_modulate = Color(0.6, 0.9, 1.0, 0.55)


## 运行时换皮（联调 / 同一角色换装）：一次给两帧，不带 blink 就是不眨眼。
## 换完记得让宿主再调一次 fit_visuals()，尺寸不会停在旧图上。
func set_art(open_art: Texture2D, blink_art: Texture2D = null) -> void:
	_open = open_art if open_art != null else DEFAULT_OPEN
	_blink = blink_art if blink_art != null else _open
	texture = _open
	elapsed = 0.0
	_walk_time = 0.0
	_reset_jump_pose()


## 把外观缩放到碰撞体：高度 = body.y × visual_height_ratio，宽度按贴图自己的长宽比，脚底对齐。
## 缩放以「当前睁眼贴图」为基准，所以换任意尺寸的图都只是外观变化，判定仍由 body_size 决定。
func fit_to_body(body: Vector2) -> void:
	_body_size = body
	if _open == DEFAULT_OPEN:
		_show_default_frame(IDLE_FRAMES[0], IDLE_CENTER_X[0], 420.0)
		return
	var tex := _open if _open != null else texture
	if tex == null:
		return
	var texture_height := float(tex.get_height())
	if texture_height <= 0.0:
		return
	var visual_height := body.y * visual_height_ratio
	var ratio := visual_height / texture_height
	scale = Vector2(ratio, ratio)
	position = Vector2((body.x - tex.get_width() * ratio) * 0.5, body.y - visual_height)


func _show_default_frame(frame: Texture2D, center_x: float, visible_height: float) -> void:
	texture = frame
	var ratio := _body_size.y * visual_height_ratio / visible_height
	scale = Vector2.ONE * ratio
	var center := 400.0 - center_x if flip_h else center_x
	position = Vector2(_body_size.x * 0.5 - center * ratio, _body_size.y - 480.0 * ratio)


func _reset_jump_pose() -> void:
	_airborne = false
	_show_landing = false
	_landing_time = 0.0


func _jump_frame(motor: CharacterBody2D, delta: float) -> int:
	if motor == null or motor.get("is_dead") or motor.get("climbing"):
		_reset_jump_pose()
		return -1
	if not motor.is_on_floor():
		var speed := motor.velocity.y / maxf(1.0, absf(float(motor.get("jump_velocity"))))
		# 重生后的第一帧还没更新地面接触，静止时先保留待机。
		if not _airborne and is_zero_approx(speed):
			return -1
		var taking_off := not _airborne and speed < -0.1
		_airborne = true
		_show_landing = _show_landing or absf(speed) > 0.18
		_landing_time = 0.0
		if taking_off: return 0
		if speed < -0.6: return 1
		if speed < -0.15: return 2
		if speed < 0.13: return 3
		if speed < 0.42: return 4
		if speed < 0.7: return 5
		return 6
	if _airborne and _show_landing:
		_landing_time = 0.10
	_airborne = false
	_show_landing = false
	if _landing_time <= 0.0:
		return -1
	_landing_time -= delta
	return 7 if _landing_time > 0.05 else 8


func _physics_process(delta: float) -> void:
	var moving := false
	var direction := 0.0
	var actor := get_parent()
	var motor := actor as CharacterBody2D
	if _open == DEFAULT_OPEN and actor is CharacterBody2D:
		direction = actor.velocity.x
		moving = not actor.get("is_dead") and actor.is_on_floor() and absf(direction) > 28.0
	elif _open == DEFAULT_OPEN and actor.is_in_group("echo"):
		motor = actor.animation_motor()
		var step: Vector2 = actor.get("last_delta")
		direction = step.x
		moving = absf(direction) > 0.4 and absf(step.y) < 0.8
	if _open == DEFAULT_OPEN:
		var jump_index := _jump_frame(motor, delta)
		if jump_index >= 0:
			_walk_time = 0.0
			if absf(direction) > 0.4:
				flip_h = direction < 0.0
			var frame: Texture2D = JUMP_FRAMES[jump_index]
			var anchor: Vector2 = JUMP_ANCHORS[jump_index]
			var ratio := _body_size.y * visual_height_ratio / 420.0
			var center := frame.get_width() - anchor.x if flip_h else anchor.x
			texture = frame
			scale = Vector2.ONE * ratio
			position = Vector2(_body_size.x * 0.5 - center * ratio, _body_size.y - anchor.y * ratio)
			return
	if moving:
		_walk_time += delta
		var index := int(_walk_time * walk_fps) % WALK_FRAMES.size()
		var frame: Texture2D = WALK_FRAMES[index]
		var face_left := direction < 0.0
		if texture != frame or flip_h != face_left:
			flip_h = face_left
			# 每帧可见像素范围略有不同；以脚底和身体中心对齐，避免换帧抖动。
			_show_default_frame(frame, WALK_CENTER_X[index], WALK_VISIBLE_HEIGHT[index])
		return
	if texture in WALK_FRAMES:
		_walk_time = 0.0
	if _open == DEFAULT_OPEN:
		elapsed = fmod(elapsed + delta, maxf(blink_interval, blink_duration + 0.1))
		var index: int = 1 if elapsed >= blink_interval - blink_duration else [0, 2, 3][int(elapsed) % 3]
		var frame: Texture2D = IDLE_FRAMES[index]
		if texture != frame:
			_show_default_frame(frame, IDLE_CENTER_X[index], 420.0)
		return
	if _open == null or _blink == _open:
		return
	elapsed = fmod(elapsed + delta, maxf(blink_interval, blink_duration + 0.1))
	var want: Texture2D = _blink if elapsed >= blink_interval - blink_duration else _open
	if texture != want:
		texture = want
