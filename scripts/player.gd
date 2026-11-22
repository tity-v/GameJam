extends CharacterBody2D
## 主角移动 + 死亡/重生。
## 坐标约定：本节点的 position 就是角色包围盒左上角（与原游戏 actor.pos 一致），
## 所以关卡里直接填出生点 (90, 522)，和原始数据对得上。
##
## 数值沿用原游戏 scripts/platformer/actor.gd；水平加减速改成了 6 帧起步 / 3 帧刹停的凹形曲线（见 L14–L27）。
## 死亡流程照抄原版：按住不动 → 1.3s 内淡出并画叉 → 回到重生点。

## 死亡瞬间发一次（echo_manager 靠它收尾本次录制）
signal movement_input(axis: float, jump_pressed: bool, jump_released: bool)
signal died
## 复活那一刻发一次（echo_manager 靠它把所有虚影倒回第 0 帧）
signal respawned

@export_group("水平移动")
## 满速 273px/s（原 210 × 1.3），横穿 1280 宽的屏幕约 4.7 秒。
@export var max_speed: float = 273.0
## 起步：0 → 满速 6 帧（60fps = 0.1s）。这里填这段的平均加速度，
## 实际速度是凹形：慢起、后段越走越快，见 curve_power。
@export var accel: float = 2730.0
## 空中起步 7 帧（0.116s），比地面软，但空中修正够快；比上一版快 15%。
@export var air_accel: float = 2355.0
## 刹停：满速 → 0 3 帧（0.05s），比加速陡一倍，松手马上收住。
@export var friction: float = 5460.0
## 空中松手后的阻力：比地面小得多，跳起来会顺着惯性飞一段，不再"空中急刹"。
## 400 约 0.68s / 93px 滑停；想要更飘调到 250，想要更黏调到 800。
@export var air_friction: float = 400.0
## 空中反向的急停速度：满速 273 归零约 2 帧，之后才按反方向重新加速。
@export var air_turn_stop: float = 8200.0
## 凹弧强度：1 = 直线，2 = 参考图那种慢起后快的凹形，越大起步越"憋"。
## 按速度大小计算曲线，左右方向互为镜像。
@export_range(1.0, 3.0, 0.1) var curve_power: float = 2.0
## 空中单独用平曲线：1 = 直线，按下方向第一帧就有 34px/s，不会"按了没反应"。
## 地面仍然是上面的凹形，两边互不影响。
@export_range(1.0, 3.0, 0.1) var air_curve_power: float = 1.0

@export_group("跳跃")
## 起跳与重力一起提高，让上升更快；60Hz 下到顶约 0.33s，高度仍约 115px。
@export var gravity: float = 2210.0
@export var jump_velocity: float = -732.0
## 下落时的重力倍率：上升用 100%，下落用 110%，落地更干脆，顶点也会偏前。
@export var fall_gravity_mult: float = 1.1
## 新增：上升途中松开跳跃键，上升速度乘以该系数。
## 恢复同步前的松键截断系数。
@export var jump_cut: float = 0.65
## 离开平台边缘后仍可起跳的宽限。
@export var coyote_time: float = 0.1
## 原 BUFFER。落地前一瞬间预按跳跃也算数，0.12s。
@export var jump_buffer: float = 0.12
## 原下落终速。
@export var max_fall_speed: float = 850.0

@export_group("死亡与重生")
## 原 world.death_duration。死亡动画时长，结束后在重生点复活。
@export var death_duration: float = 1.3
## 原版死亡时的最低不透明度（maxf(0.18, 1 - t/duration)）。
@export var death_min_alpha: float = 0.18
## 掉落超过这个 y 判定为摔死（原版同样在 y > 750 时 die）。
@export var kill_y: float = 750.0
## 死亡叉号颜色（已烘进 assets/actors/player_death_cross.png，换图即换色）
@export_group("外观")
## 贴图的设计尺寸。Sprite 与 DeathMark 会按「碰撞体尺寸 / 设计尺寸」自动缩放，
## 所以改角色大小只需改 Scene 里 Collision 的 shape.size，贴图不用重画。
@export var design_size: Vector2 = Vector2(28, 38)

## 固定重生点（关卡里放进 respawn_point 组的 Marker2D）。
## 想把重生点挪到别处，改关卡里的标记即可，不用动这里。
var respawn_position: Vector2 = Vector2.ZERO
var is_dead := false

var _death_time := 0.0
var _sprite: Sprite2D
var _mark: Sprite2D
var _coyote := 0.0
var _buffer := 0.0
## 脚下踩着的虚影（如果踩的是地面则为 null）
var _support: Node2D

