@tool
extends StaticBody2D
## 拉杆是一个**开关**，不是一道门：拨过去就一直躺着，碰撞体保持禁用，
## 直到 `reset_mechanism()`（R 键复位）才重新立起来挡人。
##
## 为什么不能「没人碰就重新启用」：
## 玩家拨完杆继续往前走，几帧后离开 reach（-20..20），`touching` 变 false，
## 碰撞体就恢复了——玩家自己已经穿过去了，看不见；但**虚影是之后才重放这条轨迹的**，
## 它到杆前面时杆已经重新立起来，于是被卡在杆右侧走不过去，表现为
## 「主角能过拉杆、虚影过不了」。杆细（10×12），拨过去以后本来也不该再挡人。
##
## 回归：`_reference/tools/test_lever_pass.gd`（未拨时有实体 / 拨过不挡人 / 复位后恢复）。
const CFG = preload("res://graybox/db/mechanisms.tres")
const Motion = preload("res://graybox/glue/actor_motion.gd")
const Bounds = preload("res://scripts/actor_bounds.gd")
@export var initially_right := true
var active := false
var travel := 0.0
var latched := false
func _ready() -> void:
	reset_mechanism()
	if not Engine.is_editor_hint():
		add_to_group("mechanism")
		process_physics_priority = 10
func reset_mechanism() -> void:
	active = not initially_right
	travel = 0
	latched = false
	$Collision.set_deferred("disabled",false)
	update_arm()
func update_arm() -> void:
	$Arm.rotation = (-1 if active else 1) * (PI / 4 - travel / CFG.lever_travel * PI / 2)
func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressing := false
	var touching := false
	var side := -1 if active else 1
	for actor in Bounds.actors(get_tree()):
		if not Bounds.available(actor):
			continue
		var body := Bounds.rect(actor)
		var reach := global_transform * Rect2(Vector2(-20, -28), Vector2(40, 30))
		if not reach.intersects(body):
			continue
		touching = true
		var horizontal: float = Motion.horizontal(actor, dt)
		var actor_side := signf(to_local(body.get_center()).x)
		var local_motion := to_local(global_position + Vector2(horizontal, 0)).x
		if not latched and actor_side == side and local_motion * side < 0:
			travel += absf(horizontal) * dt
			pressing = true
	if not touching:
		# 只清 latched，**不**恢复碰撞体：见文件头注释
		latched = false
	if not pressing:
		travel = 0
	if travel >= CFG.lever_travel:
		active = not active
		latched = true
		$Collision.set_deferred("disabled",true)
		travel = 0
	update_arm()
