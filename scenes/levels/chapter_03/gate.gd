extends StaticBody2D
## 3-1 的铁栅。
##
## 它不是机关，是「预告」：玩家不需要操作，只要看见「那团青光经过的地方，
## 一吨半的铁栅自己起来了」。所以它必须挡人——不挡人的话，门升起这件事
## 对玩家就没有意义，玩家会直接从它身上走过去。
##
## 时序：虚影走到 stop_x 时调 open() → Tween 1.4s 把栅栏抬进黑暗 → 抬完才撤碰撞。
## 1.4s 是刻意的，快于此就变成「咔一下开了」，少了「有什么东西在动」的那段。

@export var gate_width := 32.0
@export var gate_height := 128.0
@export var bar_count := 4

var opened := false
var lift := 0.0

const IRON := Color("#3b4a46")
const EDGE := Color("#6d8078")
const RUST := Color("#8a6446")
## 三道横梁在门高上的位置（0=顶端 1=底端）
const CROSSBARS := [0.02, 0.44, 0.93]

var _solid: CollisionShape2D


func _ready() -> void:
	_solid = get_node_or_null("Solid") as CollisionShape2D


func open() -> void:
	if opened:
		return
	opened = true
	var t := create_tween()
	t.tween_method(_set_lift, 0.0, 200.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_release)


func _release() -> void:
	if _solid != null:
		_solid.set_deferred("disabled", true)


func _set_lift(value: float) -> void:
	lift = value
	queue_redraw()


func _draw() -> void:
	# 原点在门底（贴着台面），所以门体画在 -gate_height..0，升起时再往上推 lift。
	# 别把这里的变量叫 top：下面循环里同名会遮蔽外层，`top + ...` 就会读到自己。
	var board_top := -gate_height - lift
	var step := gate_width / float(maxi(bar_count, 1))
	for i in bar_count:
		var x := (i + 0.22) * step
		draw_rect(Rect2(x, board_top, step * 0.56, gate_height), IRON)
		draw_rect(Rect2(x, board_top, step * 0.16, gate_height), EDGE)
	for ratio in CROSSBARS:
		draw_rect(Rect2(0.0, board_top + gate_height * ratio, gate_width, 5.0), EDGE)
	draw_rect(Rect2(0.0, board_top + gate_height - 12.0, gate_width, 12.0), RUST)
