extends Control
signal requested(command: String, value: Variant)

const PAPER = preload("res://frontend/assets/floor_directory_background.png")
const ILLUSTRATION_EFFECT = preload("res://frontend/view/ui_illustration.gdshader")

@export var panel: PanelContainer
@export var panel_width: float = 460.0
@export var heading: Label
@export var detail: Label
@export var content: VBoxContainer
@export var footer: HBoxContainer
@export var scrim: ColorRect
@export var notice: Label
@export var illustration: Texture2D
@export_enum("Echo", "Scan", "Door opening") var illustration_motion := 0
@export var opened_illustration: Texture2D
var first_button: Control

func present(model: Dictionary) -> void:
	panel.custom_minimum_size.x = panel_width
	$Center.anchor_right = 0.0
	$Center.offset_left = 68.0
	$Center.offset_right = 68.0 + panel_width
	heading.text = model.title
	detail.text = model.get("detail", "")
	detail.visible = not detail.text.is_empty()
	set_notice(model.get("notice", ""))
	if model.get("overlay", false):
		scrim.color = Color(0.025, 0.045, 0.067, 0.44)
	else:
		var background := TextureRect.new()
		background.texture = PAPER
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background.modulate = Color(0.69, 0.75, 0.79)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)
		move_child(background, scrim.get_index() + 1)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if illustration != null:
		_present_illustration()
	panel.draw.connect(_draw_panel_edges)
	if model.has("cards"):
		var grid := GridContainer.new()
		grid.columns = model.columns
		content.add_child(grid)
		for card: Dictionary in model.cards:
			add_button(grid, card)
	if model.has("settings"):
		add_settings(model.settings)
	for item: Dictionary in model.get("buttons", []):
		add_button(content, item)
	for item: Dictionary in model.get("footer", []):
		add_button(footer, item)
	if first_button != null:
		first_button.grab_focus()
	_animate_panel_entry()

func _animate_panel_entry() -> void:
	var center: Control = $Center
	center.offset_left += 8.0
	center.offset_right += 8.0
	panel.modulate.a = 0.56
	var entry := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entry.tween_property(center, "offset_left", 68.0, 0.22)
	entry.tween_property(center, "offset_right", 68.0 + panel_width, 0.22)
	entry.tween_property(panel, "modulate:a", 1.0, 0.23)

func _animate_button_focus(button: Button) -> void:
	var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
	if normal == null:
		return
	var surface := normal.duplicate() as StyleBoxTexture
	button.add_theme_stylebox_override("normal", surface)
	var rest := surface.modulate_color
	var focused := Color(1.23, 1.36, 1.36, 0.95)
	var update := func(tint: Color):
		var previous := button.get_meta("focus_fade", null) as Tween if button.has_meta("focus_fade") else null
		if previous != null:
			previous.kill()
		var fade := button.create_tween()
		button.set_meta("focus_fade", fade)
		fade.tween_property(surface, "modulate_color", tint, 0.15)
	button.focus_entered.connect(func(): update.call(focused))
	button.focus_exited.connect(func(): update.call(rest))

func _new_illustration() -> TextureRect:
	var art := TextureRect.new()
	art.texture = illustration
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	move_child(art, $Center.get_index())
	art.anchor_left = 0.54
	art.anchor_right = 0.96
	art.anchor_top = 0.15
	art.anchor_bottom = 0.85
	return art

func _present_illustration() -> void:
	var art := _new_illustration()
	art.modulate = Color(0.78, 0.88, 0.90, 0.0)
	if illustration_motion == 2 and opened_illustration != null:
		var opened := _new_illustration()
		opened.texture = opened_illustration
		opened.modulate = Color(0.88, 0.97, 0.97, 0.0)
		var opening := create_tween()
		opening.tween_property(art, "modulate:a", 0.84, 0.15)
		opening.tween_interval(0.16)
		opening.tween_property(opened, "modulate:a", 0.96, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		opening.parallel().tween_property(art, "modulate:a", 0.0, 0.20).set_delay(0.12)
		opening.tween_callback(art.queue_free)
		return
	var reveal := create_tween().set_parallel()
	reveal.tween_property(art, "modulate:a", 0.32 if illustration_motion == 0 else 0.77, 0.32)
	if illustration_motion == 0:
		var echo := _new_illustration()
		echo.modulate = Color(0.57, 0.78, 0.78, 0.20)
		echo.offset_left = -34
		echo.offset_right = -34
		reveal.tween_property(echo, "modulate:a", 0.0, 0.36)
		reveal.tween_property(echo, "offset_left", -5.0, 0.36)
		reveal.tween_property(echo, "offset_right", -5.0, 0.36)
		reveal.chain().tween_callback(echo.queue_free)
		return
	var effect := ShaderMaterial.new()
	effect.shader = ILLUSTRATION_EFFECT
	art.material = effect
	var update_progress := func(value: float):
		effect.set_shader_parameter("progress", value)
	reveal.tween_method(update_progress, 0.0, 1.0, 0.65).set_delay(0.10)

func set_notice(message: String) -> void:
	notice.text = message
	notice.visible = not message.is_empty()

func _draw_panel_edges() -> void:
	var width := panel.size.x
	var height := panel.size.y
	var border := Color("#617b83")
	panel.draw_rect(Rect2(0, 0, 29, 2), border)
	panel.draw_rect(Rect2(0, 0, 2, 23), border)
	panel.draw_rect(Rect2(36, 0, width - 62, 1), Color(border, 0.48))
	panel.draw_rect(Rect2(width - 2, height - 23, 2, 23), border)
	panel.draw_rect(Rect2(width - 29, height - 2, 29, 2), border)
	panel.draw_rect(Rect2(23, height - 1, width - 62, 1), Color(border, 0.48))

func add_button(parent: Container, item: Dictionary) -> void:
	var button := Button.new()
	button.text = item.text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if item.command == "choose":
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = button.text
	button.disabled = item.get("disabled", false)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var command: String = item.command
	var value: Variant = item.get("value")
	button.pressed.connect(func(): requested.emit(command, value))
	parent.add_child(button)
	_animate_button_focus(button)
	if first_button == null and not button.disabled:
		first_button = button

func add_settings(model: Dictionary) -> void:
	var volume_label := Label.new()
	volume_label.text = model.volume_label
	content.add_child(volume_label)
	var slider := HSlider.new()
	slider.value = model.volume
	slider.value_changed.connect(func(value: float): requested.emit("volume", value))
	content.add_child(slider)
	first_button = slider
	var sfx_label := Label.new()
	sfx_label.text = "音效音量"
	content.add_child(sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.value = model.sfx_volume
	sfx_slider.value_changed.connect(func(value: float): requested.emit("sfx_volume", value))
	content.add_child(sfx_slider)
	add_toggle(model.mute_label, "mute", model.muted)
	add_toggle(model.fullscreen_label, "fullscreen", model.fullscreen)
	add_toggle("开局暂停", "start_paused", model.start_paused)
	var guide := Label.new()
	guide.text = model.keys
	guide.theme_type_variation = "Detail"
	content.add_child(guide)

func add_toggle(label: String, command: String, enabled: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = enabled
	toggle.toggled.connect(func(value: bool): requested.emit(command, value))
	content.add_child(toggle)
	_animate_button_focus(toggle)
