extends CanvasLayer

const Portal = preload("res://scripts/level_exit.gd")
const Flow = preload("res://frontend/systems/flow.gd")
const Store = preload("res://frontend/glue/store.gd")
const DEFAULT_CATALOG = preload("res://frontend/db/catalog.tres")
const THEME = preload("res://frontend/db/pixel_theme.tres")
## 转场时长。0.24s 是实测「被读成有意设计」的下限（<0.15s 等于没发生）。
const SLIDE_TIME := 0.24
## 切黑半程时长：黑出 0.10 + 黑入 0.10。
const CUT_FADE := 0.10
const CUT_MASK := Color(0.043, 0.055, 0.078, 1.0)
const PAGES := {
	"home": preload("res://frontend/view/home.tscn"),
	"levels": preload("res://frontend/view/levels.tscn"),
	"chapter": preload("res://frontend/view/chapter.tscn"),
	"pause": preload("res://frontend/view/pause.tscn"),
	"settings": preload("res://frontend/view/settings.tscn"),
	"result": preload("res://frontend/view/result.tscn"),
	"finished": preload("res://frontend/view/finished.tscn"),
}

var flow := Flow.new()
var store := Store.new()
var catalog = DEFAULT_CATALOG
var copy: Dictionary = {}
var settings := {"volume": 100.0, "sfx_volume": 100.0, "muted": false, "fullscreen": false, "start_paused": false}
var notice := ""
var view: Control
var dialog: ConfirmationDialog
var dialog_focus: Control
var dialog_command := ""
var pending: Array[Dictionary] = []
var target_index := -1
var target_page := ""
var switching := false
var outgoing_frame: Texture2D
var slide_direction := Vector2.RIGHT
var legacy_pause: Node
var legacy_hud: CanvasLayer
var legacy_pause_mode: ProcessMode
var legacy_hud_visible := true
var owns_pause := false

