extends RefCounted

var directory := "user://frontend"

func read_record(name: String) -> Dictionary:
	var path := directory.path_join(name + ".cfg")
	if not FileAccess.file_exists(path):
		return {"ok": true, "data": {}}
	var file := ConfigFile.new()
	if file.load(path) != OK or file.get_value("record", "version", 0) != 1:
		return {"ok": false, "data": {}}
	var data: Variant = file.get_value("record", "data", null)
	return {"ok": data is Dictionary, "data": data if data is Dictionary else {}}

func write_record(name: String, data: Dictionary) -> bool:
	var folder := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return false
	var path := directory.path_join(name + ".cfg")
	var temporary := path + ".tmp"
	var record := ConfigFile.new()
	record.set_value("record", "version", 1)
	record.set_value("record", "data", data)
	if FileAccess.file_exists(path) and not read_record(name).ok:
		preserve_invalid(name)
		if FileAccess.file_exists(path):
			return false
	if record.save(temporary) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

func preserve_invalid(name: String) -> void:
	var path := ProjectSettings.globalize_path(directory.path_join(name + ".cfg"))
	if not FileAccess.file_exists(path):
		return
	var backup := "%s.invalid-%s" % [path, Time.get_ticks_usec()]
	DirAccess.rename_absolute(path, backup)
