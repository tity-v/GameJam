extends Node2D
## 光敏面板：铺在竖井底部的地面上，只被「够亮 + 光心落在感应区」的光驱动。
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

## 感应区尺寸（宽, 高），以本节点为底边中点向上展开。
@export var zone := Vector2(120, 82)
## 光源横向半径门槛。40（底光）以下一律推不动。
@export var min_radius := 60.0
## 虚影的照明半径，跟 Blackout 的 echo_radii 保持一致。
@export var echo_radii := Vector2(72, 100)
## 调试用：1 强制点亮，-1 强制熄灭，0 正常判定。
@export_range(-1, 1) var force := 0

const PLATE := Color("#2b3a37")
const PLATE_EDGE := Color("#465955")
const COLD := Color("#5f8f92")
const WARM := Color("#f2c785")

var lit := false


func zone_rect() -> Rect2:
	return Rect2(global_position + Vector2(-zone.x * 0.5, -zone.y), zone)


func is_lit() -> bool:
	if force != 0:
		return force > 0
	var area := zone_rect()
	for light in get_tree().get_nodes_in_group("torch_light"):
		var radii: Variant = light.get("radii")
		if radii is Vector2 and radii.x >= min_radius and area.has_point(light.global_position):
			return true
	for echo in get_tree().get_nodes_in_group("echo"):
		if not echo.is_active():
			continue
		var fade: float = maxf(0.01, 1.0 - float(echo._fade_time) / float(echo.fade_duration))
		if echo_radii.x * fade < min_radius:
			continue
		if area.has_point(echo.body_rect().get_center()):
			return true
	return false


func _physics_process(_dt: float) -> void:
	# 每帧都重算并重绘：面板亮/灭是本关最重要的一条反馈，
	# 玩家必须能在按下打火的同一帧看见它变暖。
	var now := is_lit()
	if now != lit:
		lit = now
	queue_redraw()


func _draw() -> void:
	# 地面上的 32×8 灯条，点亮时由冷青转暖黄。
	var base := Rect2(-16.0, -8.0, 32.0, 8.0)
	draw_rect(base, PLATE)
	draw_rect(base, PLATE_EDGE, false, 1.0)
	var core := Rect2(-13.0, -7.0, 26.0, 5.0)
	draw_rect(core, WARM if lit else COLD)
	if lit:
		draw_rect(base, Color(WARM.r, WARM.g, WARM.b, 0.55), false, 1.0)
		# 亮起时往上透一小段光柱，让「光打进去了」在黑暗里看得见。
		draw_rect(Rect2(-11.0, -26.0, 22.0, 18.0), Color(WARM.r, WARM.g, WARM.b, 0.16))
		draw_rect(Rect2(-5.0, -40.0, 10.0, 14.0), Color(WARM.r, WARM.g, WARM.b, 0.07))
