extends "res://scripts/echo_manager.gd"
var portal_offset := Vector2.ZERO
func exclude_jump(displacement: Vector2) -> void:
	portal_offset += displacement
func _physics_process(dt: float) -> void:
	var recorded := _recording and _player != null
	super._physics_process(dt)
	if recorded and not _trail.is_empty():
		_trail[-1] -= portal_offset
func reset_all() -> void:
	portal_offset = Vector2.ZERO
	super.reset_all()
func _on_player_respawned() -> void:
	portal_offset = Vector2.ZERO
	super._on_player_respawned()