func start(_entry: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	copy = preload("res://frontend/db/copy.tres").strings
	if not flow.setup(catalog.levels):
		notice = tr_copy("catalog_failed")
	flow.unlock_all = catalog.preview_unlock
	read_progress()
	read_settings()
	legacy_pause = get_node_or_null(catalog.legacy_pause)
	legacy_hud = get_node_or_null(catalog.legacy_hud) as CanvasLayer
	if legacy_pause != null:
		legacy_pause_mode = legacy_pause.process_mode
		legacy_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if legacy_hud != null:
		legacy_hud_visible = legacy_hud.visible
	get_tree().scene_changed.connect(scene_arrived)
	dialog = ConfirmationDialog.new()
	dialog.theme = THEME
	dialog.title = tr_copy("confirm")
	dialog.ok_button_text = tr_copy("confirm")
	dialog.cancel_button_text = tr_copy("cancel")
	dialog.dialog_close_on_escape = true
	dialog.confirmed.connect(func(): request(dialog_command))
	dialog.visibility_changed.connect(restore_dialog_focus)
	add_child(dialog)
	redraw()

func _exit_tree() -> void:
	if owns_pause and get_tree() != null:
		get_tree().paused = false
	if is_instance_valid(legacy_pause):
		legacy_pause.process_mode = legacy_pause_mode
	if is_instance_valid(legacy_hud):
		legacy_hud.visible = legacy_hud_visible

func _input(event: InputEvent) -> void:
	if get_node("/root/ObservationPause").active:
		return
	if switching or dialog == null or dialog.visible or not event.is_action_pressed(catalog.pause_action):
		return
	if flow.page in ["game", "pause", "levels", "chapter", "settings", "result", "finished"]:
		get_viewport().set_input_as_handled()
		request("escape")

func request(command: String, value: Variant = null) -> void:
	if not switching:
		pending.append({"command": command, "value": value})

func _process(_delta: float) -> void:
	if dialog == null or switching:
		return
	# 检测本帧关卡事实，再处理输入请求，最后更新界面。
	var room := get_tree().current_scene
	if flow.page == "game" and flow.current >= 0 and is_instance_valid(room) and room.get(catalog.completion_property) == true:
		var old_panel := room.get_node_or_null(catalog.legacy_result_panel) as CanvasItem
		if old_panel != null:
			old_panel.hide()
		pending.clear()
		# 试玩模式（catalog.preview_unlock）下不写正式存档。
		# 这些房间是原型，通关记录会污染正式流程的解锁顺序，也会在章内列表里
		# 挂上「已完成」——那不是真的做完了，只是有人试玩了一遍。
		if not flow.unlock_all:
			flow.mark_complete()
			save_progress()
		var following := flow.current + 1
		if flow.playable(following) and flow.chapter_of(following) == flow.chapter_of(flow.current):
			if DisplayServer.get_name() != "headless" and transition_kind(flow.current, following) == "slide":
				slide_direction = slide_axis(flow.current)
				var frame := get_viewport().get_texture().get_image()
				if frame != null and not frame.is_empty():
					outgoing_frame = ImageTexture.create_from_image(frame)
			launch(following, false, true)
			if switching:
				return
			outgoing_frame = null
		redraw()
	var commands := pending.duplicate()
	pending.clear()
	for item in commands:
		handle(item.command, item.value)
		if switching:
			break

func handle(command: String, value: Variant) -> void:
	match command:
		"escape":
			match flow.page:
				"game": set_page("pause")
				"pause": set_page("game")
				"settings": set_page(flow.settings_parent)
				"chapter": set_page("levels")
				"levels": set_page("home")
				"result", "finished": leave("levels")
		"new_game":
			if not flow.playable(0):
				show_notice("load_failed")
			elif flow.recent != "" or not flow.completed.is_empty():
				confirm("restart_prompt", "start_confirmed")
			else:
				launch(0)
		"start_confirmed": launch(0, true)
		"continue_game": launch(flow.continue_index())
		"chapter": open_chapter(int(value))
		"choose": launch(int(value))
		"next": launch(flow.current + 1)
		"retry": launch(flow.current)
		"resume": set_page("game")
		"open_settings":
			flow.settings_parent = flow.page
			set_page("settings")
		"go_back":
			if flow.page == "settings":
				set_page(flow.settings_parent)
			elif flow.page == "chapter":
				set_page("levels")
			else:
				set_page("home")
		# 暂停页的「选择关卡」直接落到当前这一章，不用先回章节目录再点一次。
		"pause_chapter":
			confirm("leave_prompt", "leave_chapter")
		"levels", "home":
			if flow.page == "pause":
				confirm("leave_prompt", "leave_" + command)
			else:
				leave(command)
		"leave_levels": leave("levels")
		"leave_home": leave("home")
		"leave_chapter":
			flow.chapter = flow.chapter_of(maxi(flow.current, 0))
			leave("chapter")
		"clear":
			confirm("clear_prompt", "clear_confirmed")
		"clear_confirmed":
			if store.write_record("progress", {"completed": [], "recent": ""}):
				flow.clear_progress()
				if flow.current >= 0:
					leave("home")
			else:
				show_notice("save_failed")
		"volume", "sfx_volume", "mute", "fullscreen", "start_paused":
			var key := "muted" if command == "mute" else command
			settings[key] = value
			apply_settings()
			if not store.write_record("settings", settings):
				show_notice("save_failed")
		"quit": get_tree().quit()

func set_page(page: String) -> void:
	flow.page = page
	apply_pause(page == "pause" or (page == "settings" and flow.settings_parent == "pause"))
	redraw()

## 章节目录 → 该章的关卡列表。判据与目录卡片一致：没有可进入的房间就进不去，
## 否则一张 disabled 的卡片背后还藏着一条能走通的路（旧界面、脚本、手滑）。
func open_chapter(index: int) -> void:
	if index < 0 or index >= flow.chapter_count():
		return
	if int(flow.chapter_card(index).entry) < 0:
		return
	flow.chapter = index
	set_page("chapter")

func apply_pause(enabled: bool) -> void:
	if enabled and not get_tree().paused:
		get_tree().paused = true
		owns_pause = true
	elif not enabled and owns_pause:
		get_tree().paused = false
		owns_pause = false

func confirm(message: String, command: String) -> void:
	dialog_command = command
	dialog_focus = get_viewport().gui_get_focus_owner()
	dialog.dialog_text = tr_copy(message)
	if is_instance_valid(view):
		view.process_mode = Node.PROCESS_MODE_DISABLED
	dialog.popup_centered()

func restore_dialog_focus() -> void:
	if not dialog.visible:
		if is_instance_valid(view):
			view.process_mode = Node.PROCESS_MODE_INHERIT
		if is_instance_valid(dialog_focus):
			dialog_focus.grab_focus.call_deferred()

## `auto_advance` 只有「刚打完一间、顺序进下一间」这一条路会传 true。
## 其余入口（选关、重试、章节跳转、继续游戏）一律切黑——它们没有「空间连续」可言，
## 硬套滑动会变成「从右边走出去却从中间冒出来」，玩家会读成 bug。
func launch(index: int, clear_first := false, auto_advance := false) -> void:
	if not flow.playable(index):
		show_notice("load_failed")
		return
	var path := str(flow.levels[index].scene)
	var packed: PackedScene
	if ResourceLoader.exists(path, "PackedScene"):
		packed = load(path) as PackedScene
	var room := packed.instantiate() if packed != null else null
	# 合同校验在切换前完成，错误时保留原页面。
	if room == null or not has_completion_property(room):
		if room != null:
			room.free()
		show_notice("load_failed")
		return
	var previous_page := flow.page
	var kind := transition_kind(flow.current, index) if auto_advance else "cut"
	if kind == "slide":
		swap_room(room, index, clear_first, previous_page)
	else:
		cut_into_room(room, index, clear_first, previous_page)

## 真正换场景。解暂停放在这里，切黑的那 0.20s 里旧房间仍保持暂停/静止。
func swap_room(room: Node, index: int, clear_first: bool, previous_page: String) -> void:
	apply_pause(false)
	if get_tree().change_scene_to_node(room) != OK:
		room.free()
		apply_pause(previous_page == "pause")
		show_notice("load_failed")
		return
	if clear_first:
		flow.clear_progress()
	target_index = index
	switching = true

func has_completion_property(room: Node) -> bool:
	for property in room.get_property_list():
		if property.name == catalog.completion_property and property.type == TYPE_BOOL:
			return true
	return false

func leave(page: String) -> void:
	if flow.current < 0:
		set_page(page)
		return
	var blank := Node.new()
	var previous_page := flow.page
	apply_pause(false)
	if get_tree().change_scene_to_node(blank) != OK:
		blank.free()
		apply_pause(previous_page == "pause")
		show_notice("load_failed")
		return
	target_page = page
	switching = true

func scene_arrived() -> void:
	if not switching:
		return
	switching = false
	notice = ""
	if target_index >= 0:
		flow.begin(target_index)
		var room := get_tree().current_scene
		var panel := room.get_node_or_null(catalog.legacy_result_panel) as CanvasItem
		if panel != null:
			panel.modulate.a = 0.0
		lock_player(0.0)
		if outgoing_frame != null:
			slide_into_room()
		target_index = -1
		save_progress()
	else:
		flow.current = -1
		flow.page = target_page
		target_page = ""
	redraw()

## 黑场切：0.10s 黑出 → 换场景 → 0.10s 黑入。跨章、重试、选关跳转都走这条。
## 无头模式不做动画，直接换——测试不需要等 0.2s，也不会因为 tween 掉帧而假红。
func cut_into_room(room: Node, index: int, clear_first: bool, previous_page: String) -> void:
	if DisplayServer.get_name() == "headless":
		swap_room(room, index, clear_first, previous_page)
		return
	switching = true
	var mask := ColorRect.new()
	mask.color = Color(CUT_MASK, 0.0)
	mask.position = Vector2.ZERO
	mask.size = get_viewport().get_visible_rect().size
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)
	var fade := create_tween()
	fade.tween_property(mask, "color:a", 1.0, CUT_FADE)
	fade.tween_callback(swap_room.bind(room, index, clear_first, previous_page))
	fade.tween_property(mask, "color:a", 0.0, CUT_FADE)
	fade.tween_callback(mask.queue_free)

