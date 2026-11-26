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
## 竖井 A（四格宽：三格平台 + 一格光敏条凹槽），底层 → 中层
const SHAFT_LEFT := 9
const SHAFT_RIGHT := 12
## 竖井 B（三格宽，整口给平台），中层 → 顶层
const SHAFT_B_LEFT := 20
const SHAFT_B_RIGHT := 22
## 中层楼板：竖井 A 右侧这一段（玩家从平台 A 跳上来后往右走）
const MID_LEFT := 13
const MID_RIGHT := 19
## 顶层楼板：从最左一直铺到竖井 B 左壁，玩家出井 B 后往左走到出口
const UP_LEFT := 1
const UP_RIGHT := 19
## 中层右段悬挑台（井 B 对面）：放火盆与光敏板 B
const LEDGE_LEFT := 23
const LEDGE_RIGHT := 28
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
	# 中层楼板（row 11，顶面 352）。拆成两段，中间让出竖井 B：
	#   左段 13~19（416~640）给玩家走，右段 23~28（736~928）是井 B 对面的悬挑台，
	#   火盆与光敏板 B 都架在上面。两段之间 20~22（640~736）是竖井 B 的口，
	#   落差 224px 到顶层，玩家掉进去会直接落回底层地板，不致死。
	for x in range(MID_LEFT, MID_RIGHT + 1):
		solid.append(Vector2i(x, 11))
	for x in range(LEDGE_LEFT, LEDGE_RIGHT + 1):
		solid.append(Vector2i(x, 11))
	# 顶层楼板（row 4，顶面 128）：从左墙一直铺到竖井 B 左壁。
	# 平台 B 升到 128 时台面与这块楼板齐平，玩家直接走过去。
	for x in range(UP_LEFT, UP_RIGHT + 1):
		solid.append(Vector2i(x, 4))

	var world := TileMapLayer.new()
	world.tile_set = WORLD_KIT
	world.set_cells_terrain_connect(solid, 0, 0)
	print("CELLS=", solid.size())
	print("WORLD=", Marshalls.raw_to_base64(world.tile_map_data))
	# 抽查：这些格必须是实心的，两口竖井与坑必须是空的
	for probe in [Vector2i(20, 18), Vector2i(0, 5), Vector2i(18, 11), Vector2i(5, 4),
			Vector2i(25, 11), Vector2i(15, 4)]:
		print("SOLID ", probe, "=", world.get_cell_source_id(probe) != -1)
	for probe in [Vector2i(35, 18), Vector2i(10, 11), Vector2i(21, 11), Vector2i(21, 4)]:
		print("EMPTY ", probe, "=", world.get_cell_source_id(probe) == -1)

	# 两盏固定火把：
	#   1. 顶层出口旁当路标（玩家出井 B 后一路往左走，得看得见门在哪）。
	#   2. 中层右端（列 19 = 624）。这一盏是给「换乘」指路的：
	#      玩家从中层走过来，光照到井 B 口，才能看见对面悬挑台上那口火盆。
	#      没有它，井 B 对面整片在黑幕里，玩家只会觉得"走到头了"。
	# 两口井里仍然一盏都不放——火把照明半径 128/176，放进去整口井就亮了，
	# 「摸黑坐电梯」这件事就没了。
	var torches := TileMapLayer.new()
	torches.tile_set = NIGHT_KIT
	torches.set_cell(Vector2i(2, 3), 0, Vector2i(0, 2))
	torches.set_cell(Vector2i(19, 10), 0, Vector2i(0, 2))
	print("TORCH=", Marshalls.raw_to_base64(torches.tile_map_data))

	var black := TileMapLayer.new()
	black.tile_set = NIGHT_KIT
	for x in COLS:
		for y in ROWS:
			black.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	print("BLACK=", Marshalls.raw_to_base64(black.tile_map_data))
	quit()
