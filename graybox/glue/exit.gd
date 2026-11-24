@tool
extends "res://scripts/level_exit.gd"

const PuzzleDoor = preload("res://scripts/puzzle_door.gd")
const Config = preload("res://graybox/db/editor.tres")


func _get_configuration_warnings() -> PackedStringArray:
	if not door_path.is_empty() and not (get_node_or_null(door_path) is PuzzleDoor):
		return [Config.exit_warning]
	return []
