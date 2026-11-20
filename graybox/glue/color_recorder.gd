@tool
extends Node2D
const CFG = preload("res://graybox/db/mechanisms.tres")
@export var tint := Color.SKY_BLUE:
	set(value):
		tint = value
		if is_instance_valid(preview): preview.modulate = tint
var preview: CanvasItem
var original_color := Color.WHITE
var source: Node2D
var visual: CanvasItem
const Track = preload("res://graybox/systems/motion_track.gd")
var samples: Track
var tracks: Array = []
var frame := 0
var recording := true
var frame_limit := 0
var track_limit := 0
func _ready() -> void:
	source = get_parent() as Node2D
	if not source or not source.is_in_group("graybox_recordable"):
		source = null
		set_physics_process(false)
		return
	original_color = source.modulate
	for child in source.get_children():
		if child is Polygon2D or child is NinePatchRect:
			visual = child
			break
	if Engine.is_editor_hint():
		set_physics_process(false)
		if visual:
			# 预览节点不设 owner，保存房间时不会写入组件或改变原颜色。
			preview = visual.duplicate(0)
			preview.set_script(null)
			if preview is Control: preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(preview)
			preview.modulate = tint
		return
	connect_room.call_deferred()

func connect_room() -> void:
	var manager := get_tree().get_first_node_in_group("echo_manager")
	var player := get_tree().get_first_node_in_group("player")
	if not visual or not manager or not player:
		set_physics_process(false)
		return
	frame_limit = maxi(2, manager.max_frames)
	samples = Track.new(frame_limit)
	track_limit = manager.max_echoes()
	player.died.connect(finish_track)
	player.respawned.connect(rewind)
	add_to_group("mechanism")
	process_physics_priority = 40
func _exit_tree() -> void:
	for track in tracks:
		if is_instance_valid(track.ghost): track.ghost.queue_free()
func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() or not get_parent().is_in_group("graybox_recordable"):
		return ["放在可记录的机关根节点下。"]
	return []
func finish_track() -> void:
	recording = false
	if samples == null or samples.count == 0: return
	if tracks.size() >= track_limit:
		tracks.pop_front().ghost.queue_free()
	var ghost := preload("res://graybox/glue/component_echo.gd").new()
	ghost.setup(source, visual, samples)
	get_tree().current_scene.add_child(ghost)
	tracks.append({"ghost":ghost})
	samples = Track.new(frame_limit)
func rewind() -> void:
	if source.has_method("reset_mechanism"): source.reset_mechanism()
	frame = 0
	samples = Track.new(frame_limit)
	recording = true
	for track in tracks: track.ghost.restart()
func reset_mechanism() -> void:
	for track in tracks: track.ghost.queue_free()
	tracks.clear()
	rewind()
func _physics_process(_dt: float) -> void:
	if not visual or frame_limit == 0: return
	if recording:
		var texture = visual.texture if visual is NinePatchRect else null
		var color := visual.modulate * original_color * tint
		var shape := source.get_node_or_null("Collision") as CollisionShape2D
		var signal_on: bool = source.get("active") == true if "active" in source else false
		var usable: bool = source.recorded_open if "recorded_open" in source else false
		var target := Vector2.ZERO
		if usable and source.destination: target = source.destination.global_position
		var state := [visual.get_transform(), signal_on, shape != null and not shape.disabled, usable, target]
		samples.record(source.global_transform, texture, color, state)
