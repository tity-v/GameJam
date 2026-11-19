extends "res://graybox/glue/room.gd"

# 占位房间沿用通关接口，走到画面右边即可离开。
const RIGHT_EDGE := 1280.0

func _physics_process(_delta: float) -> void:
	if player.position.x >= RIGHT_EDGE:
		complete()
