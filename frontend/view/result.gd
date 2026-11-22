extends "res://frontend/view/pause.gd"


func present(model: Dictionary) -> void:
	include_level_list = true
	var display := model.duplicate()
	display.buttons = model.get("buttons", []).duplicate()
	display.buttons.append_array(model.get("footer", []))
	super.present(display)
	menu.position.y = 258
	var title := Label.new()
	title.text = model.get("title", "")
	title.position = Vector2(94, 175)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", INK)
	add_child(title)
	var detail := Label.new()
	detail.text = model.get("detail", "")
	detail.position = Vector2(94, 212)
	detail.add_theme_font_override("font", FONT)
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", MUTED)
	add_child(detail)
