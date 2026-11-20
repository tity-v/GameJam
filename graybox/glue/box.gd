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
func resize() -> void:
	$Collision.shape.size = box_size
	var half := box_size / 2
	$Face.polygon = PackedVector2Array([-half, Vector2(half.x,-half.y), half, Vector2(-half.x,half.y)])
	mass = box_size.x * box_size.y * CFG.box_density
func _ready() -> void:
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
		resetting = false
		return
	for i in state.get_contact_count():
		var actor := state.get_contact_collider_object(i)
		if actor is CharacterBody2D and actor.is_in_group("player"):
			var axis := Input.get_axis("move_left","move_right")
			if axis * (global_position.x - actor.global_position.x) > 0 and absf(state.get_contact_local_normal(i).x) > 0.5:
				state.apply_central_force(Vector2.RIGHT * axis * CFG.push_force)
				break
	var body := Rect2(state.transform.origin - box_size / 2, box_size)
	for echo in get_tree().get_nodes_in_group("echo"):
		if not Bounds.available(echo): continue
		var other := Bounds.rect(echo)
		if other.end.y <= body.position.y or other.position.y >= body.end.y: continue
		var axis := signf(Motion.horizontal(echo,state.step))
		var gap := body.position.x-other.end.x if axis > 0 else other.position.x-body.end.x
		if gap >= -1 and gap <= 2 and axis != 0:
			state.apply_central_force(Vector2.RIGHT * axis * CFG.push_force)
