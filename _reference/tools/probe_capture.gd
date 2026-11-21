extends SceneTree
## 实测全屏回读 + 建 ImageTexture 的开销（方案 D 的滑动依赖它）。
## 必须带窗口跑（headless 没有渲染结果）：
##   godot --path . --fixed-fps 60 -s _reference/tools/probe_capture.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/tutorial_relay.tscn")
	var room: Node = packed.instantiate()
	root.add_child(room)
	current_scene = room
	for i in 30:
		await process_frame

	var samples: Array[int] = []
	var made := 0
	for i in 40:
		var t0 := Time.get_ticks_usec()
		var img: Image = root.get_viewport().get_texture().get_image()
		var tex: ImageTexture = null
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
		var cost := Time.get_ticks_usec() - t0
		if tex != null:
			made += 1
		samples.append(cost)
		await process_frame

	samples.sort()
	var total := 0
	for s in samples:
		total += s
	var mean := float(total) / float(samples.size())
	print("C capture samples=%d ok=%d mean=%.2fms p50=%.2fms p95=%.2fms max=%.2fms" % [
		samples.size(), made, mean / 1000.0,
		float(samples[samples.size() / 2]) / 1000.0,
		float(samples[int(samples.size() * 0.95)]) / 1000.0,
		float(samples[samples.size() - 1]) / 1000.0])
	print("C resolution=%s" % str(root.get_viewport().get_visible_rect().size))
	quit()
