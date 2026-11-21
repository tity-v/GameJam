extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	for manager in get_tree().get_nodes_in_group("graybox_trail_adapter"):
		if manager.activate_checkpoint(self, body):
			return

func set_lit(active: bool) -> void:
	$Flag.color = Color("#72e5b0") if active else Color("#f5b04d")