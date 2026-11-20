extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 40)
	collision.shape = shape
	floor_body.position = Vector2(500, 320)
	floor_body.add_child(collision)
	room.add_child(floor_body)
	var echo = load("res://scenes/echo/echo.tscn").instantiate()
	room.add_child(echo)
	var start := Vector2(100, 300 - echo.body_size.y - 2)
	var trail := PackedVector2Array([start, start + Vector2(12, 12), start + Vector2(24, 12)])
	echo.setup(trail)
	echo.reset()
	await physics_frame
	await physics_frame
	echo.advance(1.0 / 60)
	echo.advance(1.0 / 60)
	var distance: float = echo.position.x - start.x
	print("落地后水平位移=", distance, "，记录位移=24")
	if absf(distance - 24) > 0.1:
		push_error("落地碰撞丢失了记录中的水平位移")
		quit(1)
		return
	print("PASS 落地时保留水平方向的记录位移")
	quit()
