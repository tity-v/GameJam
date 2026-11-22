extends "res://graybox/glue/box.gd"

func _ready() -> void:
	resize()
	preload("res://scripts/replay_rules.gd").mark_ghost(self)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	apply_push(state,push_action)
