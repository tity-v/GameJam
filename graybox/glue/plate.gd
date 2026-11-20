@tool
extends "res://scripts/pressure_plate.gd"
@export var accepts_boxes := true
func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint(): return
	if accepts_boxes:
		var area := global_transform * Rect2(Vector2.ZERO, block_size)
		for box in get_tree().get_nodes_in_group("graybox_box"):
			var body: Rect2 = box.global_transform * Rect2(-box.box_size/2, box.box_size)
			if body.end.x > area.position.x and body.position.x < area.end.x and body.end.y >= area.position.y-1 and body.end.y <= area.end.y+1:
				if not active:
					active = true
					$Patch.texture = preload("res://assets/mechanisms/pressure_on.png")
					activation_changed.emit(true)
				return
	super._physics_process(dt)
