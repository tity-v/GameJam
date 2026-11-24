extends SceneTree
## 拍主界面三页，确认「试玩开关」有没有让第三章的卡片变成可点。
##   godot --path . --fixed-fps 60 -s _reference/tools/shot_main_menu.gd
##
## 必须带窗口跑：headless 拿不到渲染结果。

const OUT := "res://build/shots/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var entry: Node = (load("res://frontend/entry.tscn") as PackedScene).instantiate()
	root.add_child(entry)
	current_scene = entry
	# 入口会先异步挂一个房间当背景，等它稳定
	for i in 90:
		await process_frame
	var session := _session()
	if session == null:
		print("EMPTY 找不到 session")
		quit(1)
		return
	await _shot("ui_home")
	session.request("levels")
	await _shot("ui_levels")
	session.request("chapter", 2)
	await _shot("ui_chapter3")
	print("DONE")
	quit()


func _session() -> Node:
	for child in root.get_children():
		if child.has_method("request") and child.get("flow") != null:
			return child
	return null


func _shot(name: String) -> void:
	for i in 12:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("EMPTY ", name)
		return
	img.save_png(OUT + name + ".png")
	print("saved ", name, " ", img.get_width(), "x", img.get_height())
