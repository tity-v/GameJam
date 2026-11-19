extends Resource

## 按数组顺序解锁。ID 用于存档，调整标题或场景时保留 ID。
@export var levels: Array[Dictionary] = []
@export var columns: int = 5
@export var completion_property: StringName = &"won"
@export var legacy_result_panel: NodePath = ^"UI/Win"
@export var legacy_pause: NodePath = ^"/root/PauseMenu"
@export var legacy_hud: NodePath = ^"/root/Hud"
@export var pause_action: StringName = &"pause"
