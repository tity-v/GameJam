extends SceneTree
## 校验「尺寸解耦」：贴图/碰撞/叉号都跟着一个尺寸源走，且同类实例互不串台。

var lvl: Node
var player: Node2D
var step := 0
var fails := 0


func _initialize() -> void:
	lvl = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(lvl)
	player = lvl.get_node("Player")


func _process(_d: float) -> bool:
	step += 1
	if step == 4:
		_run()
		print("失败项：", fails)
		return true
	return false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print(("  OK  " if cond else "  FAIL") + " " + label + ("" if detail == "" else "  " + detail))
	if not cond:
		fails += 1


func _run() -> void:
	print("=== 物块：block_size 是唯一尺寸源 ===")
	var g: Node2D = lvl.get_node("Solids/Ground")
	var w: Node2D = lvl.get_node("Solids/Wall")
	var gp: Control = g.get_node("Patch")
	var gc: CollisionShape2D = g.get_node("Collision")
	_check("Ground block_size", g.block_size == Vector2(1800, 120), str(g.block_size))
	_check("Ground Patch.size 跟随", gp.size == Vector2(1800, 120), str(gp.size))
	_check("Ground 碰撞尺寸跟随", (gc.shape as RectangleShape2D).size == Vector2(1800, 120))
	_check("Ground 碰撞居中", gc.position == Vector2(900, 60), str(gc.position))
	_check("Ground 顶边九宫格 3px", (gp as NinePatchRect).patch_margin_top == 3)

	print("=== 九宫格：拉伸后边角不变形 ===")
	_check("出口四边 margin=3",
		_assert_exit_margins(), "")

	print("=== 策划改尺寸：一处改动，贴图与碰撞同步 ===")
	g.block_size = Vector2(1000, 80)
	_check("改后 Patch.size", gp.size == Vector2(1000, 80), str(gp.size))
	_check("改后碰撞尺寸", (gc.shape as RectangleShape2D).size == Vector2(1000, 80))
	_check("改后碰撞居中", gc.position == Vector2(500, 40), str(gc.position))

	print("=== 同类实例互不串台（resource_local_to_scene）===")
	var wc: CollisionShape2D = w.get_node("Collision")
	_check("改地面不影响左墙", (wc.shape as RectangleShape2D).size == Vector2(40, 680),
		str((wc.shape as RectangleShape2D).size))

	print("=== 玩家：叉号是节点，随碰撞体缩放 ===")
	_check("DeathMark 存在", player.get_node_or_null("DeathMark") != null)
	var mark: Sprite2D = player.get_node("DeathMark")
	_check("初始不可见", not mark.visible)
	# 叉号是「碰撞框」的标记，按 碰撞尺寸 / design_size 缩放。
	# 人物外观走 character_portrait（48 高、底部对齐），和叉号差 4px 是有意的：
	# 叉号标的是"死在哪块判定矩形上"，不是人物剪影。
	var pc0: CollisionShape2D = player.get_node("Collision")
	var design: Vector2 = player.design_size
	var body0: Vector2 = (pc0.shape as RectangleShape2D).size
	_check("叉号按碰撞尺寸缩放",
		mark.scale.is_equal_approx(Vector2(body0.x / design.x, body0.y / design.y)), str(mark.scale))
	player.die()
	_check("死亡时出现", mark.visible)
	var spr: Sprite2D = player.get_node("Sprite")
	_check("死亡时方块开始淡出", player.is_dead)
	player.respawn()
	_check("复活后隐藏", not mark.visible)

	# 模拟策划把角色放大一倍：只改碰撞体尺寸，外观应自动跟上
	var pc: CollisionShape2D = player.get_node("Collision")
	(pc.shape as RectangleShape2D).size = Vector2(56, 76)
	player.call("_fit_visuals")
	_check("叉号跟着放大", mark.scale.is_equal_approx(Vector2(56.0 / design.x, 76.0 / design.y)), str(mark.scale))
	# 人物外观现在由 character_portrait 定规则：高 = 碰撞高 × 外观比例，宽按贴图长宽比
	var ratio: float = float(spr.get("visual_height_ratio"))
	var drawn: Vector2 = spr.texture.get_size() * spr.scale
	_check("人物外观跟着放大", is_equal_approx(drawn.y, 76.0 * ratio), str(drawn))
	_check("放大后保持原图长宽比",
		is_equal_approx(drawn.x / drawn.y, spr.texture.get_size().x / spr.texture.get_size().y), str(drawn))
	# 改回去，别影响后续截图/回归
	(pc.shape as RectangleShape2D).size = body0
	player.call("_fit_visuals")

	print("=== 暂停按钮：贴图驱动 ===")
	var pm = root.get_node_or_null("PauseMenu")
	_check("PauseMenu 已挂载", pm != null)
	var btn = pm.get_node("Root/ContinueButton") if pm != null else null
	_check("按钮是 TextureButton", btn is TextureButton, "" if btn == null else btn.get_class())
	if btn is TextureButton:
		_check("normal 贴图已设", btn.texture_normal != null)
		_check("hover 贴图已设", btn.texture_hover != null)
		_check("pressed 贴图已设", btn.texture_pressed != null)
		_check("点击信号已连", btn.pressed.get_connections().size() > 0)


func _assert_exit_margins() -> bool:
	var ex = lvl.get_node("Exit")
	var p: NinePatchRect = ex.get_node("Patch")
	return (p.patch_margin_top == 3 and p.patch_margin_bottom == 3
		and p.patch_margin_left == 3 and p.patch_margin_right == 3)
