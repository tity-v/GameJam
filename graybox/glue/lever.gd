@tool
extends StaticBody2D
const CFG = preload("res://graybox/db/mechanisms.tres")
const Motion = preload("res://graybox/glue/actor_motion.gd")
const Bounds = preload("res://scripts/actor_bounds.gd")
@export var initially_right := true
var active := false
var travel := 0.0
var latched := false
var trip_time := 0.0
func _ready() -> void:
	reset_mechanism()
	if not Engine.is_editor_hint():
		add_to_group("mechanism")
		process_physics_priority = 10
func reset_mechanism() -> void:
	active = not initially_right
	trip_time = 0.0
	travel = 0
	latched = false
	$Collision.set_deferred("disabled",false)
	update_arm()
func update_arm() -> void:
	$Arm.rotation = (-1 if active else 1) * (PI / 4 - travel / CFG.lever_travel * PI / 2)
func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressing := false
	var touching := false
	var wrong_side := false
	var side := -1 if active else 1
	for actor in Bounds.actors(get_tree()):
		if not Bounds.available(actor):
			continue
		var body := Bounds.rect(actor)
		var reach := global_transform * Rect2(Vector2(-20, -28), Vector2(40, 30))
		if not reach.intersects(body):
			continue
		touching = true
		var horizontal: float = Motion.horizontal(actor, dt)
		var actor_side := signf(body.get_center().x - global_position.x)
		if actor_side == -side and horizontal * side > 0:
			wrong_side = true
		if not latched and actor_side == side and horizontal*side < 0:
			travel += absf(horizontal) * dt
			pressing = true
	if wrong_side:
		trip_time += dt
		if trip_time >= CFG.trip_seconds:
			$Collision.set_deferred("disabled", true)
			latched = true
	else:
		trip_time = 0.0
	if not touching:
		latched = false
		$Collision.set_deferred("disabled",false)
	if not pressing:
		travel = 0
	if travel >= CFG.lever_travel:
		active = not active
		latched = true
		$Collision.set_deferred("disabled",true)
		travel = 0
	update_arm()
