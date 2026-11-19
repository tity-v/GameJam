extends Node2D

var won := false
var resetting := false

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
