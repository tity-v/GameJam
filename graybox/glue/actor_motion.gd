extends RefCounted
## 读取操作意图，贴墙后仍然能够推箱或拨杆。
static func horizontal(actor: Node2D, _dt: float) -> float:
	if actor.is_in_group("echo"):
		return actor.horizontal_intent()
	return Input.get_axis("move_left", "move_right") * actor.max_speed
