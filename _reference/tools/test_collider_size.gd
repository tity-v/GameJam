extends SceneTree
## 实测：改主角碰撞体积时的行为边界。
## 结论分四段：①基线 ②正确同步改大 ③只改 size 不改 position ④高速是否隧穿 ⑤极端小尺寸

var lvl: Node
var player: CharacterBody2D
var col: CollisionShape2D


func _initialize() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")
	col = player.get_node("Collision") as CollisionShape2D
	_run()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _sh() -> RectangleShape2D:
	return col.shape as RectangleShape2D


## 节点原点 = 包围盒左上角，所以视觉脚底就是 y + 碰撞高度
func _feet() -> float:
	return player.global_position.y + _sh().size.y


func _place(x: float, floor_y: float = 560.0) -> void:
	player.global_position = Vector2(x, floor_y - _sh().size.y - 30.0)
	player.velocity = Vector2.ZERO


func _resize(w: float, h: float, sync_pos: bool) -> void:
	_sh().size = Vector2(w, h)
	if sync_pos:
		col.position = Vector2(w, h) * 0.5
	player.call("_fit_visuals")


func _jump_height() -> float:
	var start := player.global_position.y
	var top := start
	Input.action_press("jump")
	for i in 90:
		await physics_frame
		top = minf(top, player.global_position.y)
	Input.action_release("jump")
	await _wait(40)
	return start - top


func _run() -> void:
	await _wait(3)

	print("=== A 基线（28x38）===")
	print("  shape.size = %s   Collision.position = %s" % [_sh().size, col.position])
	print("  站立 y=%.2f  脚底=%.2f  贴地=%s" % [player.global_position.y, _feet(), player.is_on_floor()])
	var base_jump := await _jump_height()

	print("\n=== B 改成 56x76，position 同步为 (28,38) ===")
	_resize(56, 76, true)
	_place(300)
	await _wait(50)
	print("  站立 y=%.2f  脚底=%.2f（地面顶面 560）  贴地=%s" % [
		player.global_position.y, _feet(), player.is_on_floor()])
	print("  Sprite.scale = %s（自动跟随，贴图没重画）" % player.get_node("Sprite").scale)
	var big_jump := await _jump_height()
	print("  跳高 基线 %.1f → 改大后 %.1f（跳跃参数没变，所以高度不变）" % [base_jump, big_jump])

	Input.action_press("move_left")
	await _wait(120)
	Input.action_release("move_left")
	await _wait(10)
	print("  一路向左撞墙，停在 x=%.2f（墙面在 x=0）" % player.global_position.x)

	print("\n=== C 只改 size、忘了改 position（最常见的手误）===")
	_resize(28, 38, true)
	_sh().size = Vector2(56, 76)   # 只改尺寸
	player.call("_fit_visuals")
	_place(300)
	await _wait(50)
	print("  Collision.position = %s（应为其一半 (28,38)）" % col.position)
	print("  碰撞底 = %.2f（应为 76）  →  视觉脚底插进地面 %.1f px" % [
		col.position.y + _sh().size.y * 0.5, _feet() - 560.0])

	print("\n=== D 极端速度会不会穿墙（28x38）===")
	_resize(28, 38, true)
	player.set("max_speed", 6000.0)
	player.set("accel", 200000.0)
	_place(400)
	await _wait(30)
	Input.action_press("move_left")
	await _wait(60)
	Input.action_release("move_left")
	await _wait(10)
	print("  6000 px/s（约 100 px/帧）撞墙，x=%.2f（墙面在 0，不能为负）" % player.global_position.x)
	player.set("max_speed", 210.0)
	player.set("accel", 1800.0)

	print("\n=== E 极端小尺寸 4x4 ===")
	_resize(4, 4, true)
	_place(300)
	await _wait(50)
	print("  站立 y=%.2f  脚底=%.2f  贴地=%s" % [player.global_position.y, _feet(), player.is_on_floor()])
	var ys := []
	for i in 20:
		await physics_frame
		ys.append(player.global_position.y)
	print("  静止 20 帧 y 波动 = %.4f px（>0.5 说明在抖）" % (ys.max() - ys.min()))

	print("\n=== F 改大后忘改出生点（关卡里仍是 522）===")
	_resize(56, 76, true)
	player.global_position = Vector2(90, 522)   # 高 76 时脚底会到 598，与地面重叠 38px
	player.velocity = Vector2.ZERO
	await _wait(1)
	print("  塞入瞬间 y=%.2f 脚底=%.2f（插进地面 %.0f px）" % [
		player.global_position.y, _feet(), _feet() - 560.0])
	await _wait(40)
	print("  40 帧后 y=%.2f 脚底=%.2f 贴地=%s（引擎自动解穿插，不是卡死）" % [
		player.global_position.y, _feet(), player.is_on_floor()])
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await _wait(30)
	Input.action_release("move_right")
	print("  按 D 半秒位移 = %.1f（正常应约 91，说明没被卡住）" % (player.global_position.x - x0))

	quit()
