extends RefCounted
const Bounds = preload("res://scripts/actor_bounds.gd")
static func transfer(portal: Node2D, usable: bool, target: Vector2, destination: Node2D, occupied: Dictionary, one_shot: bool) -> bool:
	var area := portal.global_transform * Rect2(Vector2(-16,-32),Vector2(32,64))
	var moved := false
	var actors := Bounds.actors(portal.get_tree())
	actors.append_array(portal.get_tree().get_nodes_in_group("graybox_box"))
	for actor in actors:
		var id := actor.get_instance_id()
		var body: Rect2 = actor.global_transform * Rect2(-actor.box_size / 2, actor.box_size) if actor.is_in_group("graybox_box") else Bounds.rect(actor)
		if not actor.is_in_group("graybox_box") and not Bounds.available(actor) or not area.intersects(body):
			occupied.erase(id)
			continue
		if not usable or occupied.has(id): continue
		var displacement := target - body.get_center()
		actor.global_position += displacement
		occupied[id] = true
		if is_instance_valid(destination) and destination.has_method("mark_arrival"):
			destination.mark_arrival(id)
			for ghost in destination.get_meta(&"graybox_portal_echoes", []):
				if is_instance_valid(ghost): ghost.mark_arrival(id)
		moved = true
		if one_shot: break
	return moved
