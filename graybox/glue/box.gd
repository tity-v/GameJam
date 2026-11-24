@tool
extends RigidBody2D
const Motion = preload("res://graybox/glue/actor_motion.gd")
const Bounds = preload("res://scripts/actor_bounds.gd")
const CFG = preload("res://graybox/db/mechanisms.tres")
@export var box_size := Vector2(40,40):
	set(value):
		box_size = value.max(Vector2.ONE)
		if is_node_ready(): resize()
var initial := Transform2D.IDENTITY
var resetting := false
var falling_speed := 0.0
var push_action := 0.0
var last_push_sound_ms := -1000
func resize() -> void:
	$Collision.shape.size = box_size
	var half := box_size / 2
	$Face.polygon = PackedVector2Array([-half, Vector2(half.x,-half.y), half, Vector2(-half.x,half.y)])
	mass = box_size.x * box_size.y * CFG.box_density
func _ready() -> void:
	set_collision_mask_value(preload("res://scripts/replay_rules.gd").WALL_LAYER, true)
	resize()
	initial = global_transform
	if not Engine.is_editor_hint(): add_to_group("mechanism")
func reset_mechanism() -> void:
	sleeping = false
	resetting = true
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint(): return
	if resetting:
		state.transform = initial
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		push_action = 0
		resetting = false
		return
	var body := Rect2(state.transform.origin - box_size / 2, box_size)
	var push_dir := 0.0
	# 玩家推动：不能用接触事件——CharacterBody2D 的 safe_margin 让玩家停在
	# 箱子表面 ~0.08px 处，持久接触从未建立，接触回调里读不到玩家。
	# 与虚影分支一致，用包围盒侧面间隙检测。
	for actor in get_tree().get_nodes_in_group("player"):
		if not Bounds.available(actor): continue
		var other := Bounds.rect(actor)
		if other.end.y <= body.position.y or other.position.y >= body.end.y: continue
		var axis := Input.get_axis("move_left", "move_right")
		var dir := signf(body.get_center().x - other.get_center().x)
		var gap := body.position.x - other.end.x if dir > 0 else other.position.x - body.end.x
		if axis * dir > 0 and gap >= -1 and gap <= CFG.push_gap:
			push_dir = dir
			break
	# 虚影推动：保留原逻辑，玩家未推时才生效（两侧同时发力会互相抵消）。
	if push_dir == 0.0:
		for echo in get_tree().get_nodes_in_group("echo"):
			if not Bounds.available(echo): continue
			var other := Bounds.rect(echo)
			if other.end.y <= body.position.y or other.position.y >= body.end.y: continue
			var axis := signf(Motion.horizontal(echo,state.step))
			var gap := body.position.x-other.end.x if axis > 0 else other.position.x-body.end.x
			if gap >= -1 and gap <= 2 and axis != 0:
				push_dir = axis
				break
	if push_dir != 0 and push_action != push_dir and Time.get_ticks_msec() - last_push_sound_ms >= 450:
		get_node("/root/GameSfx").play("crate_push")
		last_push_sound_ms = Time.get_ticks_msec()
	for i in state.get_contact_count():
		if falling_speed > 65 and absf(state.get_contact_local_normal(i).y)>0.5:
			get_node("/root/GameSfx").play("crate_land_%d" % randi_range(1,2))
			break
	falling_speed = state.linear_velocity.y
	push_action = push_dir
	apply_push(state, push_action)

func apply_push(state: PhysicsDirectBodyState2D, axis: float) -> void:
	if axis != 0:
		state.linear_velocity.x = axis * CFG.push_speed
	elif not _on_moving_support(state):
		state.linear_velocity.x = move_toward(state.linear_velocity.x, 0.0, CFG.push_damp * state.step)

## 箱子是否站在移动平台（AnimatableBody2D）上。
func _on_moving_support(state: PhysicsDirectBodyState2D) -> bool:
	for i in state.get_contact_count():
		# 竖直方向的接触（支撑/压顶）才可能是平台；法线方向随引擎约定，取绝对值。
		if absf(state.get_contact_local_normal(i).y) > 0.5:
			var obj := state.get_contact_collider_object(i)
			if obj is AnimatableBody2D:
				return true
	return false
