@tool
extends Node2D
## 旧楼布景的第二层：天花板收边、墙面色带、立管、踢脚线、前景立柱。
##
## 为什么要单独一层：整屏 40×22 格固定机位下，墙面只有一扇窗、一个通风口和一片
## 点阵，地板与墙又是同一个色值（#8e9faa），眼睛读到的是"一块平面"而不是"一间房"。
## 补空间感靠的是**分割面**——顶有梁、墙有色带、地有踢脚——而不是往上堆道具。
## 所以这里只有 4 类东西，且都能被窗/门/机关整片遮住（窗在 z=-2，本层在 z=-3）。
##
## 参数尽量从兄弟节点推导（Interior 的窗/通风口、World 的地面轮廓），
## 每关不用重复配置；需要例外时在房间场景里覆盖对应导出变量。

@export_enum("墙面", "前景") var part := 0:
	set(value):
		part = value
		queue_redraw()
## 窗/通风口/立柱的位置来源。为空时退回默认值，不会报错。
@export var interior: NodePath = ^"../Interior"
## 地面轮廓的来源。为空时立管一律画到墙脚。
@export var world: NodePath = ^"../World"
## 天花板横梁厚度。窗顶最低是 y=54（room_04），所以别超过 40。
@export var ceiling_depth := 36.0:
	set(value):
		ceiling_depth = value
		queue_redraw()
## 墙面腰线高度。要低于所有窗底（最高的是 room_02 的 264），否则会横穿窗户。
@export var waist_y := 300.0:
	set(value):
		waist_y = value
		queue_redraw()
## 立管根数。2 根读作管线，4 根以上会读成栏杆——这里宁可少。
@export var pipe_count := 2:
	set(value):
		pipe_count = value
		queue_redraw()
## 立管最小间距。
@export var pipe_gap := 340.0:
	set(value):
		pipe_gap = value
		queue_redraw()
## 只影响渗水痕长度和法兰相位，换个数就是另一间房。
@export var variation := 1:
	set(value):
		variation = value
		queue_redraw()

const W := 1280.0
const H := 704.0
const CELL := 32.0
## 左右各两格是承重墙，踢脚与腰线不往墙上爬。
const COL_MIN := 2
const COL_MAX := 37

const DARK := Color("#6b7c88")
const DARKER := Color("#5a6b78")
const BRIGHT := Color("#a3b4be")
const HILIGHT := Color("#b0c0c9")
const FORE := Color("#445468")

func _draw() -> void:
	if part == 1:
		draw_foreground()
		return
	draw_waist()
	draw_ceiling()
	draw_stains()
	draw_contact_shadow()
	draw_skirting()
	draw_pipes()

## 接地阴影：地面往上 88px 由透明渐变到暗。这是最便宜的纵深线索——
## 有了它，地板才"压在"墙前面，而不是和墙贴在同一张纸上。
func draw_contact_shadow() -> void:
	var tops := floor_tops()
	var clear := Color(DARKER, 0.0)
	var heavy := Color(DARKER, 0.22)
	for column in range(COL_MIN, COL_MAX + 1):
		var top: float = tops[column]
		if top <= ceiling_depth + 40.0 or top >= H:
			continue
		var x := column * CELL
		var wide := CELL + 1.0
		var quad := PackedVector2Array([
			Vector2(x, top - 88.0), Vector2(x + wide, top - 88.0),
			Vector2(x + wide, top - 15.0), Vector2(x, top - 15.0),
		])
		draw_polygon(quad, PackedColorArray([clear, clear, heavy, heavy]))

## 腰线：一条旧漆色带。横贯的线是打散大平面的最低成本手段，
## 位置压在所有窗底之下，窗在 z=-2 盖住它也不会露馅。
func draw_waist() -> void:
	draw_rect(Rect2(0, waist_y, W, 9.0), Color(DARK, 0.34))
	draw_rect(Rect2(0, waist_y + 9.0, W, 2.0), Color(BRIGHT, 0.28))
	draw_rect(Rect2(0, waist_y - 2.0, W, 2.0), Color(DARKER, 0.18))

## 天花板：一段压暗的梁底 + 稀疏宽梁头 + 底缘亮线。
## 作用是把墙封顶，画面从无限平面变成有高度的室内。
func draw_ceiling() -> void:
	if ceiling_depth <= 0.0:
		return
	draw_rect(Rect2(0, 0, W, ceiling_depth), Color(DARK, 0.46))
	draw_rect(Rect2(0, ceiling_depth - 2.0, W, 2.0), Color(BRIGHT, 0.42))
	var x := 40.0
	var index := 0
	while x < W - 40.0:
		var depth := ceiling_depth + (7.0 if index % 2 == 0 else 3.0)
		draw_rect(Rect2(x, 0, 58.0, depth), Color(DARKER, 0.42))
		draw_rect(Rect2(x - 4.0, 0, 4.0, depth - 3.0), Color(DARKER, 0.28))
		x += 240.0
		index += 1

## 渗水痕：从梁缝往下拖的浅色竖条，只做出"这里不是新房子"的暗示。
func draw_stains() -> void:
	var spots := [214.0, 742.0, 1114.0]
	for i in spots.size():
		var x: float = spots[i] + float(variation % 3) * 26.0
		var length := 54.0 + float((i * 37 + variation * 13) % 70)
		draw_rect(Rect2(x, ceiling_depth, 5.0, length), Color(DARKER, 0.12))
		draw_rect(Rect2(x + 5.0, ceiling_depth, 3.0, length * 0.6), Color(DARKER, 0.09))

