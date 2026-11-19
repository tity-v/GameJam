@tool
extends "res://scripts/block.gd"

@export var plate_paths: Array[NodePath] = []
@export var latch_open := true
var opened := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 20

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or (opened and latch_open):
		return
	var satisfied := not plate_paths.is_empty()
	for path in plate_paths:
		var plate := get_node_or_null(path)
		if plate == null or not plate.active:
			satisfied = false
	if satisfied != opened:
		opened = satisfied
		$Collision.set_deferred("disabled", opened)
		$Patch.texture = load("res://assets/mechanisms/door_open.png" if opened else "res://assets/mechanisms/door_closed.png")
