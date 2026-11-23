@tool
extends Node2D
## 给单行单向平台补出「检修走道」的形态：板厚、下沿、托架、端头收口。
## 单向平台瓦片本身只画上半截（约 8px），单独摆放会像一条悬空细线。
## 这里按 World 层的地形数据反推走道段，纯补画结构，不参与碰撞。

@export var world: NodePath = ^"../World"

const CELL := 32.0
const DEPTH := 19.0          ## 板下沿的可见厚度
const BRACKET_GAP := 120.0   ## 托架间距
const DARK := Color("#46545d")
const LIT := Color("#8a9ba4")
const IRON := Color("#5c6d76")
const IRON_LIT := Color("#93a3ab")

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	var layer := get_node_or_null(world) as TileMapLayer
	if layer == null:
		return
	for run in walkway_runs(layer):
		draw_run(run)

## 把连续的单向平台格合并成水平段：{x0, x1, top, y}
func walkway_runs(layer: TileMapLayer) -> Array:
	var cells: Array[Vector2i] = []
	for cell in layer.get_used_cells():
		var data := layer.get_cell_tile_data(cell)
		if data != null and data.terrain_set == 1:
			cells.append(cell)
	cells.sort()
	var runs := []
	var index := 0
	while index < cells.size():
		var start := cells[index]
		var end := start
		while index + 1 < cells.size() \
				and cells[index + 1].y == start.y \
				and cells[index + 1].x == cells[index].x + 1:
			index += 1
			end = cells[index]
		runs.append({"x0": float(start.x) * CELL, "x1": float(end.x + 1) * CELL,
				"top": float(start.y) * CELL, "y": start.y})
		index += 1
	return runs

func draw_run(run: Dictionary) -> void:
	var x0: float = run.x0
	var x1: float = run.x1
	var top: float = run.top
	var body := top + 4.0
	var bottom := body + DEPTH
	# 板体：浅上沿 + 深板身 + 暗下沿
	draw_rect(Rect2(x0, body, x1 - x0, DEPTH), DARK)
	draw_rect(Rect2(x0, body, x1 - x0, 2.0), LIT)
	draw_rect(Rect2(x0, bottom - 2.0, x1 - x0, 2.0), Color(DARK.darkened(0.35), 0.9))
	# 板身横向接缝，避免读成一整根实心条
	var seam := x0 + 48.0
	while seam < x1 - 8.0:
		draw_line(Vector2(seam, body + 2.0), Vector2(seam, bottom - 2.0), Color(DARK.darkened(0.22), 0.6), 1.0)
		seam += 48.0
	# 端头收口
	for edge in [x0, x1 - 3.0]:
		draw_rect(Rect2(edge, body, 3.0, DEPTH), Color(LIT, 0.55))
	# 托架：板下每 BRACKET_GAP 一个，读作从墙里挑出来的牛腿
	var span := x1 - x0
	var count := maxi(1, int(round(span / BRACKET_GAP)))
	for i in range(1, count + 1):
		var cx := x0 + span * float(i) / float(count + 1)
		var half := minf(17.0, span * 0.25)
		var points := PackedVector2Array([
			Vector2(cx - half, bottom),
			Vector2(cx + half, bottom),
			Vector2(cx + half * 0.32, bottom + 22.0),
			Vector2(cx - half * 0.32, bottom + 22.0),
		])
		draw_colored_polygon(points, Color(IRON, 0.85))
		draw_line(Vector2(cx - half, bottom), Vector2(cx - half * 0.32, bottom + 22.0), Color(IRON_LIT, 0.5), 1.0)
		draw_line(Vector2(cx + half, bottom), Vector2(cx + half * 0.32, bottom + 22.0), Color(IRON_LIT, 0.5), 1.0)
