extends RefCounted
## 机关使用完整身体范围，Echo 的头顶薄片仅负责被玩家踩。
##
## 两条硬规则（改之前先看 echo.gd / player.gd 的注释）：
##   1. **判定尺寸不读贴图**。玩家取 Collision shape，虚影取 body_size；
##      美术换图只影响外观，不能改变"刚好踩不踩得到"。
##   2. **虚影只看 is_active() 一个状态**，不看 visible：
##      visible 只是表现，拿它当判定依据会出现"看不见但压力板亮了"。

static func actors(tree: SceneTree) -> Array[Node]:
	var result: Array[Node] = tree.get_nodes_in_group("player")
	result.append_array(tree.get_nodes_in_group("echo"))
	return result

static func available(actor: Node2D) -> bool:
	if actor.is_in_group("player"):
		return not actor.is_dead and actor.is_visible_in_tree()
	if actor.has_method("is_active"):
		return bool(actor.call("is_active"))
	if actor.has_method("is_gone"):
		return not bool(actor.call("is_gone")) and actor.is_visible_in_tree()
	return actor.is_visible_in_tree()

static func rect(actor: Node2D) -> Rect2:
	if actor.is_in_group("player"):
		var collision := actor.get_node("Collision") as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		return actor.global_transform * Rect2(collision.position - shape.size / 2, shape.size)
	# 虚影：用脚本的 body_size，**不要**读 Body 贴图矩形 ——
	# 否则美术多留 2px 透明边，压力板判定范围就跟着变大。
	if actor.has_method("body_rect"):
		return actor.call("body_rect")
	var body := actor.get_node("Body") as Sprite2D
	return body.global_transform * body.get_rect()
