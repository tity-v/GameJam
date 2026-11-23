extends Node
const MIX = preload("res://assets/audio/game/mix.tres")
var last := {}
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"SFX")
	get_tree().node_added.connect(watch_ui)
	var data=preload("res://frontend/glue/store.gd").new().read_record("settings").data
	set_level(data.get("sfx_volume",100.0))
func set_level(value: float):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"),clampf(value/100.0,0,1))
func play(key: String):
	if not MIX.sounds.has(key): return
	var now=Time.get_ticks_msec()
	if now-int(last.get(key,-1000))<60: return
	last[key]=now
	var player=AudioStreamPlayer.new()
	player.stream=MIX.sounds[key].stream
	player.volume_db=MIX.sounds[key].db
	player.bus="SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
func watch_ui(node):
	if node is BaseButton:
		node.pressed.connect(func():
			if not node.is_in_group("home_ui_button"): play("other_click"))
var crossings := {}
func _physics_process(_dt):
	if get_tree().paused: return
	for ghost in get_tree().get_nodes_in_group("replay_ghost"):
		if not is_instance_valid(ghost) or not ghost is Node2D: continue
		var area: Rect2
		if ghost.has_method("body_rect"): area=ghost.body_rect()
		elif "box_size" in ghost: area=Rect2(ghost.global_position-ghost.box_size/2,ghost.box_size)
		else: continue
		var inside=false
		for wall in get_tree().get_nodes_in_group("echo_wall"):
			var col=wall.get_node_or_null("Collision")
			if col and area.intersects(col.global_transform*Rect2(-col.shape.size/2,col.shape.size)): inside=true;break
		var id=ghost.get_instance_id()
		if crossings.get(id,false) and not inside: play("ghost_wall")
		crossings[id]=inside
	for id in crossings.keys():
		if not is_instance_id_valid(id): crossings.erase(id)
