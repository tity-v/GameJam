extends "res://frontend/view/page.gd"

var animate := true
var tabs: TabContainer
var paint: TextureRect

func present(model: Dictionary) -> void:
	animate = not model.get("reduced_motion", false)
	theme = theme.duplicate()
	theme.default_font = preload("res://frontend/assets/MaShanZheng-Regular.ttf")
	theme.default_font_size = 24
	for state in ["normal","hover","pressed","focus"]:
		var kind := "button" if state == "normal" else "selected"
		theme.set_stylebox(state,"Button",brush("focus" if state == "focus" else kind))
	theme.set_color("font_color","Header",Color("#e4dfd8"))
	var art := TextureRect.new()
	art.texture = preload("res://frontend/assets/painted_menu/backdrop.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(art)
	move_child(art,0)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.visible = not model.get("overlay",false)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	paint = TextureRect.new()
	paint.texture = preload("res://frontend/assets/painted_menu/panel.png")
	paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paint)
	move_child(paint,$Center.get_index())
	panel.item_rect_changed.connect(fit_paint)
	fit_paint.call_deferred()
	var pigment := ShaderMaterial.new()
	pigment.shader = preload("res://frontend/view/menu_paint.gdshader")
	pigment.set_shader_parameter("stroke_order", preload("res://frontend/assets/painted_menu/stroke_order.png"))
	paint.material = pigment
	pigment.set_shader_parameter("motion",float(animate))
	var margin := panel.get_node("Margin") as MarginContainer
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,32)
	super.present(model)
	scrim.color = Color(0.025,0.035,0.055,0.60)
	if animate:
		pigment.set_shader_parameter("sweep",0.)
		panel.modulate.a = 0.
		var entry := create_tween().set_parallel()
		entry.tween_method(func(v:float): pigment.set_shader_parameter("sweep",v),0.,1.,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		entry.tween_property(panel,"modulate:a",1.,0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func section(title:String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = title
	tabs.add_child(group)
	group.add_theme_constant_override("separation",14)
	return group

func add_settings(model:Dictionary) -> void:
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 247
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.TRANSPARENT
	paper.content_margin_left = 18
	paper.content_margin_right = 18
	paper.content_margin_top = 14
	paper.content_margin_bottom = 12
	tabs.add_theme_stylebox_override("panel",paper)
	for state in ["tab_selected","tab_unselected","tab_hovered"]:
		var tab := brush("selected" if state == "tab_selected" else "button")
		tabs.add_theme_stylebox_override(state,tab)
	content.add_child(tabs)
	var audio := section("声音")
	for key in ["volume","sfx_volume"]:
		var row := HBoxContainer.new()
		audio.add_child(row)
		var label := Label.new()
		label.text = "主音量" if key == "volume" else "音效音量"
		label.custom_minimum_size.x = 105
		row.add_child(label)
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value = model[key]
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 62
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.text = "%d%%" % slider.value
		row.add_child(number)
		slider.value_changed.connect(func(v:float):
			number.text = "%d%%" % v
			requested.emit(key,v))
	switch(audio,"静音","mute",model.muted)
	var screen := section("画面")
	switch(screen,"全屏显示","fullscreen",model.fullscreen)
	switch(screen,"垂直同步","vsync",model.vsync)
	switch(screen,"减少菜单动效","reduced_motion",model.reduced_motion)
	var controls := section("操作")
	switch(controls,"进入关卡时暂停","start_paused",model.start_paused)
	var guide := Label.new()
	guide.text = model.keys.trim_prefix("操作说明\n")
	guide.theme_type_variation = "Detail"
	controls.add_child(guide)
	first_button = tabs.get_tab_bar()

func switch(group:Container,label:String,key:String,enabled:bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = enabled
	toggle.toggled.connect(func(v:bool):
		if key == "reduced_motion":
			animate = not v
			(paint.material as ShaderMaterial).set_shader_parameter("motion",float(animate))
		requested.emit(key,v))
	group.add_child(toggle)

func add_button(parent:Container, item:Dictionary) -> void:
	if item.command == "clear" and tabs != null:
		super.add_button(section("存档"),item)
	else:
		super.add_button(parent,item)

func fit_paint() -> void:
	paint.size = panel.size * Vector2(1.36,1.43)
	paint.global_position = panel.global_position - (paint.size-panel.size)*0.5

func leave_echo(host:Node) -> void:
	if not animate:
		return
	# 退场时沿四道笔锋逐笔收墨；只留下无输入的纹理副本。
	var undercoat := paint.duplicate() as TextureRect
	undercoat.material = paint.material.duplicate()
	host.add_child(undercoat)
	undercoat.z_index = 7
	undercoat.global_position = paint.global_position
	var ink := undercoat.material as ShaderMaterial
	var departure := undercoat.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var coverage := float(ink.get_shader_parameter("sweep"))
	departure.tween_method(func(v:float): ink.set_shader_parameter("sweep",v),coverage,0.,0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	departure.tween_callback(undercoat.queue_free)
	var echo := TextureRect.new()
	echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	echo.texture = preload("res://frontend/assets/painted_menu/echo.png")
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	echo.z_index = 8
	host.add_child(echo)
	echo.size = paint.size
	echo.global_position = paint.global_position
	echo.pivot_offset = echo.size*0.5
	echo.modulate.a = 0.12 * coverage
	var fade := echo.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	fade.tween_property(echo,"scale",Vector2(1.025,1.035),0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(echo,"modulate:a",0.,0.17)
	fade.chain().tween_callback(echo.queue_free)

func brush(kind:String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	const TEXTURES := {
		"button": preload("res://frontend/assets/painted_menu/button.png"),
		"selected": preload("res://frontend/assets/painted_menu/selected.png"),
		"focus": preload("res://frontend/assets/painted_menu/focus.png"),
	}
	box.texture = TEXTURES[kind]
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		box.set_texture_margin(side,18)
		box.set_content_margin(side,18)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		box.set_texture_margin(side,7)
		box.set_content_margin(side,6)
	return box
