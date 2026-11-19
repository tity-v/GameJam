@tool
extends "res://scripts/puzzle_door.gd"

const ActorBounds = preload("res://scripts/actor_bounds.gd")
const PressurePlate = preload("res://scripts/pressure_plate.gd")
const Config = preload("res://graybox/db/editor.tres")

@export var safety_player: CharacterBody2D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not latch_open and safety_player == null:
		warnings.append(Config.safety_player_warning)
	if not _has_valid_plates():
		warnings.append(Config.plate_warning)
	return warnings


func _has_valid_plates() -> bool:
	if plate_paths.is_empty():
		return false
	for path in plate_paths:
		if not (get_node_or_null(path) is PressurePlate):
			return false
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _has_valid_plates():
		return
	if opened and not latch_open and safety_player != null:
		var area := global_transform * Rect2(Vector2.ZERO, block_size)
		if area.intersects(ActorBounds.rect(safety_player)):
			return
	super._physics_process(delta)
