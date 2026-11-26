@tool
extends Node2D
## 仅绘制双扇门；碰撞仍由门节点统一控制。

const PANEL = preload("res://assets/mechanisms/door_closed.png")
var openness := 0.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_parent().block_size
	var half := size.x * 0.5
	var visible_half := half * (1.0 - openness)
	var source_size := PANEL.get_size()
	var source_half := source_size.x * 0.5
	if visible_half > 0.0:
		draw_texture_rect_region(PANEL, Rect2(0, 0, visible_half, size.y), Rect2(source_half * openness, 0, source_half * (1.0 - openness), source_size.y))
		draw_texture_rect_region(PANEL, Rect2(size.x - visible_half, 0, visible_half, size.y), Rect2(source_half, 0, source_half * (1.0 - openness), source_size.y))
	# 两侧收揽线始终留在原位，表明这里有门框。
	draw_line(Vector2(0, 0), Vector2(0, size.y), Color("#283341"), 2.0)
	draw_line(Vector2(size.x, 0), size, Color("#283341"), 2.0)
	if openness < 1.0:
		draw_line(Vector2(half, 0), Vector2(half, size.y), Color("#263443"), 1.0)
