extends Marker2D

func _ready() -> void:
	apply_spawn.call_deferred()

func apply_spawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_to_spawn"):
		player.respawn_position = to_global(Vector2(-16, -28))
		player.reset_to_spawn()
