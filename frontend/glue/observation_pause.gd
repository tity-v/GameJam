extends Node
## P 键暂停观察，与 Esc 菜单分开；计时、角色和机关一起冻结。
var active := false
var colors := preload("res://frontend/glue/pause_colors.gd").new()
var view_camera: Camera2D
var view_origin := Vector2.ZERO
var return_tween: Tween
const VIEW_SPEED := 520.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(on_room)
	on_room.call_deferred()

func on_room() -> void:
	if active:
		set_active(false)
	var room := get_tree().current_scene
	if room == null or not room.has_node("Player"):
		return
	var settings := preload("res://frontend/glue/store.gd").new().read_record("settings")
	if settings.ok and settings.data.get("start_paused", false) == true:
		set_active(true)

func _process(delta: float) -> void:
	if not active or not is_instance_valid(view_camera):
		return
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
	).normalized()
	view_camera.global_position += direction * VIEW_SPEED * delta

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		var room := get_tree().current_scene
		if room != null and room.has_node("Player") and (active or not get_tree().paused):
			set_active(not active)
			get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

func set_active(enabled: bool) -> void:
	if enabled:
		if return_tween and return_tween.is_running():
			return_tween.kill()
		view_camera = get_viewport().get_camera_2d()
		if is_instance_valid(view_camera):
			view_origin = view_camera.position
			view_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	active = enabled
	get_tree().paused = enabled
	colors.apply(get_tree().current_scene, enabled)
	if not enabled and is_instance_valid(view_camera):
		return_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		return_tween.tween_property(view_camera, "position", view_origin, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return_tween.finished.connect(func():
			if is_instance_valid(view_camera):
				view_camera.process_mode = Node.PROCESS_MODE_INHERIT
		)
