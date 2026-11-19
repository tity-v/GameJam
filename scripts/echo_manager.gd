extends Node2D
## 虚影管理器：录玩家轨迹 → 死亡时留下一条虚影 → 复活时所有虚影同步从头重放。
##
## 站位：本节点在关卡里，process_physics_priority = -10，保证每一帧先推虚影、
## 再跑玩家，玩家才能拿到虚影本帧的位移（被带着走）。

const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
## 上限：场上最多 5 条虚影。满了之后新死的一条顶掉最旧的一条（先进先出）。
const MAX_ECHOES := 5
## 单条轨迹最长帧数（60fps 下 100 秒），防止一直不死把内存吃满。
## 做成导出而不是 const：测试要把它调小才能验证（`test_echo_recording_cap.gd`），
## 特殊关卡也可以按需调大。
@export var max_frames: int = 6000

@export var player_path: NodePath

var _player: Node2D
var _trail := PackedVector2Array()
var _echoes: Array[Node2D] = []
var _recording := false


func _ready() -> void:
	process_physics_priority = -10
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("EchoManager: 找不到 player_path=%s" % player_path)
		return
	_player.died.connect(_on_player_died)
	_player.respawned.connect(_on_player_respawned)
	_trail = PackedVector2Array()
	_recording = true


func _physics_process(_delta: float) -> void:
	# 虚影始终在播（玩家死亡动画期间也播，不然会像卡住的雕像）
	for e in _echoes:
		if is_instance_valid(e):
			e.advance(_delta)

	if _recording and _player != null:
		if _trail.size() < max_frames:
			_trail.append(_player.global_position)
		else:
			# 满了就丢掉最旧的一半，保留**最近**这一段（滚动窗口）。
			# 不能只是停止追加：那样虚影重放的是"这一生最初的 100 秒"，
			# 尸体落在 100 秒前的位置，和真正的死亡点差出几百像素
			# （实测把上限调成 1 秒时，虚影末帧比死亡点落后 320px）。
			# 折半而不是每帧 pop_front：后者是 O(n) 内存搬移，5000 帧时每秒要搬几 MB。
			_trail = _trail.slice(_trail.size() / 2)
			_trail.append(_player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	# 本节点是 PAUSABLE，暂停时这里不会被调用，所以暂停中按 R 不会偷偷清场
	if not event.is_action_pressed("reset_echoes"):
		return
	get_viewport().set_input_as_handled()
	# 通关后按 R 不做事：整关重来是 Win 面板上 Replay 的职责（见 room_controller.reset_room）
	var level := get_tree().current_scene
	if level != null and level.get("won") == true:
		return
	reset_all()


## R：把这一关恢复到初始状态——清掉所有虚影、玩家回出生点、机关复位
## （压力板松开、门关上、出口熄灭）。**不重载场景**，所以相机、HUD、节点都不重建。
##
## 为什么不再像以前那样调 `level.reset_room()` 重载场景：
## 重载会有一帧黑屏/重建，而且任何运行时状态（比如本局的录制、HUD 计数）都从零开始，
## 手感上像「切换了一关」。现在只复位该复位的，其余原样保留。
##
## 顺序不能换：先放人 → 再复位机关 → 最后清录制。
##   - 人没回出生点就复位机关：下一物理帧压力板会重新检测到人还踩在上面，门立刻又开
##   - 复位机关前清录制：不影响正确性，但先放人可以让 HUD 的「虚影已重置」后置，读起来顺
func reset_all() -> void:
	if _player != null and _player.has_method("reset_to_spawn"):
		_player.reset_to_spawn()
	var level := get_tree().current_scene
	if level != null and level.has_method("reset_mechanisms"):
		level.reset_mechanisms()
	clear_all()


## R 的"虚影部分"：清掉此前留下的所有虚影，并让这一轮从当下重新开始录。
## 玩家位置由 `reset_all()` 负责，这里不管人。
## 为什么连录制也清：否则重置后死一次，留下的虚影里会包含重置前走过的路，
## 看着像"没重置干净"。
func clear_all() -> void:
	var removed := _echoes.size()
	for e in _echoes:
		if is_instance_valid(e):
			e.queue_free()
	_echoes.clear()
	_trail = PackedVector2Array()
	# 死亡动画中按 R：录制本来就停着，别把它打开
	if _player != null and not _player.is_dead:
		_recording = true
	_notify_hud(removed)


func _notify_hud(removed: int) -> void:
	# 文案不再只说「虚影已重置」：R 现在连机关一起复位，
	# 说清是「回到初始状态」，否则玩家会以为门是他自己关上的。
	_flash_hud("已回到初始状态" if removed > 0 else "机关与虚影已复位")


func _flash_hud(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("flash"):
		hud.flash(text)


func _on_player_died() -> void:
	_recording = false
	_add_echo(_trail)


func _on_player_respawned() -> void:
	_trail = PackedVector2Array()
	_recording = true
	for e in _echoes:
		if is_instance_valid(e):
			e.reset()


func _add_echo(trail: PackedVector2Array) -> void:
	# 一出生就死（轨迹太短）不留虚影，没有意义
	if trail.size() < 2:
		return

	# 满员：先清掉**最早生成**的那一条再放新的（_echoes 是 FIFO 队列，
	# pop_front 拿到的就是最早；正在"死亡淡出"尚未消失的也算在内，
	# 否则上限会随尸体滞留在场上而临时超员）。
	var replaced := false
	while _echoes.size() >= MAX_ECHOES:
		var oldest: Node2D = _echoes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
			replaced = true

	var echo := ECHO_SCENE.instantiate()
	add_child(echo)
	# 必须 duplicate：PackedVector2Array 会跟 _trail 共用一个缓冲，
	# 不复制的话虚影播放的是"当前这轮正在录"的轨迹
	echo.setup(trail.duplicate())
	# 玩家还在死亡淡出中，新虚影等复活那一刻再一起登场
	echo.visible = false
	_echoes.append(echo)

	# 满员替换要让玩家知道，否则会以为"新死的这次没留下虚影"
	if replaced:
		_flash_hud("虚影已满 %d 条，替换最早的一条" % MAX_ECHOES)


## 调试/后续关卡会用到
func echo_count() -> int:
	return _echoes.size()


## HUD 右端「回声 n / max」用
func max_echoes() -> int:
	return MAX_ECHOES


func echo_positions() -> Array:
	var out := []
	for e in _echoes:
		if is_instance_valid(e):
			out.append(e.global_position)
	return out


func echo_frames() -> Array:
	var out := []
	for e in _echoes:
		if is_instance_valid(e):
			out.append([e.frame_index, e.frames.size()])
	return out
