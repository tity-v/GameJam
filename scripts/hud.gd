extends Control
## 屏幕底部操作提示栏（autoload：Hud）。
##
## 外观全部在 scenes/ui/hud.tscn 里，本脚本只管两件事：
##   1. 刷新右端的「回声 n / 5」
##   2. R / 满员替换时闪一行提示（Flash 节点的文字与淡出）
## 想改文案、加一条操作：在编辑器里打开 hud.tscn，在 Hints 下复制一个 KeyHint 实例
## 改它的 keys / desc 即可，不需要动这里。键帽样式在 keycap.tscn，说明文字在 key_hint.tscn。
##
## 为什么放 autoload 而不是关卡里：以后加第二/三关、或者重开关卡，这条提示栏都自动在，
## 不用每关手动摆一遍，也不会出现"某一关忘了写提示"。

const FLASH_DURATION := 1.5
const ECHO_ICON = preload("res://assets/actors/office_character/idle.png")

var _flash_time := 0.0
var _echo_total := -1
var _echo_max := 5
var _icons: Array[TextureRect] = []

@onready var _count: Label = $Count
@onready var _flash: Label = $Flash


func _ready() -> void:
	add_to_group("hud")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 暂停时自己也停，免得提示文字在暂停画面背后继续淡出
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_flash.modulate.a = 0.0
	$BarBg.hide()
	$Hints.hide()
	_count.hide()
	_flash.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_flash.position = Vector2(get_viewport_rect().size.x - 360, 68)
	var icons := HBoxContainer.new()
	icons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	icons.offset_left = -220
	icons.offset_top = 20
	icons.offset_right = -20
	icons.offset_bottom = 60
	icons.add_theme_constant_override("separation", 7)
	add_child(icons)
	for index in _echo_max:
		var icon := TextureRect.new()
		icon.texture = ECHO_ICON
		icon.custom_minimum_size = Vector2(32, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(icon)
		_icons.append(icon)
	update_icons(0)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		var t := 1.0 - _flash_time / FLASH_DURATION
		# 前 60% 保持清晰，后 40% 淡出，不然还没读完就没了
		_flash.modulate.a = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)

	var total := _count_echoes()
	if total != _echo_total:
		_echo_total = total
		update_icons(total)

func update_icons(total: int) -> void:
	for index in _icons.size():
		_icons[index].modulate = Color(0.67, 0.95, 0.90, 1.0) if index < total else Color(0.72, 0.83, 0.85, 0.43)


## 条上方居中闪一行提示（虚影重置 / 满员替换）
func flash(text: String) -> void:
	_flash.text = text
	_flash_time = FLASH_DURATION
	_flash.modulate.a = 1.0


func _count_echoes() -> int:
	var em := get_tree().get_first_node_in_group("echo_manager")
	if em == null or not em.has_method("echo_count"):
		return 0
	if em.has_method("max_echoes"):
		_echo_max = int(em.max_echoes())
	return int(em.echo_count())
