extends StaticBody2D
## 虚影（回声）：某一次生命里玩家走过的轨迹，原样重放。
##
## 位置由 echo_manager 逐帧喂进来，自己不模拟物理 —— 这样重放和当时看到的完全一致，
## 不会因为物理误差一帧帧漂开（原版是录指令再跑模拟，对确定性要求很高；
## 我们录轨迹，等价但更稳）。
##
## 外观全部由场景里的两个 Sprite2D 提供，代码不画任何像素：
##   Body  → assets/actors/office_character/idle.png（character_portrait：缩放 + 眨眼 + 青色）
##   Cross → assets/echo/echo_cross.png  死亡叉号（默认隐藏）
## 换皮只需替换这两张 png（或改 echo.tscn 里 Sprite 的 texture），不用碰脚本。
##
## **判定体积与贴图完全解耦**：机关（压力板）和世界阻挡都只看 `body_size`，
## Body/Cross 会被 `fit_visuals()` 缩放到这个尺寸。美术给 56×76、或者多留 2px
## 透明边，都只影响清晰度，不会把「刚好踩不到」变成「踩到了」。
## 想改虚影的判定体积，改 `body_size`，永远不要靠改图片。
##
## **只有一个「激活」状态**（`_active`）：回放、碰撞层、机关判定全部由它决定。
## 虚影生成时先不激活，等玩家复活那一刻 `reset()` 才登场——所以不会出现
## 「看不见但能踩」或「画面没出现，压力板已经被压住」这种两套规则打架的情况。
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

## 虚影的**判定体积**：压力板取这个矩形、撞墙扫描也用这个尺寸。
## 和贴图无关——美术换图只会被缩放到这个尺寸，不会改变谜题里能踩到哪。
## 改体积改这里；改外观改 png。两者不要互相牵连。
@export var body_size := Vector2(32, 44):
	set(value):
		body_size = value
		# 运行时/检查器改尺寸：外观、扫描形状、可踩薄片一起跟上
		if is_node_ready():
			fit_visuals()
			_build_probe()

## 头顶可踩薄片的高度（宽度始终等于 body_size.x，见 fit_visuals）
const TOP_HEIGHT := 8.0

## 淡出只作用在 Body 上；Cross 不跟着淡（主角死亡时也是「方块淡、叉不淡」），
## 否则尸体快消失时那个叉几乎看不见，认不出这是具能踩的尸首。
@onready var _body: Sprite2D = $Body
@onready var _cross: Sprite2D = $Cross
@onready var _top: CollisionShape2D = $Top

var frames: PackedVector2Array = PackedVector2Array()
var frame_index := 0
## 本帧位移，站在它头上的玩家靠这个被带着走
var last_delta := Vector2.ZERO

## 世界层：地形、门都在这层。虚影只被这层挡，不会被别的虚影或玩家挡。
const WORLD_LAYER := 1
## 扫描用的形状和内缩量。形状比身体小 1px（body_size 32x44 时是 31x43），
## 否则「脚正好贴地」这种静止接触会被判成碰撞，虚影一出生就卡死。
const PROBE_INSET := 1.0

var _probe: RectangleShape2D
var _probe_offset := Vector2(14, 19)

## 唯一的「是否参与游戏」状态：
##   false → 不显示、无碰撞、advance() 不推进、机关看不见
##   true  → 正常回放 / 尸体淡出（淡出期间仍是实体）
## 回放、碰撞层、机关判定都读它，不要再各判各的（visible / is_gone / 层 bit）。
var _active := false
var _fading := false
var _fade_time := 0.0
var _gone := false


func _ready() -> void:
	# 头顶薄片由场景里的 CollisionShape2D 提供（one_way_collision）
	fit_visuals()
	_build_probe()
	_set_active(false)


## 载入轨迹，但**先不登场**：等玩家复活时由 echo_manager 调 reset() 激活。
func setup(trail: PackedVector2Array) -> void:
	frames = trail
	_rewind()
	_set_active(false)


## 玩家复活：回到第 0 帧，并正式登场。这是虚影唯一的激活入口。
func reset() -> void:
	_rewind()
	_set_active(true)


## 回到第 0 帧的状态（不动激活标志）
func _rewind() -> void:
	frame_index = 0
	last_delta = Vector2.ZERO
	_fading = false
	_fade_time = 0.0
	_gone = false
	_body.modulate.a = 1.0
	_cross.visible = false
	if not frames.is_empty():
		global_position = frames[0]


## 激活/停用的唯一实现：显示、碰撞层、机关判定同源。
## 用 set_deferred 关 shape 是因为可能在物理回调里被调用（_complete 来自 advance）。
func _set_active(on: bool) -> void:
	_active = on and not frames.is_empty()
	visible = _active
	# 层 3（值 4）= 虚影层，玩家 mask 里包含它；关掉就等于"不存在"
	set_collision_layer_value(3, _active)
	if _top != null:
		_top.set_deferred("disabled", not _active)