## 一段加减速的起点、终点、进度，用来把直线换成凹形（见 _approach_speed）
var _ramp_from := 0.0
var _ramp_to := 0.0
var _ramp_rate := 0.0
var _ramp_power := 1.0
var _ramp_dur := 0.0
var _ramp_time := 0.0
var _ramp_on := false

## 转场滑入期间由前端置 true：不做水平输入、不起跳。
## 为什么需要：滑动时玩家其实已经站在新房间里（只是被旧截图盖着），
## 这 0.24s 里按着方向键能跑 65px，画面露出来时人就偏出出生点了。
var input_locked := false
var _lock_left := 0.0


func _ready() -> void:
	set_collision_mask_value(preload("res://scripts/replay_rules.gd").WALL_LAYER, true)
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_mark = get_node_or_null("DeathMark") as Sprite2D
	_fit_visuals()
	var marker := get_tree().get_first_node_in_group("respawn_point") as Node2D
	if marker != null:
		respawn_position = marker.global_position
	else:
		respawn_position = global_position
		push_warning("Player: 关卡里没有 respawn_point 组的标记，退回自身初始位置作为重生点")


## 让外观跟着碰撞体走：人物走 character_portrait.fit_to_body（48 高、底部对齐），
## 死亡叉号按 碰撞尺寸 / design_size 缩放，不用重画素材。
func _fit_visuals() -> void:
	var body := design_size
	var col := get_node_or_null("Collision") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		body = (col.shape as RectangleShape2D).size
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return
	var k := Vector2(body.x / design_size.x, body.y / design_size.y)
	if _sprite != null:
		if _sprite.has_method("fit_to_body"):
			_sprite.call("fit_to_body", body)
		else:
			_sprite.scale = k
	if _mark != null:
		_mark.scale = k


## 锁住操作一段时间（秒）。自动解锁，不依赖调用方再调一次——
## 前端就算中途被释放，玩家也不会永久卡在锁死状态。
func lock_input(seconds: float) -> void:
	if seconds <= 0.0:
		input_locked = false
		_lock_left = 0.0
		return
	input_locked = true
	_lock_left = seconds


func _physics_process(delta: float) -> void:
	if _lock_left > 0.0:
		_lock_left = maxf(0.0, _lock_left - delta)
		if _lock_left <= 0.0:
			input_locked = false
	# E 键自杀：随时可用，死亡中按无效
	if not input_locked and Input.is_action_just_pressed("die"):
		die()

	if is_dead:
		_tick_death(delta)
		return

	var axis := Input.get_axis("move_left", "move_right") if not input_locked else 0.0
	var pressed := not input_locked and Input.is_action_just_pressed("jump")
	var released := not input_locked and Input.is_action_just_released("jump")
	movement_input.emit(axis, pressed, released)
	move_with_input(delta, axis, pressed, released)

	# 掉出地图也算死亡（原版同样处理，第一关地面铺满所以一般触发不到）
	if global_position.y > kill_y:
		die()


func move_with_input(delta: float, axis: float, jump_pressed: bool, jump_released: bool) -> void:
	# 先补上脚下虚影本帧的位移，否则站在移动的虚影头上会被"抽走"地面
	_carry()

	var on_ground := is_on_floor()
	var target := axis * max_speed
	var rate := accel if on_ground else air_accel
	var power := curve_power if on_ground else air_curve_power
	if absf(axis) <= 0.01:
		target = 0.0
		# 空中松手用很小的阻力，动量会带着走；地面还是 3 帧急停
		rate = friction if on_ground else air_friction
	elif velocity.x * axis < 0.0:
		# 反向分两段：先刹到 0，再朝新方向起步。
		target = 0.0
		rate = friction if on_ground else air_turn_stop
		if not on_ground:
			power = 1.0
	# 地面用凹形（慢起后快），空中用平曲线（按下立刻动）
	velocity.x = _approach_speed(target, rate, power, delta)

	# 土狼时间：刚踩空的那几帧仍允许起跳
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	# 跳跃缓冲：落地前提前按也算
	if jump_pressed:
		_buffer = jump_buffer
	else:
		_buffer = maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0

	# 长按/短按的高度差：只在上升中生效，下落时松键不影响
	if jump_released and velocity.y < 0.0:
		velocity.y *= jump_cut

	velocity.y = minf(velocity.y + _gravity_now() * delta, max_fall_speed)
	move_and_slide()
	_refresh_support()


