extends "res://frontend/view/page.gd"

const BACKGROUND = preload("res://frontend/assets/home_background.jpg")
const FLASH_BACKGROUND = preload("res://frontend/assets/home_flash.jpg")
const FONT = preload("res://frontend/assets/NotoSansSC-Medium.otf")
const SELECT_SOUND = preload("res://assets/audio/ui_select.wav")
const CONFIRM_SOUND = preload("res://assets/audio/ui_confirm.wav")
const INK := Color("d9e0e3")
const ACCENT := Color("a5c9c3")

var canvas: Control
var menu: Control
var flash_image: TextureRect
var marker: ColorRect
var underline: ColorRect
var rows: Array[Button] = []
var row_tweens: Dictionary = {}
var marker_tween: Tween
var entry_tween: Tween
var busy := false
var selection_initialized := false
var select_audio: AudioStreamPlayer
var confirm_audio: AudioStreamPlayer

func present(model: Dictionary) -> void:
	select_audio = AudioStreamPlayer.new()
	select_audio.stream = SELECT_SOUND
	select_audio.volume_db = -14.0
	add_child(select_audio)
	confirm_audio = AudioStreamPlayer.new()
	confirm_audio.stream = CONFIRM_SOUND
	confirm_audio.volume_db = -11.0
	add_child(confirm_audio)
	$Center.hide()
	$Scrim.hide()
	canvas = Control.new()
	canvas.size = Vector2(1280, 704)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = canvas.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	flash_image = TextureRect.new()
	flash_image.texture = FLASH_BACKGROUND
	flash_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	flash_image.size = canvas.size
	flash_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_image.modulate.a = 0.0
	canvas.add_child(flash_image)
	var rule := ColorRect.new()
	rule.position = Vector2(77, 354)
	rule.size = Vector2(34, 2)
	rule.color = ACCENT
	canvas.add_child(rule)
	menu = Control.new()
	menu.position = Vector2(73, 374)
	canvas.add_child(menu)
	for item: Dictionary in model.get("buttons", []):
		make_row(item)
	marker = ColorRect.new()
	marker.size = Vector2(3, 24)
	marker.color = ACCENT
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(marker)
	underline = ColorRect.new()
	underline.size = Vector2(198, 1)
	underline.color = Color(ACCENT, 0.35)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(underline)
	make_label("↑ ↓ 选择     Enter 确认", Vector2(77, 663), 13).modulate.a = 0.7
	notice.reparent(canvas)
	notice.position = Vector2(77, 625)
	notice.size = Vector2(410, 48)
	notice.add_theme_font_override("font", FONT)
	notice.add_theme_font_size_override("font_size", 15)
	set_notice(model.get("notice", ""))
	resized.connect(fit_canvas)
	fit_canvas()
	if first_button != null:
		first_button.grab_focus()
	canvas.modulate.a = 0.0
	menu.position.x = 62.0
	entry_tween = create_tween().set_parallel(true)
	entry_tween.tween_property(canvas, "modulate:a", 1.0, 0.55)
	entry_tween.tween_property(menu, "position:x", 73.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func fit_canvas() -> void:
	var factor := minf(size.x / 1280.0, size.y / 704.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - canvas.size * factor) * 0.5

func make_label(text: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	canvas.add_child(label)
	return label

func make_row(item: Dictionary) -> void:
	var button := Button.new()
	button.position = Vector2(0, rows.size() * 48)
	button.size = Vector2(260, 44)
	button.disabled = item.get("disabled", false)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = item.text
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var text := Label.new()
	text.name = "Caption"
	text.text = item.text
	text.position = Vector2(19, 5)
	text.add_theme_font_override("font", FONT)
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", INK)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(text)
	menu.add_child(button)
	rows.append(button)
	button.focus_entered.connect(func(): select_row(button))
	button.mouse_entered.connect(func():
		if not busy and not button.disabled:
			button.grab_focus())
	button.pressed.connect(func(): activate(item))
	if first_button == null and not button.disabled:
		first_button = button

func select_row(selected: Button) -> void:
	if selection_initialized and not busy:
		select_audio.play()
	selection_initialized = true
	for button in rows:
		if row_tweens.has(button):
			row_tweens[button].kill()
		var caption: Label = button.get_node("Caption")
		var active := button == selected
		var tween := create_tween().set_parallel(true)
		tween.tween_property(caption, "position:x", 25.0 if active else 19.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(caption, "modulate:a", 1.0 if active else 0.68, 0.16)
		row_tweens[button] = tween
	if marker_tween != null:
		marker_tween.kill()
	marker_tween = create_tween().set_parallel(true)
	marker_tween.tween_property(marker, "position:y", selected.position.y + 10, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	marker_tween.tween_property(underline, "position:y", selected.position.y + 42, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func activate(item: Dictionary) -> void:
	if busy:
		return
	busy = true
	confirm_audio.play()
	if entry_tween != null:
		entry_tween.kill()
	flash_image.modulate.a = 1.0
	await get_tree().create_timer(0.09).timeout
	var flash_out := create_tween()
	flash_out.tween_property(flash_image, "modulate:a", 0.0, 0.16)
	await flash_out.finished
	requested.emit(item.command, item.get("value"))
	# A new-game confirmation may keep this page alive beneath its dialog.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	busy = false
