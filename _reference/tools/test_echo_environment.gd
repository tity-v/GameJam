extends SceneTree
## 锁定「虚影对环境有碰撞体积」这条规则，以及它的边界。
##
## 结论先写在这：
##   机关（压力板）→ 认虚影**完整身体矩形**，踩上去就响应
##   出口 / 尖刺   → 只认玩家，虚影不触发、不会被杀
##   墙 / 关着的门 → **挡不住虚影**（重放坐标，不做物理模拟）
##
## 最后一条不是 bug，是这套"录坐标重放"的必然代价。写进测试是为了让改这部分的人
## 知道自己在改什么，而不是某天发现"虚影穿门"就顺手给 echo 加 mask —— 那会让
## 重放位置和录下的位置对不上，整关错位。

const ECHO := preload("res://scenes/echo/echo.tscn")

var room: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
	print("PASS ", message)


## 造一条静止的虚影（两帧同点，不会自己走动），用来测"站在某处"的判定
func place_echo(pos: Vector2) -> Node2D:
	var echo := ECHO.instantiate()
	room.add_child(echo)
	echo.setup(PackedVector2Array([pos, pos]))
	echo.global_position = pos
	return echo


func run() -> void:
	room = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	player = room.get_node("Player")
	await frames(10)

	var plate := room.get_node("PlateA") as Node2D
	var area: Rect2 = plate.global_transform * Rect2(Vector2.ZERO, plate.block_size)

	# --- 0. 虚影的"体积"就是 28x38 身体矩形（美术换图会改变这个矩形） ---
	var probe := place_echo(Vector2(120, 538))
	await frames(2)
	var rect: Rect2 = preload("res://scripts/actor_bounds.gd").rect(probe)
	check(rect.size.is_equal_approx(Vector2(28, 38)), "echo body rect is 28x38 (art swap would change it)")

	# --- 1. 空场：板不亮 ---
	probe.queue_free()
	await frames(4)
	check(not plate.active, "empty plate is inactive")

	# --- 2. 虚影站上去 → 板响应（用户要求的那条） ---
	var foot_y: float = area.position.y
	var stand := place_echo(Vector2(area.position.x + 10.0, foot_y - 38.0))
	await frames(4)
	check(plate.active, "echo standing on plate presses it")
	check(plate.get_node("Patch").texture.resource_path.ends_with("pressure_on.png"), "plate swaps to on texture")

	# --- 3. 虚影走开 → 板释放 ---
	stand.global_position = Vector2(area.position.x - 300.0, foot_y - 38.0)
	await frames(4)
	check(not plate.active, "echo leaving plate releases it")

	# --- 4. 悬在板的上方（脚够不着）不触发：判定看脚底，不是整块重叠 ---
	stand.global_position = Vector2(area.position.x + 10.0, foot_y - 38.0 - 40.0)
	await frames(4)
	check(not plate.active, "echo floating above plate does not press it")

	# --- 5. 半拉出板的横向范围 → 只要还有重叠就算踩住 ---
	stand.global_position = Vector2(area.end.x - 4.0, foot_y - 38.0)
	await frames(4)
	check(plate.active, "4px horizontal overlap still counts")
	stand.global_position = Vector2(area.end.x + 2.0, foot_y - 38.0)
	await frames(4)
	check(not plate.active, "fully off the plate does not count")

	# --- 6. 尖刺只杀玩家，不杀虚影 ---
	var spikes := room.get_node("Spikes") as Node2D
	var spike_rect: Rect2 = spikes.global_transform * Rect2(Vector2(3, 4), Vector2(spikes.block_size.x - 6, spikes.block_size.y - 8))
	stand.global_position = spike_rect.position - Vector2(-2, 8)
	await frames(6)
	check(is_instance_valid(stand) and stand.is_visible_in_tree() and not stand.is_gone(), "spikes do not kill echo")
	check(not player.is_dead, "player far from spikes stays alive")

	# --- 7. 出口只认玩家：虚影站在出口上不会通关 ---
	var exit_node := room.get_node("Exit") as Node2D
	stand.global_position = exit_node.global_position + Vector2(8, 8)
	await frames(6)
	check(not room.won, "echo standing on exit does not win")

	# --- 8. 关着的门挡不住虚影（重放坐标，不做物理） ---
	var door := room.get_node("Door") as Node2D
	check(not door.opened, "door starts closed")
	var inside := door.global_position + Vector2(30, 40)
	stand.global_position = inside
	await frames(6)
	check(stand.global_position.is_equal_approx(inside), "closed door does not push echo out (no world physics)")

	# --- 9. 播完进入 1.3s 淡出的"尸体"仍然压得住板；彻底消失后释放 ---
	var corpse := place_echo(Vector2(area.position.x + 10.0, foot_y - 38.0))
	corpse.setup(PackedVector2Array([
		corpse.global_position,
		corpse.global_position + Vector2(1, 0),
		corpse.global_position + Vector2(2, 0),
	]))
	await frames(4)
	check(plate.active, "corpse still presses plate before replay ends")
	corpse.advance(0.02)
	corpse.advance(0.02)
	await frames(2)
	check(corpse.is_gone() == false, "corpse is still solid during the 1.3s fade")
	check(plate.active, "fading corpse still presses plate")
	corpse.advance(1.5)
	await frames(2)
	check(corpse.is_gone(), "corpse is gone after fade")
	check(not plate.active, "gone corpse releases plate")

	print("ECHO_ENVIRONMENT_ALL_PASS")
	quit()
