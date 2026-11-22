extends Node
## P 键暂停观察，与 Esc 菜单分开；计时、角色和机关一起冻结。
var active := false
var colors := preload("res://frontend/glue/pause_colors.gd").new()

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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		var room := get_tree().current_scene
		if room != null and room.has_node("Player") and (active or not get_tree().paused):
			set_active(not active)
			get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

func set_active(enabled: bool) -> void:
	active = enabled
	get_tree().paused = enabled
	colors.apply(get_tree().current_scene, enabled)
