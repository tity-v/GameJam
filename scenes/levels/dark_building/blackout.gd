extends TileMapLayer
## 只读取本帧角色与机关的位置，遮罩没有碰撞。
@export var personal_radii := Vector2(72,100)
## 虚影的照亮半径。**已废弃**：虚影现在自己带一盏灯（`echo.gd` 的 Lamp，
## 挂进 `torch_light` 组），光的大小由「死时手里有没有手电」决定——
## 没手电时 72/100（和主角一样），有手电时 120/180（和持手电的主角一样）。
## 所以这里不再单独给虚影画圈，否则会画两圈。属性留着只为旧场景里的赋值不报错。
@export var echo_radii := Vector2(72,100)
@export var torch_radii := Vector2(128,176)
## 光由内向外衰减的曲线。1.0 = 线性（原行为），越大外圈越早暗、中心越保。
@export var falloff := 1.0
var torches: TileMapLayer
var clock := 0.0
var flags: Array[Node] = []
func _ready() -> void:
	torches = get_parent().get_node("Torches")
	flags = get_parent().find_children("*","Area2D",true,false).filter(func(n): return n.has_method("set_lit"))
	refresh()
func _process(dt: float) -> void:
	clock += dt
	refresh()
func refresh() -> void:
	var circles := PackedVector4Array()
	for player in get_tree().get_nodes_in_group("player"):
		var weight := 1.0
		if player.is_dead: weight = maxf(0.01,1.0-player._death_time/player.death_duration)
		add_circle(circles,player.global_position+Vector2(16,22),personal_radii*weight)
	for flag in flags: add_circle(circles,flag.global_position,personal_radii)
	# 动态光源统一走这个循环：随身手电、地上的手电、火盆、虚影身上的灯。
	# 它们的共同点是半径会变（未拾取 72 / 持手电 120 / 火盆 0→140），
	# 而 personal_radii 是常量，所以不能并进 player 那一段。
	for light in get_tree().get_nodes_in_group("torch_light"):
		var radii: Variant = light.get("radii")
		if radii is Vector2:
			add_circle(circles,light.global_position,radii)
	for cell in torches.get_used_cells(): add_circle(circles,torches.to_global(torches.map_to_local(cell)),torch_radii)
	material.set_shader_parameter("count",circles.size())
	circles.resize(32)
	material.set_shader_parameter("sources",circles)
	material.set_shader_parameter("drift",clock)
	material.set_shader_parameter("falloff",falloff)
func add_circle(list: PackedVector4Array, center: Vector2, radii: Vector2) -> void:
	if list.size()<32: list.append(Vector4(center.x,center.y,radii.x,radii.y))
