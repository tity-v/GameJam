extends Node

const Session = preload("res://frontend/glue/session.gd")

func _ready() -> void:
	# 等启动场景进入树后，再挂载跨场景保留的会话。
	_start.call_deferred()

func _start() -> void:
	var session := Session.new()
	get_tree().root.add_child(session)
	session.start(self)
