extends SceneTree
## 逐关把玩家放上压力板，看门开不开、出口亮不亮——回答「导入的地图是空壳还是谜题通了」。
##   godot --headless --path . --fixed-fps 60 -s _reference/tools/probe_chapter1.gd
##
## 只验「站上去」这一层：板→门→出口的连线。跳跃能不能走通不在本探针范围。

const TUTORIAL := "res://scenes/levels/chapter_01_tutorial/room_%02d.tscn"
const SHIPPED := "res://scenes/levels/chapter_01_room_%02d.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n=== 教程导入版 ===")
	for i in range(1, 11):
		await _report(TUTORIAL % i)
	print("\n=== 目录版（游戏里跑的，作对照）===")
	for i in range(1, 6):
		await _report(SHIPPED % i)
	print("\nDONE")
	quit()


func _report(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("%s 缺失" % path.get_file())
		return
	var room: Node = (load(path) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await physics_frame
	await physics_frame

	var world := room.get_node_or_null("World") as TileMapLayer
	var mech := room.get_node_or_null("Mechanisms")
	var player := room.get_node_or_null("Player") as Node2D
	var cells := world.get_used_cells().size() if world != null else 0

	var plates: Array[Node] = []
	var doors: Array[Node] = []
	var exit_node: Node = null
	if mech != null:
		for c in mech.get_children():
			var nm := String(c.name)
			if c.get("door_path") != null:
				exit_node = c
			elif c.get("plate_paths") != null:
				doors.append(c)
			elif nm.begins_with("plate") or nm.begins_with("压力板") or nm.length() <= 2:
				plates.append(c)

	# 记录初始状态
	var init_open: Array[String] = []
	for d in doors:
		init_open.append("%s=%s" % [d.name, str(d.get("opened"))])

	# 逐块板试：把玩家放到板面上，等物理稳定，看哪些门变了
	var lines: Array[String] = []
	for p in plates:
		var blk: Vector2 = p.get("block_size") if p.get("block_size") != null else Vector2(32, 32)
		player.global_position = (p as Node2D).global_position + Vector2(blk.x * 0.5 - 16.0, -44.0)
		player.velocity = Vector2.ZERO
		for f in 12:
			await physics_frame
		var opened: Array[String] = []
		for d in doors:
			if bool(d.get("opened")):
				opened.append(String(d.name))
		var act := ""
		if exit_node != null:
			act = " 出口亮" if bool(exit_node.get("active")) else " 出口灭"
		lines.append("%s→%s%s" % [p.name, ",".join(opened) if opened.size() > 0 else "无门开", act])

	print("%-22s 地形%4d 板%d 门%d 出口%s｜初态 %s｜%s" % [
		path.get_file(), cells, plates.size(), doors.size(),
		"有" if exit_node != null else "无",
		",".join(init_open) if init_open.size() > 0 else "-",
		"  ".join(lines) if lines.size() > 0 else "无板（走到出口即可）"])

	room.queue_free()
	await physics_frame
