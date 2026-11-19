@tool
extends "res://scripts/level_exit.gd"

func _ready() -> void:
	super._ready()
	active = true
	$Patch.texture = preload("res://assets/mechanisms/exit_active.png")

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			get_tree().current_scene.complete()
