extends Control
signal requested(command: String, value: Variant)

@export var panel: PanelContainer
@export var panel_width: float = 460.0
@export var heading: Label
@export var detail: Label
@export var content: VBoxContainer
@export var footer: HBoxContainer
@export var scrim: ColorRect
@export var notice: Label
var first_button: Control

func present(model: Dictionary) -> void:
	panel.custom_minimum_size.x = panel_width
	heading.text = model.title
	detail.text = model.get("detail", "")
	detail.visible = not detail.text.is_empty()
	set_notice(model.get("notice", ""))
	if model.get("overlay", false):
		scrim.color.a = 0.82
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

func set_notice(message: String) -> void:
	notice.text = message
	notice.visible = not message.is_empty()

func add_button(parent: Container, item: Dictionary) -> void:
	var button := Button.new()
	button.text = item.text
	if item.command == "choose":
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = button.text
	button.disabled = item.get("disabled", false)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var command: String = item.command
	var value: Variant = item.get("value")
	button.pressed.connect(func(): requested.emit(command, value))
	parent.add_child(button)
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
	add_toggle(model.mute_label, "mute", model.muted)
	add_toggle(model.fullscreen_label, "fullscreen", model.fullscreen)
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
