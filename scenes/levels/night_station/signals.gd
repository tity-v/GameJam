extends Node2D
## 同一入口与落点共用图形。出口上方逐灯显示各个联锁输入。
const PORTAL_COLORS := [Color("#83edf5"), Color("#f4a4e4"), Color("#e7c781")]

var portals: Array[Node] = []
var gates: Array[Node] = []
var plates: Array[Node] = []

var last_lights := -1

func _ready() -> void:
	for part in get_parent().get_node("Mechanisms").get_children():
		if "destination" in part:
			portals.append(part)
		elif "plate_paths" in part:
			gates.append(part)
		elif "accepts_boxes" in part:
			plates.append(part)

func _physics_process(_delta: float) -> void:
	var lights := 0
	for portal in portals:
		lights = (lights << 1) | int(portal.recorded_open)
	for gate in gates:
		for path in gate.plate_paths:
			lights = (lights << 1) | int(gate.get_node(path).active)
	for plate in plates:
		lights = (lights << 1) | int(plate.active)
	if lights != last_lights:
		last_lights = lights
		queue_redraw()

func glyph(pos: Vector2, index: int, tint: Color) -> void:
	if index == 0:
		draw_polyline(PackedVector2Array([pos+Vector2.UP*7,pos+Vector2.RIGHT*6,pos+Vector2.DOWN*7,pos+Vector2.LEFT*6,pos+Vector2.UP*7]),tint,2)
	elif index == 1:
		draw_arc(pos,7,0,TAU,16,tint,2)
		draw_arc(pos,3,0,TAU,12,tint,2)
	else:
		draw_rect(Rect2(pos-Vector2(5,5),Vector2(10,10)),tint,false,2)

func _draw() -> void:
	for i in portals.size():
		var part = portals[i]
		var tint: Color = PORTAL_COLORS[i % PORTAL_COLORS.size()]
		glyph(to_local(part.global_position)+Vector2(0,-42),i,tint if part.recorded_open else tint.darkened(0.43))
		glyph(to_local(part.destination.global_position)+Vector2(0,-8),i,tint)
	for gate in gates:
		var pos := to_local(gate.global_position)+Vector2(0,-9)
		for path in gate.plate_paths:
			var source = gate.get_node(path)
			draw_rect(Rect2(pos-Vector2.ONE,Vector2(9,7)),Color("#1b142c"))
			draw_rect(Rect2(pos,Vector2(7,5)),Color("#86f4e2") if source.active else Color("#946f9d"))
			pos.x += 12
	for plate in plates:
		var pos := to_local(plate.global_position)+Vector2(8,-17)
		var edge := Color("#acfff0") if plate.active else Color("#b4a0c5")
		var base := to_local(plate.global_position) - Vector2(0,5)
		draw_rect(Rect2(base,Vector2(plate.block_size.x,3)),edge)
		for x in [0.0, plate.block_size.x-4]:
			draw_rect(Rect2(base+Vector2(x,-2),Vector2(4,6)),edge)
		if plate.accepts_boxes and not plate.accepts_player:
			draw_rect(Rect2(pos,Vector2(8,7)),Color("#ffd58f"),false,2)
		else:
			draw_line(pos,pos+Vector2(4,0),Color("#9de7f4"),2)
			draw_rect(Rect2(pos+Vector2(6,-4), Vector2(4,6)),Color("#9de7f4"))
