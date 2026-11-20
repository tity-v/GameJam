@tool
extends "res://scripts/block.gd"

const Bounds = preload("res://scripts/actor_bounds.gd")

@export var plate_paths: Array[NodePath] = []
var opened := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 20
	if not Engine.is_editor_hint():
		add_to_group("mechanism")

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var satisfied := not plate_paths.is_empty()
	for path in plate_paths:
		var plate := get_node_or_null(path)
		if plate == null or not plate.active:
			satisfied = false
	if satisfied == opened:
		return
	# 关门前先看一眼门口有没有人。
	# 门是「松开压板就关」，代价是可能正好关在玩家身上——而玩家一旦和门的碰撞体重叠，
	# 横向完全推不动（实测按住方向键 130 帧，x 一个像素都没变，y 在被上下挤），
	# 只能按 R 脱身。所以这里让关门等一等：保持开着，等人走出去再关。
	if not satisfied and _player_in_doorway():
		return
	opened = satisfied
	$Collision.set_deferred("disabled", opened)
	$Patch.texture = load("res://assets/mechanisms/door_open.png" if opened else "res://assets/mechanisms/door_closed.png")


## 门洞（就是这扇门的矩形）里是否站着活着的玩家。
## 只认玩家，不认虚影：虚影是回放出来的，被门关住只是看着卡住，不会造成软锁；
## 而如果让虚影也能顶住门，一条刚好停在门口的轨迹就能把门永久撑开。
func _player_in_doorway() -> bool:
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in get_tree().get_nodes_in_group("player"):
		if Bounds.available(actor) and area.intersects(Bounds.rect(actor)):
			return true
	return false


## R 用：同步关门状态、外观和碰撞。
## R 是硬关——调用前玩家已经被送回出生点，不需要再等门口空出来。
func reset_mechanism() -> void:
	if not opened:
		return
	opened = false
	$Collision.set_deferred("disabled", false)
	$Patch.texture = load("res://assets/mechanisms/door_closed.png")
