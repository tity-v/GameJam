extends Node2D
## 光敏面板：嵌在竖井右缘的地面仪表，只被「够亮 + 光心落在感应区」的光驱动。
##
## 为什么用矩形感应区而不是「圆形光斑覆盖到面板」：
##   圆形光斑的判定长度就是光的半径（打火 150px），而打火半径足以照到
##   平台升到 100px 以上时的脚下——那会让玩家不打火也能爬到中层，
##   「你必须先死一次」这条设计就废了。感应区高度是独立参数，可以卡在
##   平台只升 60px 的位置，跟光的视觉半径解耦。
##
## 驱动条件三条同时成立：
##   1. 光源横向半径 ≥ min_radius（底光 40 不够，打火 96 / 虚影 72 够）
##   2. 光心落在感应区内
##   3. 光源在亮（虚影淡出到不足 min_radius 时不算）
##
## 固定火把不算光源：它们是 TileMapLayer 上的格子，本组件只认 torch_light
## 与 echo 两个组，避免「门口的火把把电梯顶上去」这种事故。
##
## ---- 可读性（11-26 重做）----
## 旧版是 32×8 的一条橙色地缝，玩家看不出它是「装置」，也看不出它和井里的
## 升降台有关系。现在补三件事，都是为了让「板 → 电 → 台」这条因果链在画面上
## 连起来：
##   1. 板本身做成工业仪表：金属框、四角螺丝、受光透镜、三颗状态灯；
##      待机时灯珠慢呼吸，玩家靠近呼吸加快（像在「等人」）。
##   2. 从板左缘往井内壁接一条电缆，再沿井壁竖直拉一条导轨到天花板；
##      点亮时导轨上有电流点往上跑。
##   3. 升降台右侧挂一个滑块夹在这条导轨上（见 lift.gd），台面和板同色同亮。
## 这样即使玩家还没搞懂「要持续供光」，也先看懂「这块板是给那个台子供电的」。

## 感应区尺寸（宽, 高），以本节点为底边中点向上展开。
## 现在只用于「玩家走进来触发引导提示」，判定改用「光斑覆盖到板」（见 is_lit）。
@export var zone := Vector2(120, 82)
## 光源横向半径门槛。40（底光）以下一律推不动。
@export var min_radius := 60.0
## 光斑中心到板中心的最大距离（＝打火半径 96）。判定改成「光斑覆盖到板」，
## 不再用「光心落在感应区」：后者会留出 x=340 的作弊缝，玩家站平台左缘打火
## 就被平台带着上中层、不死一次就通关。
## 虚影的照明半径，跟 Blackout 的 echo_radii 保持一致。
@export var echo_radii := Vector2(72, 100)
## 调试用：1 强制点亮，-1 强制熄灭，0 正常判定。
@export_range(-1, 1) var force := 0
## 要不要画井壁导轨。
## 板 A 嵌在井 A 右壁上，导轨是「板 → 电 → 台」视觉链的一半，必须有。
## 板 B 立在井 B 对面的悬挑台上，它要指的那条导轨在井 B 左壁，
## 不是自己脚边——靠 rail_local_x 挪过去，不用关导轨（关了平台 B 的滑块就悬空）。
@export var show_rail := true
## 导轨在本地的 x。板 A 用 -16（世界 384，正好是井 A 右壁）。
## 板 B 节点在 788，要指的井 B 左壁在世界 640，所以本地 -148。
@export var rail_local_x := -16.0
## 引导文案。板 B 的供光源是火盆不是玩家自己的火把（玩家够不到板 B），
## 直接沿用「打火照亮它」会把玩家往错误方向指。
@export var hint_fire := "打火照亮它"
@export var hint_lit := "光敏板 · 光要一直照着"

const PLATE := Color("#232f2c")
const PLATE_EDGE := Color("#465955")
const BOLT := Color("#6d8078")
const LENS_DARK := Color("#1a2422")
const COLD := Color("#5f8f92")
const WARM := Color("#f2c785")
const CABLE := Color("#2a3733")
const SPARK := Color("#ffd9a0")
const HAZARD := Color("#c9a227")

## 板体画在感应区**右侧**（局部 +60 起），不放在感应区中心。
##
## 这不是构图偏好，是硬约束：玩家要站在感应区里供光，如果板在他脚下，
## 32×44 的角色会把整块板盖住——"看不见"的一半原因在这里，光把板画大没用。
## 放到区外右侧，玩家站在 340~460 之间时板始终露在视野里。
const PLATE_RECT := Rect2(60.0, -22.0, 64.0, 22.0)

