extends TileMapLayer
## 只读取本帧角色与机关的位置，遮罩没有碰撞。
@export var personal_radii := Vector2(72,100)
@export var torch_radii := Vector2(128,176)
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
	for echo in get_tree().get_nodes_in_group("echo"):
		if echo.is_active():
			add_circle(circles,echo.body_rect().get_center(),personal_radii*maxf(0.01,1.0-echo._fade_time/echo.fade_duration))
	for flag in flags: add_circle(circles,flag.global_position,personal_radii)
	for cell in torches.get_used_cells(): add_circle(circles,torches.to_global(torches.map_to_local(cell)),torch_radii)
	material.set_shader_parameter("count",circles.size())
	circles.resize(32)
	material.set_shader_parameter("sources",circles)
	material.set_shader_parameter("drift",clock)
func add_circle(list: PackedVector4Array, center: Vector2, radii: Vector2) -> void:
	if list.size()<32: list.append(Vector4(center.x,center.y,radii.x,radii.y))
