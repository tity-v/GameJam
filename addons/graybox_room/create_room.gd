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
static func create(catalog_path: String, directory: String) -> Dictionary:
	var catalog = ResourceLoader.load(catalog_path)
	if catalog == null: return {"error":"无法读取关卡目录。"}
	for index: int in catalog.levels.size():
		var entry: Dictionary = catalog.levels[index]
		if not str(entry.scene).is_empty(): continue
		@warning_ignore("integer_division")
		var chapter := index / Flow.ROOMS_PER_CHAPTER + 1
		var room := index % Flow.ROOMS_PER_CHAPTER + 1
		var path := directory.path_join("chapter_%02d_room_%02d.tscn" % [chapter, room])
		if FileAccess.file_exists(path):
			return {"error":"已有同名场景，请先核对目录中的房间：" + path}
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null: return {"error":"无法创建房间文件。"}
		var written := file.store_string(STARTER)
		file.close()
		if not written or not ResourceLoader.load(path) is PackedScene:
			DirAccess.remove_absolute(path)
			return {"error":"新房间校验失败。"}
		var updated = catalog.duplicate(true)
		updated.levels[index].scene = path
		var temp := catalog_path.get_basename() + ".new-%s.tres" % Time.get_ticks_usec()
		var err := ResourceSaver.save(updated, temp)
		if err == OK: err = DirAccess.rename_absolute(temp, catalog_path)
		if err != OK:
			DirAccess.remove_absolute(path)
			if FileAccess.file_exists(temp): DirAccess.remove_absolute(temp)
			return {"error":"写入关卡目录失败。"}
		catalog.levels[index].scene = path
		catalog.emit_changed()
		return {"path":path}
	return {"error":"所有房间都已接入。"}