## 转场语法的唯一判定点：只有「同一章、顺序推进」才滑动，其余一律切黑。
## 纯函数、不看场景，方便在 `frontend/tests/` 里直接断言。
func transition_kind(from_index: int, to_index: int) -> String:
	if from_index < 0 or to_index != from_index + 1:
		return "cut"
	if not flow.exists_at(from_index) or not flow.exists_at(to_index):
		return "cut"
	if flow.chapter_of(from_index) != flow.chapter_of(to_index):
		return "cut"
	if str(flow.levels[from_index].get("link", "")) == "cut":
		return "cut"
	return "slide"

func transition_plan(from_index: int, to_index: int) -> Dictionary:
	if transition_kind(from_index, to_index) == "cut":
		return {"kind": "cut", "dir": Vector2.RIGHT, "time": CUT_FADE * 2.0}
	return {"kind": "slide", "dir": slide_axis(from_index), "time": SLIDE_TIME}

## 滑动方向由「出口在哪一侧」决定。目录里给某关写 `"link": "h"` / `"v"` 可以强制轴。
func slide_axis(from_index: int) -> Vector2:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var dir := exit_direction(scene)
	var link := str(flow.levels[from_index].get("link", "")) if flow.exists_at(from_index) else ""
	if link == "h":
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	if link == "v":
		return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP
	return dir

