extends "res://frontend/view/page.gd"

const FONT = preload("res://frontend/assets/NotoSansSC-Medium.otf")
const INK := Color("dce3e5")
const MUTED := Color("8c9ca5")
const FRAME := Color("78949e")

var menu: Control
var marker: ColorRect
var old_marker: ColorRect
var rows: Array[Button] = []
var marker_tween: Tween
var has_selection := false
var include_level_list := false


func present(model: Dictionary) -> void:
	$Center.hide()
	scrim.color = Color(0.025, 0.043, 0.06, 0.34)
	menu = Control.new()
	menu.position = Vector2(93, 222)
	add_child(menu)
	for item: Dictionary in model.get("buttons", []):
		if item.command == "levels" and not include_level_list:
			continue
		var button := Button.new()
		button.position = Vector2(0, rows.size() * 58)
		button.size = Vector2(265, 48)
		button.disabled = item.get("disabled", false)
		button.flat = true
		button.text = item.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", MUTED)
		button.add_theme_color_override("font_focus_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		menu.add_child(button)
		rows.append(button)
		button.focus_entered.connect(func():
			play_ui_select()
			_select(button))
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus())
		button.pressed.connect(func():
			play_ui_confirm()
			requested.emit(item.command, item.get("value")))
	marker = ColorRect.new()
	marker.color = Color("a7c7c7")
	marker.size = Vector2(4, 4)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(marker)
	old_marker = ColorRect.new()
	old_marker.color = Color(0.54, 0.71, 0.71, 1.0)
	old_marker.modulate.a = 0.0
	old_marker.size = Vector2(4, 4)
	old_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(old_marker)
	queue_redraw()
	for button in rows:
		if not button.disabled:
			first_button = button
			button.grab_focus()
			break


func _draw() -> void:
	var area := Rect2(69, 146, 360, 410)
	# 16px 的半透明硬边色阶，右侧逐渐融回冻结的关卡画面。
	for column in 22:
		var fade := 1.0 - float(column) / 22.0
		draw_rect(Rect2(area.position.x + column * 16, area.position.y, 16, area.size.y), Color(0.035, 0.063, 0.082, 0.38 * fade))
	# 稀疏网点让背板保留像素质感，左侧稍密，向右散开。
	for row in 28:
		for column in 25:
			if (row + column) % 3 == 0 and column < 25 - row % 4:
				var strength := 1.0 - float(column) / 25.0
				draw_rect(Rect2(area.position.x + 8 + column * 14, area.position.y + 8 + row * 14, 2, 2), Color(0.40, 0.57, 0.60, 0.17 * strength))
	var x := area.position.x
	var y := area.position.y
	var right := area.end.x
	var bottom := area.end.y
	# 不闭合的 1px 像素边框，右下角留出缺口。
	draw_line(Vector2(x + 20, y), Vector2(x + 210, y), FRAME, 1.0)
	draw_line(Vector2(x + 223, y), Vector2(right - 55, y), FRAME.darkened(0.3), 1.0)
	draw_line(Vector2(x, y + 20), Vector2(x, bottom - 86), FRAME, 1.0)
	draw_line(Vector2(x, bottom - 71), Vector2(x, bottom - 16), FRAME.darkened(0.3), 1.0)
	draw_line(Vector2(right, y + 8), Vector2(right, y + 84), FRAME.darkened(0.28), 1.0)
	draw_line(Vector2(right, bottom - 108), Vector2(right, bottom - 40), FRAME.darkened(0.4), 1.0)
	draw_line(Vector2(x + 14, bottom), Vector2(x + 165, bottom), FRAME.darkened(0.22), 1.0)
	draw_line(Vector2(x + 179, bottom), Vector2(right - 84, bottom), FRAME.darkened(0.4), 1.0)
	draw_rect(Rect2(x, y, 13, 2), FRAME)
	draw_rect(Rect2(x, y, 2, 13), FRAME)
	draw_rect(Rect2(right - 3, bottom - 3, 3, 3), Color("759e9f"))
	draw_line(Vector2(x + 25, y + 50), Vector2(x + 74, y + 50), FRAME.darkened(0.15), 1.0)
	draw_rect(Rect2(x + 28, bottom - 74, 35, 2), Color(0.40, 0.57, 0.60, 0.35))
	draw_rect(Rect2(x + 31, bottom - 68, 19, 2), Color(0.40, 0.57, 0.60, 0.20))
	# 一道错开两像素的淡残影，静止时也能读出时间错位。
	draw_line(Vector2(x + 3, y + 27), Vector2(x + 3, bottom - 55), Color(0.33, 0.53, 0.56, 0.18), 1.0)


func _select(button: Button) -> void:
	for row in rows:
		row.add_theme_color_override("font_color", INK if row == button else MUTED)
	if marker_tween != null:
		marker_tween.kill()
	if has_selection:
		old_marker.position = marker.position
		old_marker.modulate.a = 0.55
		create_tween().tween_property(old_marker, "modulate:a", 0.0, 0.22)
	has_selection = true
	marker_tween = create_tween()
	marker_tween.tween_property(marker, "position:y", button.position.y + 21, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
