extends Node2D

var won := false
var resetting := false

## 整关重来：只有通关面板上的 Replay 会调它，会把机关、通关状态、虚影一起复位。
## 注意 **R 键不走这里**——R 只清虚影 + 把玩家送回出生点，机关状态保留
## （见 `echo_manager.reset_all`）。按 R 重载整关会让人以为"开门白解了"。
func reset_room() -> void:
	if resetting:
		return
	resetting = true
	get_tree().call_deferred("reload_current_scene")

func complete() -> void:
	if won or resetting:
		return
	won = true
	$Player.set_physics_process(false)
	$EchoManager.set_physics_process(false)
	$UI/Win.visible = true
	$UI/Win/Replay.grab_focus()

func _ready() -> void:
	$UI/Win/Replay.pressed.connect(reset_room)
