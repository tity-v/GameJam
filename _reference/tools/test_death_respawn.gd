extends SceneTree
## 临时验证：固定重生点 + E 自杀 + 死亡期间失控 + 复活后恢复操作。

var lvl
var player
var cam


func _initialize() -> void:
	_run()


func _run() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	cam = lvl.get_node("Camera2D")

	print("die action exists: ", InputMap.has_action("die"))
	await _wait(30)
	print("[开局] pos=(%.1f,%.1f) respawn=(%.1f,%.1f) is_dead=%s" % [
		player.global_position.x, player.global_position.y,
		player.respawn_position.x, player.respawn_position.y, player.is_dead])

	# ---------- 1. 走到远处按 E 自杀 ----------
	player.global_position = Vector2(1000.0, 522.0)
	player.velocity = Vector2.ZERO
	await _wait(5)
	var cam_far: Vector2 = cam.global_position
	print("[走远] pos.x=%.1f cam.x=%.1f" % [player.global_position.x, cam_far.x])

	_key(KEY_E, true)
	await _wait(2)
	_key(KEY_E, false)
	print("[按E] is_dead=%s (应 true)" % player.is_dead)

	await _wait(36)  # 约 0.6s
	var sprite = player.get_node("Sprite")
	print("[死亡中 0.6s] is_dead=%s alpha=%.2f (应 <1)" % [player.is_dead, sprite.modulate.a])

	var x_mid: float = player.global_position.x
	_key(KEY_D, true)
	await _wait(30)
	print("[死亡中按D 0.5s] dx=%.2f (应≈0，输入被忽略)" % (player.global_position.x - x_mid))
	_key(KEY_D, false)

	await _wait(50)  # 累计超过 1.3s
	print("[复活] is_dead=%s pos=(%.1f,%.1f) vel=(%.1f,%.1f) alpha=%.2f" % [
		player.is_dead, player.global_position.x, player.global_position.y,
		player.velocity.x, player.velocity.y, sprite.modulate.a])
	print("[相机归位] cam.x=%.1f (走远时 %.1f，应回到关卡左边界)" % [cam.global_position.x, cam_far.x])

	# ---------- 2. 复活后操作恢复正常 ----------
	await _wait(10)
	var x_after: float = player.global_position.x
	_key(KEY_D, true)
	await _wait(30)
	print("[复活后右移 0.5s] dx=%.1f vx=%.1f (应能动)" % [player.global_position.x - x_after, player.velocity.x])
	_key(KEY_D, false)
	await _wait(20)

	# ---------- 3. 死亡中再按 E 不叠加 ----------
	_key(KEY_E, true)
	await _wait(2)
	_key(KEY_E, false)
	await _wait(30)
	_key(KEY_E, true)
	await _wait(2)
	_key(KEY_E, false)
	print("[死亡中再按E] is_dead=%s (仍为 true，不应重置计时)" % player.is_dead)
	await _wait(60)
	print("[第二次复活] is_dead=%s pos=(%.1f,%.1f)" % [player.is_dead, player.global_position.x, player.global_position.y])

	# ---------- 4. 掉出地图也判定死亡 ----------
	player.global_position = Vector2(600.0, 800.0)
	player.velocity = Vector2.ZERO
	await _wait(3)
	print("[掉出地图 y=800] is_dead=%s (应 true)" % player.is_dead)
	await _wait(90)
	print("[摔死复活] is_dead=%s pos=(%.1f,%.1f)" % [player.is_dead, player.global_position.x, player.global_position.y])

	quit()


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = 0
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
