extends "res://frontend/view/page.gd"

const FONT = preload("res://frontend/assets/NotoSansSC-Medium.otf")
const TITLE_FONT = preload("res://frontend/assets/LXGWMarkerGothic-Regular.ttf")
const NUMBER_FONT = preload("res://frontend/assets/fusion-pixel-12px-monospaced-latin.otf")
const BACKGROUND = preload("res://frontend/assets/floor_directory_background.png")
const DOOR_DONE = preload("res://frontend/assets/floor_door_done.png")
const DOOR_READY = preload("res://frontend/assets/floor_door_ready.png")
const INK := Color("#dce5e6")
const DIM := Color("#8b9da4")
const ECHO := Color("#89c2bb")
const RULE := Color("#3a5059")

var _floors: Array[Dictionary] = []
var _floor_buttons: Array[Button] = []
var _doors: Array[Button] = []
var _selected := -1
var _recent := -1
var _door_root: Control
var _room_name: Label
var _back: Button
var _allow_sfx := false
var _reveal: Tween


func present(model: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	$Center.hide()
	scrim.hide()
	_floors.assign(model.directory)
	_recent = model.recent_room
	var title := _label("楼层目录", Vector2(89, 97), 46, INK)
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_color_override("font_shadow_color", Color("#3c6266"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_room_name = _label("", Vector2(424, 447), 19, INK)
	_room_name.size.x = 700
	_room_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_door_root = Control.new()
	_door_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_door_root)
	notice.reparent(self, false)
	notice.position = Vector2(424, 556)
	notice.size.x = 700
	set_notice(model.get("notice", ""))
	_back = _button("返回", Rect2(90, 595, 122, 38))
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.draw.connect(func():
		if _back.has_focus():
			_back.draw_rect(Rect2(0, 36, 40, 1), ECHO))
	_back.pressed.connect(func(): requested.emit("go_back", null))
	for index in _floors.size():
		var floor_data := _floors[index]
		var row := _button(floor_data.name, Rect2(90, 204 + index * 60, 245, 46))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_floor_buttons.append(row)
		var progress := _label(floor_data.progress, Vector2(282, 217 + index * 60), 12, DIM)
		progress.add_theme_font_override("font", NUMBER_FONT)
		progress.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.focus_entered.connect(func(): _show_floor(index))
		row.pressed.connect(func():
			if not _doors.is_empty():
				_doors[0].grab_focus())
	if _floor_buttons.is_empty():
		first_button = _back
	else:
		var initial := clampi(model.selected_floor, 0, _floor_buttons.size() - 1)
		_show_floor(initial)
		first_button = _floor_buttons[initial]
		for door in _doors:
			if door.get_meta("room_index") == _recent:
				first_button = door
				break
	first_button.grab_focus()
	_allow_sfx = true


func _label(value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.position = at
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	add_child(item)
	return item


func _button(value: String, area: Rect2) -> Button:
	var item := Button.new()
	item.text = value
	item.position = area.position
	item.size = area.size
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", 19)
	item.add_theme_color_override("font_color", DIM)
	item.add_theme_color_override("font_focus_color", INK)
	item.add_theme_color_override("font_hover_color", INK)
	for state in ["normal", "focus", "hover", "pressed"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(item)
	item.focus_entered.connect(func():
		if _allow_sfx:
			get_node("/root/GameSfx").play("home_hover")
		item.queue_redraw())
	item.focus_exited.connect(item.queue_redraw)
	return item


func _show_floor(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	for row in _floor_buttons:
		row.add_theme_color_override("font_color", INK if row == _floor_buttons[index] else DIM)
		row.focus_neighbor_right = NodePath()
	for door in _doors:
		_door_root.remove_child(door)
		door.queue_free()
	_doors.clear()
	_room_name.text = ""
	var rooms: Array = _floors[index].rooms
	var two_rows := rooms.size() > 5
	_room_name.position.y = 484 if two_rows else 447
	var button_height := 110 if two_rows else 191
	for slot in rooms.size():
		var room: Dictionary = rooms[slot]
		var column := slot % 5
		@warning_ignore("integer_division")
		var row := slot / 5
		var door := _button("%02d" % room.number, Rect2(425 + column * 137, 222 + row * 112, 104, button_height))
		door.reparent(_door_root, false)
		door.add_theme_font_override("font", NUMBER_FONT)
		door.add_theme_font_size_override("font_size", 24)
		var number_style := StyleBoxEmpty.new()
		number_style.content_margin_top = 83 if two_rows else 150
		for state in ["normal", "focus", "hover", "pressed"]:
			door.add_theme_stylebox_override(state, number_style)
		door.set_meta("room_index", room.index)
		door.tooltip_text = room.name
		door.draw.connect(func(): _draw_door(door, room.done))
		door.focus_entered.connect(func(): _room_name.text = room.name)
		door.focus_exited.connect(func(): _room_name.text = "")
		door.pressed.connect(func():
			get_node("/root/GameSfx").play("home_chosen")
			requested.emit("choose", room.index))
		_doors.append(door)
	if rooms.is_empty():
		_room_name.text = "尚无可进入的房间"
	else:
		if _reveal != null:
			_reveal.kill()
		_reveal = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for slot in _doors.size():
			var door := _doors[slot]
			door.modulate.a = 0.27
			_reveal.tween_property(door, "modulate:a", 1.0, 0.23).set_delay(minf(slot * 0.035, 0.19))
	for row in _floor_buttons.size():
		var button := _floor_buttons[row]
		button.focus_neighbor_top = button.get_path_to(_floor_buttons[maxi(0, row - 1)])
		button.focus_neighbor_bottom = button.get_path_to(_floor_buttons[row + 1] if row + 1 < _floor_buttons.size() else _back)
		if row == index and not _doors.is_empty():
			button.focus_neighbor_right = button.get_path_to(_doors[0])
	_back.focus_neighbor_top = _back.get_path_to(_floor_buttons.back())
	for slot in _doors.size():
		var door := _doors[slot]
		door.focus_neighbor_left = door.get_path_to(_floor_buttons[index] if slot % 5 == 0 else _doors[slot - 1])
		var next := slot + 1
		door.focus_neighbor_right = door.get_path_to(_doors[next] if next < _doors.size() and next % 5 != 0 else door)
		door.focus_neighbor_top = door.get_path_to(_doors[slot - 5] if slot >= 5 else door)
		door.focus_neighbor_bottom = door.get_path_to(_doors[slot + 5] if slot + 5 < _doors.size() else _back)
	queue_redraw()


func _draw_door(door: Button, done: bool) -> void:
	var texture := DOOR_DONE if done else DOOR_READY
	var art_size := Vector2(41, 76) if door.size.y < 150 else Vector2(76, 141)
	var art := Rect2(Vector2(roundf((door.size.x - art_size.x) / 2.0), 7), art_size)
	var tint := Color(1.16, 1.16, 1.16) if door.has_focus() else Color.WHITE
	door.draw_texture_rect(texture, art, false, tint)
	if door.has_focus():
		door.draw_rect(Rect2(art.position.x - 10, floorf(art.get_center().y), 4, 4), INK)


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(89, 171, 63, 2), ECHO.darkened(0.28))
	draw_rect(Rect2(159, 171, 42, 1), RULE)
	var rule_y := 462 if _doors.size() > 5 else 418
	draw_rect(Rect2(424, rule_y, 711, 1), Color(RULE, 0.56))
	if _selected >= 0:
		draw_rect(Rect2(76, 225 + _selected * 60, 4, 4), ECHO)
