extends AnimatableBody2D
var active := false
var box_size := Vector2.ZERO
const ReplayBox = preload("res://graybox/glue/replay_box.gd")
var crate: ReplayBox
var platform := false
var phase := 0.0
var original: Node2D
var appearance: CanvasItem
var hit: CollisionShape2D
var layer := 0
var track
var elapsed := 0
var cursor := 0
var playing := false
var occupied := {}
var portal := false
var recorded_target := Vector2.ZERO
var portal_open := false
const CFG = preload("res://graybox/db/mechanisms.tres")
const PortalActions = preload("res://graybox/glue/portal_actions.gd")

static func switch_on(source: Node) -> bool:
	if not is_instance_valid(source) or not "active" in source: return false
	if source.active: return true
	for ghost in source.get_meta(&"graybox_switch_echoes", []):
		if is_instance_valid(ghost) and ghost.playing and ghost.active and not ghost.is_queued_for_deletion(): return true
	return false

func setup(source: Node2D, face: CanvasItem, history) -> void:
	preload("res://scripts/replay_rules.gd").mark_ghost(self)
	original = source
	platform = source.has_method("route_start")
	track = history
	sync_to_physics = false
	collision_layer = 0
	collision_mask = 0
	portal = source.has_method("mark_arrival")
	if portal:
		var portals: Array = source.get_meta(&"graybox_portal_echoes", [])
		portals.append(self)
		source.set_meta(&"graybox_portal_echoes", portals)
	if source is CollisionObject2D:
		layer = source.collision_layer
		var shape := source.get_node_or_null("Collision") as CollisionShape2D
		if shape:
			hit = shape.duplicate(0)
			add_child(hit)
	if source.is_in_group("graybox_box"):
		crate = ReplayBox.new()
		crate.box_size = source.box_size
		crate.freeze = true
		crate.lock_rotation = true
		crate.can_sleep = false
		crate.contact_monitor = true
		crate.max_contacts_reported = 8
		crate.physics_material_override = source.physics_material_override
		crate.gravity_scale = source.gravity_scale
		crate.collision_layer = 0
		crate.add_collision_exception_with(source)
		hit.reparent(crate, false)
		hit = null
		add_child(crate)
	if "active" in source:
		var echoes: Array = source.get_meta(&"graybox_switch_echoes", [])
		echoes.append(self)
		source.set_meta(&"graybox_switch_echoes", echoes)
	appearance = face.duplicate(0)
	appearance.set_script(null)
	if appearance is Control: appearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if crate:
		crate.add_child(appearance)
	else:
		add_child(appearance)
	hide()
	process_physics_priority = -20

func _exit_tree() -> void:
	if portal and is_instance_valid(original): original.get_meta(&"graybox_portal_echoes", []).erase(self)
	if is_instance_valid(original) and original.has_meta(&"graybox_switch_echoes"):
		var echoes: Array = original.get_meta(&"graybox_switch_echoes")
		echoes.erase(self)

func restart() -> void:
	elapsed = 0
	cursor = 0
	occupied.clear()
	playing = true
	global_transform = track.origin
	if platform:
		phase = track.phase
	if crate:
		crate.global_transform = track.origin
		crate.freeze = false
		crate.linear_velocity = track.velocity
		crate.collision_layer = layer
		if not crate.is_in_group("graybox_box"):
			crate.add_to_group("graybox_box")
	show()
	apply_frame()

func apply_frame() -> void:
	cursor = track.cursor_at(cursor, elapsed)
	var key: Array = track.keys[cursor]
	var state: Array = key[3]
	if crate:
		crate.push_action = state[5] if elapsed < track.length else 0.0
	if appearance is Node2D: appearance.transform = state[0]
	if appearance is NinePatchRect: appearance.texture = key[1]
	appearance.modulate = key[2] * Color(1,1,1,CFG.ghost_alpha)
	active = state[1]
	collision_layer = layer if state[2] and not crate else 0
	portal_open = state[3]
	recorded_target = state[4]

func _physics_process(dt: float) -> void:
	if not playing: return
	apply_frame()
	if platform and elapsed < track.length:
		var route: Array = track.keys[cursor][3]
		var a: Vector2 = route[5]
		var b: Vector2 = route[6]
		var length := a.distance_to(b)
		if length > 0:
			global_position = a.lerp(b, pingpong(phase,length)/length)
			phase += float(route[7])*dt
	if portal:
		PortalActions.transfer(self, portal_open, recorded_target, original.destination, occupied, false)
	elapsed += 1

func mark_arrival(id: int) -> void:
	occupied[id] = true
