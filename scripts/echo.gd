extends StaticBody2D
## 虚影（回声）：某一次生命里玩家走过的轨迹，原样重放。
##
## 位置由 echo_manager 逐帧喂进来，自己不模拟物理 —— 这样重放和当时看到的完全一致，
## 不会因为物理误差一帧帧漂开（原版是录指令再跑模拟，对确定性要求很高；
## 我们录轨迹，等价但更稳）。
##
## 外观全部由场景里的两个 Sprite2D 提供，代码不画任何像素：
##   Body  → assets/echo/echo_body.png   半透明方块 + 顶边亮线
##   Cross → assets/echo/echo_cross.png  死亡叉号（默认隐藏）
## 换皮只需替换这两张 png（或改 echo.tscn 里 Sprite 的 texture），不用碰脚本。
##
## 碰撞只有头顶那一条 one-way 薄片：
##   侧面走过来 → 穿过去（薄片对横向运动不生效）
##   从下往上跳 → 穿过去
##   从上方落下 → 踩住，可以站着，也可以借它跳
## 和原版「虚影只有当平台用、不当墙用」的设计一致。
##
## 但虚影**自己**会被世界挡住（地形、关着的门）：
## 位置虽然是喂进来的，每帧仍做一次形状扫描（`_clip_motion`），
## 撞上就停在接触点，下一帧继续试。所以录的时候门开着、重放时门关着，
## 虚影会撞在门上停住，而不是穿过去。
## 硬编码用坐标瞬移（`global_position = frames[next]`）会隧穿过薄墙，
## 这就是必须走扫描的原因。

## 轨迹播完后的「死亡」时长。刻意等于主角的 death_duration（1.3s）：
## 虚影和玩家走的是同一条时间轴 —— 玩家活 T 秒再死 1.3 秒，
## 虚影就重放 T 秒再死 1.3 秒，于是它总比玩家晚 1.3 秒消失。
## 这 1.3 秒里尸体仍然是实体（能踩、能站），是后面尖刺/陷阱关的支点：
## 「让回声掉进尖刺，趁它消失前踩上去跨过去」就是靠这段时间。
@export var fade_duration := 1.3
## 淡出终点：原版 maxf(0.18, 1 - t/duration)，尸体不会彻底看不见。
## 不要改成 0：玩家踩在上面时需要看到脚下还有东西。
@export var death_min_alpha := 0.18

## 淡出只作用在 Body 上；Cross 不跟着淡（主角死亡时也是「方块淡、叉不淡」），
## 否则尸体快消失时那个叉几乎看不见，认不出这是具能踩的尸首。
@onready var _body: Sprite2D = $Body
@onready var _cross: Sprite2D = $Cross

var frames: PackedVector2Array = PackedVector2Array()
var frame_index := 0
## 本帧位移，站在它头上的玩家靠这个被带着走
var last_delta := Vector2.ZERO

## 世界层：地形、门都在这层。虚影只被这层挡，不会被别的虚影或玩家挡。
const WORLD_LAYER := 1
## 扫描用的形状和内缩量。形状比身体小 1px（26x36 塞在 28x38 里），
## 否则「脚正好贴地」这种静止接触会被判成碰撞，虚影一出生就卡死。
const PROBE_INSET := 1.0

var _probe: RectangleShape2D
var _probe_offset := Vector2(14, 19)

var _fading := false
var _fade_time := 0.0
var _gone := false


func _ready() -> void:
	# 头顶薄片由场景里的 CollisionShape2D 提供（one_way_collision）
	visible = false
	_build_probe()


func setup(trail: PackedVector2Array) -> void:
	frames = trail
	reset()


## 回到第 0 帧：每次玩家复活，所有虚影一起从头开始，和玩家同一时间轴
func reset() -> void:
	frame_index = 0
	last_delta = Vector2.ZERO
	_fading = false
	_fade_time = 0.0
	_gone = false
	# 播完时关过碰撞，重放前要打开，否则第二条命开始虚影就是穿模的
	set_collision_layer_value(3, true)
	visible = frames.size() > 0
	_body.modulate.a = 1.0
	_cross.visible = false
	if frames.size() > 0:
		global_position = frames[0]


## 由 echo_manager 每物理帧调用一次
func advance(delta: float) -> void:
	if _gone:
		return

	if _fading:
		_fade_time += delta
		var t := clampf(_fade_time / fade_duration, 0.0, 1.0)
		_body.modulate.a = lerpf(1.0, death_min_alpha, t)
		if t >= 1.0:
			_complete()
		return

	if frames.is_empty():
		_complete()
		return

	var next := mini(frame_index + 1, frames.size() - 1)
	if next != frame_index:
		# 增量推进，而不是直接赋值成记录坐标：一旦被墙截住，若还继续用绝对坐标，
		# 记录轨迹跨过那面墙时虚影会直接"隧穿"过去。
		last_delta = _clip_motion(frames[next] - frames[frame_index])
		global_position += last_delta
		frame_index = next
	else:
		last_delta = Vector2.ZERO

	# 播到最后一帧就"死亡"：淡出 + 叉号，之后不再提供碰撞
	if frame_index >= frames.size() - 1:
		_fading = true
		_fade_time = 0.0
		_cross.visible = true


func is_gone() -> bool:
	return _gone


## 扫描形状 = 身体矩形内缩 1px。内缩是为了避开「脚正好贴地」这种静止接触被判成碰撞。
func _build_probe() -> void:
	var size := Vector2(28, 38)
	if _body != null and _body.texture != null:
		size = _body.texture.get_size()
	_probe = RectangleShape2D.new()
	_probe.size = (size - Vector2(PROBE_INSET, PROBE_INSET) * 2.0).max(Vector2(2, 2))
	_probe_offset = size * 0.5


## 把这一帧的位移按世界碰撞截短：撞上就只走到接触点。
## 用 cast_motion（形状扫描）而不是"目标点是否重叠"，因为后者会漏掉隧穿。
func _clip_motion(motion: Vector2) -> Vector2:
	if motion == Vector2.ZERO:
		return Vector2.ZERO
	if _probe == null:
		_build_probe()
	var space := get_world_2d().direct_space_state
	if space == null:
		return motion
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _probe
	params.transform = Transform2D(0.0, global_position + _probe_offset)
	params.motion = motion
	params.collision_mask = WORLD_LAYER
	params.exclude = [get_rid()]
	var hit := space.cast_motion(params)
	if hit.size() < 2:
		return motion
	return motion * clampf(hit[0], 0.0, 1.0)


## 本帧位移：站在它头上的玩家靠这个被带着走
func get_frame_delta() -> Vector2:
	if _gone or _fading:
		return Vector2.ZERO
	return last_delta


func _complete() -> void:
	_gone = true
	visible = false
	# 播完就撤掉碰撞，免得玩家踩在空气上
	set_collision_layer_value(3, false)
