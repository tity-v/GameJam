extends AnimatableBody2D
## 3-2 的光控升降台：**有光就自动循环**（到顶不用操作，自己落回来）。
##
## 一遍循环：底部停 → 升到顶 → 顶部停 → 落回底部 → 底部停 →（还亮着就再升）
##
## 「循环」指的是**顶部自动下降、底部自动再升**，省掉操作；
## 但**上升过程必须持续有光**，光一断当帧转下落。这两件事不矛盾：
##   玩家要解决的是时机（什么时候上去、什么时候在顶部走出去），
##   而不是「按一下开关让台子自己跑完一整圈」。
##
## 为什么上升必须持续供光——这是第一段谜题的唯一支点：
##   若「点亮一次＝跑完整圈」，玩家可以自己站到板旁把手电举起来、再跑回井口
##   踏上台面白嫖上去，虚影和火盆全成摆设（实测漏洞，见 probe_selfsolo.gd）。
##   现在光断即落：在板旁点亮的人一离开，台子就往回掉；而站在台面上的人
##   手电够不到板心，板本来就不亮。能让台子一直升的只有「另一束留在板旁的光」。
##
## 两端都要停留，缺一个就玩不成：
##   底停 1.2s —— 玩家从地面走上来需要这点时间，否则台子永远在跑，上不去
##   顶停 1.8s —— 玩家从台面走到楼板（第一段还要跳 36px），不然必被带回去
##
## 失光时**从当前位置落回底部**，绝不停在半空：玩家在顶部就走出去了，
## 在途中就跟着台子一起下来，不会出现「人挂在半空、只能等」的状态。
##
## 原点在**台面**中点，板体从原点向下 16px（吊在半空的一块板，不是一块砖）。
## 这样 position.y 就等于「玩家脚下那面的高度」，可以直接用 top_y / bottom_y
## 描述行程，不必再减板厚——写反过一次，表现是玩家站上去比台面高 16px。
##
## 台板的 CollisionShape2D 在场景里设了 one_way_collision：**从下方完全没有碰撞**。
## 必须保留，否则会出死锁——平台落回时板底（592）到凹槽地面（608）只剩 16px，
## 而玩家判定高 44px，物理引擎只能把人按进地面，跳跃横移全部失效。
## 单向之后平台直接穿过人，玩家原地一跳就站到台面上，也才能「追上升中的台子」
## （第一段复活后跑过来时，台子常常已经在升了）。

@export var sensor_path: NodePath
## 行程：台面最低 / 最高（世界坐标 y）
@export var bottom_y := 576.0
@export var top_y := 128.0
## 上升：加速度与巡航速度。
## up_speed 100：224px 行程约 2.34s，玩家从台面走到楼板来得及，
## 也让「追上升中的台子」可行（玩家起跳速度远高于它）。
@export var rise_accel := 480.0
@export var up_speed := 100.0
## 下落：加速度与巡航速度（机器比人重，落得比升得快）
@export var fall_accel := 420.0
@export var fall_speed := 280.0
## 两端停留时间
@export var top_dwell := 1.8
@export var bottom_dwell := 1.2

## 停着 / 上升 / 顶部停留 / 下落 / 底部停留
enum Phase { PARKED, RISING, TOP_WAIT, FALLING, BOTTOM_WAIT }

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
## 当前处于循环的哪一段。探针/测试直接读它判断「在不在动」。
var phase := Phase.PARKED

var _sensor: Node
var _wait := 0.0
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
		phase = Phase.PARKED
		_wait = 0.0
		queue_redraw()
		return

	lit = _sensor_lit()
	# 上升阶段必须**持续**有光：光一断，当帧就转下落。
	#
	# 这一条是「第一段必须死一次」的物理保障，缺了它就有一个通行漏洞：
	# 玩家自己拿着手电站到板旁（x≈450，离板心 42，板亮）→ 平台开始升 →
	# 他立刻跑回井口踏上台面。旧版（失光仍跑完这一圈）他就能这么白嫖上去，
	# 虚影和火盆都变成摆设。
	#
	# 加上这一条之后，两种「一个人干两件事」的企图同时被堵死：
	#   - 在板旁点亮 → 光随身带走 → 平台立刻回落，追不上
	#   - 站在台面上 → 手电 120 够不到板心 141 → 板本来就灭着，平台根本不动
	# 唯一能让平台一直升的办法，是让「另一束光」留在板旁：虚影或火盆。
	if phase == Phase.RISING and not lit:
		phase = Phase.FALLING
	match phase:
		Phase.PARKED:
			speed = 0.0
			if lit:
				phase = Phase.RISING
		Phase.RISING:
			speed = minf(speed + rise_accel * delta, up_speed)
			position.y -= speed * delta
			if position.y <= top_y:
				position.y = top_y
				speed = 0.0
				phase = Phase.TOP_WAIT
				_wait = 0.0
		Phase.TOP_WAIT:
			speed = 0.0
			_wait += delta
			# 失光就不再等满：玩家多半正要下来，多停一秒都是折磨
			if _wait >= top_dwell or not lit:
				phase = Phase.FALLING
		Phase.FALLING:
			speed = maxf(speed - fall_accel * delta, -fall_speed)
			position.y -= speed * delta
			if position.y >= bottom_y:
				position.y = bottom_y
				speed = 0.0
				phase = Phase.BOTTOM_WAIT
				_wait = 0.0
		Phase.BOTTOM_WAIT:
			speed = 0.0
			_wait += delta
			if _wait >= bottom_dwell:
				_wait = 0.0
				phase = Phase.RISING if lit else Phase.PARKED
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
