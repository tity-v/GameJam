extends RefCounted
## 纯数据。关卡目录的数组顺序决定游戏顺序，进度使用稳定 ID。

var levels: Array[Dictionary] = []
var completed: Array[String] = []
var recent := ""
var current := -1
var page := "home"
var settings_parent := "home"

func setup(entries: Array[Dictionary]) -> bool:
	var ids := {}
	for entry in entries:
		var id := str(entry.get("id", ""))
		if id.is_empty() or ids.has(id):
			return false
		ids[id] = true
	levels = entries
	return true

func exists_at(index: int) -> bool:
	return index >= 0 and index < levels.size()

func available(index: int) -> bool:
	return exists_at(index) and not str(levels[index].get("scene", "")).is_empty()

func unlocked(index: int) -> bool:
	if not exists_at(index):
		return false
	return index == 0 or completed.has(str(levels[index].id)) or completed.has(str(levels[index - 1].id))

func playable(index: int) -> bool:
	return available(index) and unlocked(index)

func continue_index() -> int:
	for index in levels.size():
		if levels[index].id == recent and playable(index):
			return index
	return -1

func mark_complete() -> void:
	var id := str(levels[current].id)
	if not completed.has(id):
		completed.append(id)
	page = "finished" if current == levels.size() - 1 else "result"

func begin(index: int) -> void:
	current = index
	recent = str(levels[index].id)
	page = "game"

func clear_progress() -> void:
	completed.clear()
	recent = ""

func restore(data: Dictionary) -> bool:
	var saved_completed: Variant = data.get("completed", [])
	var saved_recent: Variant = data.get("recent", "")
	if not (saved_completed is Array or saved_completed is PackedStringArray) or not saved_recent is String:
		return false
	var valid_ids := {}
	for level in levels:
		valid_ids[level.id] = true
	for id in saved_completed:
		if not id is String:
			return false
		if valid_ids.has(id) and not completed.has(id):
			completed.append(id)
	recent = saved_recent if valid_ids.has(saved_recent) else ""
	return true
