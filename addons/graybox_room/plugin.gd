@tool
extends EditorPlugin
const Builder = preload("res://addons/graybox_room/create_room.gd")
const CATALOG := "res://frontend/db/catalog.tres"
var prompt := ConfirmationDialog.new()
var name_field := LineEdit.new()
var slots := OptionButton.new()
var replace_dialog := ConfirmationDialog.new()
var error_dialog := AcceptDialog.new()
var current_path := ""
var pending_index := -1
var expected := ""

func _enter_tree() -> void:
	for dialog in [prompt,replace_dialog,error_dialog]:
		EditorInterface.get_base_control().add_child(dialog)
	var fields := VBoxContainer.new()
	prompt.add_child(fields)
	fields.add_child(name_field)
	fields.add_child(slots)
	name_field.placeholder_text = "输入草稿名"
	prompt.confirmed.connect(confirm)
	replace_dialog.confirmed.connect(assign)
	add_tool_menu_item("新建灰盒房间", draft)
	add_tool_menu_item("将当前房间接入章节", choose_slot)

func _exit_tree() -> void:
	remove_tool_menu_item("新建灰盒房间")
	remove_tool_menu_item("将当前房间接入章节")
	for dialog in [prompt,replace_dialog,error_dialog]: dialog.queue_free()

func draft() -> void:
	prompt.title = "新建房间草稿"
	name_field.clear()
	name_field.show()
	slots.hide()
	prompt.popup_centered(Vector2i(400,120))
	name_field.grab_focus()

func choose_slot() -> void:
	var room := EditorInterface.get_edited_scene_root()
	if not room or room.scene_file_path.is_empty() or not room.has_method("complete") or not room.get_node_or_null("World") is TileMapLayer:
		report("请先打开并保存一个瓦片房间。")
		return
	current_path = room.scene_file_path
	var catalog = load(CATALOG)
	slots.clear()
	for entry in catalog.levels:
		var old := str(entry.scene)
		slots.add_item("%s　%s" % [entry.title, "空位" if old.is_empty() else old.get_file()])
		slots.set_item_metadata(slots.item_count-1, old)
	slots.select(-1)
	prompt.title = "选择章节和房间号"
	name_field.hide()
	slots.show()
	prompt.popup_centered(Vector2i(430,120))

func confirm() -> void:
	if name_field.visible:
		var result := Builder.create_draft("res://scenes/levels/drafts",name_field.text)
		if result.has("error"):
			report(result.error)
			return
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(result.path)
		select_world.call_deferred(result.path)
		return
	pending_index = slots.selected
	if pending_index < 0:
		report("请选择房间槽位。")
		return
	expected = slots.get_item_metadata(pending_index)
	if expected == current_path: return
	if not expected.is_empty():
		replace_dialog.dialog_text = "用 %s 替换 %s？" % [current_path.get_file(),expected.get_file()]
		replace_dialog.popup_centered()
	else:
		assign()

func assign() -> void:
	var result := Builder.assign_slot(CATALOG,pending_index,current_path,expected)
	if result.has("error"): report(result.error)

func select_world(path: String) -> void:
	var room := EditorInterface.get_edited_scene_root()
	if room and room.scene_file_path == path:
		var world := room.get_node("World")
		EditorInterface.set_main_screen_editor("2D")
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(world)
		EditorInterface.edit_node(world)

func report(text: String) -> void:
	error_dialog.dialog_text = text
	error_dialog.popup_centered()
