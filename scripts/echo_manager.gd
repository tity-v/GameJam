extends Node2D
## 虚影管理器：录玩家操作 → 死亡时留下一条虚影 → 复活时所有虚影同步从头重放。
##
## 站位：本节点在关卡里，process_physics_priority = -10，保证每一帧先推虚影、
## 再跑玩家，玩家才能拿到虚影本帧的位移（被带着走）。

const ECHO_SCENE := preload("res://scenes/echo/echo.tscn")
## 上限：场上最多 5 条虚影。满了之后新死的一条顶掉最旧的一条（先进先出）。
const MAX_ECHOES := 5
@export_range(1, 5) var room_echo_limit := MAX_ECHOES
## 单条轨迹最长帧数（60fps 下 100 秒），防止一直不死把内存吃满。
## 做成导出而不是 const：测试要把它调小才能验证（`test_echo_recording_cap.gd`），
## 特殊关卡也可以按需调大。
@export var max_frames: int = 6000

## 虚影放完录像后在原地站多久再消散，默认 0（放完就散，第一到第三章通例）。
## 3-2 靠虚影「站在板旁边替你供光」，需要一个固定窗口，所以在那个场景里调成 7 秒。
## 放在管理器而不是 echo.tscn 上：虚影是运行时 instantiate 的，
## echo.tscn 里的导出值改不到，只能建的时候写进去。
@export var echo_hold_duration := 0.0

@export var player_path: NodePath

var _player: Node2D
var _trail := PackedVector2Array()
var _echoes: Array[Node2D] = []
var _recording := false
var _origin := Vector2.ZERO
var _velocity := Vector2.ZERO
var _mid_origin := Vector2.ZERO
var _mid_velocity := Vector2.ZERO
var _motion := PackedFloat32Array()
var _mid_motion := PackedFloat32Array()
var pin_start := false


func _ready() -> void:
	process_physics_priority = -10
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("EchoManager: 找不到 player_path=%s" % player_path)
		return
	_player.movement_input.connect(_record_input)
	_player.died.connect(_on_player_died)
	_player.respawned.connect(_on_player_respawned)
	_trail = PackedVector2Array()
	_recording = true


func _physics_process(_delta: float) -> void:
	# 虚影始终在播（玩家死亡动画期间也播，不然会像卡住的雕像）
	for e in _echoes:
		if is_instance_valid(e):
			e.advance(_delta)

func _record_input(axis: float, pressed: bool, released: bool) -> void:
	if not _recording: return
	var limit := maxi(2, max_frames)
	var cut := ceili(limit * 0.5)
	if _trail.size() >= limit:
		if pin_start: return
		_trail = _trail.slice(cut)
		_origin = _mid_origin
		_velocity = _mid_velocity
		_motion = _mid_motion
	if _trail.is_empty():
		_origin = _player.global_position
		_velocity = _player.velocity
		_motion = _player.capture_motion()
	if _trail.size() == cut:
		_mid_origin = _player.global_position
		_mid_velocity = _player.velocity
		_mid_motion = _player.capture_motion()
	_trail.append(Vector2(axis, int(pressed) | (int(released) << 1) | _player.ladder_flags))


func _unhandled_input(event: InputEvent) -> void:
	# 本节点是 PAUSABLE，暂停时这里不会被调用，所以暂停中按 R 不会偷偷清场
	var reset := event.is_action_pressed("reset_echoes")
	var remove_latest := event.is_action_pressed("remove_latest_echo") and not event.is_echo()
	if not reset and not remove_latest:
		return
	get_viewport().set_input_as_handled()
	# 通关后按 R 不做事：整关重来是 Win 面板上 Replay 的职责（见 room_controller.reset_room）
	var level := get_tree().current_scene
	if level != null and level.get("won") == true:
		return
	if remove_latest:
		clear_latest_echo()
		return
	get_node("/root/GameSfx").play("reset_room")
	reset_all()

func clear_latest_echo() -> void:
	if _echoes.is_empty():
		return
	var latest: Node2D = _echoes.pop_back()
	if is_instance_valid(latest):
		latest.queue_free()
	_flash_hud("已清除最新虚影")


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


## 死的那一刻手里有没有手电。虚影带着同一支手电重放，
## 「让虚影站在板旁边替你供光」才成立——第三章 3-2 整段都压在这上面。
## 遍历子节点而不是写死 `Flashlight`：3-1 的节点名不同，而且以后可能换。
func _player_has_flashlight() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	for child in _player.get_children():
		if child.get("has_flashlight") == true:
			return true
	return false


func _add_echo(trail: PackedVector2Array) -> void:
	get_node("/root/GameSfx").play("echo_created")
	# 一出生就死（轨迹太短）不留虚影，没有意义
	if trail.size() < 2:
		return

	# 满员：先清掉**最早生成**的那一条再放新的（_echoes 是 FIFO 队列，
	# pop_front 拿到的就是最早；正在"死亡淡出"尚未消失的也算在内，
	# 否则上限会随尸体滞留在场上而临时超员）。
	var replaced := false
	while _echoes.size() >= room_echo_limit:
		var oldest: Node2D = _echoes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
			replaced = true

	var echo := ECHO_SCENE.instantiate()
	add_child(echo)
	# 先写待机时长再 setup：setup() 会 reset()，把 _hold_time 归零，
	# 但不会动 hold_duration 本身，所以两个顺序都行——写前面更不容易以后改乱。
	echo.set("hold_duration", echo_hold_duration)
	# 必须 duplicate：PackedVector2Array 会跟 _trail 共用一个缓冲，
	# 不复制的话虚影播放的是"当前这轮正在录"的轨迹
	echo.setup_actions(trail.duplicate(), _origin, _velocity, _player, _motion, _player_has_flashlight())
	# setup() 自带"未激活"状态：不显示、无碰撞、不推进、机关不认。
	# 等玩家复活时 _on_player_respawned() 里的 reset() 才让它登场——
	# 显示、碰撞、机关判定三件事共用同一个 _active，不会再出现
	# "看不见的虚影已经能挡住人/压住板"这种状态不一致。
	_echoes.append(echo)

	# 满员替换要让玩家知道，否则会以为"新死的这次没留下虚影"
	if replaced:
		_flash_hud("虚影已满 %d 条，替换最早的一条" % room_echo_limit)


## 调试/后续关卡会用到
func echo_count() -> int:
	return _echoes.size()


## HUD 右端「回声 n / max」用
func max_echoes() -> int:
	return room_echo_limit


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
