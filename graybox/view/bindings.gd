@tool
extends Node2D
const CFG = preload("res://graybox/db/mechanisms.tres")
func _ready() -> void:
	set_process(Engine.is_editor_hint())
func _process(_dt: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var source := get_parent()
	if source.has_method("route_start") and source.has_method("route_end"):
		var a := to_local(source.route_start())
		var b := to_local(source.route_end())
		if not a.is_equal_approx(b):
			draw_line(a, b, CFG.binding_color, 1.0, true)
		draw_circle(a, 3.0, CFG.binding_color)
		draw_arc(b, 5.0, 0.0, TAU, 16, CFG.binding_color, 1.0, true)
	for key in [&"plate_paths", &"destination", &"switch_source"]:
		if not key in source:
			continue
		var links = source.get(key)
		for link in (links if links is Array else [links]):
			var target = source.get_node_or_null(link) if link is NodePath and not link.is_empty() else link
			if target is Node2D:
				draw_line(Vector2.ZERO, to_local(target.global_position), CFG.binding_color, 1.0, true)
