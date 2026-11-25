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
const COLD := Color("#5f8f92")
const WARM := Color("#f2c785")
const HALF_WIDTH := 44.0
const THICKNESS := 16.0
## 井壁导轨相对台面中心的 x（世界 384 - 336 = 48）。
## 必须和 light_sensor.gd 的 RAIL_X 对上，否则滑块会飘在导轨外面。
@export var rail_x := 48.0

## 当前竖直速度，正 = 上升（往下落时为负）。探针直接读这个。
var speed := 0.0
var lit := false

var _sensor: Node
## R 键复位是「挂个待办」，真正搬位置留到本帧 _physics_process 里做。
## 不能直接在 reset_mechanism() 里写 position：AnimatableBody2D 的 transform
## 归物理服务器管，物理帧之外赋值下一帧就被回滚——实测 `lift.position.y = 300`
## 之后再读还是 128，按 R 平台会永远停在半空。
var _reset_pending := false


func _ready() -> void:
	add_to_group("mechanism")
	_sensor = get_node_or_null(sensor_path)
	position.y = bottom_y


## R / 重来时回到底部静止。台面高度也归位，否则复活后平台停在半空。
func reset_mechanism() -> void:
	speed = 0.0
	_reset_pending = true


func _physics_process(delta: float) -> void:
	if _reset_pending:
		_reset_pending = false
		position.y = bottom_y
		speed = 0.0
		lit = false
		queue_redraw()
		return
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
	# 右侧滑块：夹在井壁那条导轨上（导轨由 light_sensor.gd 画，世界 x=384）。
	# 这是「板 → 电 → 台」视觉链的最后一环：玩家看到电流沿导轨往上跑，
	# 再看到这个滑块带着台面走，就明白台子是被那块板供着电的。
	var glow := WARM if lit else COLD
	var slide := Rect2(rail_x - 6.0, 2.0, 10.0, 10.0)
	draw_rect(slide, EDGE)
	draw_rect(Rect2(slide.position + Vector2(2.0, 1.0), Vector2(6.0, 3.0)), Color(0.10, 0.14, 0.13))
	draw_circle(Vector2(rail_x - 1.0, 8.0), 3.6, Color(glow.r, glow.g, glow.b, 0.16 if not lit else 0.30))
	draw_circle(Vector2(rail_x - 1.0, 8.0), 1.8, Color(glow.r, glow.g, glow.b, 0.45 if not lit else 1.0))
