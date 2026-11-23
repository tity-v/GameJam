extends Node2D

var won := false
var resetting := false

## 整关重来：只有通关面板上的 Replay 会调它，重载场景（玩家、机关、虚影全部重建）。
## R 键不走这里——R 是「回到本关初始状态」但不重载场景，见 `echo_manager.reset_all()`。
func reset_room() -> void:
	if resetting:
		return
	resetting = true
	get_tree().call_deferred("reload_current_scene")


## R 的「机关部分」：把所有登记在 `mechanism` 组里的机关恢复初始状态
## （压力板松开、门关上并清掉锁存、出口随之熄灭）。
##
## 为什么不在这里点名字（`$PlateA` / `$Door` / `$Exit`）：
## 那样每加一个机关就要回来改一次，漏一个就是「按 R 之后门还开着」的玄学 bug。
## 新机关只要在 `_ready()` 里 `add_to_group("mechanism")` 并实现 `reset_mechanism()` 就会被收纳。
func reset_mechanisms() -> void:
	for node in get_tree().get_nodes_in_group("mechanism"):
		if node.has_method("reset_mechanism"):
			node.call("reset_mechanism")

func complete() -> void:
	if won or resetting:
		return
	won = true
	get_node("/root/GameSfx").play("complete")
	$Player.set_physics_process(false)
	$EchoManager.set_physics_process(false)
	$UI/Win.visible = true
	$UI/Win/Replay.grab_focus()

func _ready() -> void:
	$UI/Win/Replay.pressed.connect(reset_room)
