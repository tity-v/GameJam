@tool
extends "res://scripts/puzzle_door.gd"

const PressurePlate = preload("res://scripts/pressure_plate.gd")
const Config = preload("res://graybox/db/editor.tres")

@export var safety_player: CharacterBody2D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
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
	super._physics_process(delta)
