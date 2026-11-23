extends RefCounted
## 纯数据。关卡目录的数组顺序决定游戏顺序，进度使用稳定 ID。

const ROOMS_PER_CHAPTER := 5

var levels: Array[Dictionary] = []
var completed: Array[String] = []
var recent := ""
var current := -1
var page := "home"
var settings_parent := "home"
## 关卡选择页当前打开的是哪一章（0 起）。
var chapter := 0

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

func chapter_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / ROOMS_PER_CHAPTER

func chapter_card(chapter: int) -> Dictionary:
	var first := chapter * ROOMS_PER_CHAPTER
	var count := 0
	var entry := -1
	var replay := -1
	for index in range(first, mini(first + ROOMS_PER_CHAPTER, levels.size())):
		if completed.has(levels[index].id):
			count += 1
			if replay < 0 and playable(index):
				replay = index
		elif entry < 0 and playable(index):
			entry = index
	return {"entry": entry if entry >= 0 else replay, "count": count}

## 一章的房间下标。章号越界时返回空数组，界面据此显示空章而不是崩。
func chapter_rooms(chapter: int) -> Array[int]:
	var rooms: Array[int] = []
	for index in range(chapter * ROOMS_PER_CHAPTER, mini((chapter + 1) * ROOMS_PER_CHAPTER, levels.size())):
		rooms.append(index)
	return rooms

func chapter_count() -> int:
	@warning_ignore("integer_division")
	return (levels.size() + ROOMS_PER_CHAPTER - 1) / ROOMS_PER_CHAPTER

## 关卡选择页每格的状态，取值与 `copy.tres` 的键同名：done / ready / locked / missing。
func room_state(index: int) -> String:
	if not available(index):
		return "missing"
	if completed.has(str(levels[index].id)):
		return "done"
	return "ready" if unlocked(index) else "locked"

## 关卡选择页的短名：目录标题去掉「第 N 章 · 」；「房间 3/5」这类占位名收敛成「房间 3」。
## 第二章的标题自带场名（「错过 · 过站」），保留下来比「房间 2」好认。
func room_label(index: int) -> String:
	if not exists_at(index):
		return ""
	var slot := index % ROOMS_PER_CHAPTER + 1
	var title := str(levels[index].get("title", ""))
	var prefix := "第 %d 章 · " % (chapter_of(index) + 1)
	if title.begins_with(prefix):
		title = title.substr(prefix.length())
	if title.is_empty() or (title.begins_with("房间 ") and title.ends_with("/%d" % ROOMS_PER_CHAPTER)):
		title = "房间 %d" % slot
	return title

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