## 录制起点的短时运动状态。
func capture_motion() -> PackedFloat32Array:
	return PackedFloat32Array([coyote_time if is_on_floor() else _coyote, _buffer, _ramp_from, _ramp_to,
		_ramp_rate, _ramp_power, _ramp_dur, _ramp_time, float(_ramp_on)])

func _gravity_now() -> float:
	return gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)


## 朝 target 逼近，但不是匀速：rate 是这段的平均加速度，
## 所以走完的时间仍是 |Δv| / rate（273 / 2730 = 6 帧），只是速度变化不是直线。
func _approach_speed(target: float, rate: float, power: float, delta: float) -> float:
	if (not _ramp_on or not is_equal_approx(target, _ramp_to)
			or not is_equal_approx(rate, _ramp_rate) or not is_equal_approx(power, _ramp_power)):
		_ramp_from = velocity.x
		_ramp_to = target
		_ramp_rate = rate
		_ramp_power = power
		_ramp_dur = absf(target - _ramp_from) / maxf(rate, 0.0001)
		_ramp_time = 0.0
		_ramp_on = true

	_ramp_time += delta
	var u := clampf(_ramp_time / maxf(_ramp_dur, 0.0001), 0.0, 1.0)
	if u >= 1.0:
		_ramp_on = false
		return _ramp_to
	var speeding_up := absf(_ramp_to) > absf(_ramp_from)
	return lerpf(_ramp_from, _ramp_to, _shape(u, speeding_up, power))


## 曲线压在起点—终点连线的下方（不鼓起来）：
## 加速 = 慢起、后段越走越快；刹车 = 先掉得快、尾巴慢慢收。
## p = 1 是直线，2 是参考图那种明显的凹弧，p 越大起步越"憋"。
func _shape(u: float, rising: bool, p: float) -> float:
	var e := maxf(p, 1.0)
	if rising:
		return pow(u, e)
	return 1.0 - pow(1.0 - u, e)


## 虚影是逐帧瞬移的静态体，引擎不会自动带人；原版也是手动补位移（support.delta_pos）。
func _carry() -> void:
	if _support == null:
		return
	if not is_instance_valid(_support) or (_support.has_method("is_gone") and _support.is_gone()):
		_support = null
		return
	if _support.has_method("get_frame_delta"):
		move_and_collide(_support.get_frame_delta())


## 记录下一帧要跟着谁走：只有「站在头上」（碰撞法线朝上）且对方是虚影才算
func _refresh_support() -> void:
	_support = null
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > -0.7:
			continue
		var body := c.get_collider()
		if body is Node2D and body.is_in_group("echo"):
			_support = body
			return


## 死亡：立刻停掉输入，之后只受重力与摩擦影响（原版行为），并淡出、画叉。
func die() -> void:
	if is_dead:
		return
	is_dead = true
	_death_time = 0.0
	_buffer = 0.0
	_coyote = 0.0
	_support = null
	_ramp_on = false
	# 叉号是独立 Sprite，不随方块一起淡出（原版也是分开画的）
	if _mark != null:
		_mark.visible = true
	died.emit()


func _tick_death(delta: float) -> void:
	_death_time += delta

	move_after_death(delta)

	if _sprite != null:
		var t := clampf(_death_time / death_duration, 0.0, 1.0)
		_sprite.modulate.a = lerpf(1.0, death_min_alpha, t)

	if _death_time >= death_duration:
		respawn()


func move_after_death(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = minf(velocity.y + _gravity_now() * delta, max_fall_speed)
	move_and_slide()


func respawn() -> void:
	_place_at_spawn()
	respawned.emit()


## R 重置用：把玩家瞬间拉回出生点，但**不发 `respawned`**。
## 为什么要区分：`respawned` 的语义是"复活"，echo_manager 收到后会把现有虚影倒回第 0 帧继续播；
## 而 R 是把虚影整批删掉（见 `echo_manager.reset_all`），两者不是一回事。
## 死亡淡出中按 R 也能直接打断淡出、立刻回到出生点。
func reset_to_spawn() -> void:
	_place_at_spawn()


## respawn() 与 reset_to_spawn() 共用的落点逻辑：位置、速度、各种计时器、贴图状态、相机。
func _place_at_spawn() -> void:
	is_dead = false
	_death_time = 0.0
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	_ramp_on = false
	_support = null
	global_position = respawn_position
	if _sprite != null:
		_sprite.modulate.a = 1.0
	if _mark != null:
		_mark.visible = false
	# 相机原本是平滑跟随，重生/重置都是瞬移，要让镜头立刻归位而不是从旧位置滑过来
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
