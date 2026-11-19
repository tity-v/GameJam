@tool
extends Node2D

const Config = preload("res://graybox/db/editor.tres")

@export var patch: Control
@export var show_plate_feet_range := false


func _ready() -> void:
	if Engine.is_editor_hint() and patch != null:
		patch.resized.connect(queue_redraw)


func _draw() -> void:
	if not Engine.is_editor_hint() or patch == null:
		return
	var bounds := Rect2(Vector2.ZERO, patch.size)
	var color := Config.exit_outline_color
	if show_plate_feet_range:
		# 只复现共享压板判定的编辑器示意范围。
		bounds = bounds.grow_individual(0, Config.plate_feet_margin.x, 0, Config.plate_feet_margin.y)
		color = Config.plate_outline_color
	else:
		bounds = bounds.grow(Config.exit_outline_padding)
	draw_rect(bounds, color, false, Config.outline_width)
