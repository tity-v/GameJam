extends SceneTree

const Session = preload("res://frontend/glue/session.gd")
const Store = preload("res://frontend/glue/store.gd")
const Flow = preload("res://frontend/systems/flow.gd")
const REAL_CATALOG = preload("res://frontend/db/catalog.tres")
const ROOM := "res://scenes/levels/complete_room.tscn"
var session: CanvasLayer
var store := Store.new()

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func frames(count := 4) -> void:
	for index in count:
		await process_frame

func command(action: String, value: Variant = null) -> void:
	session.request(action, value)
	await frames()

func escape() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)
	await frames()

func run() -> void:
	# 章内选关的纯数据部分先用真实目录校一遍：标题收敛、章内下标、顺序解锁。
	var real := Flow.new()
	expect(real.setup(REAL_CATALOG.levels), "真实目录可加载")
	expect(real.chapter_count() == 4 and real.chapter_rooms(1).size() == 5, "每章五间")
	expect(real.chapter_rooms(1)[0] == 5, "第二章从下标 5 开始")
	expect(real.room_label(0) == "房间 1", "占位标题收敛成房间号")
	expect(real.room_label(5) == "错过 · 过站", "保留第二章的场名")
	expect(real.room_state(0) == "ready" and real.room_state(1) == "locked", "章内只解锁第一间")
	expect(real.room_state(6) == "locked", "跨章也要前一章打完才解锁")
	real.completed.append(str(real.levels[0].id))
	expect(real.room_state(0) == "done" and real.room_state(1) == "ready", "打完解锁下一间")
	expect(real.room_state(15) == "missing", "空路径显示待接入")

	# 试玩开关：跳过顺序解锁，但不能把空房间变成可进入，也不动完成记录。
	var preview := Flow.new()
	expect(preview.setup(REAL_CATALOG.levels), "真实目录可加载")
	expect(not preview.unlock_all, "试玩开关默认关闭")
	preview.unlock_all = true
	expect(preview.room_state(6) == "ready", "试玩开关让未完成的章直接可进")
	expect(preview.chapter_card(1).entry == 5, "试玩开关打开章节入口")
	expect(preview.chapter_card(3).entry == -1, "空章仍是待接入")
	expect(preview.completed.is_empty(), "试玩开关不写完成记录")

	var shell := Node.new()
	root.add_child(shell)
	current_scene = shell
	session = Session.new()
	var catalog = session.catalog.duplicate()
	var levels: Array[Dictionary] = []
	for number in range(1, 21):
		levels.append({"id": str(number), "title": "测试关 " + str(number), "scene": ROOM})
	catalog.levels = levels
	catalog.preview_unlock = false
	session.catalog = catalog
	store.directory = "res://build/frontend-test-%s" % Time.get_ticks_usec()
	session.store = store
	root.add_child(session)
	session.start(shell)

	expect(session.flow.page == "home" and session.flow.continue_index() == -1, "首次启动不显示继续")
	expect(not session.flow.unlock_all, "目录默认不跳过解锁")
	await command("levels")
	expect(session.page_model().cards.size() == 4, "选章显示四章")
	expect(session.page_model().cards[1].disabled, "第二章初始锁定")
	expect(not root.get_node("Hud").visible, "主界面隐藏旧 HUD")
	await command("chapter", 1)
	expect(session.flow.page == "levels", "锁定的章点不进去")
	await command("chapter", 0)
	expect(session.flow.page == "chapter" and session.page_model().cards.size() == 5, "章节点进去后列出五个房间")
	expect(not session.page_model().cards[0].disabled, "第一间可进入")
	expect(session.page_model().cards[1].disabled, "第二间未完成前锁定")
	expect(session.page_model().cards[0].text == "测试关 1\n可进入", "章内卡片显示房间名和状态")
	await escape()
	expect(session.flow.page == "levels", "Esc 从关卡列表回章节列表")
	await command("chapter", 0)
	await command("choose", 0)
	expect(session.flow.page == "game" and current_scene.scene_file_path == ROOM, "正常进入真实关卡")
	expect(root.get_node("Hud").visible, "游戏中显示旧 HUD")
	var room := current_scene
	await escape()
	expect(paused and session.flow.page == "pause", "Esc 打开新暂停页")
	expect(not root.get_node("PauseMenu/Root").visible, "旧暂停未同时打开")
	var position_before: Vector2 = room.get_node("Player").position
	await command("open_settings")
	expect(paused and session.flow.page == "settings", "从暂停打开设置仍暂停")
	await command("volume", 42.0)
	await command("mute", true)
	await command("fullscreen", true)
	expect(store.read_record("settings").data.volume == 42.0, "设置写入磁盘")
	expect(store.read_record("settings").data.muted, "设置替换文件后保留静音")
	expect(store.read_record("settings").data.fullscreen, "全屏设置可保存")
	expect(room.get_node("Player").position == position_before, "暂停时玩家位置冻结")
	await escape()
	expect(paused and session.flow.page == "pause", "Esc 从设置回暂停")
	await command("home")
	expect(session.dialog.visible and current_scene == room, "离开关卡前确认")
	session.dialog.hide()
	await escape()
	expect(not paused and session.flow.page == "game", "Esc 恢复玩法")
	await escape()
	await command("pause_chapter")
	expect(session.dialog.visible and session.flow.page == "pause", "跳关卡前确认放弃本轮")
	session.dialog.hide()
	await command("leave_chapter")
	expect(session.flow.page == "chapter" and session.flow.chapter == 0, "暂停页直接落到当前章")
	expect(session.flow.current == -1 and not paused, "离开关卡清当前关并解除暂停")
	await command("choose", 0)
	expect(session.flow.page == "game" and session.flow.current == 0, "从章内列表重新进入")
	room = current_scene
	await escape()
	await command("retry")
	expect(not paused and current_scene != room and session.flow.current == 0, "暂停重试重新实例化场景")

	catalog.levels[1].scene = ""
	current_scene.complete()
	await frames()
	expect(session.flow.page == "result" and session.page_model().buttons[0].disabled, "下一间待接入时停在当前房间")
	catalog.levels[1].scene = ROOM
	expect(session.flow.chapter_card(0).entry == 1, "章节定位到首个未完成房间")
	await command("retry")
	for index in range(20):
		expect(session.flow.current == index, "顺序进入第 %s 关" % (index + 1))
		current_scene.complete()
		await frames()
		expect(not current_scene.get_node("UI/Win").visible, "旧结算被隐藏")
		expect(session.flow.completed.size() == index + 1, "进度记录一次")
		if index < 19 and (index + 1) % 5 == 0:
			expect(session.flow.page == "result" and session.flow.playable(index + 1), "完成后解锁下一关")
			await command("next")
	expect(session.flow.page == "finished", "第 20 关显示全部通关")
	await command("levels")
	expect(session.flow.page == "levels" and not paused and session.flow.current == -1, "结算可返回选关")

	session.queue_free()
	await frames()
	expect(root.get_node("PauseMenu").process_mode == Node.PROCESS_MODE_ALWAYS, "退出前端恢复旧暂停处理模式")
	expect(root.get_node("Hud").visible, "退出前端恢复旧 HUD")

	# 试玩开关接到会话上：打开后所有已接入的房间都能直接点。
	catalog.preview_unlock = true
	session = Session.new()
	session.catalog = catalog
	session.store = store
	root.add_child(session)
	session.start(current_scene)
	expect(session.flow.unlock_all, "目录开关下发到流程")
	expect(session.flow.playable(19), "试玩下最后一关也能进")
	expect(session.flow.completed.size() == 20, "试玩不抹掉已有进度")

	# 试玩模式通关不写存档：原型关不应该在正式进度里留下「已完成」。
	session.flow.clear_progress()
	await frames()
	await command("choose", 0)
	current_scene.complete()
	await frames()
	expect(session.flow.completed.is_empty(), "试玩模式通关不写完成记录")
	# 把进度写回去给后面的「重启读取通关记录」用，否则那一条会读到空盘。
	# recent 也要一起还原：中间的 choose 把它改成了第 1 关。
	for index in range(20):
		session.flow.completed.append(str(catalog.levels[index].id))
	session.flow.recent = str(catalog.levels[19].id)
	session.save_progress()

	session.queue_free()
	await frames()
	catalog.preview_unlock = false

	session = Session.new()
	catalog.levels[0].scene = "res://frontend/tests/missing_scene.tscn"
	catalog.levels[1].scene = ""
	session.catalog = catalog
	session.store = store
	root.add_child(session)
	session.start(current_scene)
	expect(session.flow.completed.size() == 20 and session.flow.continue_index() == 19, "重启读取通关记录和继续位置")
	expect(session.settings.volume == 42.0 and session.settings.muted, "重启读取设置")
	await command("levels")
	expect(not session.flow.playable(1), "待接入房间无法进入")
	await command("chapter", 0)
	expect(session.page_model().cards[1].disabled, "待接入的房间在章内也不可点")
	await command("choose", 0)
	expect(session.flow.page == "chapter" and not session.notice.is_empty(), "无效场景留在当前页")
	await command("continue_game")
	expect(session.flow.current == 19, "继续进入最近关")
	await escape()
	await command("open_settings")
	await command("clear")
	expect(session.dialog.visible and session.flow.completed.size() == 20, "清进度先确认")
	session.dialog.hide()
	await command("clear_confirmed")
	expect(session.flow.completed.is_empty() and store.read_record("settings").data.volume == 42.0, "清进度保留设置")
	var path := store.directory.path_join("progress.cfg")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("[record]\nversion=99\n")
	bad.close()
	session.read_progress()
	expect(not session.notice.is_empty() and not FileAccess.file_exists(path), "损坏存档恢复默认并另存")
	var files := DirAccess.get_files_at(store.directory)
	expect(files.size() == 2, "保留损坏文件和设置")
	for file in files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.directory.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.directory))
	print("FRONTEND_ALL_PASS")
	quit()
