@tool
extends "res://scripts/block.gd"

@export var plate_paths: Array[NodePath] = []
var opened := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 20
	if not Engine.is_editor_hint():
		add_to_group("mechanism")

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
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


## R 用：同步关门状态、外观和碰撞。
func reset_mechanism() -> void:
	if not opened:
		return
	opened = false
	$Collision.set_deferred("disabled", false)
	$Patch.texture = load("res://assets/mechanisms/door_closed.png")
