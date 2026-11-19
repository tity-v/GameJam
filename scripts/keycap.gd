extends PanelContainer
## 一个键帽：圆角底板 + 居中键名。
##
## 美术换外观：改本场景 PanelContainer 的 theme_override_styles/panel
## （换成九宫格贴图也行），或整张换掉 assets/ui/keycap 系列图。
## 策划改键名：在检查器里改 key_text 即可，不用展开子节点。

@export var key_text := "A":
	set(value):
		key_text = value
		if is_node_ready():
			_label.text = value

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = key_text
