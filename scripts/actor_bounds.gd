extends RefCounted
## 机关使用完整身体范围，Echo 的头顶薄片仅负责被玩家踩。

static func actors(tree: SceneTree) -> Array[Node]:
	var result: Array[Node] = tree.get_nodes_in_group("player")
	result.append_array(tree.get_nodes_in_group("echo"))
	return result

static func available(actor: Node2D) -> bool:
	if not actor.is_visible_in_tree():
		return false
	if actor.is_in_group("player"):
		return not actor.is_dead
	return not actor.is_gone()

static func rect(actor: Node2D) -> Rect2:
	if actor.is_in_group("player"):
		var collision := actor.get_node("Collision") as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		return actor.global_transform * Rect2(collision.position - shape.size / 2, shape.size)
	var body := actor.get_node("Body") as Sprite2D
	return body.global_transform * body.get_rect()
