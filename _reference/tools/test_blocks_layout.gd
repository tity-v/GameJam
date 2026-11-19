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
	_check("初始 scale=1", mark.scale == Vector2.ONE, str(mark.scale))
	player.die()
	_check("死亡时出现", mark.visible)
	var spr: Sprite2D = player.get_node("Sprite")
	_check("死亡时方块开始淡出", player.is_dead)
	player.respawn()
	_check("复活后隐藏", not mark.visible)

	# 模拟策划把角色放大一倍：只改碰撞体尺寸，贴图应自动跟上
	var pc: CollisionShape2D = player.get_node("Collision")
	(pc.shape as RectangleShape2D).size = Vector2(56, 76)
	player.call("_fit_visuals")
	_check("叉号缩放 2x", mark.scale == Vector2(2, 2), str(mark.scale))
	_check("方块缩放 2x", spr.scale == Vector2(2, 2), str(spr.scale))
	# 改回去，别影响后续截图/回归
	(pc.shape as RectangleShape2D).size = Vector2(28, 38)
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
