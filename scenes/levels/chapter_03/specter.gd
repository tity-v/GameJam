extends "res://scripts/player.gd"
## 3-1 的预录虚影。
##
## 它不读按键，也不回放录制——这一关的虚影是「过去已经走过一次的你」，
## 剧本写死在场景里。继承 player.gd 只有一个理由：跳跃弧线必须和玩家
## 逐帧一致，否则玩家会看到「它跳得比我高」这种无法解释的差异。
##
## 行为：等 `delay` 秒 → 一直向右 → 前方没地面或撞墙就跳 → 到 `stop_x` 停下。
## 停下后不再移动，光还亮着（它是路标，不是消耗品）。

## 走过 trigger_x 时发一次，铁栅据此升起。
signal trigger_pulled

@export var stop_x := 1090.0
@export var delay := 0.9
## 走到这个位置就通知铁栅升起。它比 stop_x 更早，所以玩家会看到
## 「光经过 → 门开始动 → 光继续往前走」，因果顺序是清楚的。
@export var trigger_x := 1028.0
@export var start_radii := Vector2(128.0, 150.0)
@export var still_radii := Vector2(112.0, 132.0)

## blackout.gd 每帧读这个（`torch_light` 组）
var radii: Vector2
var halted := false
var triggered := false
var _wait := 0.0
var _start := Vector2.ZERO
var _world: TileMapLayer


func _ready() -> void:
	super._ready()
	# 虚影不挡人、也不被别人挡，只和世界地形碰撞
	collision_layer = 0
	collision_mask = 1
	add_to_group("torch_light")
	add_to_group("specter")
	add_to_group("mechanism")
	radii = start_radii
	_start = global_position
	# World 是同级节点，缓存下来给 _floor_ahead 用，不要每帧查树
	_world = get_parent().get_node_or_null("World") as TileMapLayer


## R 键：回到起点重新走一遍，铁栅那边也会被 gate.reset_mechanism() 关回去。
## 少了这一条，3-1 按 R 之后虚影还杵在出口旁，玩家跟着走过去就通关了。
func reset_mechanism() -> void:
	_restart()


func _physics_process(delta: float) -> void:
	if halted:
		move_with_input(delta, 0.0, false, false)
		return
	if _wait < delay:
		# 等待期间也要走物理，出生点若悬空它会落地，而不是浮在半空
		_wait += delta
		move_with_input(delta, 0.0, false, false)
		return
	# 掉出地图就回**自己的**起点。不能调 reset_to_spawn()：那是玩家的重生
	# 逻辑，respawn_position 指向玩家出生点，虚影会被搬到地图另一头。
	if global_position.y > kill_y:
		_restart()
		return
	if not triggered and global_position.x >= trigger_x:
		triggered = true
		trigger_pulled.emit()
	if global_position.x >= stop_x:
		halted = true
		radii = still_radii
		return
	var jump := is_on_floor() and (is_on_wall() or not _floor_ahead())
	move_with_input(delta, 1.0, jump, false)


func _restart() -> void:
	global_position = _start
	velocity = Vector2.ZERO
	halted = false
	triggered = false
	_wait = 0.0
	radii = start_radii


## 前方 38px、脚下 46px 处有没有瓦片。
func _floor_ahead() -> bool:
	if _world == null:
		return true
	var probe := _world.to_local(global_position + Vector2(38.0, 46.0))
	return _world.get_cell_source_id(_world.local_to_map(probe)) >= 0
