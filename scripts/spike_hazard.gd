@tool
extends "res://scripts/block.gd"

const Bounds = preload("res://scripts/actor_bounds.gd")

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 尖刺上半部为伤害区，底座不判伤害。Echo 沿用录下的死亡时机。
	var area := global_transform * Rect2(Vector2(3, 4), Vector2(maxf(1, block_size.x - 6), maxf(1, block_size.y - 8)))
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			actor.die()
