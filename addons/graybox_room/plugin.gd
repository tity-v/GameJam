@tool
extends EditorPlugin
const MENU := "新建灰盒房间"
const Builder = preload("res://addons/graybox_room/create_room.gd")
var message: AcceptDialog
func _enter_tree() -> void:
	message = AcceptDialog.new()
	message.title = MENU
	get_editor_interface().get_base_control().add_child(message)
	add_tool_menu_item(MENU, create_room)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	message.queue_free()
func create_room() -> void:
	var result := Builder.create("res://frontend/db/catalog.tres", "res://scenes/levels")
	if result.has("error"):
		message.dialog_text = result.error
		message.popup_centered()
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().open_scene_from_path(result.path)
