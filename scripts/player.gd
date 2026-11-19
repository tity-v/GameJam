extends CharacterBody2D
## 主角移动 + 死亡/重生。
## 坐标约定：本节点的 position 就是角色包围盒左上角（与原游戏 actor.pos 一致），
## 所以关卡里直接填出生点 (90, 522)，和原始数据对得上。
##
## 数值全部沿用原游戏 scripts/platformer/actor.gd；只有「长按/短按不同跳高」是本步新增。
## 死亡流程照抄原版：按住不动 → 1.3s 内淡出并画叉 → 回到重生点。

## 死亡瞬间发一次（echo_manager 靠它收尾本次录制）
signal died
## 复活那一刻发一次（echo_manager 靠它把所有虚影倒回第 0 帧）
signal respawned

@export_group("水平移动")
## 原 SPEED。满速 210px/s，横穿 1280 宽的屏幕约 6 秒。
@export var max_speed: float = 210.0
## 原 ACCEL。地面 0 → 满速约 0.12s，按下就走、不拖泥带水。
@export var accel: float = 1800.0
## 原 AIR_ACCEL。空中略弱于地面，但 0.16s 就能反向，满足「空中可调整方向」。
@export var air_accel: float = 1300.0
## 原 FRICTION。松手后约 0.1s 停下，不会滑冰。
@export var friction: float = 2200.0

@export_group("跳跃")
## 原 GRAVITY。配合 jump_velocity，跳跃是「上快下慢」的固定重力曲线。
@export var gravity: float = 1400.0
## 原 JUMP。按住不放时跃起高度约 93px，0.36s 到顶。
@export var jump_velocity: float = -510.0
## 新增：上升途中松开跳跃键，上升速度乘以该系数。
## 0.65 对应「轻点一帧约 37px，按住约 93px」，高度差 2.5 倍，肉眼一眼能分辨。
@export var jump_cut: float = 0.65
## 原 COYOTE。离开平台边缘后仍可起跳的宽限，0.1s。
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


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_mark = get_node_or_null("DeathMark") as Sprite2D
	_fit_visuals()
	var marker := get_tree().get_first_node_in_group("respawn_point") as Node2D
	if marker != null:
		respawn_position = marker.global_position
	else:
		respawn_position = global_position
		push_warning("Player: 关卡里没有 respawn_point 组的标记，退回自身初始位置作为重生点")


## 让贴图跟着碰撞体走：角色改尺寸时，白方块和死亡叉号一起缩放，不用重画素材。
func _fit_visuals() -> void:
	var body := design_size
	var col := get_node_or_null("Collision") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		body = (col.shape as RectangleShape2D).size
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return
	var k := Vector2(body.x / design_size.x, body.y / design_size.y)
	if _sprite != null:
		_sprite.scale = k
	if _mark != null:
		_mark.scale = k


func _physics_process(delta: float) -> void:
	# E 键自杀：随时可用，死亡中按无效
	if Input.is_action_just_pressed("die"):
		die()

	if is_dead:
		_tick_death(delta)
		return

	_move(delta)

	# 掉出地图也算死亡（原版同样处理，第一关地面铺满所以一般触发不到）
	if global_position.y > kill_y:
		die()


func _move(delta: float) -> void:
	# 先补上脚下虚影本帧的位移，否则站在移动的虚影头上会被"抽走"地面
	_carry()

	var axis := Input.get_axis("move_left", "move_right")
	var rate := accel if is_on_floor() else air_accel

	if absf(axis) > 0.01:
		velocity.x = move_toward(velocity.x, axis * max_speed, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# 土狼时间：刚踩空的那几帧仍允许起跳
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	# 跳跃缓冲：落地前提前按也算
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	else:
		_buffer = maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0

	# 长按/短按的高度差：只在上升中生效，下落时松键不影响
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	_refresh_support()


## 虚影是逐帧瞬移的静态体，引擎不会自动带人；原版也是手动补位移（support.delta_pos）。
func _carry() -> void:
	if _support == null:
		return
	if not is_instance_valid(_support) or (has_method("is_gone") and _support.is_gone()):
		_support = null
		return
	if _support.has_method("get_frame_delta"):
		global_position += _support.get_frame_delta()


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
	# 叉号是独立 Sprite，不随方块一起淡出（原版也是分开画的）
	if _mark != null:
		_mark.visible = true
	died.emit()


func _tick_death(delta: float) -> void:
	_death_time += delta

	# 原版：死亡中 x 方向只有摩擦，y 方向继续受重力，所以会顺着惯性滑一小段再落下
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()

	if _sprite != null:
		var t := clampf(_death_time / death_duration, 0.0, 1.0)
		_sprite.modulate.a = lerpf(1.0, death_min_alpha, t)

	if _death_time >= death_duration:
		respawn()


func respawn() -> void:
	is_dead = false
	_death_time = 0.0
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	global_position = respawn_position
	if _sprite != null:
		_sprite.modulate.a = 1.0
	_support = null
	if _mark != null:
		_mark.visible = false
	# 相机原本是平滑跟随，重生是瞬移，要让镜头立刻归位而不是从旧位置滑过来
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
	respawned.emit()


