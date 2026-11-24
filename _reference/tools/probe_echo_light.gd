extends SceneTree
## 验证「自杀后产生的虚影」到底照不照亮。
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/probe_echo_light.gd
##
## 黑幕给虚影的光半径是 echo_radii * (1 - fade进度)。
## room_31_proto.tscn 把 personal_radii 设成 (2,2)（玩家只靠手电），
## 所以虚影必须走自己那条 echo_radii，共用的话光会被一起关掉。

var room: Node
var bo: Node
var player: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/chapter_03/room_31_proto.tscn")
	room = packed.instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(10)

	bo = room.get_node("Blackout")
	player = room.get_node("Player")
	print("A personal_radii=", bo.personal_radii, " echo_radii=", bo.echo_radii, " falloff=", bo.falloff)

	# 自杀
	Input.action_press("die")
	await _frames(3)
	Input.action_release("die")
	await _frames(6)

	var echoes := get_nodes_in_group("echo")
	print("B 死亡后 echo 数=", echoes.size())
	for e in echoes:
		print("   active=", e.is_active(), " pos=", e.global_position)

	# 等复活，然后抓虚影「刚登场、还没开始淡出」的那一帧——重放阶段
	# _fade_time 恒为 0，光才是满额；等 150 帧去看只剩个尾焰。
	var snap: Array = []
	for i in 400:
		await process_frame
		if player.is_dead:
			continue
		for e in get_nodes_in_group("echo"):
			if e.is_active() and float(e._fade_time) < 0.05:
				snap.append(e)
		if not snap.is_empty():
			break
	print("C 抓到登场瞬间 echo 数=", snap.size(), " player_alive=", not player.is_dead)
	# 黑幕在 _process 里刷新，探针读到的要晚一帧才是这一帧的圆
	await _frames(2)
	print("   黑幕 sources:")
	var src0: PackedVector4Array = bo.material.get_shader_parameter("sources")
	var n0: int = bo.material.get_shader_parameter("count")
	for i in n0:
		var v := src0[i]
		print("      [", i, "] 中心=", Vector2(v.x, v.y), " rx=", v.z, " ry=", v.w)
	var hits: int = 0
	for e in snap:
		var c: Vector2 = e.body_rect().get_center()
		var remain: float = 1.0 - float(e._fade_time) / e.fade_duration
		var r: Vector2 = bo.echo_radii * maxf(0.01, remain)
		print("   虚影 active=", e.is_active(), " 中心=", c,
			" 淡出进度=", "%.2f" % (float(e._fade_time) / e.fade_duration),
			" 照明半径=", r)
		if r.x > 8.0:
			hits += 1
			# 看黑幕实际收到的圆里有没有它
			var src: PackedVector4Array = bo.material.get_shader_parameter("sources")
			var n: int = bo.material.get_shader_parameter("count")
			var found := false
			for i in n:
				var v := src[i]
				if Vector2(v.x, v.y).distance_to(c) < 2.0:
					found = true
					print("     黑幕收到该光源：rx=", v.z, " ry=", v.w)
			print("     黑幕里能找到它=", found)

	print("D 有效照明的虚影数=", hits)
	if hits == 0:
		print("E 结论：虚影没进黑幕，echo_radii 太小或没接上")
	else:
		print("E 结论：虚影在照亮，半径随淡出线性收缩")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
