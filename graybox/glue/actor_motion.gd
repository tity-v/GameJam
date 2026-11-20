extends RefCounted
## 虚影即使被物体挡住，也会按记录的方向继续施力。
static func horizontal(actor: Node2D, dt: float) -> float:
	if actor.is_in_group("echo"):
		var index: int = actor.frame_index
		if index <= 0: return 0.0
		return (actor.frames[index].x - actor.frames[index-1].x) / dt
	return Input.get_axis("move_left", "move_right") * actor.max_speed
