extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node2D = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await physics_frame
	var player = scene.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite")
	var collision := player.get_node("Collision") as CollisionShape2D
	assert(collision.shape.size == Vector2(32, 44))
	assert(player.is_on_floor())
	assert(absf(player.position.y + 44 - 576) < 0.2)
	assert(absf(sprite.texture.get_height() * sprite.scale.y - 48) < 0.01)
	assert(absf(sprite.position.y + sprite.texture.get_height() * sprite.scale.y - 44) < 0.01)
	assert(sprite.texture.resource_path.ends_with("idle.png"))
	sprite.elapsed = 2.9
	for i in 2:
		await physics_frame
	assert(sprite.texture.resource_path.ends_with("blink.png"))
	var before: float = sprite.elapsed
	paused = true
	for i in 4:
		await process_frame
	assert(sprite.elapsed == before)
	paused = false
	player.die()
	for i in 90:
		await physics_frame
	var manager = scene.get_node("EchoManager")
	assert(manager.echo_count() == 1)
	var echo = manager.get_child(0)
	assert(echo.body_size == Vector2(32, 44))
	assert(echo.get_node("Top").shape.size == Vector2(32, 8))
	var body: Sprite2D = echo.get_node("Body")
	assert(absf(body.texture.get_height() * body.scale.y - 48) < 0.01)
	assert(body.self_modulate.a < 1.0)
	print("CHARACTER_ALL_PASS: dimensions, ground contact, blink, pause, echo appearance")
	scene.queue_free()
	await process_frame
	quit()