## 机关与外部查询用：虚影现在是否参与游戏（含尸体淡出的 1.3 秒）
func is_active() -> bool:
	return _active


## 机关用的判定矩形：只由 body_size 决定，**不读贴图**
func body_rect() -> Rect2:
	return Rect2(global_position, body_size)


## 把外观缩放到 body_size：换图只影响外观，不改变判定。
## 运行时换皮（改 Body.texture）之后也要调一次。
func fit_visuals() -> void:
	for s: Sprite2D in [_body, _cross]:
		if s == null or s.texture == null:
			continue
		if s.has_method("fit_to_body"):
			s.call("fit_to_body", body_size)
			continue
		var ts: Vector2 = s.texture.get_size()
		if ts.x <= 0.0 or ts.y <= 0.0:
			continue
		s.scale = Vector2(body_size.x / ts.x, body_size.y / ts.y)
	# 可踩薄片跟着身体宽度走：身体变宽而薄片不变，边缘就会踩空
	if _top != null and _top.shape is RectangleShape2D:
		var shape := _top.shape.duplicate() as RectangleShape2D
		shape.size = Vector2(body_size.x, TOP_HEIGHT)
		_top.shape = shape
		_top.position = Vector2(body_size.x * 0.5, TOP_HEIGHT * 0.5)


## 由 echo_manager 每物理帧调用一次
func advance(delta: float) -> void:
	# 没激活就完全冻结：不推进帧号、不淡出。
	# 之前这里是"照常推进"，于是玩家死亡到复活这段时间，虚影在幕后把轨迹走完了，
	# 压力板却因为 visible=false 忽略它——同一具虚影在两套规则里状态不同。
	if not _active:
		return
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


## 扫描形状 = body_size 内缩 1px。内缩是为了避开「脚正好贴地」这种静止接触被判成碰撞。
## 尺寸取自 body_size 而不是贴图：换图不会改变"离墙多远会停"。
func _build_probe() -> void:
	_probe = RectangleShape2D.new()
	_probe.size = (body_size - Vector2(PROBE_INSET, PROBE_INSET) * 2.0).max(Vector2(2, 2))
	_probe_offset = body_size * 0.5


## 把这一帧的位移按世界碰撞截短：撞上就只走到接触点。
## 用 cast_motion（形状扫描）而不是"目标点是否重叠"，因为后者会漏掉隧穿。
func _clip_motion(motion: Vector2) -> Vector2:
	# 分轴扫描，落地只截断竖直位移，贴墙只截断水平位移。
	# 整个向量按同一比例截短会丢掉沿地面或墙面的轨迹，误差会逐帧累积。
	var horizontal := _cast_motion(Vector2(motion.x, 0), global_position)
	var vertical := _cast_motion(Vector2(0, motion.y), global_position + horizontal)
	return horizontal + vertical


func _cast_motion(motion: Vector2, start: Vector2) -> Vector2:
	if motion == Vector2.ZERO:
		return Vector2.ZERO
	if _probe == null:
		_build_probe()
	var space := get_world_2d().direct_space_state
	if space == null:
		return motion
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _probe
	params.transform = Transform2D(0.0, start + _probe_offset)
	params.motion = motion
	params.collision_mask = WORLD_LAYER
	params.exclude = [get_rid()]
	var hit := space.cast_motion(params)
	# TileMap 的单向平台允许从下方穿过，形状查询自身不会处理单向规则。
	while hit.size() >= 2 and hit[0] < 1.0 and motion.y <= 0.0:
		params.transform.origin = start + _probe_offset + motion * hit[1]
		params.margin = 0.05
		var contact := space.get_rest_info(params)
		if contact.is_empty():
			break
		var layer := instance_from_id(contact.collider_id) as TileMapLayer
		if layer == null:
			break
		var cell := layer.local_to_map(layer.to_local(contact.point - contact.normal * PROBE_INSET))
		var tile := layer.get_cell_tile_data(cell)
		if tile == null or tile.get_collision_polygons_count(0) != 1 or not tile.is_collision_polygon_one_way(0, 0):
			break
		params.exclude = params.exclude + [contact.rid]
		params.transform.origin = start + _probe_offset
		hit = space.cast_motion(params)
	if hit.size() < 2:
		return motion
	return motion * clampf(hit[0], 0.0, 1.0)


## 本帧位移：站在它头上的玩家靠这个被带着走
func get_frame_delta() -> Vector2:
	if not _active or _gone or _fading:
		return Vector2.ZERO
	return last_delta


func _complete() -> void:
	_gone = true
	# 播完就撤掉显示与碰撞，免得玩家踩在空气上；机关也随之忽略它
	_set_active(false)
