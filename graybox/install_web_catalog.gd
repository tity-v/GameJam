extends SceneTree
## 由批量导入器在用户指定 --install 时调用。
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size()!=1:
  push_error("需要章节清单 JSON");quit(1);return
 var manifest = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not manifest is Dictionary or not manifest.get("chapters") is Array:
  push_error("章节清单无效");quit(1);return
 var path := "res://frontend/db/catalog.tres"
 var catalog = load(path).duplicate(true)
 var snapshot: Array = catalog.levels.duplicate(true)
 var claimed := {}
 for chapter in manifest.chapters:
  var number := int(chapter.number)
  if number<1 or number>4 or claimed.has(number) or chapter.rooms.size()!=5:
   push_error("章号或房间数量无效");quit(1);return
  claimed[number]=true
  for i in range(5):
   var entry = chapter.rooms[i]
   var slot := (number-1)*5+i
   if slot>=snapshot.size() or not ResourceLoader.exists(str(entry.scene)):
    push_error("槽位或生成场景失效");quit(1);return
   var updated: Dictionary = snapshot[slot].duplicate()
   updated.scene=entry.scene
   updated.title=entry.title
   updated.web_level_id=entry.id
   updated.exit_direction=entry.direction
   updated.erase("link")
   snapshot[slot]=updated
 catalog.levels.assign(snapshot)
 var backup := path+".web-backup-"+str(Time.get_unix_time_from_system()).replace(".","-")
 if DirAccess.copy_absolute(path,backup)!=OK:
  push_error("无法创建目录备份");quit(1);return
 var temp := "res://frontend/db/catalog.web-import.tres"
 if ResourceSaver.save(catalog,temp)!=OK:
  push_error("无法保存临时目录");quit(1);return
 if DirAccess.rename_absolute(temp,path)!=OK:
  push_error("无法替换目录，备份保留在 "+backup);quit(1);return
 print("章节目录已更新，原目录备份："+backup)
 quit()
