@tool
extends Node2D
## 物块通用脚本：一块可九宫格拉伸的贴图 + 可选碰撞体。
##
## 尺寸只有一个来源：**block_size**。
## 改它，贴图（Patch.size）和碰撞（Collision.shape.size + 居中偏移）一起跟着变，
## 所以美术再也不用画准最终像素尺寸，策划也不用自己算碰撞框的位置。
##
## 贴图用 NinePatchRect（九宫格）/ TextureRect（平铺），边角不随拉伸变形：
## 实心块的顶部亮线永远 3px，出口的边框永远 3px。

@export var block_size: Vector2 = Vector2(64, 64):
	set(value):
		block_size = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	# 场景加载时属性先于子节点就绪，这里等到进树后再统一同步一次
	if not is_inside_tree():
		return

	var patch := get_node_or_null("Patch") as Control
	if patch != null and not patch.size.is_equal_approx(block_size):
		patch.size = block_size

	var col := get_node_or_null("Collision") as CollisionShape2D
	if col == null:
		return
	# 碰撞体保持「左上角对齐本节点」，和原版 Rect2(x, y, w, h) 的坐标约定一致
	col.position = block_size * 0.5
	var rect := col.shape as RectangleShape2D
	if rect != null and not rect.size.is_equal_approx(block_size):
		rect.size = block_size
