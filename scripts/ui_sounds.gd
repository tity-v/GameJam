extends Node

const SELECT = preload("res://assets/audio/ui_select.wav")
const CONFIRM = preload("res://assets/audio/ui_confirm.wav")

var _select: AudioStreamPlayer
var _confirm: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_select = AudioStreamPlayer.new()
	_select.stream = SELECT
	_select.volume_db = -14.0
	add_child(_select)
	_confirm = AudioStreamPlayer.new()
	_confirm.stream = CONFIRM
	_confirm.volume_db = -11.0
	add_child(_confirm)


func play_select() -> void:
	_select.play()


func play_confirm() -> void:
	_confirm.play()
