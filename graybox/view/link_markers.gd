extends Node2D
## 每个关联源分配一种颜色，相同颜色同时标在源和目标下方。

var marks: Dictionary = {}
var style: Dictionary

func _ready() -> void:
	style = JSON.parse_string(FileAccess.get_file_as_string("res://graybox/db/link_markers.json"))
	var index := 0
	for source in get_parent().find_children("*", "Node2D", true, false):
		var targets: Array[Node2D] = []
		for key in [&"plate_paths", &"destination", &"switch_source"]:
			if not key in source:
				continue
			var value = source.get(key)
			for link in (value if value is Array else [value]):
				var target = source.get_node_or_null(link) if link is NodePath and not link.is_empty() else link
				if target is Node2D and target != source and not targets.has(target):
					targets.append(target)
		if targets.is_empty():
			continue
		for target in targets:
			var color := Color(style.colors[index % style.colors.size()])
			index += 1
			for endpoint in [source, target]:
				if not marks.has(endpoint):
					marks[endpoint] = []
				marks[endpoint].append(color)
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for target in marks:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			continue
		var size := Vector2.ZERO
		if "block_size" in target:
			size = target.block_size
		elif target.get_node_or_null("Patch") is Control:
			size = target.get_node("Patch").size
		var center: Vector2 = target.global_transform * Vector2(size.x * 0.5, size.y)
		var colors: Array = marks[target]
		var step: float = style.size + style.gap
		var width: float = colors.size() * step - style.gap
		var origin := to_local(center) + Vector2(-width * 0.5, style.offset)
		for i in colors.size():
			var rect := Rect2(origin + Vector2(i * step, 0), Vector2.ONE * float(style.size))
			draw_rect(rect.grow(1), Color(style.outline))
			draw_rect(rect, colors[i])
