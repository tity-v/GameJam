extends SceneTree
## 校验「关卡网格」契约：一张图 = 40x22 格 x 32px = 1280x704，空瓦片铺满，机关全部落在格线上。
##
## 这组断言是这个规格的唯一守门人。以后谁改了图集、改了层、把机关挪了半个格子，
## 这里会先炸，而不是等美术把图画完才发现整关偏了 16px。

const COLS := 40
const ROWS := 22
const TILE := 32

var lvl: Node
var step := 0
var fails := 0


func _initialize() -> void:
	lvl = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(lvl)


func _process(_d: float) -> bool:
	step += 1
	if step == 6:
		_run()
		print("失败项：", fails)
		return true
	return false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print(("  OK  " if cond else "  FAIL") + " " + label + ("" if detail == "" else "  " + detail))
	if not cond:
		fails += 1


func _layer(name: String) -> TileMapLayer:
	var n = lvl.get_node_or_null(name)
	return n as TileMapLayer


func _atlas_cells(layer: TileMapLayer) -> Array:
	var out := []
	for c in layer.get_used_cells():
		out.append([c, layer.get_cell_atlas_coords(c)])
	return out


func _run() -> void:
	print("=== 视口 = 地图 = 40x22x32 ===")
	var vw: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vh: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	_check("视口宽 = 40*32", vw == COLS * TILE, str(vw))
	_check("视口高 = 22*32", vh == ROWS * TILE, str(vh))

	print("=== 三层：占位 / 实体 / 装饰 ===")
	var air := _layer("Map_Placeholder")
	var world := _layer("World")
	var decor := _layer("Decor")
	_check("Map_Placeholder 存在", air != null)
	_check("World 存在", world != null)
	_check("Decor 存在", decor != null)
	if air == null or world == null:
		return
	_check("占位层关碰撞", air.collision_enabled == false)
	_check("实体层开碰撞", world.collision_enabled == true)
	_check("三层都不缩放（不要再用 scale=2 凑 32）",
		air.scale == Vector2.ONE and world.scale == Vector2.ONE and decor.scale == Vector2.ONE,
		str(air.scale) + " " + str(world.scale))
	_check("瓦片尺寸 32x32", air.tile_set.tile_size == Vector2i(TILE, TILE), str(air.tile_set.tile_size))

	print("=== 空瓦片铺满整张地图（880 格）===")
	var air_cells := air.get_used_cells()
	_check("占位格数 = 40*22", air_cells.size() == COLS * ROWS, str(air_cells.size()))
	var all_air := true
	for c in air_cells:
		if air.get_cell_atlas_coords(c) != Vector2i(0, 1):
			all_air = false
			break
	_check("占位格全部是 air(0,1)", all_air)
	_check("占位层角落有瓦片", air_cells.has(Vector2i(0, 0)) and air_cells.has(Vector2i(COLS - 1, ROWS - 1)))

	print("=== 实体层：地表 y=18、内层 19~21、左右墙 0~17 ===")
	var surface_ok := true
	var fill_ok := true
	var wall_ok := true
	for x in COLS:
		if world.get_cell_atlas_coords(Vector2i(x, 18)) != Vector2i(0, 0):
			surface_ok = false
		for y in range(19, ROWS):
			if world.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(1, 0):
				fill_ok = false
	for y in range(0, 18):
		for x in [0, COLS - 1]:
			if world.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(2, 0):
				wall_ok = false
	_check("地表整行是 solid_top", surface_ok)
	_check("地表以下整行是 solid_fill", fill_ok)
	_check("左右两列是 solid_wall", wall_ok)

	print("=== 图集语义：实心有碰撞、空的没有 ===")
	var src := air.tile_set.get_source(0) as TileSetAtlasSource
	_check("图集源存在", src != null)
	if src != null:
		var solid_data := src.get_tile_data(Vector2i(0, 0), 0)
		var air_data := src.get_tile_data(Vector2i(0, 1), 0)
		_check("solid_top 有 1 个碰撞多边形", solid_data.get_collision_polygons_count(0) == 1,
			str(solid_data.get_collision_polygons_count(0)))
		_check("air 没有碰撞多边形", air_data.get_collision_polygons_count(0) == 0)
		var one_way := src.get_tile_data(Vector2i(3, 0), 0)
		_check("one_way 标了单向", one_way.is_collision_polygon_one_way(0, 0))

	print("=== 物理实证：地面顶边在 y=576，两侧有墙 ===")
	var space: PhysicsDirectSpaceState2D = lvl.get_node("Player").get_world_2d().direct_space_state
	_check("地面上方 6px 是空的", not _hit(space, Vector2(640, 570)))
	_check("地面下方 6px 是实的", _hit(space, Vector2(640, 582)))
	_check("左墙(8,300) 是实的", _hit(space, Vector2(8, 300)))
	_check("右墙(1272,300) 是实的", _hit(space, Vector2(1272, 300)))
	_check("房间上方(640,100) 是空的", not _hit(space, Vector2(640, 100)))

	print("=== 机关对齐格线（左/底贴 32 的倍数，宽是 32 的倍数）===")
	for n in ["PlateA", "PlateB", "Door", "Exit", "Spikes"]:
		var node := lvl.get_node_or_null(n) as Node2D
		_check(n + " 存在", node != null)
		if node == null:
			continue
		var size: Vector2 = node.block_size
		var px: float = node.position.x
		var bottom: float = node.position.y + size.y
		_check(n + " 左边贴格线", int(px) % TILE == 0, str(px))
		_check(n + " 底边贴格线", int(bottom) % TILE == 0, str(bottom))
		_check(n + " 宽是整格", int(size.x) % TILE == 0, str(size.x))

	print("=== 相机对准房间中心 ===")
	var cam := lvl.get_node_or_null("Camera2D") as Camera2D
	_check("相机存在", cam != null)
	if cam != null:
		_check("相机在 (640, 352)", cam.position == Vector2(COLS * TILE / 2, ROWS * TILE / 2), str(cam.position))


func _hit(space: PhysicsDirectSpaceState2D, point: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = point
	q.collision_mask = 1
	q.collide_with_bodies = true
	return not space.intersect_point(q, 1).is_empty()
