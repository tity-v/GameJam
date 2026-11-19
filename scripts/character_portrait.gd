extends Sprite2D
## 两帧待机眨眼，使用原始透明贴图并保持长宽比。
const OPEN = preload("res://assets/actors/office_character/idle.png")
const BLINK = preload("res://assets/actors/office_character/blink.png")
@export var echo_tint := false
@export var blink_interval := 3.0
@export var blink_duration := 0.15
## 44 单位碰撞高度对应 48 单位外观，底部对齐。
@export var visual_height_ratio := 48.0 / 44.0
var elapsed := 0.0

func _ready() -> void:
	texture = OPEN
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if echo_tint:
		self_modulate = Color(0.6, 0.9, 1.0, 0.55)

func fit_to_body(body: Vector2) -> void:
	var visual_height := body.y * visual_height_ratio
	var ratio := visual_height / OPEN.get_height()
	scale = Vector2(ratio, ratio)
	position = Vector2((body.x - OPEN.get_width() * ratio) * 0.5, body.y - visual_height)

func _physics_process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, maxf(blink_interval, blink_duration + 0.1))
	texture = BLINK if elapsed >= blink_interval - blink_duration else OPEN
