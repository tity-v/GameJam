@tool
extends "res://scripts/puzzle_door.gd"

const PressurePlate = preload("res://scripts/pressure_plate.gd")
const Config = preload("res://graybox/db/editor.tres")

@export var initially_open := false:
	set(value):
		initially_open = value
		if is_node_ready() and Engine.is_editor_hint():
			_apply_open(value, true)
@export var slide_seconds := 0.28

func _ready() -> void:
	super._ready()
	_apply_open(initially_open, true)

func reset_mechanism() -> void:
	_apply_open(initially_open, true)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	$SlidingPanels.openness = move_toward($SlidingPanels.openness, 1.0 if opened else 0.0, delta / maxf(slide_seconds, 0.01))
	if not opened and is_zero_approx($SlidingPanels.openness):
		set("collision_layer", 1)
		$Collision.set_deferred("disabled", false)

func _apply_open(value: bool, instant := false) -> void:
	var changed := opened != value
	opened = value
	if changed and not Engine.is_editor_hint():
		get_node("/root/GameSfx").play("door_open" if opened else "door_close")
	if opened or instant:
		set("collision_layer", 0 if opened else 1)
		$Collision.set_deferred("disabled", opened)
	if instant:
		$SlidingPanels.openness = 1.0 if opened else 0.0
	$Patch.texture = preload("res://assets/mechanisms/door_open.png")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not _has_valid_plates() and not (initially_open and plate_paths.is_empty()):
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
	var desired_open := not initially_open if satisfied else initially_open
	if opened != desired_open:
		if not desired_open and _player_in_doorway():
			return
		_apply_open(desired_open)


## 关门前先看门口有没有活着的玩家：有就保持开门，等人走出去再关。
## 门是「松开任一压板就关」，代价是可能正好关在玩家身上——玩家一旦和门的碰撞体重叠，
## 横向完全推不动，只能按 R 脱身。只认玩家组、不认虚影：虚影是回放出来的，被门关住只是卡一下，
## 而若让虚影也能顶门，一条停在门口的轨迹会把门永久撑开。
func _player_in_doorway() -> bool:
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			return true
	for box in get_tree().get_nodes_in_group("graybox_box"):
		if area.intersects(box.global_transform * Rect2(-box.box_size / 2, box.box_size)):
			return true
	return false
