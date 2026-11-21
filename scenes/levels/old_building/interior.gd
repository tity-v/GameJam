@tool
extends Node2D
## 固定机位的楼内布景。位置由房间配置，全部图形只在重绘时绘制。

@export var window := Rect2i(104, 60, 438, 136):
	set(value):
		window = value
		queue_redraw()
@export var vent := Vector2i(918, 126):
	set(value):
		vent = value
		queue_redraw()
@export var pier_x := 820:
	set(value):
		pier_x = value
		queue_redraw()

@export_enum("空窗", "封窗", "线缆", "双封板") var damage := 0:
	set(value):
		damage = value
		queue_redraw()

const STEEL := Color("#657a87")
const REVEAL := Color("#6f8390")
const GLAZE := Color("#b4c4cb")
const LIGHT := Color("#d1dbdd")

func panel(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x,y,w,h), color)

func shape(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw() -> void:
	draw_window()
	draw_vent()
	draw_spall(Vector2(pier_x-36,393))
	draw_spall(Vector2(vent.x+103,398))
	draw_spall(Vector2(window.position.x+28,window.end.y+15))

func draw_window() -> void:
	# 玻璃内的楼群使用雾色。破口和斜光只集中在一扇窗上。
	var x := window.position.x
	var y := window.position.y
	var w := window.size.x
	var h := window.size.y
	var count := maxi(3,roundi(w/84.0))
	var step := floori(float(w)/count)
	panel(x-9,y-7,w+18,h+18,REVEAL)
	panel(x-4,y-2,w+8,h+8,Color("#718793"))
	panel(x,y,w,h,GLAZE)
	panel(x,y,w, h*0.36,Color("#becdd2"))
	var horizon := y+h-18
	for i in range(count*2):
		var left := x+floori(i*w/float(count*2))
		var right := x+floori((i+1)*w/float(count*2))
		var top: int = horizon - [4,17,11,30,22,5,15][i%7]
		panel(left,top,right-left,y+h-top,Color("#9eafb9"))
		if i%4==2:
			panel(left+7,top-10,5,10,Color("#9eafb9"))
	# 对街楼顶的蓄水箱和支架只露出剪影。
	var tank := Vector2(x+roundi(w*0.73), y+h-52)
	panel(tank.x,tank.y,22,13,Color("#99acb6"))
	shape([tank+Vector2(-2,0),tank+Vector2(11,-6),tank+Vector2(24,0)],Color("#99acb6"))
	for dx in [3,16]:
		panel(tank.x+dx,tank.y+13,3,13,Color("#99acb6"))
	var torn := x+step*clampi(1+damage%2,1,count-2)
	var mid := y+roundi(h*0.34)
	shape([Vector2(torn,mid),Vector2(torn+step,mid),Vector2(torn+step,mid+13),Vector2(torn+step-19,mid+29),Vector2(torn+step-38,mid+18),Vector2(torn+13,mid+45),Vector2(torn,mid+41)],LIGHT)
	draw_polyline(PackedVector2Array([Vector2(torn+step-38,mid+18),Vector2(torn+step-29,mid+39),Vector2(torn+step-33,mid+48)]),Color("#93a6b0"),2)
	draw_polyline(PackedVector2Array([Vector2(torn+13,mid+43),Vector2(torn+8,mid+54),Vector2(torn+12,mid+63)]),Color("#8ea2ad"),2)
	if damage == 1 or damage == 3:
		var boarded := Vector2(x+w-step,y+h-9)
		for offset in ([0,25] if damage == 3 else [0]):
			var a: Vector2 = boarded-Vector2(0,offset)
			var b := a+Vector2(step,-28)
			shape([a,b,b-Vector2(0,9),a-Vector2(0,9)],Color("#788891"))
			draw_line(a-Vector2(0,8),b-Vector2(0,8),Color("#9da8aa"),2)
	for i in range(1,count):
		panel(x+i*step,y,6,h,STEEL)
		panel(x+i*step+6,y,2,h,Color("#94a6af"))
	panel(x,mid-2,w,5,STEEL)
	panel(x-9,y+h+3,w+22,5,Color("#a1b0b8"))
	panel(x-7,y+h+8,w+18,4,REVEAL)
	var start := Vector2(torn+4,y+h+12)
	var ray := PackedVector2Array([start,start+Vector2(step-11,0),start+Vector2(step+118,220),start+Vector2(128,220)])
	var lit := Color(0.84,0.89,0.89,0.18)
	var faded := Color(lit,0)
	draw_polygon(ray,PackedColorArray([lit,lit,faded,faded]))

func draw_vent() -> void:
	var x := vent.x
	var y := vent.y
	# 走线和检修格栅共用一个墙面落点，不占用可行走区域。
	draw_polyline(PackedVector2Array([Vector2(x-100,30),Vector2(x-100,y+12),Vector2(x-92,y+20),Vector2(x,y+20)]),REVEAL,3)
	for cy in range(64,y,54):
		panel(x-103,cy,8,3,Color("#778c98"))
	panel(x,y,76,38,REVEAL)
	panel(x+3,y+3,70,32,Color("#9aabb3"))
	for row in range(4):
		panel(x+7,y+7+row*6,62,3,Color("#7f929e"))
	panel(x,y+38,76,3,Color("#8295a0"))
	if damage == 2:
		draw_polyline(PackedVector2Array([Vector2(x+8,y+40),Vector2(x+10,y+63),Vector2(x+23,y+79),Vector2(x+34,y+77),Vector2(x+37,y+61)]),STEEL,3)
		draw_line(Vector2(x+37,y+61),Vector2(x+40,y+56),Color("#9eaeb6"),2)

func draw_spall(at: Vector2) -> void:
	var contour := PackedVector2Array([Vector2(0,0),Vector2(40,0),Vector2(40,3),Vector2(29,3),Vector2(25,8),Vector2(17,8),Vector2(13,13),Vector2(5,11),Vector2(7,6),Vector2(0,6)])
	for i in contour.size():
		contour[i] += at
	draw_colored_polygon(contour,Color("#81949f"))
