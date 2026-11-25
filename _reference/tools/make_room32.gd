extends SceneTree
## 生成 3-2 原型的两层 tile_map_data（世界地形 + 黑幕）。
##   godot --headless --path . -s _reference/tools/make_room32.gd
##
## 为什么不让脚本直接写 tscn：手写 peering 编码（哪一格用哪张图）几乎必错，
## 让引擎的 set_cells_terrain_connect 选完瓦再原样导出字节最稳。

const WORLD_KIT := preload("res://scenes/levels/building_tiles/world_tiles.tres")
const NIGHT_KIT := preload("res://scenes/levels/dark_building/night_parts.tres")

const COLS := 40
const ROWS := 22
## 左右墙所在列
const WALL_COLS := [0, 39]
## 竖井（四格宽：三格平台 + 一格光敏条凹槽）
const SHAFT_LEFT := 9
const SHAFT_RIGHT := 12
## 死亡坑
const PIT_LEFT := 34
const PIT_RIGHT := 37


func _init() -> void:
	var solid: Array[Vector2i] = []
	# 底层地板（row 18，顶面 576）：坑与平台正下方留空
	for x in COLS:
		if (x < PIT_LEFT or x > PIT_RIGHT) and (x < SHAFT_LEFT or x >= SHAFT_RIGHT):
			solid.append(Vector2i(x, 18))
	# 平台正下方挖深一格（row 19，顶面 608）：平台静止时台面 576 与地板齐平，
	# 玩家是「走上平台」而不是「站在地板上、平台从身体里升上去」。
	# 只挖三格——光敏板那一格（SHAFT_RIGHT）必须是平地面，虚影要站在那里，
	# 挖深了它会陷进平台底板里，看不见。
	for x in range(SHAFT_LEFT, SHAFT_RIGHT):
		solid.append(Vector2i(x, 19))
	# 左右墙
	for x in WALL_COLS:
		for y in 18:
			solid.append(Vector2i(x, y))
	# 中层楼板（row 11，顶面 352）：只在竖井右侧
	for x in range(SHAFT_RIGHT + 1, 23):
		solid.append(Vector2i(x, 11))
	# 顶层楼板（row 4，顶面 128）：只在竖井左侧
	for x in range(1, 8):
		solid.append(Vector2i(x, 4))

	var world := TileMapLayer.new()
	world.tile_set = WORLD_KIT
	world.set_cells_terrain_connect(solid, 0, 0)
	print("CELLS=", solid.size())
	print("WORLD=", Marshalls.raw_to_base64(world.tile_map_data))
	# 抽查：这些格必须是实心的，竖井与坑必须是空的
	for probe in [Vector2i(20, 18), Vector2i(0, 5), Vector2i(18, 11), Vector2i(5, 4)]:
		print("SOLID ", probe, "=", world.get_cell_source_id(probe) != -1)
	for probe in [Vector2i(35, 18), Vector2i(10, 11), Vector2i(10, 4)]:
		print("EMPTY ", probe, "=", world.get_cell_source_id(probe) == -1)

	# 只留一盏固定火把：给顶层的出口当路标。竖井里一盏都不放——
	# 火把的照明半径 128/176，放进去整口井就亮了，「摸黑坐电梯」这件事就没了。
	var torches := TileMapLayer.new()
	torches.tile_set = NIGHT_KIT
	torches.set_cell(Vector2i(2, 3), 0, Vector2i(0, 2))
	print("TORCH=", Marshalls.raw_to_base64(torches.tile_map_data))

	var black := TileMapLayer.new()
	black.tile_set = NIGHT_KIT
	for x in COLS:
		for y in ROWS:
			black.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	print("BLACK=", Marshalls.raw_to_base64(black.tile_map_data))
	quit()
