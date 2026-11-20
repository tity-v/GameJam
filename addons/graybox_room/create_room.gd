@tool
extends RefCounted
const Flow = preload("res://frontend/systems/flow.gd")
const STARTER := """[gd_scene format=3]
[ext_resource type="PackedScene" path="res://graybox/base_level.tscn" id="base"]
[ext_resource type="PackedScene" path="res://graybox/exit.tscn" id="exit"]

[node name="Room" instance=ExtResource("base")]

[node name="Exit" parent="Mechanisms" instance=ExtResource("exit")]
position = Vector2(1184, 480)
block_size = Vector2(64, 96)
"""
static func create_draft(directory: String, room_name: String) -> Dictionary:
	var label := room_name.strip_edges()
	if label.is_empty() or not label.is_valid_filename():
		return {"error":"请输入有效的房间名。"}
	var path := directory.path_join(label + ".tscn")
	if FileAccess.file_exists(path):
		return {"error":"草稿已存在，请换一个名字。"}
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"error":"无法创建草稿目录。"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"error":"创建草稿失败。"}
	var written := file.store_string(STARTER)
	file.close()
	if not written or not ResourceLoader.load(path) is PackedScene:
		DirAccess.remove_absolute(path)
		return {"error":"草稿校验失败。"}
	return {"path":path}

static func assign_slot(catalog_path: String, index: int, path: String, expected: String) -> Dictionary:
	var catalog = ResourceLoader.load(catalog_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if catalog == null or index < 0 or index >= catalog.levels.size() or not ResourceLoader.exists(path,"PackedScene"):
		return {"error":"关卡或槽位无效。"}
	if catalog.levels[index].scene != expected:
		return {"error":"槽位内容已经变更，请重新选择。"}
	catalog.levels[index].scene = path
	var temp := catalog_path.get_basename() + ".new-%s.tres" % Time.get_ticks_usec()
	var err := ResourceSaver.save(catalog, temp)
	if err == OK: err = DirAccess.rename_absolute(temp, catalog_path)
	if err != OK:
		if FileAccess.file_exists(temp): DirAccess.remove_absolute(temp)
		return {"error":"保存章节目录失败。"}
	ResourceLoader.load(catalog_path,"",ResourceLoader.CACHE_MODE_REPLACE)
	return {}