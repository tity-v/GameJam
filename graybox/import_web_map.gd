extends SceneTree
# 命令行导入网页 JSON，输出新的独立场景。
const SCENES = {
	"moving_platform":"platform", "box":"box", "lever":"lever", "portal":"portal",
	"plate":"pressure_plate", "door":"door", "exit":"exit", "open_exit":"open_exit",
	"echo_wall":"echo_wall", "text":"room_text", "color_recorder":"color_recorder", "checkpoint":"checkpoint"
}
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or not args[1].begins_with("res://") or not args[1].ends_with(".tscn") or FileAccess.file_exists(args[1]):
		push_error("参数应为 JSON 路径和新的 res://场景.tscn 路径"); quit(1); return
	var data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not data is Dictionary or not data.get("components") is Array:
		push_error("地图 JSON 格式错误"); quit(1); return
	var chapter := int(data.get("chapter",0))
	var template: String = {1:"res://scenes/levels/old_building/base.tscn",2:"res://scenes/levels/night_station/base.tscn",3:"res://scenes/levels/dark_building/base.tscn"}.get(chapter,"res://graybox/base_level.tscn")
	var room = load(template).instantiate()
	room.set_meta("web_chapter",chapter)
	room.set_meta("web_exit_direction",str(data.get("exitDirection","")))
	room.set_meta("web_level_id",str(data.get("levelId","")))
	var night_layers := {}
	for entry in [["Blackout",20],["Torches",21],["Ladders",0]]:
		var layer := TileMapLayer.new()
		layer.name=entry[0];layer.z_index=entry[1]
		layer.tile_set=load("res://scenes/levels/dark_building/night_parts.tres")
		layer.collision_enabled=false
		if layer.name=="Ladders":layer.add_to_group("night_ladders",true)
		room.add_child(layer);layer.owner=room;night_layers[str(layer.name)]=layer
	root.add_child(room)
	var world = room.get_node("World")
	world.clear()
	for branch in ["Terrain","Mechanisms","Decor"]:
		var parent = room.get_node_or_null(branch)
		if parent:
			for child in parent.get_children(): child.free()
	var nodes := {}
	var solid_cells: Array[Vector2i] = []
	var platform_cells: Array[Vector2i] = []
	var objects: Array = data.components
	for o in objects:
		var kind: String = o.get("mapping",o.type)
		var node: Node2D
		var size := Vector2(o.w,o.h)*32
		var pos := Vector2(o.x,o.y)*32
		if kind=="spawn":
			nodes[o.id]=room.get_node("RespawnPoint")
			nodes[o.id].position=pos
			continue
		if kind in ["darkness","torch","ladder"]:
			var layer: TileMapLayer=night_layers[{"darkness":"Blackout","torch":"Torches","ladder":"Ladders"}[kind]]
			var atlas := {"darkness":0,"ladder":1,"torch":2}
			for x in range(int(o.x),ceili(o.x+o.w)):
				for y in range(int(o.y),ceili(o.y+o.h)):layer.set_cell(Vector2i(x,y),0,Vector2i(atlas[kind],0))
			node=Node2D.new()
		elif kind in ["terrain","platform"]:
			var background: bool = o.get("layer","")=="背景"
			if not background:
				for x in range(int(o.x),ceili(o.x+o.w)):
					for y in range(int(o.y),ceili(o.y+o.h)):
						var one_way: bool = kind=="platform" or o.get("props",{}).get("collision_mode",0)==1 or o.get("collision",{}).get("mode","")=="单向平台"
						if chapter in [1,2,3]:
							if one_way: platform_cells.append(Vector2i(x,y))
							else: solid_cells.append(Vector2i(x,y))
						else: world.set_cell(Vector2i(x,y),0,Vector2i(3 if one_way else 0,0))
			node=Node2D.new()
		elif kind=="marker":
			node=Marker2D.new()
		elif kind=="spikes":
			node=load("res://scenes/blocks/spike_tile.tscn").instantiate()
		elif SCENES.has(kind):
			node=load("res://graybox/"+SCENES[kind]+".tscn").instantiate()
		else:
			push_error("尚未实现的类型："+kind);room.free();quit(1);return
		node.name="Web_"+str(nodes.size())
		room.add_child(node);node.owner=room
		node.position=pos
		if kind in ["moving_platform","box","portal"]: node.position+=size/2
		if kind=="echo_wall":node.set("cells",Vector2i(maxi(1,ceili(o.w)),maxi(1,ceili(o.h))))
		if kind=="box":node.set("box_size",size)
		if kind=="checkpoint":node.position+=Vector2(16,16)
		for property in node.get_property_list():
			if property.name=="block_size":node.set("block_size",size)
		var props: Dictionary=o.get("props",{})
		for key in ["speed_override","initially_open","initially_right","initially_enabled","close_after_use","accepts_player","accepts_echo","accepts_boxes","font_size","text"]:
			if props.has(key):node.set(key,props[key])
		if kind=="text":node.set("text",props.get("text",o.get("name","")))
		if kind=="color_recorder":node.set("tint",Color(props.get("tint","#87ceeb")))
		if kind not in ["darkness","ladder","torch"] and o.get("asset") is String and not o.asset.is_empty():
			var uri: String=data.get("assets",{}).get(o.asset,"")
			var image:=Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(uri.get_slice(",",1)))!=OK:
				push_error("图片无法解码："+str(o.asset));room.free();quit(1);return
			var texture: Texture2D=ImageTexture.create_from_image(image)
			if o.get("crop") is Array:
				var cut=AtlasTexture.new();cut.atlas=texture;cut.region=Rect2(o.crop[0],o.crop[1],o.crop[2],o.crop[3]);texture=cut
			var visual:=Sprite2D.new();visual.texture=texture;visual.centered=false
			visual.scale=size/texture.get_size()
			if kind in ["box","portal","moving_platform"]:visual.position=-size/2
			node.add_child(visual);visual.owner=room
			var face=node.get_node_or_null("Face")
			if face:face.hide()
		nodes[o.id]=node
	for o in objects:
		var node: Node2D=nodes[o.id]
		var kind: String=o.get("mapping",o.type)
		var props: Dictionary=o.get("props",{})
		for key in ["start_point","end_point","destination","switch_source"]:
			if props.get(key,"")!="":
				if not nodes.has(props[key]):push_error("失效关联："+str(props[key]));room.free();quit(1);return
				node.set(key,nodes[props[key]])
		var links: Array=o.get("links",[])
		if kind=="door":
			var paths: Array[NodePath]=[]
			for id in links:
				if not nodes.has(id):push_error("门关联失效");room.free();quit(1);return
				paths.append(node.get_path_to(nodes[id]))
			node.set("plate_paths",paths)
		if kind=="exit" and not links.is_empty():
			if not nodes.has(links[0]):push_error("出口关联失效");room.free();quit(1);return
			node.set("door_path",node.get_path_to(nodes[links[0]]))
		if kind=="color_recorder":
			if not nodes.has(props.get("parent_id","")):push_error("记录器缺少挂载目标");room.free();quit(1);return
			node.owner=null;node.reparent(nodes[props.parent_id]);node.position=Vector2.ZERO;node.owner=room
	if chapter in [1,2,3]:
		if not solid_cells.is_empty():world.set_cells_terrain_connect(solid_cells,0,0)
		if not platform_cells.is_empty():world.set_cells_terrain_connect(platform_cells,1,0)
	var background=room.get_node_or_null("Background")
	if background:
		background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(data.map.columns*32,0),Vector2(data.map.columns*32,data.map.rows*32),Vector2(0,data.map.rows*32)])
		if chapter not in [1,2,3]:background.color=Color(data.get("background",{}).get("color","#f7fafc"))
	var placeholder=room.get_node_or_null("Map_Placeholder")
	if placeholder:
		placeholder.clear()
		for x in range(int(data.map.columns)):
			for y in range(int(data.map.rows)):placeholder.set_cell(Vector2i(x,y),0,Vector2i(0,1))
	var fog: TileMapLayer=night_layers["Blackout"]
	if not fog.get_used_cells().is_empty():
		var material:=ShaderMaterial.new()
		material.shader=load("res://scenes/levels/dark_building/blackout.gdshader")
		fog.material=material
		fog.set_script(load("res://scenes/levels/dark_building/blackout.gd"))
		for object in objects:
			if object.get("mapping","")=="darkness":
				for field in ["personal_radii","torch_radii"]:
					var value=object.get("props",{}).get(field)
					if value is Array and value.size()==2:fog.set(field,Vector2(value[0],value[1]))
				break
		fog.owner=null;room.remove_child(fog);fog.request_ready();room.add_child(fog);fog.owner=room
	var scene:=PackedScene.new()
	var error:=scene.pack(room)
	if error==OK:
		DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
		error=ResourceSaver.save(scene,args[1])
	room.free()
	if error!=OK:push_error("场景保存失败");quit(1);return
	print("已导入："+args[1]);quit()
