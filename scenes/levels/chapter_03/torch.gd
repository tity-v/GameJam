extends Node2D
## 玩家随身光源（第三章专用，挂在 Player 下，不改 player.tscn）。
##
## 黑幕不是用 PointLight2D 做的，是 `blackout.gd` 每帧收集光源后丢给 shader。
## 这里把自己注册进 `torch_light` 组，`blackout.gd` 就会来读 `radii`。
##
## 两档半径：
##   底光 40/90 —— 只够看清脚下，撑不起任何一次跳跃判断
##   打火 96/150 —— 全亮 3 格（刚好看清台面前缘），再往外 54px 渐隐
## 打火亮 2.5s，冷却 1.5s（冷却期间回到底光，不是全黑）。
##
## 前一个数字是全亮半径（玩法参数，不能动），后一个数字是「归零半径」。
## 两者之差就是柔边宽度：原来只差 16px，边界是一刀切的硬圆；拉到 54px
## 才能看出光在往暗处散。再宽就会糊成灰雾——黑幕只能加黑，加宽等于拿
## 砖缝的结构换柔和，划不来。

const BASE_RADII := Vector2(40.0, 90.0)
const FIRE_RADII := Vector2(96.0, 150.0)
const FIRE_TIME := 2.5
const COOLDOWN := 1.5

## blackout.gd 每帧读这个
var radii := BASE_RADII
var burning := 0.0
## 距离下一次能打火还剩多久。打火时设成 燃烧+冷却，所以它总比 burning 晚归零。
var cooling := 0.0
## 累计打火次数，探针用
var fire_count := 0


func _ready() -> void:
	add_to_group("torch_light")


func _process(delta: float) -> void:
	burning = maxf(0.0, burning - delta)
	cooling = maxf(0.0, cooling - delta)
	if cooling <= 0.0 and Input.is_action_just_pressed("fire"):
		burning = FIRE_TIME
		cooling = FIRE_TIME + COOLDOWN
		fire_count += 1
	radii = FIRE_RADII if burning > 0.0 else BASE_RADII
