extends Node2D
## 玩家随身手电（第三章）。
##
## 它不是火把：没有「打火」这个动作，光一直亮着。两档半径：
##   未拾取  72/100 —— 和虚影自带的光完全一样，只够看清脚下
##   拾取后 120/180 —— 明显亮一圈，而且**成为唯一能被机关认的光**
##
## 判定靠 `can_power`，不靠组名：
##   光敏板 / 火盆只认 torch_light 组里 can_power = true 的光源。
##   人物自带的小光 can_power = false，所以站在板旁边也不会误触发——
##   这正是「虚影和主角的光照大小相同，但都不能激活机关」的实现方式：
##   光是一样的光，只是手里有没有那支手电。
##
## 手电不能放下（放下就灭）。所以「把光留在板旁边」这件事只能靠火盆，
## 火盆在这个机制里不是装饰，是唯一的「光的存档点」。

const DIM_RADII := Vector2(72.0, 100.0)
const LIT_RADII := Vector2(120.0, 180.0)

## blackout.gd 每帧读这个
var radii := DIM_RADII
## 光敏板 / 火盆只认 true 的光源
var can_power := false
var has_flashlight := false


func _ready() -> void:
	add_to_group("torch_light")
	# 按 R 回初始状态时要一起复位，否则手电还在手上、地上那支却没了
	add_to_group("mechanism")


func pick_up() -> bool:
	if has_flashlight:
		return false
	has_flashlight = true
	can_power = true
	radii = LIT_RADII
	return true


## 只有按 R 才调用。死亡复活**不能**清——虚影替玩家拿着手电的那一段，
## 玩家复活后手里还是那支。
func reset_mechanism() -> void:
	has_flashlight = false
	can_power = false
	radii = DIM_RADII
