@tool
extends Node2D

@export_range(1, 5) var bay := 1:
	set(value):
		bay = value
		queue_redraw()

const BLACK := Color("#0b1416")
const IRON := Color("#192a2a")
const PAINT := Color("#293a36")
const EDGE := Color("#41504a")
const RUST := Color("#654736")
const BRASS := Color("#927052")
const LIGHT := Color("#edc899")

func plate(x:int,y:int,w:int,h:int,c:Color) -> void:
	draw_rect(Rect2(x,y,w,h), c)

func bar(x:int,y:int,u:int,v:int,c:Color,width:=2) -> void:
	draw_line(Vector2(x,y),Vector2(u,v),c,width,false)

func disc(x:int,y:int,r:int,c:Color) -> void:
	draw_circle(Vector2(x,y),r,c)

func pipe(x:int,y:int,w:int,d:int) -> void:
	plate(x,y,w,d,BLACK)
	plate(x,y+2,w,d-6,PAINT)
	plate(x,y+3,w,2,EDGE)
	for joint in range(x+19,x+w-7,116):
		plate(joint,y-3,8,d+4,IRON)
		plate(joint+1,y-2,2,d+1,RUST)

func wheel(x:int,y:int,r:int) -> void:
	disc(x,y,r+5,BLACK)
	disc(x,y,r,EDGE)
	disc(x,y,r-5,IRON)
	for i in 8:
		var tip := Vector2.from_angle(i*PI/4+0.19)*(r-7)
		bar(x,y,x+roundi(tip.x),y+roundi(tip.y),PAINT,6)
	disc(x,y,10,RUST)
	disc(x,y,5,BLACK)

func lamp(x:int,y:int) -> void:
	bar(x,84,x,y,BLACK,3)
	plate(x-16,y,32,6,BLACK)
	plate(x-12,y+6,24,4,BRASS)
	plate(x-8,y+7,16,2,LIGHT)
	var cone := PackedVector2Array([Vector2(x-10,y+10),Vector2(x+10,y+10),Vector2(x+83,620),Vector2(x-66,620)])
	draw_colored_polygon(cone,Color(0.65,0.63,0.45,0.035))

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 451+bay
	# 旧桁架、跨梁和断线贯穿整座厂房。
	for x in range(-20,1280,112):
		bar(x,38,x+56,82,IRON,7)
		bar(x+56,82,x+112,38,IRON,7)
		plate(x+52,75,9,8,PAINT)
	plate(0,33,1280,7,IRON)
	plate(0,80,1280,9,BLACK)
	pipe(0,102,1280,17)
	for i in 85:
		var x := rng.randi_range(0,1276)
		var y := rng.randi_range(128,625)
		plate(x,y,rng.randi_range(1,4),rng.randi_range(3,28),Color("#19262478"))
	match bay:
		1: # 装卸卷帘门和停用的控制箱。
			plate(310,231,432,363,BLACK)
			for y in range(246,577,12):
				plate(324,y,404,9,IRON)
				plate(324,y,404,1,PAINT)
			plate(752,414,56,83,PAINT)
			for i in 6: plate(759,423+i*4,36,2,BLACK)
			disc(765,470,4,BRASS)
		2: # 墙脚只留下拆除设备后的残管和手轮。
			pipe(335,495,114,10)
			plate(386,481,7,16,IRON)
			wheel(389,478,8)
			plate(445,492,5,16,RUST)
		3: # 双卷扬轮、悬索与检修梯。
			for x in [523,738]:
				bar(x-59,283,x-59,610,PAINT,3)
				bar(x+59,283,x+59,574,RUST,2)
				wheel(x,282,61)
			for x in [875,911]: plate(x,135,4,458,PAINT)
			for y in range(145,587,19): plate(878,y,34,3,EDGE)
		4: # 两排配电柜，缺失的面板露出母线。
			for i in 7:
				var x := 190+i*124
				plate(x,365,112,227,BLACK)
				plate(x+4,369,103,217,IRON)
				for j in 8: plate(x+14,390+j*5,62,2,BLACK)
				if i==4:
					plate(x+9,440,83,111,BLACK)
					for j in 4: plate(x+20+j*15,445,3,98,RUST)
				else:
					plate(x+85,477,4,18,EDGE)
					plate(x+14,451,19,6,BRASS)
		5: # 桥吊横梁、行车和空钩。
			plate(90,215,1092,34,IRON)
			plate(84,214,1104,5,EDGE)
			plate(84,247,1104,8,BLACK)
			for x in range(105,1176,36): plate(x,226,3,3,RUST)
			plate(713,229,136,52,BLACK)
			pipe(725,253,110,18)
			for x in [752,786]: bar(x,276,767,438,EDGE,2)
			disc(767,442,11,RUST)
			bar(767,448,767,465,PAINT,6)
			bar(767,465,778,470,PAINT,6)
			bar(778,470,786,459,PAINT,5)
	for i in 3:
		var x := 133+i*409+bay*9
		bar(x,119,x+8,148+i*5,BLACK,2)
		bar(x+8,148+i*5,x+22,155+i*5,BLACK,2)
	lamp([810,392,902,593,676][bay-1], [203,188,175,224,151][bay-1])
