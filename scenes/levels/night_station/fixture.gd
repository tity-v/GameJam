@tool
extends Node2D
## 站台地标。所有图案都在角色与地形后方，不参与碰撞。
@export_enum("候车长椅", "折返标", "升降井刻度", "货台窗列") var kind := 0:
	set(value):
		kind = value
		queue_redraw()
@export_range(32, 640, 1) var span := 96:
	set(value):
		span = value
		queue_redraw()

const FRAME := Color("#38355f")
const EDGE := Color("#695884")
const GLASS := Color("#373458")

func _draw() -> void:
	match kind:
		0:
			draw_rect(Rect2(-28, -23, 60, 8), EDGE)
			draw_rect(Rect2(-30, -12, 64, 5), EDGE)
			for x in [-23, 24]:
				draw_rect(Rect2(x, -22, 4, 22), FRAME)
		1:
			draw_rect(Rect2(-3, -42, 4, 42), FRAME)
			draw_rect(Rect2(-19, -50, 34, 20), FRAME)
			draw_polyline(PackedVector2Array([Vector2(8,-46), Vector2(8,-39), Vector2(-9,-39), Vector2(-5,-43)]), EDGE, 2)
			draw_line(Vector2(-9,-39),Vector2(-5,-35),EDGE,2)
		2:
			for x in [-20, 20]:
				draw_rect(Rect2(x, 0, 3, span), FRAME)
			for y in range(0, span, 32):
				draw_rect(Rect2(-20,y,10,2), EDGE)
				draw_rect(Rect2(14,y,8,2), EDGE)
		3:
			for x in range(0, span-27, 44):
				draw_rect(Rect2(x, -90, 28, 40), FRAME)
				draw_rect(Rect2(x+3, -87, 22, 34), GLASS)
				draw_line(Vector2(x+14,-87),Vector2(x+14,-53),FRAME,2)
				draw_line(Vector2(x+3,-70),Vector2(x+25,-70),FRAME,2)