var lit := false

var _t := 0.0
## 点亮那一刻的时间戳，用来放一次扩张脉冲（最强的「它响应了」信号）。
var _lit_at := -99.0
## 一次性提示发过没有。玩家第一次站进感应区时提示「要持续」，
## 因为这一关最容易踩的坑不是「找不到板」，而是「按一下打火就跑」。
var _hinted := false
## 靠近板但还没打火时提示「打火照亮它」；发过就置 true，避免反复刷屏。
var _hinted_fire := false
var _player: Node2D
## 玩家是否在「一眼能看清板」的距离内。用来决定画不画感应区角标、
## 以及待机呼吸要不要加速——远景全亮会变成噪点，也失去「走近才发现」的节奏。
var _near := false


func zone_rect() -> Rect2:
	return Rect2(global_position + Vector2(-zone.x * 0.5, -zone.y), zone)


## 板中心（世界坐标）。判定是「光源的光斑覆盖到这个点」，
## 而不是「光心落在感应区」。两者的差别是：光斑判定按半径覆盖，
## 玩家站平台左缘（x=340）打火时，光斑右缘 436 够不到板中心 492，推不动；
## 只有站到板附近（x≥460）光斑才扫得到板，而那时平台已经在他左边升上去了，
## 玩家上不去——正好守住「必须死一次」。
func _plate_center() -> Vector2:
	return global_position + PLATE_RECT.get_center()


func is_lit() -> bool:
	if force != 0:
		return force > 0
	var plate := _plate_center()
	for light in get_tree().get_nodes_in_group("torch_light"):
		var radii: Variant = light.get("radii")
		if radii is Vector2 and radii.x >= min_radius \
			and light.global_position.distance_to(plate) <= radii.x:
			return true
	for echo in get_tree().get_nodes_in_group("echo"):
		if not echo.is_active():
			continue
		var fade: float = maxf(0.01, 1.0 - float(echo._fade_time) / float(echo.fade_duration))
		if echo_radii.x * fade < min_radius:
			continue
		if echo.body_rect().get_center().distance_to(plate) <= echo_radii.x * fade:
			return true
	return false


func _ready() -> void:
	add_to_group("mechanism")
	_player = get_tree().get_first_node_in_group("player") as Node2D


## R 键：把「已经提示过」也清掉。重来一次就该重新教一次，
## 否则玩家按了 R 反而拿不到这句唯一的说明。
func reset_mechanism() -> void:
	_hinted = false
	_hinted_fire = false


