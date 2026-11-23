extends "res://scripts/echo_manager.gd"

var _checkpoint: Area2D
var _room_spawn := Vector2.ZERO

func activate_checkpoint(point: Area2D, actor: Node2D) -> bool:
	var is_player := actor == _player
	var is_echo: bool = actor.is_in_group("echo") and actor.has_method("is_active") and actor.is_active()
	if not (is_player or is_echo) or not _recording or _player.is_dead:
		return false
	if point == _checkpoint:
		return true
	if is_instance_valid(_checkpoint):
		_checkpoint.set_lit(false)
	else:
		_room_spawn = _player.respawn_position
	_checkpoint = point
	point.set_lit(true)
	get_node("/root/GameSfx").play("checkpoint")
	# 使用接触旗帜时的实际站位，保留这段轨迹与后续机关的空间对齐。
	_player.respawn_position = actor.global_position
	pin_start = true
	# 虚影触旗不截断本体录像，否则回放瞬移。
	if is_player:
		_trail.clear()
	return true

func reset_all() -> void:
	if is_instance_valid(_checkpoint):
		_checkpoint.set_lit(false)
		_player.respawn_position = _room_spawn
		_checkpoint = null
	pin_start = false
	super.reset_all()
