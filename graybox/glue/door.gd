@tool
extends "res://scripts/puzzle_door.gd"

const PressurePlate = preload("res://scripts/pressure_plate.gd")
const Config = preload("res://graybox/db/editor.tres")
const Bounds = preload("res://scripts/actor_bounds.gd")

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
		var source := get_node_or_null(path)
		if source == null or not "active" in source:
			return false
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _has_valid_plates():
		return
	var satisfied := true
	for path in plate_paths:
		if not preload("res://graybox/glue/component_echo.gd").switch_on(get_node_or_null(path)):
			satisfied = false
			break
	if opened != satisfied:
		if not satisfied and _player_in_doorway():
			return
		opened = satisfied
		$Collision.set_deferred("disabled", opened)
		$Patch.texture = preload("res://assets/mechanisms/door_open.png") if opened else preload("res://assets/mechanisms/door_closed.png")


## 关门前先看门口有没有活着的玩家：有就保持开门，等人走出去再关。
## 门是「松开任一压板就关」，代价是可能正好关在玩家身上——玩家一旦和门的碰撞体重叠，
## 横向完全推不动，只能按 R 脱身。只认玩家组、不认虚影：虚影是回放出来的，被门关住只是卡一下，
## 而若让虚影也能顶门，一条停在门口的轨迹会把门永久撑开。
func _player_in_doorway() -> bool:
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			return true
	return false