func _flash(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("flash"):
		hud.call("flash", text)


func _physics_process(dt: float) -> void:
	_t += dt
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_near = _player != null and is_instance_valid(_player) \
		and _player.global_position.distance_to(global_position) < 260.0
	# ---- 引导：三段，由玩家状态驱动，各只发一次 ----
	# 1. 靠近板但还没打火（_near 且板没亮）→ 提示「打火照亮它」。
	#    这是回答「玩家怎么知道要打火」的关键：不能等他踩进感应区才说，
	#    那时他已经绕一圈了；要在「靠近板」这个更早的时机就点破。
	if _near and not _hinted_fire and not lit:
		_hinted_fire = true
		_flash(hint_fire)
	# 2. 第一次踩进感应区（还没打火成功）→ 补一句「光要一直照着」，
	#    提醒他这不是按一下就完事，而是持续供光。
	if not _hinted and _player != null and is_instance_valid(_player):
		var body := Rect2(_player.global_position, Vector2(32, 44))
		if zone_rect().intersects(body):
			_hinted = true
			if not lit:
				_flash(hint_lit)
	# 每帧都重算并重绘：面板亮/灭是本关最重要的一条反馈，
	# 玩家必须能在按下打火的同一帧看见它变暖。
	var now := is_lit()
	if now != lit:
		lit = now
		if lit:
			_lit_at = _t
	queue_redraw()


func _draw() -> void:
	# 呼吸周期：无人时 1.1Hz，玩家靠近后加快到 2.2Hz（「它注意到你了」）。
	var rate := 2.2 if _near else 1.1
	var pulse := 0.5 + 0.5 * sin(_t * rate)
	var glow := WARM if lit else COLD

	if show_rail:
		_draw_rail(glow)
	_draw_plate(glow, pulse)
	if lit:
		_draw_beam()
		_draw_pulse()
	if _near:
		_draw_zone_brackets(Color(glow.r, glow.g, glow.b, 0.28))


## 井壁导轨 + 到板的电缆。点亮时三个光点从板这边往井口上游。
func _draw_rail(glow: Color) -> void:
	var top := -global_position.y  # 本地 y 对应世界 y=0
	var bx := PLATE_RECT.position.x
	# 导轨本体要比暗色电缆亮一档，否则在 1x 分辨率下就是一条看不见的噪点
	var rail_col := Color("#5c7169") if not lit else Color("#8aa294")
	# 电缆：板左缘贴地走到井壁，再沿井壁竖直拉到天花板
	draw_line(Vector2(bx, -4.0), Vector2(rail_local_x, -4.0), CABLE, 3.0)
	draw_line(Vector2(rail_local_x, -4.0), Vector2(rail_local_x, top), Color(0.06, 0.09, 0.08, 0.9), 5.0)
	draw_line(Vector2(rail_local_x, -4.0), Vector2(rail_local_x, top), rail_col, 2.0)
	# 每隔 32px 一个固定卡扣，让竖线读起来是「一条固定在墙上的导轨」而不是噪点
	var y := 0.0
	while y > top:
		draw_rect(Rect2(rail_local_x - 4.0, y, 10.0, 3.0), rail_col)
		y -= 32.0

	if not lit:
		return
	# 电流点：先沿地面从板跑到井壁，再沿导轨往上，三个错开相位
	for i in 3:
		var phase := fmod(_t * 0.55 + i / 3.0, 1.0)
		var pos: Vector2
		if phase < 0.2:
			pos = Vector2(lerpf(bx, rail_local_x, phase / 0.2), -4.0)
		else:
			pos = Vector2(rail_local_x, lerpf(-4.0, top * 0.75, (phase - 0.2) / 0.8))
		var a := sin(phase * PI)  # 两端淡出，中间最亮
		# 拖尾：沿来路补三个更小更淡的点，在 1x 下才看得出是「在跑」
		for k in 4:
			var trail := pos + (Vector2(0, 8.0) if phase >= 0.2 else Vector2(-8.0, 0)) * k
			draw_circle(trail, 4.0 - k * 0.75, Color(SPARK.r, SPARK.g, SPARK.b, a * (0.95 - k * 0.22)))
		draw_circle(pos, 14.0, Color(SPARK.r, SPARK.g, SPARK.b, a * 0.16))
		draw_circle(pos, 7.0, Color(SPARK.r, SPARK.g, SPARK.b, a * 0.22))


func _draw_plate(glow: Color, pulse: float) -> void:
	var body := PLATE_RECT
	var bx := body.position.x
	var by := body.position.y
	var cx := body.get_center().x

	# 点亮时先在板外扩三层暖光，让「亮/暗」的差别在余光里就能感觉到
	if lit:
		for k in 3:
			var pad := 5.0 + k * 6.0
			draw_rect(Rect2(body.position - Vector2(pad, pad),
				body.size + Vector2(pad * 2.0, pad * 2.0)),
				Color(WARM.r, WARM.g, WARM.b, 0.10 - k * 0.028))

	# 底座阴影：让板「嵌下去」而不是浮在地面上
	draw_rect(Rect2(body.position + Vector2(-3, 3), body.size + Vector2(6, 2)), Color(0, 0, 0, 0.45))
	draw_rect(body, PLATE)
	draw_rect(body, PLATE_EDGE, false, 1.0)
	# 上沿一条工业黄警示线：一眼区分「设备」和「地砖」
	draw_rect(Rect2(bx, by, body.size.x, 3.0), HAZARD)
	draw_rect(Rect2(bx + 2.0, by + 1.0, body.size.x * 0.55, 1.0), Color(0, 0, 0, 0.55))
	# 四角螺丝
	for sx in [bx + 4.0, body.end.x - 4.0]:
		for sy in [by + 12.0, -4.0]:
			draw_circle(Vector2(sx, sy), 1.7, BOLT)

	# 受光透镜：朝左（朝井口/朝玩家来的方向）。
	# 待机时刻意压得很暗——「亮起来」这件事必须是一个变化，而不是一直亮着。
	var lens := Rect2(bx + 6.0, by + 7.0, 32.0, 10.0)
	draw_rect(lens, LENS_DARK)
	var lens_a := 0.98 if lit else 0.08 + 0.14 * pulse
	draw_rect(lens, Color(glow.r, glow.g, glow.b, lens_a))
	draw_rect(lens, Color(glow.r, glow.g, glow.b, minf(1.0, lens_a + 0.25)), false, 1.0)
	# 透镜里的两道斜纹（玻璃反光）：只有点亮时才给，待机时它是一块暗玻璃
	if lit:
		draw_line(lens.position + Vector2(6, 7), lens.position + Vector2(13, 3),
			Color(1, 1, 1, 0.40), 1.0)
		draw_line(lens.position + Vector2(17, 7), lens.position + Vector2(24, 3),
			Color(1, 1, 1, 0.24), 1.0)

	# 三颗状态灯：竖排在板右端，待机时呼吸，点亮时依次跳（像在读三相电）
	for i in 3:
		var pos := Vector2(body.end.x - 13.0, by + 6.0 + i * 6.0)
		var a: float
		if lit:
			a = 0.55 + 0.45 * sin(_t * 8.0 - i * 1.3)
		else:
			a = 0.10 + 0.30 * (0.5 + 0.5 * sin(_t * (2.2 if _near else 1.1) - i * 0.7))
		draw_circle(pos, 5.4, Color(glow.r, glow.g, glow.b, a * 0.18))
		draw_circle(pos, 2.2, Color(glow.r, glow.g, glow.b, a))

	# 点亮时板面整体蒙一层暖色，读数上「整块板活了」
	if lit:
		draw_rect(body, Color(WARM.r, WARM.g, WARM.b, 0.10))
		draw_rect(Rect2(bx + 4.0, by - 26.0, 40.0, 24.0), Color(WARM.r, WARM.g, WARM.b, 0.10))
		draw_rect(Rect2(bx + 10.0, by - 46.0, 28.0, 20.0), Color(WARM.r, WARM.g, WARM.b, 0.06))


## 点亮那一刻放一次向外扩张的双环。这是「它响应了」最强的一帧信号：
## 玩家按下打火，板先亮，再荡开一圈光——因果被写在动画里，不需要文字。
func _draw_pulse() -> void:
	var age := _t - _lit_at
	if age < 0.0 or age > 0.5:
		return
	var k := age / 0.5
	var a := (1.0 - k) * (1.0 - k)
	var c := Vector2(PLATE_RECT.get_center().x, -12.0)
	for i in 2:
		var kk := clampf(k - i * 0.14, 0.0, 1.0)
		var r := lerpf(12.0, 78.0, kk)
		# 完整一圈（下半圈压在地面里看不见，无所谓），比半圆读起来更像冲击波
		draw_arc(c, r, 0.0, TAU, 36,
			Color(WARM.r, WARM.g, WARM.b, a * (0.70 - i * 0.28)), 2.0)


## 点亮时从板面往上的一束窄光，告诉玩家「照这里」是有效的。
func _draw_beam() -> void:
	var bx := PLATE_RECT.position.x
	var by := PLATE_RECT.position.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx + 8.0, by),
		Vector2(bx + 40.0, by),
		Vector2(bx + 50.0, by - 60.0),
		Vector2(bx - 2.0, by - 60.0),
	]), Color(WARM.r, WARM.g, WARM.b, 0.10))


## 感应区的四个角标：只在玩家靠近时出现，避免全图噪点。
## 它回答的是「光要打在哪」，比画一整条虚线框克制。
func _draw_zone_brackets(col: Color) -> void:
	var r := Rect2(-zone.x * 0.5, -zone.y, zone.x, zone.y)
	var arm := 10.0
	for corner in [r.position, Vector2(r.end.x, r.position.y)]:
		var sx := 1.0 if corner.x < 0.0 else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0.0), col, 1.0)
		draw_line(corner, corner + Vector2(0.0, arm), col, 1.0)
	# 下沿贴地，只画两侧一小段，免得和板体打架
	for x in [r.position.x, r.end.x]:
		var dir := 12.0 if x < 0.0 else -12.0
		draw_line(Vector2(x, -4.0), Vector2(x + dir, -4.0), col, 1.0)
