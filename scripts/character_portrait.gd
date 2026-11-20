extends Sprite2D
## 两帧待机眨眼。
##
## **美术换角色改场景里 Sprite 的 texture（或调 set_art），不要改这个脚本里的常量。**
## 睁眼帧 = 场景里给的贴图；闭眼帧 = blink_texture（不填就用内置的 blink.png）。
## 之前这里每帧硬写 texture = 常量，导致「把新 png 拖到 Sprite 上」完全没反应。

const DEFAULT_OPEN = preload("res://assets/actors/office_character/idle.png")
const DEFAULT_BLINK = preload("res://assets/actors/office_character/blink.png")

@export var blink_texture: Texture2D
@export var echo_tint := false
@export var blink_interval := 3.0
@export var blink_duration := 0.15
## 44 单位碰撞高度对应 48 单位外观，底部对齐（头发/装饰允许伸出碰撞框）。
@export var visual_height_ratio := 48.0 / 44.0

var _open: Texture2D
var _blink: Texture2D
var elapsed := 0.0

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


## 把外观缩放到碰撞体：高度 = body.y × visual_height_ratio，宽度按贴图自己的长宽比，脚底对齐。
## 缩放以「当前睁眼贴图」为基准，所以换任意尺寸的图都只是外观变化，判定仍由 body_size 决定。
func fit_to_body(body: Vector2) -> void:
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


func _physics_process(delta: float) -> void:
	if _open == null or _blink == _open:
		return
	elapsed = fmod(elapsed + delta, maxf(blink_interval, blink_duration + 0.1))
	var want: Texture2D = _blink if elapsed >= blink_interval - blink_duration else _open
	if texture != want:
		texture = want
