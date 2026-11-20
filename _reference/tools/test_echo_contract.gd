extends SceneTree
## 虚影的两条「契约」，谁破坏谁请客：
##
## 1. **判定体积与贴图解耦**：机关和撞墙只看 `body_size`，美术给 56×76
##    或者多留透明边，都不能改变「刚好踩不踩得到 / 离墙多远停」。
## 2. **只有一个激活状态**：虚影生成时未激活（不显示、无碰撞、不推进、
##    机关不认），玩家复活时 `reset()` 才登场。回放 / 碰撞 / 机关判定同源。
##
## 这两条一旦破掉，表现是"美术换图把谜题改了"和"看不见的虚影把板压住了"，
## 都很难从画面上定位，所以用断言钉住。

const ECHO := preload("res://scenes/echo/echo.tscn")
const Bounds = preload("res://scripts/actor_bounds.gd")

var room: Node2D
var plate: Node2D
var area: Rect2
var manager: Node


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


func make_echo(pos: Vector2) -> Node2D:
	var echo := ECHO.instantiate()
	room.add_child(echo)
	echo.setup(PackedVector2Array([pos, pos, pos, pos]))
	return echo


func run() -> void:
	room = load("res://scenes/levels/complete_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	manager = room.get_node("EchoManager")
	await frames(10)
	plate = room.get_node("PlateA")
	area = plate.global_transform * Rect2(Vector2.ZERO, plate.block_size)
	# 尺寸从场景读，不写死像素——人物外观/碰撞都调过一次（28x38 -> 32x44）
	var template := ECHO.instantiate()
	var body_size: Vector2 = template.body_size
	template.free()
	var stand_pos := Vector2(area.position.x + 10.0, area.position.y - body_size.y)

	# ---------- 1. 未激活 = 不显示、无碰撞、不推进、机关不认 ----------
	var e := make_echo(stand_pos)
	check(not e.is_active(), "echo starts inactive after setup")
	check(not e.visible, "inactive echo is not visible")
	check(not e.get_collision_layer_value(3), "inactive echo has no collision layer")
	await frames(4)
	check(e.get_node("Top").disabled, "inactive echo's standable shape is disabled")
	var start_frame: int = e.frame_index
	for i in 10:
		e.advance(1.0 / 60.0)
	check(e.frame_index == start_frame, "inactive echo does not advance replay")
	check(not plate.active, "inactive echo does not press plate")

	# ---------- 2. 激活后三件事同时生效 ----------
	e.reset()
	await frames(4)
	check(e.is_active() and e.visible and e.get_collision_layer_value(3), "reset activates echo (visible + collision)")
	check(not e.get_node("Top").disabled, "active echo's standable shape is enabled")
	check(plate.active, "active echo presses plate")

	# ---------- 3. 换图不改判定：56×76 的图仍然按 body_size 判定 ----------
	var body := e.get_node("Body") as Sprite2D
	var rect_before: Rect2 = Bounds.rect(e)
	var img := Image.create(56, 76, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.9, 1.0, 0.6))
	# 换美术走 character_portrait.set_art()：它持有睁眼/闭眼两张图。
	# 直接改 Sprite.texture 会被眨眼逻辑在下一帧顶回去（那才是之前"换图没反应"的根因）。
	body.set_art(ImageTexture.create_from_image(img))
	e.fit_visuals()
	await frames(2)
	var rect_after: Rect2 = Bounds.rect(e)
	check(rect_after.size.is_equal_approx(body_size), "body rect ignores art size")
	check(rect_after.position.is_equal_approx(rect_before.position), "body rect position unchanged by art swap")
	# 外观规则（character_portrait）：高 = body_size.y × 外观比例，宽按原图长宽比，脚底对齐。
	# 外观允许比碰撞框高（头发/装饰伸出去），但**判定永远只认 body_size**。
	var ratio: float = float(body.get("visual_height_ratio"))
	var drawn := body.texture.get_size() * body.scale
	check(is_equal_approx(drawn.y, body_size.y * ratio), "art height = body_size.y × visual ratio")
	check(is_equal_approx(drawn.x / drawn.y, 56.0 / 76.0), "art keeps its own aspect ratio")
	check(is_equal_approx(body.position.y + drawn.y, body_size.y), "art is bottom-aligned to body")

	# 判定边界也必须没变：4px 重叠算踩住，完全离开不算
	e.global_position = Vector2(area.end.x - 4.0, area.position.y - body_size.y)
	await frames(4)
	check(plate.active, "4px overlap still counts after art swap")
	e.global_position = Vector2(area.end.x + 2.0, area.position.y - body_size.y)
	await frames(4)
	check(not plate.active, "fully off plate still does not count after art swap")

	# ---------- 4. body_size 才是唯一开关：改它，判定/薄片/外观一起变 ----------
	e.global_position = Vector2(120, 520)
	e.body_size = Vector2(40, 50)
	await frames(2)
	check(Bounds.rect(e).size.is_equal_approx(Vector2(40, 50)), "body rect follows body_size")
	var top_shape := (e.get_node("Top") as CollisionShape2D).shape as RectangleShape2D
	check(is_equal_approx(top_shape.size.x, 40.0), "standable strip width follows body_size")
	var drawn2 := body.texture.get_size() * body.scale
	check(is_equal_approx(drawn2.y, 50.0 * ratio), "art height scales with body_size too")
	check(is_equal_approx(drawn2.x / drawn2.y, 56.0 / 76.0), "art keeps aspect after body_size change")
	var probe_shape := e.get("_probe") as RectangleShape2D
	check(probe_shape.size.is_equal_approx(Vector2(38, 48)), "wall probe is body_size minus 1px inset")
	e.queue_free()
	await frames(2)

	# ---------- 5. 真实生命周期：死亡→复活之间，虚影不得提前生效 ----------
	var trail := PackedVector2Array([stand_pos, stand_pos, stand_pos])
	manager.call("_add_echo", trail)
	var spawned: Node2D = manager.get_child(manager.get_child_count() - 1)
	check(not spawned.is_active() and not spawned.visible, "echo spawned while player dead stays inactive")
	await frames(10)
	check(not plate.active, "hidden echo does not press plate while player is dead")
	manager.call("_on_player_respawned")
	await frames(6)
	check(spawned.is_active(), "echo activates on player respawn")
	check(plate.active, "activated echo presses plate after respawn")

	print("ECHO_CONTRACT_ALL_PASS")
	quit()
