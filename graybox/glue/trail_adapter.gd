extends "res://scripts/echo_manager.gd"

var portal_offset := Vector2.ZERO
var _checkpoint: Area2D
var _room_spawn := Vector2.ZERO

func activate_checkpoint(point: Area2D, actor: Node2D) -> bool:
	if actor != _player or not _recording or _player.is_dead:
		return false
	if point == _checkpoint:
		return true
	if is_instance_valid(_checkpoint):
		_checkpoint.set_lit(false)
	else:
		_room_spawn = _player.respawn_position
	_checkpoint = point
	point.set_lit(true)
	# 使用接触旗帜时的实际站位，保留这段轨迹与后续机关的空间对齐。
	_player.respawn_position = actor.global_position
	portal_offset = Vector2.ZERO
	_trail = PackedVector2Array([actor.global_position])
	return true

func exclude_jump(displacement: Vector2) -> void:
	portal_offset += displacement

func _physics_process(dt: float) -> void:
	# 存档后的录像保留起点。到达帧数上限时仍然播放已有虚影。
	var capped := is_instance_valid(_checkpoint) and _recording and _trail.size() >= max_frames
	if capped:
		_recording = false
	var recorded := _recording and _player != null
	super._physics_process(dt)
	if capped:
		_recording = true
	if recorded and not _trail.is_empty():
		_trail[-1] -= portal_offset

func reset_all() -> void:
	if is_instance_valid(_checkpoint):
		_checkpoint.set_lit(false)
		_player.respawn_position = _room_spawn
		_checkpoint = null
	portal_offset = Vector2.ZERO
	super.reset_all()

func _on_player_respawned() -> void:
	portal_offset = Vector2.ZERO
	super._on_player_respawned()
	if is_instance_valid(_checkpoint):
		_trail.append(_player.global_position)