extends SceneTree
## 记录「有光 → 失光」整条台面高度曲线，用来画图。
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/probe_lift_curve.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var room := (load("res://scenes/levels/chapter_03/room_32_proto.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for i in 8: await physics_frame
	var lift := room.get_node("Lift") as AnimatableBody2D
	var sensor := room.get_node("Sensor")
	var pts := []
	sensor.set("force", 1)
	for i in 72:
		await physics_frame
		pts.append([i, lift.position.y, lift.get("speed")])
	sensor.set("force", -1)
	for i in 120:
		await physics_frame
		pts.append([72 + i, lift.position.y, lift.get("speed")])
	var f := FileAccess.open("res://build/lift_curve.csv", FileAccess.WRITE)
	f.store_line("frame,y,speed")
	for p in pts:
		f.store_line("%d,%.2f,%.2f" % [p[0], p[1], p[2]])
	f.close()
	print("CURVE_DONE")
	quit()
