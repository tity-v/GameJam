extends AnimatableBody2D
## 3-2 的光控升降台。
##
## 运动规则只有一条，但要分成三段理解：
##   有光  → 以 rise_accel 加速，封顶 up_speed（140）
##   无光  → 以 fall_accel 减速（**不是立刻反向**），到 0 后向下加速，封顶 fall_speed（280）
##   到限位 → 停住，速度清零
##
## 「无光不是立刻掉，是先滑一段再掉」是这关卡的核心手感：
## 光断的那一刻平台还在往上走 0.33 秒、多爬 23px，玩家会先看到「它还在动」，
## 然后才意识到「它开始往下」。如果直接反向，玩家读到的是「开关」，
## 而不是「一台有质量的机器」。
##
## 原点在**台面**中点，板体从原点向下 16px（吊在半空的一块板，不是一块砖）。
## 这样 position.y 就等于「玩家脚下那面的高度」，可以直接用 top_y / bottom_y
## 描述行程，不必再减板厚——写反过一次，表现是玩家站上去比台面高 16px。

@export var sensor_path: NodePath
## 行程：台面最低 / 最高（世界坐标 y）
@export var bottom_y := 576.0
@export var top_y := 128.0
## 上升：加速度与巡航速度
@export var rise_accel := 480.0
@export var up_speed := 140.0
## 失光：先刹车再下落，下落更快（机器比人重）
@export var fall_accel := 420.0
@export var fall_speed := 280.0

const IRON := Color("#3b4a46")
const EDGE := Color("#6d8078")
const CABLE := Color("#243130")
const HALF_WIDTH := 44.0
const THICKNESS := 16.0

## 当前竖直速度，正 = 上升（往下落时为负）。探针直接读这个。
var speed := 0.0
var lit := false

var _sensor: Node


func _ready() -> void:
	add_to_group("mechanism")
	_sensor = get_node_or_null(sensor_path)
	position.y = bottom_y


## R / 重来时回到底部静止。台面高度也归位，否则复活后平台停在半空。
func reset_mechanism() -> void:
	speed = 0.0
	position.y = bottom_y


func _physics_process(delta: float) -> void:
	lit = _sensor_lit()
	if lit:
		speed = minf(speed + rise_accel * delta, up_speed)
	else:
		speed = maxf(speed - fall_accel * delta, -fall_speed)

	var next := position.y - speed * delta
	if next <= top_y:
		next = top_y
		speed = 0.0
	elif next >= bottom_y:
		next = bottom_y
		speed = 0.0
	position.y = next
	queue_redraw()


func _sensor_lit() -> bool:
	if _sensor == null:
		return false
	if _sensor.has_method("is_lit"):
		return _sensor.call("is_lit")
	return false


func _draw() -> void:
	# 缆绳：从台板两端一直拉到天花板（本地 y = -position.y 就是世界 y=0）。
	var ceiling := -position.y
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 30.0, 0.0), Vector2(side * 30.0, ceiling), CABLE, 1.0)
	# 台板：顶面亮边 + 底框 + 两条防滑纹
	draw_rect(Rect2(-HALF_WIDTH, 0.0, HALF_WIDTH * 2.0, THICKNESS), IRON)
	draw_rect(Rect2(-HALF_WIDTH, 0.0, HALF_WIDTH * 2.0, 3.0), EDGE)
	draw_rect(Rect2(-HALF_WIDTH, THICKNESS - 2.0, HALF_WIDTH * 2.0, 2.0), Color(0.1, 0.13, 0.13))
	for i in 3:
		var x := -26.0 + i * 26.0
		draw_rect(Rect2(x, 6.0, 14.0, 2.0), Color(EDGE.r, EDGE.g, EDGE.b, 0.45))
	# 两端的吊耳
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 30.0 - 4.0, -4.0, 8.0, 5.0), EDGE)
