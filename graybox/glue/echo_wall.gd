@tool
extends StaticBody2D
## 左上对齐 TileMap。碰撞层只对实体角色和实体组件生效。
@export var cells := Vector2i.ONE:
	set(value):
		cells = value.max(Vector2i.ONE)
		if is_node_ready(): resize()

func _ready() -> void:
	resize()

func resize() -> void:
	var size := Vector2(cells) * 32
	$Collision.shape.size = size
	$Collision.position = size / 2
	queue_redraw()

func _draw() -> void:
	var width := cells.x * 32
	for row in range(cells.y * 2):
		for x in range(-16 * (row % 2), width, 32):
			var left := maxi(0, x)
			var brick := Rect2(left+1,row*16+1,mini(x+32,width)-left-2,14)
			draw_rect(brick,Color("#9960cf83"))
			draw_line(brick.position,brick.position+Vector2(brick.size.x,0),Color("#d5adf9bd"),2)
