@tool
extends Node2D
## 碰撞调试可视化。纯绘制，不参与物理，不影响任何手感。
##
## 玩家（shape_path = ../Collision，feet_line = true）
##   黄色框      = 完整碰撞体（28×38）
##   橙色粗线    = 脚底线，这条线才是真正踩地的地方
##
## 虚影（shape_path = ../Top，stand_line = true）
##   黄色框      = 可踩薄片（28×8，one-way）
##   橙色粗线    = 可踩线，只有从上方落下时才生效
##
## 两条橙线重合 = 踩上了。美术/策划改尺寸时，框会立刻跟着变（编辑器内生效）。
## 运行时按 F1 全局开关；正式发布前把节点 visible 取消，或保留也行（F1 可关）。

@export var shape_path: NodePath = ^"../Collision"
## 框内填充色
@export var box_fill: Color = Color(1.0, 0.86, 0.25, 0.10)
## 框描边色
@export var box_line: Color = Color(1.0, 0.86, 0.25, 0.9)
## 底边画粗线（玩家：脚底）
@export var feet_line := false
## 顶边画粗线（虚影：可踩面）
@export var stand_line := false
## 接触线颜色。两种角色共用同一个色，所以「两条线碰到」这件事一眼可见
@export var contact_color: Color = Color("ff8a3d")
## 接触线两端的短刻度长度
@export var tick := 3.0

## 全局开关，多个实例共享一份
static var _shown := true

var _last := Rect2()


func _ready() -> void:
	add_to_group("hitbox_debug")
	visible = _shown


func _process(_delta: float) -> void:
	# 检查器里改尺寸、或运行时脚本改尺寸，都要立刻重画
	var r := _rect()
	if r != _last:
		_last = r
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).physical_keycode != KEY_F1:
		return
	_shown = not _shown
	get_viewport().set_input_as_handled()
	get_tree().call_group("hitbox_debug", "apply_shown", _shown)


func apply_shown(v: bool) -> void:
	visible = v


## 读取目标 CollisionShape2D 的矩形范围（父节点局部坐标）
func _rect() -> Rect2:
	var n := get_node_or_null(shape_path)
	if n is not CollisionShape2D:
		return Rect2()
	var shape := (n as CollisionShape2D).shape
	if shape is not RectangleShape2D:
		return Rect2()
	var s: Vector2 = (shape as RectangleShape2D).size
	return Rect2((n as CollisionShape2D).position - s * 0.5, s)


func _draw() -> void:
	var r := _rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return

	draw_rect(r, box_fill, true)
	draw_rect(r, box_line, false, 1.0)

	if feet_line:
		_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y))
	if stand_line:
		_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y))


## 画一条接触线：2px 实线 + 两端各一截短刻度，小尺寸下也看得清
func _line(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, contact_color, 2.0)
	var up := Vector2(0.0, -tick - 1.0)
	var down := Vector2(0.0, tick - 1.0)
	draw_line(a + up, a + down, contact_color, 1.0)
	draw_line(b + up, b + down, contact_color, 1.0)
