extends Area2D
## 丢在 3-2 底层最右端（井 A 右侧那条死路尽头）的那支手电。走过去就捡起来。
##
## **为什么放在 888px 外的死路尽头，而不是出生点旁边**：
## 出生点在 112，主路径一路向右只有井 A（288~384）和板 A（460~524）。
## 手电放在出生点右边 88px 时，玩家「往右走」这一个动作就顺手捡了——
## 那不是「找到手电」，是「开局发手电」，整关的第一课（我没有光）
## 完全没机会发生。现在它在板 A 之后再往右 480px 的死路尽头：
##   玩家先走到板 A → 提示「手电照它才有效」→ 低头一看手里没有手电
##   → 只能继续往右摸黑找 → 尽头有一小团暖光（本节点自己的 glow_radii）。
## 路是死的（再往右是死亡坑），所以他一定会回头，不会迷路。
##
## 它自己也是一个小光源（glow_radii 很弱）：黑暗房间里必须有东西把玩家的
## 视线拉过来，否则「地上有个手电」这件事永远读不出来。
##
## 注意 can_power 恒为 false——它躺在地上不是「在照谁」，所以它自己
## 不会被光敏板当成供光源，也不会把自己的板照亮。

## 只有被看见的份，不足以供能
@export var glow_radii := Vector2(48.0, 78.0)

## blackout.gd 读这两个
var radii := Vector2.ZERO
var can_power := false

var taken := false
var _t := 0.0


func _ready() -> void:
	add_to_group("mechanism")
	radii = glow_radii
	if not taken:
		add_to_group("torch_light")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if not taken:
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if taken or not body.is_in_group("player"):
		return
	var lamp := body.get_node_or_null("Flashlight")
	if lamp == null or not lamp.has_method("pick_up"):
		return
	if not lamp.call("pick_up"):
		return
	taken = true
	radii = Vector2.ZERO
	remove_from_group("torch_light")
	visible = false
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", true)
	_flash("捡到手电：光变亮了，只有它能点亮机关")


## R：手电回到地上、光圈亮回来。必须和 flashlight.reset_mechanism() 同时发生，
## 否则会出现「人手里没手电、地上也没有」的死局。
func reset_mechanism() -> void:
	taken = false
	visible = true
	radii = glow_radii
	if not is_in_group("torch_light"):
		add_to_group("torch_light")
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", false)
	queue_redraw()


func _flash(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("flash"):
		hud.call("flash", text)


func _draw() -> void:
	if taken:
		return
	# 光晕：呼吸一下，让它在黑里像「有东西在发光」而不是一块贴图
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	draw_circle(Vector2(0.0, -4.0), 13.0 + pulse * 2.0, Color(0.95, 0.82, 0.55, 0.10))
	draw_circle(Vector2(0.0, -4.0), 6.0 + pulse * 1.0, Color(1.0, 0.88, 0.62, 0.18))

	# 筒身（躺在地上，斜一点）
	var body := PackedVector2Array([
		Vector2(-11.0, -2.0), Vector2(5.0, -2.0),
		Vector2(5.0, 5.0), Vector2(-11.0, 5.0),
	])
	draw_colored_polygon(body, Color("#3b4a46"))
	# 灯头
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.0, -4.0), Vector2(12.0, -6.0),
		Vector2(12.0, 8.0), Vector2(5.0, 6.0),
	]), Color("#6d8078"))
	# 灯口的一点亮
	draw_rect(Rect2(11.0, -5.0, 3.0, 12.0), Color(1.0, 0.92, 0.72, 0.85))
	# 握把防滑纹
	for i in 3:
		draw_rect(Rect2(-9.0 + i * 4.0, -1.0, 2.0, 3.0), Color(0.16, 0.22, 0.20))
