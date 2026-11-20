extends RefCounted
const Bounds = preload("res://scripts/actor_bounds.gd")
static func transfer(portal: Node2D, usable: bool, target: Vector2, destination: Node2D, occupied: Dictionary, one_shot: bool) -> bool:
	var area := portal.global_transform * Rect2(Vector2(-16,-32),Vector2(32,64))
	var moved := false
	for actor in Bounds.actors(portal.get_tree()):
		var id := actor.get_instance_id()
		if not Bounds.available(actor) or not area.intersects(Bounds.rect(actor)):
			occupied.erase(id)
			continue
		if not usable or occupied.has(id): continue
		var displacement := target - Bounds.rect(actor).get_center()
		actor.global_position += displacement
		occupied[id] = true
		if is_instance_valid(destination) and destination.has_method("mark_arrival"):
			destination.mark_arrival(id)
			for ghost in destination.get_meta(&"graybox_portal_echoes", []):
				if is_instance_valid(ghost): ghost.mark_arrival(id)
		if actor.is_in_group("player"):
			portal.get_tree().call_group("graybox_trail_adapter","exclude_jump",displacement)
		moved = true
		if one_shot: break
	return moved
