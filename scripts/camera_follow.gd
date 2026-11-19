extends Camera2D
## 复刻原游戏的相机：水平方向把玩家固定在屏幕 x=400 附近，垂直完全锁定。
## 原逻辑是 camera_x = lerp(camera_x, clamp(player.x - 400, 0, 关卡宽 - 1280), 0.1)，
## 这里用 Camera2D 的 limit + position_smoothing 等效实现：limit 负责边界夹取，平滑负责插值。

## 要跟随的节点（关卡里的 Player）
@export var target_path: NodePath
## 玩家中心在屏幕上的固定横坐标。原游戏取 400。
@export var anchor_x: float = 400.0
## 玩家节点原点是包围盒左上角，取中心需要补半径（宽 28 → 14）
@export var target_center_offset_x: float = 14.0
## 相机中心。1280x704 视口 → (640, 352)；垂直锁定用它
@export var center: Vector2 = Vector2(640, 352)

var _target: Node2D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		push_warning("Camera2D: 找不到 target_path=%s" % target_path)
	else:
		# 开局立即就位，否则第一帧镜头会从节点默认位置滑过来
		snap_to_target()


func _process(_delta: float) -> void:
	if _target == null:
		return
	global_position = _desired_position()


## 目标位置：把玩家中心映射到屏幕 anchor_x 处，垂直恒定。
## 边界由 limit_left/right 交给引擎夹取，这里不重复算。
func _desired_position() -> Vector2:
	return Vector2(
		_target.global_position.x + target_center_offset_x - anchor_x + center.x,
		center.y
	)


## 瞬移用：玩家重生时坐标突变，直接跳过去并清掉平滑残影，
## 避免镜头从死亡位置一路滑回重生点。
func snap_to_target() -> void:
	if _target == null:
		return
	global_position = _desired_position()
	reset_smoothing()
