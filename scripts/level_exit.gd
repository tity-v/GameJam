@tool
extends "res://scripts/block.gd"

const Bounds = preload("res://scripts/actor_bounds.gd")
@export var door_path: NodePath
var active := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 30

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var door := get_node_or_null(door_path)
	active = door != null and door.get("opened") == true
	$Patch.texture = load("res://assets/mechanisms/exit_active.png" if active else "res://assets/mechanisms/exit_inactive.png")
	if not active:
		return
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			var level := get_tree().current_scene
			if level != null and level.has_method("complete"):
				level.complete()
