extends Area2D

const Bounds = preload("res://scripts/actor_bounds.gd")

func _physics_process(_delta: float) -> void:
	var shape := $CollisionShape2D.shape as RectangleShape2D
	var area := Rect2(global_position + $CollisionShape2D.position - shape.size / 2, shape.size)
	for echo in get_tree().get_nodes_in_group("echo"):
		if Bounds.available(echo) and area.intersects(Bounds.rect(echo)):
			_activate(echo)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_activate(body)

func _activate(body: Node2D) -> void:
	for manager in get_tree().get_nodes_in_group("graybox_trail_adapter"):
		if manager.activate_checkpoint(self, body):
			return

func set_lit(active: bool) -> void:
	$Flag.color = Color("#72e5b0") if active else Color("#f5b04d")
