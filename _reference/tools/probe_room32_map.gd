extends SceneTree

const ROOM := "res://scenes/levels/chapter_03/room_32_proto.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	for i in 3:
		await physics_frame
	var world := room.get_node("World") as TileMapLayer
	var used := {}
	for c in world.get_used_cells():
		used[c] = true
	for y in range(22):
		var line := "%2d " % y
		for x in range(40):
			line += "#" if used.has(Vector2i(x, y)) else "."
		print(line)
	var lift := room.get_node("Lift") as Node2D
	var sensor := room.get_node("Sensor") as Node2D
	print("lift x=%.0f 半宽 44 -> %.0f..%.0f" % [lift.position.x, lift.position.x - 44, lift.position.x + 44])
	print("sensor x=%.0f zone 宽 %.0f -> %.0f..%.0f" % [sensor.position.x, sensor.get("zone").x,
		sensor.position.x - sensor.get("zone").x * 0.5, sensor.position.x + sensor.get("zone").x * 0.5])
	quit()
