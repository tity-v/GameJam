@tool
extends "res://scripts/block.gd"

signal activation_changed(active: bool)
const Bounds = preload("res://scripts/actor_bounds.gd")
@export var accepts_player := true
@export var accepts_echo := true
var active := false

func _ready() -> void:
	super._ready()
	process_physics_priority = 10
	# 登记给 room_controller.reset_mechanisms() 统一复位（R 键）。
	# 编辑器里不登记：@tool 脚本的 _ready 在编辑器也会跑，避免把组写进场景。
	if not Engine.is_editor_hint():
		add_to_group("mechanism")
		activation_changed.connect(func(_on): get_node("/root/GameSfx").play("plate_%d" % randi_range(1,4)))

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressed := false
	var area := global_transform * Rect2(Vector2.ZERO, block_size)
	for actor in Bounds.actors(get_tree()):
		if actor.is_in_group("player") and not accepts_player:
			continue
		if actor.is_in_group("echo") and not accepts_echo:
			continue
		if not Bounds.available(actor):
			continue
		var body := Bounds.rect(actor)
		var feet := body.end.y
		if body.end.x > area.position.x and body.position.x < area.end.x and feet >= area.position.y - 8 and feet <= area.end.y + 4:
			pressed = true
			break
	if pressed != active:
		active = pressed
		$Patch.texture = load("res://assets/mechanisms/pressure_on.png" if active else "res://assets/mechanisms/pressure_off.png")
		activation_changed.emit(active)


## R 用：回到「从未被踩下」的初始状态。
## 下一物理帧仍会按场上角色重新判定，但 R 已经把玩家送回出生点、虚影也清空了，
## 所以不会刚复位又亮起来。
func reset_mechanism() -> void:
	if not active:
		return
	active = false
	$Patch.texture = load("res://assets/mechanisms/pressure_off.png")
	activation_changed.emit(false)
