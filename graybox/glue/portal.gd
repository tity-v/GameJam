@tool
extends Node2D
const Actions = preload("res://graybox/glue/portal_actions.gd")
const Echo = preload("res://graybox/glue/component_echo.gd")
var recorded_open := false
@export var destination: Node2D
@export var switch_source: Node2D
@export var initially_enabled := true
@export var close_after_use := true
var enabled := true
var occupied: Dictionary = {}
func _ready() -> void:
	reset_mechanism()
	if not Engine.is_editor_hint():
		process_physics_priority = 25
		add_to_group("mechanism")
func reset_mechanism() -> void:
	enabled = initially_enabled
	occupied.clear()
func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint(): return
	recorded_open = enabled and is_instance_valid(destination) and destination != self and (switch_source == null or Echo.switch_on(switch_source))
	$Face.modulate.a = 1.0 if recorded_open else 0.25
	var target := destination.global_position if destination else Vector2.ZERO
	if Actions.transfer(self, recorded_open, target, destination, occupied, close_after_use) and close_after_use:
		enabled = false

func mark_arrival(id: int) -> void:
	occupied[id] = true

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if destination == null or destination == self:
		warnings.append("选择一个目标标记或另一扇传送门。")
	if switch_source and not "active" in switch_source:
		warnings.append("开关应绑定拉杆或压力板。")
	return warnings
