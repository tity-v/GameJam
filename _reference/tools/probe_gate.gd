extends SceneTree
## 关卡切换预算探针：换场到底花多少毫秒、有没有掉帧。
## 跑法：godot --headless --path . --fixed-fps 60 -s _reference/tools/probe_gate.gd
## 输出 `G key=value`，单位除注明外为毫秒。

const ROOMS := [
	"res://scenes/levels/tutorial_relay.tscn",
	"res://scenes/levels/tutorial_steps.tscn",
	"res://scenes/levels/chapter_01_room_03.tscn",
	"res://scenes/levels/chapter_01_room_04.tscn",
	"res://scenes/levels/chapter_01_room_05.tscn",
]

func _initialize() -> void:
	print("G engine=%s" % Engine.get_version_info().string)

	# 1. 冷加载：load() 走磁盘 + 解析
	for path in ROOMS:
		var t0 := Time.get_ticks_usec()
		var packed := load(path) as PackedScene
		var t1 := Time.get_ticks_usec()
		var node := packed.instantiate()
		var t2 := Time.get_ticks_usec()
		print("G cold_load %s load=%.2f inst=%.2f" % [path.get_file(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		node.free()

	# 2. 热加载：资源已在缓存里（玩家实际遇到的第二次及以后）
	for path in ROOMS:
		var t0 := Time.get_ticks_usec()
		var packed := load(path) as PackedScene
		var t1 := Time.get_ticks_usec()
		var node := packed.instantiate()
		var t2 := Time.get_ticks_usec()
		print("G hot_load %s load=%.2f inst=%.2f" % [path.get_file(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		node.free()

	# 3. 全量预载（启动时一次性把 5 关读进缓存）要多久
	var t3 := Time.get_ticks_usec()
	for path in ROOMS:
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	var t4 := Time.get_ticks_usec()
	print("G preload_all_5rooms=%.2f" % ((t4 - t3) / 1000.0))

	# 4. 单帧时间预算：60Hz 一帧 16.67ms，看换场占几帧
	var worst := 0.0
	for path in ROOMS:
		var packed := load(path) as PackedScene
		var t5 := Time.get_ticks_usec()
		var node := packed.instantiate()
		node.free()
		worst = maxf(worst, (Time.get_ticks_usec() - t5) / 1000.0)
	print("G worst_instantiate=%.2f frames=%.2f" % [worst, worst / 16.667])

	# 5. 玩家场景重复实例化成本（每关都会新建一个）
	var player := load("res://scenes/player/player.tscn") as PackedScene
	var t6 := Time.get_ticks_usec()
	for i in 5:
		var p := player.instantiate()
		p.free()
	print("G player_inst_x5=%.2f" % ((Time.get_ticks_usec() - t6) / 1000.0))

	quit()
