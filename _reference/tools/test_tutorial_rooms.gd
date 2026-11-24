extends SceneTree
## 校验从 JSON 导入的教程关场景结构：地形、出生点落地、机关连通。
## 只验「导入是否忠实、能不能站人、机关接得上」，不验谜题能否解开（那要真人跑）。

const ROOMS := 10
const TILE := 32

var fails := 0


func _initialize() -> void:
	call_deferred("run")


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)


func _hit(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


## 某个像素点所在格是否有碰撞（直接问瓦片数据，避免射线起点落在形状内不命中）
func _solid_at(world: TileMapLayer, p: Vector2) -> bool:
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	var td := world.get_cell_tile_data(cell)
	return td != null and td.get_collision_polygons_count(0) > 0


func run() -> void:
	for i in range(1, ROOMS + 1):
		var path := "res://scenes/levels/chapter_01_tutorial/room_%02d.tscn" % i
		print("\n=== room_%02d ===" % i)
		var room: Node = load(path).instantiate()
		root.add_child(room)
		current_scene = room
		await physics_frame
		await physics_frame

		var world: TileMapLayer = room.get_node_or_null("World")
		var player: Node2D = room.get_node_or_null("Player")
		var spawn: Node2D = room.get_node_or_null("RespawnPoint")
		var mech: Node = room.get_node_or_null("Mechanisms")

		check(world != null, "World 存在")
		check(player != null, "Player 存在")
		check(spawn != null, "RespawnPoint 存在")
		check(mech != null, "Mechanisms 存在")

		var cells := 0
		if world != null:
			cells = world.get_used_cells().size()
		check(cells > 100, "World 有地形（%d 格）" % cells)

		# 出生点在同一格上（玩家可能被物理推几个像素，放宽到 2px）
		var drift := player.position.distance_to(spawn.position) if player != null and spawn != null else 999.0
		check(drift < 2.0, "玩家与复活点同位置（差 %.2f px）" % drift)
		if player != null and world != null:
			var feet := player.position + Vector2(16, 44)
			# 脚底下方 1px 那格必须是实心；脚底那格本身必须是空的（没陷进地里）
			var under := _solid_at(world, feet + Vector2(0, 1))
			var at := _solid_at(world, feet + Vector2(0, -1))
			check(under, "出生点脚底贴地（脚底 %s，下方格实心）" % feet)
			check(not at, "出生点没有陷进地形（脚底上方格为空）")
			# 身体中心不能在地形里
			var body := player.position + Vector2(16, 22)
			check(not _solid_at(world, body), "出生点身体不在实心地形内")

		# 机关连通
		var gates: Array[Node] = []
		var plates: Array[Node] = []
		var exit_node: Node = null
		if mech != null:
			for c in mech.get_children():
				if c.is_in_group("graybox_recordable") and c.get("plate_paths") != null:
					gates.append(c)
				elif c.is_in_group("graybox_recordable"):
					plates.append(c)
				elif c.get("door_path") != null:
					exit_node = c

		print("  机关：板 %d / 门 %d / 出口 %s" % [plates.size(), gates.size(), "有" if exit_node != null else "无"])

		for g in gates:
			var paths: Array = g.get("plate_paths")
			var ok := paths.size() > 0
			for p in paths:
				var n: Node = g.get_node_or_null(p)
				if n == null or not n.is_in_group("graybox_recordable"):
					ok = false
			check(ok, "%s 的压力板连接有效（%d 个）" % [g.name, paths.size()])

		if exit_node != null:
			var dp = exit_node.get("door_path")
			if dp == null or (dp is NodePath and (dp as NodePath).is_empty()):
				check(true, "出口没有关联门 → 常开（本关无门，合理）")
			else:
				check(exit_node.get_node_or_null(dp) != null, "出口的门连接有效")

		room.queue_free()
		await physics_frame

	print("\n=== 结果：%s（%d 条失败）===" % ["全部通过" if fails == 0 else "有失败", fails])
	quit(1 if fails > 0 else 0)
