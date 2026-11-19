extends CanvasLayer
## 暂停菜单（autoload：PauseMenu）。
##
## 暂停用 SceneTree.paused 实现：主角、机关、相机、死亡计时全部停摆，
## 因为它们都是默认的 PAUSABLE 节点；本节点是 ALWAYS，暂停中仍能接 ESC 和鼠标，
## 所以「按 ESC 恢复 / 点图标继续」在暂停状态下都能用。

@onready var _root: Control = $Root
## TextureButton：外观全在 assets/ui/continue_*.png 里，换图即换皮
@onready var _button: TextureButton = $Root/ContinueButton


func _ready() -> void:
	# 关键：暂停时自己必须继续处理输入，否则按 ESC 也无法恢复
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_button.pressed.connect(resume)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	_root.visible = true


func resume() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	_root.visible = false
