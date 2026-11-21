extends SceneTree
## 锁定「虚影对环境有碰撞体积」这条规则，以及它的边界。
##
## 结论先写在这：
##   机关（压力板）→ 认虚影**完整身体矩形**，踩上去就响应
##   墙 / 关着的门 → **挡得住**，撞上停在接触点（每帧位移扫描，不隧穿）
##   出口 / 尖刺   → 只认玩家，虚影不触发、不会被杀
##
## 挡住这件事是"截短位移"实现的，不是给 echo 加 collision_mask ——
## 加 mask 会让引擎自己去推它，和喂进来的坐标打架。
## 扫描方向和 one_way 的判定见 test_echo_oneway.gd：那也是一条曾经踩过的坑。

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
	echo.reset()  # 测试里直接摆一个「已登场」的虚影
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

	# --- 0. 虚影的"体积"就是 body_size 矩形（美术换图不会改这个矩形） ---
	# 尺寸从脚本读，不写死数字：人物尺寸调整过一次（28x38 -> 32x44），
	# 写死像素的断言会变成"改个外观就红"，那不是它要守的东西。
	var probe := place_echo(Vector2(120, 532))
	await frames(2)
	var body_size: Vector2 = probe.body_size
	var rect: Rect2 = preload("res://scripts/actor_bounds.gd").rect(probe)
	check(rect.size.is_equal_approx(body_size), "echo body rect equals body_size (not art)")

	# --- 1. 空场：板不亮 ---
	probe.queue_free()
	await frames(4)
	check(not plate.active, "empty plate is inactive")

	# --- 2. 虚影站上去 → 板响应（用户要求的那条） ---
	var foot_y: float = area.position.y
	var stand := place_echo(Vector2(area.position.x + 10.0, foot_y - body_size.y))
	await frames(4)
	check(plate.active, "echo standing on plate presses it")
	check(plate.get_node("Patch").texture.resource_path.ends_with("pressure_on.png"), "plate swaps to on texture")

	# --- 3. 虚影走开 → 板释放 ---
	stand.global_position = Vector2(area.position.x - 300.0, foot_y - body_size.y)
	await frames(4)
	check(not plate.active, "echo leaving plate releases it")

	# --- 4. 悬在板的上方（脚够不着）不触发：判定看脚底，不是整块重叠 ---
	stand.global_position = Vector2(area.position.x + 10.0, foot_y - body_size.y - 40.0)
	await frames(4)
	check(not plate.active, "echo floating above plate does not press it")

	# --- 5. 半拉出板的横向范围 → 只要还有重叠就算踩住 ---
	stand.global_position = Vector2(area.end.x - 4.0, foot_y - body_size.y)
	await frames(4)
	check(plate.active, "4px horizontal overlap still counts")
	stand.global_position = Vector2(area.end.x + 2.0, foot_y - body_size.y)
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

	# --- 8. 关着的门挡住虚影：撞在门上停住，不会隧穿 ---
	var door := room.get_node("Door") as Node2D
	check(not door.opened, "door starts closed")
	# 门的左右边从节点读，别写死像素——门挪到格线上（26~27 列）后这里才不会假过
	var door_left: float = door.global_position.x
	var door_right: float = door_left + door.block_size.x
	var path := PackedVector2Array()
	for f in 100:
		path.append(Vector2(790.0 + f * 5.0, 576.0 - body_size.y))  # 790 → 1285，横穿整道门
	var crosser := ECHO.instantiate()
	room.add_child(crosser)
	crosser.setup(path)
	crosser.reset()
	for i in 20:
		crosser.advance(1.0 / 60.0)
	await frames(2)
	check(crosser.global_position.x > 800.0, "echo moves normally before the door")
	check(crosser.global_position.x < door_left, "closed door blocks echo (no pass-through)")
	check(crosser.global_position.x < door_left - 10.0, "echo stops at the door surface, not inside it")

	# --- 9. 门开了就能穿过去（等价于双板满足后的状态） ---
	# 门现在是「松开任一压板就关」，直接 set opened 会被它自己的 _physics_process
	# 下一帧关回去。所以先把门的检测停掉，摆成"两块板一起踩着"的静止状态。
	door.set_physics_process(false)
	door.set("opened", true)
	door.get_node("Collision").set_deferred("disabled", true)
	await frames(4)
	for i in 60:
		crosser.advance(1.0 / 60.0)
	await frames(2)
	check(crosser.global_position.x > door_right, "open door lets echo through")
	door.set_physics_process(true)

	# --- 9. 实心墙走的是同一条判定（不是只有门才挡） ---
	# 门和墙都是 layer 1 的 StaticBody2D，理论上一致；这里实测一次，防止以后
	# 有人给门加特殊处理却漏掉普通墙。
	var wall: Node2D = load("res://scenes/blocks/solid_wall.tscn").instantiate()
	wall.set("block_size", Vector2(40, 120))
	wall.position = Vector2(500, 456)  # 500..540，坐在地面 576 上
	room.add_child(wall)
	await frames(3)
	check(is_instance_valid(wall.get_node_or_null("Collision")) or wall.has_node("Collision"),
		"solid wall has a collision shape")
	var wall_path := PackedVector2Array()
	for f in 60:
		wall_path.append(Vector2(380.0 + f * 5.0, 576.0 - body_size.y))
	var into_wall := ECHO.instantiate()
	room.add_child(into_wall)
	into_wall.setup(wall_path)
	into_wall.reset()
	for i in 60:
		into_wall.advance(1.0 / 60.0)
	await frames(2)
	check(into_wall.global_position.x < 500.0, "solid wall blocks echo (no pass-through)")
	check(into_wall.global_position.x > 455.0, "echo stops at the wall surface, not far away")

	# --- 10. 播完进入 1.3s 淡出的"尸体"仍然压得住板；彻底消失后释放 ---
	var corpse := place_echo(Vector2(area.position.x + 10.0, foot_y - body_size.y))
	corpse.setup(PackedVector2Array([
		corpse.global_position,
		corpse.global_position + Vector2(1, 0),
		corpse.global_position + Vector2(2, 0),
	]))
	corpse.reset()
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