## 踢脚线：地板和墙同色 #8e9faa，这是唯一能把两者分开的东西，所以画实。
## 沿真实地面轮廓走，下沉的地坑会自然跟着降下去。
func draw_skirting() -> void:
	var tops := floor_tops()
	for column in range(COL_MIN, COL_MAX + 1):
		var top: float = tops[column]
		if top <= ceiling_depth or top >= H:
			continue
		var x := column * CELL
		draw_rect(Rect2(x, top - 13.0, CELL + 1.0, 13.0), Color(DARKER, 0.62))
		draw_rect(Rect2(x, top - 15.0, CELL + 1.0, 2.0), Color(BRIGHT, 0.30))

## 立管：竖向节奏。现在的墙只有三条 1px 竖缝，人眼找不到参照物。
func draw_pipes() -> void:
	var columns := pipe_columns()
	for x in columns:
		var bottom := wall_bottom(x)
		if bottom <= ceiling_depth + 40.0:
			continue
		var top := ceiling_depth
		var height := bottom - top
		draw_rect(Rect2(x, top, 16.0, height), Color(DARK, 0.9))
		draw_rect(Rect2(x + 11.0, top, 4.0, height), Color(BRIGHT, 0.26))
		draw_rect(Rect2(x - 5.0, bottom - 11.0, 26.0, 11.0), Color(DARKER, 0.85))
		var y := top + 52.0 + fmod(float(variation * 17), 60.0)
		while y < bottom - 20.0:
			draw_rect(Rect2(x - 3.0, y, 22.0, 6.0), Color(DARKER, 0.7))
			y += 150.0
	if not columns.is_empty():
		draw_notice(columns[0])

## 墙面告示板：小件必须依附大件，单摆会像随手贴上去的贴纸。
func draw_notice(x: float) -> void:
	var bottom := wall_bottom(x)
	var top := bottom - 214.0
	if top < ceiling_depth + 60.0 or top < waist_y:
		return
	var width := 52.0
	draw_rect(Rect2(x - 20.0, top, width, 62.0), Color(DARKER, 0.9))
	draw_rect(Rect2(x - 16.0, top + 4.0, width - 8.0, 54.0), Color(DARK, 0.95))
	draw_rect(Rect2(x - 16.0, top + 4.0, width - 8.0, 2.0), Color(BRIGHT, 0.3))
	for row in 4:
		draw_rect(Rect2(x - 11.0, top + 13.0 + row * 10.0, width - 20.0, 3.0), Color(DARKER, 0.75))

## 前景：左右两根立柱剪影。只占 x<160 与 x>1120，中央 960px 的玩法区保持干净。
## 作用是把机位读成"站在门框里"，同时给画面一个最暗的色阶。
func draw_foreground() -> void:
	for x in [22.0, 1212.0]:
		draw_rect(Rect2(x, 0, 46.0, H), FORE)
		draw_rect(Rect2(x + 5.0, 0, 3.0, H), Color(HILIGHT, 0.16))
		draw_rect(Rect2(x + 41.0, 0, 5.0, H), Color(DARKER, 0.5))
		var y := 96.0
		while y < H:
			draw_rect(Rect2(x + 5.0, y, 36.0, 3.0), Color(DARKER, 0.55))
			y += 168.0

## 每列的地面高度（像素）。取该列最靠上的实心格；没有实心格的列记为屏幕底。
func floor_tops() -> PackedFloat32Array:
	var tops := PackedFloat32Array()
	tops.resize(40)
	tops.fill(H)
	var layer := get_node_or_null(world) as TileMapLayer
	if layer == null:
		return tops
	var best := {}
	for cell in layer.get_used_cells():
		if cell.x < 0 or cell.x > 39 or cell.y < 0 or cell.y > 21:
			continue
		if not best.has(cell.x) or cell.y < best[cell.x]:
			best[cell.x] = cell.y
	for column in best:
		tops[column] = float(best[column]) * CELL
	return tops

func wall_bottom(x: float) -> float:
	var tops := floor_tops()
	return tops[clampi(int(x / CELL), 0, 39)]

## 立管位置：在 40px 网格上避开窗、通风口、壁柱和承重墙。
## 先挑离两侧最远的那一列——空墙才是需要竖线的地方——再按最小间距补第二根。
func pipe_columns() -> Array[float]:
	var blocked := blocked_spans()
	var picked: Array[float] = []
	var best_gap := -1.0
	var best_x := -1.0
	var x := 96.0
	while x <= W - 96.0:
		if not in_spans(x, blocked):
			var gap := minf(x, W - x)
			if gap > best_gap:
				best_gap = gap
				best_x = x
		x += 40.0
	if best_x < 0.0:
		return picked
	picked.append(best_x)
	x = 96.0
	while x <= W - 96.0 and picked.size() < pipe_count:
		if not in_spans(x, blocked) and absf(x - picked[0]) >= pipe_gap:
			picked.append(x)
		x += 40.0
	return picked

func blocked_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(0, 84), Vector2(W - 84, W)]
	var source := get_node_or_null(interior)
	if source == null:
		return spans
	var opening: Rect2i = source.get("window")
	spans.append(Vector2(opening.position.x - 52, opening.end.x + 52))
	var vent: Vector2i = source.get("vent")
	spans.append(Vector2(vent.x - 40, vent.x + 118))
	var pier: int = source.get("pier_x")
	spans.append(Vector2(pier - 50, pier + 50))
	return spans

func in_spans(x: float, spans: Array[Vector2]) -> bool:
	for span in spans:
		if x >= span.x and x <= span.y:
			return true
	return false
