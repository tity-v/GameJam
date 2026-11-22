@tool
extends "res://scripts/level_exit.gd"

func _ready() -> void:
	super._ready()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var door := get_node_or_null(door_path) if not door_path.is_empty() else null
	active = door == null and door_path.is_empty() or door != null and door.get("opened") == true
	$Patch.texture = preload("res://assets/mechanisms/exit_active.png") if active else preload("res://assets/mechanisms/exit_inactive.png")
	if not active:
		return
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			get_tree().current_scene.complete()
