@tool
extends "res://scripts/block.gd"

signal activation_changed(active: bool)
const Bounds = preload("res://scripts/actor_bounds.gd")
@export var accepts_player := true
@export var accepts_echo := true
var active := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 10

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressed := false
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in Bounds.actors(get_tree()):
		if actor.is_in_group("player") and not accepts_player:
			continue
		if actor.is_in_group("echo") and not accepts_echo:
			continue
		if not Bounds.available(actor):
			continue
		var body := Bounds.rect(actor)
		var feet := body.end.y
		if body.end.x > area.position.x and body.position.x < area.end.x and feet >= area.position.y - 8 and feet <= area.end.y + 4:
			pressed = true
			break
	if pressed != active:
		active = pressed
		$Patch.texture = load("res://assets/mechanisms/pressure_on.png" if active else "res://assets/mechanisms/pressure_off.png")
		activation_changed.emit(active)
