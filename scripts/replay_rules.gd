extends RefCounted
## 玩家虚影、机关虚影以及它们的实体碰撞体共用此分组和墙层。
const GROUP := &"replay_ghost"
const WALL_LAYER := 4
const WALL_MASK := 1 << (WALL_LAYER - 1)

static func mark_ghost(body: PhysicsBody2D) -> void:
	body.add_to_group(GROUP)
	body.set_collision_mask_value(WALL_LAYER, false)
