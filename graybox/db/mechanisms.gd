extends Resource
@export var platform_speed := 96.0
@export var box_density := 0.002
## 玩家推动时的水平目标速度：明显慢于步行满速(273)，有推重物的吃力感。
@export var push_speed := 150.0
## 虚影推动箱子的持续推力（px/s²）。
@export var push_force := 1800.0
## 推力启动距离：玩家侧面距箱子该像素内且按方向键即开始推。
## 玩家撞上箱子会被弹停再重新加速，间隙会拉大，阈值需要盖住这个追及过程。
@export var push_gap := 16.0
## 松手后的水平阻尼（px/s²）：只在静止支撑面上生效，短滑即停。
@export var push_damp := 500.0
@export var lever_travel := 18.0
@export var binding_color := Color("#f5d65b")
@export var ghost_alpha := 0.35
@export var trip_seconds := 0.12