## 滑动那 0.24s 锁住玩家：此时人已经站在新房间里，只是被旧截图盖着。
func lock_player(seconds: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("lock_input"):
		player.call("lock_input", seconds)

func exit_direction(room: Node) -> Vector2:
	if room != null:
		var configured := str(room.get_meta("web_exit_direction",""))
		var vectors := {"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}
		if vectors.has(configured):
			return vectors[configured]
	if room == null:
		return Vector2.RIGHT
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.RIGHT
	var player_position := player.get_global_transform_with_canvas().origin
	var exit_position := player_position
	var nearest := INF
	for node in room.find_children("*", "Node2D", true, false):
		if node is Portal and node.active:
			var center: Vector2 = node.get_global_transform_with_canvas() * (node.block_size * 0.5)
			var distance := player_position.distance_squared_to(center)
			if distance < nearest:
				nearest = distance
				exit_position = center
	# 按视口宽高归一化，宽屏房间也能正确识别上下出口。
	var viewport_rect := get_viewport().get_visible_rect()
	var offset := (exit_position - viewport_rect.get_center()) / viewport_rect.size
	if absf(offset.y) > absf(offset.x):
		return Vector2.DOWN if offset.y > 0 else Vector2.UP
	return Vector2.LEFT if offset.x < 0 else Vector2.RIGHT

func slide_into_room() -> void:
	var previous := TextureRect.new()
	previous.texture = outgoing_frame
	outgoing_frame = null
	previous.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	previous.size = get_viewport().get_visible_rect().size
	previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(previous)
	var camera := get_viewport().get_camera_2d()
	var slide := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var travel := previous.size * slide_direction
	slide.tween_property(previous, "position", -travel, SLIDE_TIME)
	if camera != null:
		var resting_offset := camera.offset
		camera.offset -= travel / camera.zoom
		slide.tween_property(camera, "offset", resting_offset, SLIDE_TIME)
	slide.chain().tween_callback(previous.queue_free)
	lock_player(SLIDE_TIME)

func tr_copy(key: String) -> String:
	return str(copy.get(key, key))

func button(key: String, command: String, disabled := false, value: Variant = null) -> Dictionary:
	return {"text": tr_copy(key), "command": command, "disabled": disabled, "value": value}

func show_notice(key: String) -> void:
	notice = tr_copy(key)
	if is_instance_valid(view):
		view.set_notice(notice)

func redraw() -> void:
	if legacy_hud != null:
		legacy_hud.visible = legacy_hud_visible and flow.current >= 0
	if is_instance_valid(view):
		view.hide()
		view.queue_free()
		view = null
	if not PAGES.has(flow.page):
		return
	view = PAGES[flow.page].instantiate()
	view.requested.connect(request)
	add_child(view)
	view.present(page_model())

func page_model() -> Dictionary:
	var model := {"title": tr_copy(flow.page), "notice": notice}
	if flow.page in ["levels", "chapter"]:
		var recent := flow.continue_index()
		var selected := flow.chapter if flow.page == "chapter" else flow.chapter_of(maxi(recent, 0))
		var floors: Array[Dictionary] = []
		for chapter in flow.chapter_count():
			var rooms: Array[Dictionary] = []
			var indices := flow.chapter_rooms(chapter)
			for index in indices:
				if flow.playable(index):
					rooms.append({"index": index, "name": flow.room_label(index),
						"number": index - indices[0] + 1, "done": flow.room_state(index) == "done"})
			floors.append({"name": tr_copy("chapter") % (chapter + 1), "rooms": rooms,
				"progress": "%d/%d" % [flow.chapter_card(chapter).count, indices.size()]})
		model.directory = floors
		model.selected_floor = selected
		model.recent_room = recent
	var buttons: Array[Dictionary] = []
	var footer: Array[Dictionary] = []
	model.buttons = buttons
	model.footer = footer
	match flow.page:
		"home":
			model.title = tr_copy("game_title")
			if flow.continue_index() >= 0:
				buttons.append(button("continue_game", "continue_game"))
			buttons.append_array([button("start", "new_game", not flow.playable(0)), button("level_list", "levels"), button("settings", "open_settings"), button("quit", "quit")])
		"levels":
			model.detail = tr_copy("progress") % [flow.completed.size(), flow.levels.size()]
			model.columns = 2
			model.cards = []
			for first in range(0, flow.levels.size(), flow.ROOMS_PER_CHAPTER):
				var chapter := flow.chapter_of(first)
				var data := flow.chapter_card(chapter)
				var card := button("", "chapter", data.entry < 0, chapter)
				var status := tr_copy("chapter_progress") % [data.count, flow.ROOMS_PER_CHAPTER]
				if card.disabled:
					status += " · " + tr_copy("locked" if flow.available(first) else "missing")
				card.text = "%s\n%s" % [tr_copy("chapter") % (chapter + 1), status]
				model.cards.append(card)
			footer.append(button("back", "go_back"))
		"chapter":
			var opened := flow.chapter_rooms(flow.chapter)
			var cleared := 0
			for index in opened:
				if flow.room_state(index) == "done":
					cleared += 1
			model.title = tr_copy("chapter") % (flow.chapter + 1)
			model.detail = tr_copy("chapter_progress") % [cleared, flow.ROOMS_PER_CHAPTER]
			model.columns = 1
			model.cards = []
			for index in opened:
				var state := flow.room_state(index)
				var card := button("", "choose", state == "locked" or state == "missing", index)
				card.text = "%s\n%s" % [flow.room_label(index), tr_copy(state)]
				model.cards.append(card)
			footer.append(button("back", "go_back"))
		"pause":
			model.overlay = true
			model.detail = flow.levels[flow.current].title
			buttons.append_array([button("resume", "resume"), button("retry", "retry"), button("settings", "open_settings"), button("level_select", "pause_chapter"), button("menu", "home")])
		"settings":
			model.overlay = flow.settings_parent == "pause"
			model.settings = settings.merged({"volume_label": tr_copy("volume"), "mute_label": tr_copy("mute"), "fullscreen_label": tr_copy("fullscreen"), "keys": tr_copy("controls") + "\n" + tr_copy("keys")})
			buttons.append(button("clear", "clear"))
			footer.append(button("back", "go_back"))
		"result":
			model.overlay = true
			var next_label := "next"
			if (flow.current + 1) % flow.ROOMS_PER_CHAPTER == 0:
				next_label = "next_chapter"
				model.title = tr_copy("chapter_done")
				model.detail = tr_copy("chapter") % (flow.chapter_of(flow.current) + 1)
			else:
				model.detail = tr_copy("completed_level") % flow.levels[flow.current].title
			buttons.append(button(next_label if flow.playable(flow.current + 1) else "missing", "next", not flow.playable(flow.current + 1)))
			buttons.append(button("retry", "retry"))
			footer.append_array([button("level_select", "leave_chapter"), button("menu", "home")])
		"finished":
			model.detail = tr_copy("finished_detail")
			buttons.append(button("retry", "retry"))
			footer.append_array([button("level_list", "levels"), button("menu", "home")])
	return model

func read_progress() -> void:
	var record := store.read_record("progress")
	if not record.ok or not flow.restore(record.data):
		flow.clear_progress()
		store.preserve_invalid("progress")
		notice = tr_copy("read_failed")

func save_progress() -> void:
	if not store.write_record("progress", {"completed": flow.completed, "recent": flow.recent}):
		notice = tr_copy("save_failed")

func read_settings() -> void:
	var record := store.read_record("settings")
	var data: Dictionary = record.data
	var volume: Variant = data.get("volume", 100.0)
	var sfx_volume: Variant = data.get("sfx_volume",100.0)
	var muted: Variant = data.get("muted", false)
	var fullscreen: Variant = data.get("fullscreen", false)
	var start_paused: Variant = data.get("start_paused", false)
	if record.ok and (sfx_volume is float or sfx_volume is int) and is_finite(float(sfx_volume)) and (volume is float or volume is int) and is_finite(float(volume)) and muted is bool and fullscreen is bool and start_paused is bool:
		settings = {"sfx_volume": clampf(sfx_volume,0,100), "volume": clampf(volume, 0, 100), "muted": muted, "fullscreen": fullscreen, "start_paused": start_paused}
	else:
		store.preserve_invalid("settings")
		notice = tr_copy("read_failed")
	apply_settings()

func apply_settings() -> void:
	get_node("/root/GameSfx").set_level(settings.sfx_volume)
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_volume_linear(master, float(settings.volume) / 100.0)
		AudioServer.set_bus_mute(master, settings.muted)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
