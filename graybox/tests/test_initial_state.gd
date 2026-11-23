extends SceneTree

class Switch:
	extends Node2D
	var active := false

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	var source := Switch.new()
	source.name = "Switch"
	room.add_child(source)
	var door = load("res://graybox/door.tscn").instantiate()
	door.name = "Door"
	door.initially_open = true
	door.plate_paths.assign([NodePath("../Switch")])
	room.add_child(door)
	await physics_frame
	await physics_frame
	check(door.opened, "开局开启的门应保持开启")
	check(door.get_node("Collision").disabled, "开门应关闭碰撞")
	source.active = true
	await physics_frame
	await physics_frame
	check(not door.opened, "开局开启的门应在条件满足时关闭")
	source.active = false
	door.reset_mechanism()
	await physics_frame
	await physics_frame
	check(door.opened, "重置应恢复开局开启状态")
	door.initially_open = false
	door.reset_mechanism()
	await physics_frame
	check(not door.opened, "默认关闭状态应保持兼容")
	source.active = true
	await physics_frame
	await physics_frame
	check(door.opened, "默认关闭的门应在条件满足时开启")
	room.free()
	print("初始状态测试完成，失败 ", failures)
	quit(1 if failures else 0)
