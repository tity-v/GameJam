@tool
extends "res://scripts/room_controller.gd"

const Config = preload("res://graybox/db/editor.tres")

@export var spawn_point: Marker2D
@export var player: CharacterBody2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if spawn_point != null and spawn_point.is_in_group("respawn_point") and player != null:
		player.set("respawn_position", spawn_point.global_position)
		player.call("reset_to_spawn")
	super._ready()
	var markers := Node2D.new()
	markers.set_script(preload("res://graybox/view/link_markers.gd"))
	markers.add_to_group("pause_keep_color")
	add_child(markers)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if spawn_point == null or not spawn_point.is_in_group("respawn_point"):
		warnings.append(Config.spawn_warning)
	if player == null:
		warnings.append(Config.player_warning)
	return warnings
