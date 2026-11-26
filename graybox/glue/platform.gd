@tool
extends AnimatableBody2D
const CFG = preload("res://graybox/db/mechanisms.tres")

## 未指定起点时，从摆放位置出发。
@export var start_point: Node2D
## 指定终点标记后优先使用标记的位置。
@export var end_point: Node2D
## 相对起点的偏移，单位为平台父节点的像素。
@export var end_offset := Vector2(160, 0)
## 0 使用数据库默认速度。
@export var speed_override := 0.0
## 将相位对齐到玩家的每轮录制起点。
@export var restart_on_respawn := false
var distance := 0.0
var placed_position := Vector2.ZERO

func _ready() -> void:
	placed_position = position
	if not Engine.is_editor_hint():
		add_to_group("mechanism")
		reset_mechanism()
		if restart_on_respawn:
			var player := get_tree().get_first_node_in_group("player")
			if player != null:
				player.respawned.connect(reset_mechanism)

func route_start() -> Vector2:
	if start_point:
		return start_point.global_position
	if Engine.is_editor_hint():
		return global_position
	return get_parent().to_global(placed_position) if get_parent() is Node2D else placed_position

func route_end() -> Vector2:
	if end_point:
		return end_point.global_position
	var parent := get_parent() as Node2D
	var origin := route_start()
	return parent.to_global(parent.to_local(origin) + end_offset) if parent else origin + end_offset

func speed() -> float:
	return speed_override if speed_override > 0 else CFG.platform_speed

func reset_mechanism() -> void:
	distance = 0.0
	global_position = route_start()

func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint() or invalid_marker(start_point) or invalid_marker(end_point):
		return
	var a := route_start()
	var b := route_end()
	var length := a.distance_to(b)
	if is_zero_approx(length):
		return
	distance = fposmod(distance + speed() * dt, length * 2)
	var next := a.lerp(b, pingpong(distance, length) / length)
	if get_tree().has_group("echo_wall"):
		var sweep := PhysicsShapeQueryParameters2D.new()
		sweep.shape = $Collision.shape
		sweep.transform = $Collision.global_transform
		sweep.collision_mask = preload("res://scripts/replay_rules.gd").WALL_MASK
		sweep.motion = next - global_position
		var fraction := get_world_2d().direct_space_state.cast_motion(sweep)
		next = global_position.lerp(next, fraction[0])
	global_position = next

func invalid_marker(marker: Node2D) -> bool:
	return marker != null and (marker == self or is_ancestor_of(marker))

func _get_configuration_warnings() -> PackedStringArray:
	if invalid_marker(start_point) or invalid_marker(end_point):
		return ["端点不能跟随移动平台。请选择房间里的标记。"]
	if is_inside_tree() and route_start().is_equal_approx(route_end()):
		return ["起点与终点重合，平台将停在原地。"]
	return []
