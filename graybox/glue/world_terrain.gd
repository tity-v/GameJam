extends TileMapLayer
## 地形图块负责连边和绘制。反向判定需要旋转碰撞体，图集翻转不会反转单向法线。

var reverse_body: StaticBody2D
var rebuild_queued := false

func _ready() -> void:
	queue_reverse_collision()

func _update_cells(_cells: Array[Vector2i], _forced_cleanup: bool) -> void:
	if is_inside_tree() and (is_instance_valid(reverse_body) or tile_set != null and tile_set.has_meta(&"reverse_platform_source")):
		queue_reverse_collision()

func queue_reverse_collision() -> void:
	if rebuild_queued:
		return
	rebuild_queued = true
	rebuild_reverse_collision.call_deferred()

func rebuild_reverse_collision() -> void:
	rebuild_queued = false
	if is_instance_valid(reverse_body):
		remove_child(reverse_body)
		reverse_body.queue_free()
	if not is_inside_tree() or not enabled or not collision_enabled or tile_set == null:
		return
	var source_id := int(tile_set.get_meta(&"reverse_platform_source", -1))
	if source_id < 0:
		return
	var cells := get_used_cells_by_id(source_id)
	if cells.is_empty():
		return
	var layer_index := 0
	var tile_size_px := Vector2(tile_set.tile_size)
	var slab := RectangleShape2D.new()
	slab.size = Vector2(tile_size_px.x, 8.0)
	var bottom_strip := Vector2(0.0, (tile_size_px.y - slab.size.y) * 0.5)
	reverse_body = StaticBody2D.new()
	reverse_body.collision_layer = tile_set.get_physics_layer_collision_layer(layer_index)
	reverse_body.collision_mask = tile_set.get_physics_layer_collision_mask(layer_index)
	for cell in cells:
		var collision := CollisionShape2D.new()
		collision.shape = slab
		collision.position = map_to_local(cell) + bottom_strip
		collision.rotation = PI
		collision.one_way_collision = true
		reverse_body.add_child(collision)
	add_child(reverse_body)
