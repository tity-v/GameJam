extends Resource

## 按数组顺序解锁。ID 用于存档，调整标题或场景时保留 ID。
##
## 每关可选字段：
##   id / scene / title  必需
##   link                可选，覆盖「方向即空间」的自动推断：
##                         "cut" 这一间进下一间一律切黑（不滑动）
##                         "h"   强制横滑（并列房间）
##                         "v"   强制纵滑（楼层）
##                       不写就按出口相对视口中心的位置自动判断。
@export var levels: Array[Dictionary] = []
## 试玩开关：为 true 时不看进度，所有已接入的房间都可直接进。
## 给「想直接跳到某一章某一关」用，会关掉顺序解锁这条主线，正式版本必须设回 false。
@export var preview_unlock := false
@export var completion_property: StringName = &"won"
@export var legacy_result_panel: NodePath = ^"UI/Win"
@export var legacy_pause: NodePath = ^"/root/PauseMenu"
@export var legacy_hud: NodePath = ^"/root/Hud"
@export var pause_action: StringName = &"pause"
