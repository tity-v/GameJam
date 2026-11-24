extends SceneTree
## 从主界面一路点到 3-1，确认目录改动后真的能进、且进得干净。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_flow_31.gd
##
## 必须带窗口跑：headless 拿不到渲染结果，也走不了滑动转场。

const OUT := "res://build/shots/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var entry: Node = (load("res://frontend/entry.tscn") as PackedScene).instantiate()
	root.add_child(entry)
	current_scene = entry
	await _wait(90)
	var session := _session()
	if session == null:
		print("EMPTY no session")
		quit(1)
		return
	session.request("chapter", 2)
	await _wait(12)
	await _shot("ui_chapter3")
	print("A 第 3 章卡片=", _card_texts(session))
	session.request("choose", 10)
	await _wait(150)
	var room := current_scene
	print("B 进入后的场景=", room.name if room != null else "<null>",
		"  page=", session.flow.page, "  current=", session.flow.current)
	if room != null:
		print("C 有 won 属性=", room.get("won") != null,
			"  旧结算面板=", room.get_node_or_null("UI/Win") != null,
			"  黑幕格数=", (room.get_node("Blackout") as TileMapLayer).get_used_cells().size() if room.get_node_or_null("Blackout") != null else -1)
	await _shot("ui_in_31")
	# 直接判定通关，确认前端能接管结算并推进到下一间
	if room != null and room.has_method("complete"):
		room.complete()
		await _wait(40)
		print("D 通关后 page=", session.flow.page, "  completed=", session.flow.completed.size())
	await _shot("ui_31_result")
	print("DONE")
	quit()


func _wait(count: int) -> void:
	for i in count:
		await process_frame


func _session() -> Node:
	for child in root.get_children():
		if child.has_method("request") and child.get("flow") != null:
			return child
	return null


func _card_texts(session: Node) -> Array:
	var out: Array = []
	for card in session.page_model().get("cards", []):
		out.append(str(card.text).replace("\n", " / "))
	return out


func _shot(name: String) -> void:
	await _wait(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", name)
		return
	img.save_png(OUT + name + ".png")
	print("saved ", name)
