extends HBoxContainer
## 一组操作提示：「键帽… 说明」。例如 [A][D] 移动。
##
## 键帽数量由 keys 决定（A/D 是两个键帽，空格是一个），说明文字换成 desc。
## 策划在 hud.tscn 里复制一个本场景的实例，改这两个字段就能加一条新操作提示。

const KEYCAP := preload("res://scenes/ui/keycap.tscn")

@export var keys: PackedStringArray = ["A", "D"]
@export var desc := "移动"

@onready var _desc: Label = $Desc


func _ready() -> void:
	_desc.text = desc
	for i in keys.size():
		var cap := KEYCAP.instantiate()
		add_child(cap)
		move_child(cap, i)
		cap.key_text = keys[i]
