@tool
extends "res://scripts/block.gd"

## 全向实体阻挡各个方向；单向地形允许从下方穿过，在顶面落脚。
@export_enum("全向实体", "单向顶面") var collision_mode: int = 0:
	set(value):
		collision_mode = value
		if is_node_ready():
			$Collision.one_way_collision = collision_mode == 1

func _ready() -> void:
	super._ready()
	$Collision.one_way_collision = collision_mode == 1
