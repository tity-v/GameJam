extends Node2D
## 中层火盆：玩家打火点着它，火盆当固定光源去供光敏板 B，平台 B 才会升。
##
## 为什么非要有这个东西：
##   站上平台 B 的玩家，火把在 (704,374)，到板 B 板心 176px，而打火半径只有 96
##   ——点不着。板 B 又必须在平台之外（否则它跟着台面一起升，等于没开关）。
##   一根绳子两头都够不着，中间必须插一个「替身光源」：
##     火盆距玩家火把 56（点得着），距板 B 板心 120（照得到）。
##   于是「人不离开平台、也能把台子叫上来」成立。
##
## 这跟底层那套路数是同一条机制的两次变奏：底层用死后的虚影当替身，
## 这里用火盆当替身。玩家在两段里学的是同一件事——「光可以来自别人」。
##
## 点燃不是瞬时的：引燃 1.2s 里 radii 从 0 涨到满值，火焰从小烧到旺。
## 这不是特效，是缓冲：真实玩家按下打火后要看清"火起来了"才反应得过来。
## 燃料 10s，烧完 1.5s 渐灭，平台失光回落——所以它是可重试的，不是一次性开关。

## 未点燃 / 引燃中 / 燃烧 / 熄灭中
enum Phase { IDLE, IGNITE, BURN, DYING }

@export var ignite_time := 1.2
## 燃料 6s：平台 B 跑完 224px 只要 2.3s，剩下的时间是给「点早了」的容错。
## 为什么不能更长：玩家其实走得到悬挑台（平台 B 与台面只差 4px），
## 在那里点火盆会让平台先升走、人留在台上。这时唯一的恢复路径是
## 「等火盆烧完 → 板 B 灭 → 平台落回 352 → 走回去」，6s 是可以忍的惩罚；
## 10s 会让人以为卡死了。
@export var burn_time := 6.0
@export var dying_time := 1.5
## 满亮半径。必须同时满足两件事：比「火盆到板 B 的 120」大（板才亮），
## 又比「火把打火半径 96」明显大（看得出火盆比手电强一个量级）。
@export var full_radii := Vector2(140, 190)
## 玩家火把到盆心的最大点燃距离
@export var reach := 96.0
## 调试用：1 强制点燃，-1 强制熄灭，0 正常。
@export_range(-1, 1) var force := 0

const IRON := Color("#3b4a46")
const EDGE := Color("#6d8078")
const COAL := Color("#5a2a1e")
const SPARK := Color("#ffd9a0")
const WARM := Color("#f2c785")
const FLAME := Color("#ff9a3c")

## blackout.gd 每帧读这个
var radii := Vector2.ZERO
## 是否已经点着（引燃中算点着，熄灭中不算）
var lit := false
var phase := Phase.IDLE

var _t := 0.0
## 当前亮度系数 0~1，radii 与火焰尺寸都乘它
var _fade := 0.0
var _phase_t := 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group("mechanism")
	add_to_group("torch_light")
	_player = get_tree().get_first_node_in_group("player") as Node2D


## R 键：火盆是机关，重来时它得灭。否则按 R 后平台 B 还被一盏烧着的火盆顶着。
func reset_mechanism() -> void:
	phase = Phase.IDLE
	_phase_t = 0.0
	_fade = 0.0
	radii = Vector2.ZERO
	lit = false
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if force != 0:
		_fade = 1.0 if force > 0 else 0.0
		lit = force > 0
		radii = full_radii * _fade
		queue_redraw()
		return

	_phase_t += delta
	match phase:
		Phase.IDLE:
			_fade = 0.0
			lit = false
			if _trying_to_fire():
				phase = Phase.IGNITE
				_phase_t = 0.0
				_flash("火盆被点着了")
		Phase.IGNITE:
			# t² 曲线：前段几乎不亮（像火苗还在舔底），后段猛地窜起来。
			# 这样 radii 跨过 min_radius 的时刻偏晚，板 B 亮得干脆，不会有"半亮"的糊状态。
			var k := clampf(_phase_t / ignite_time, 0.0, 1.0)
			_fade = k * k
			lit = true
			if k >= 1.0:
				phase = Phase.BURN
				_phase_t = 0.0
		Phase.BURN:
			_fade = 1.0
			lit = true
			if _phase_t >= burn_time:
				phase = Phase.DYING
				_phase_t = 0.0
		Phase.DYING:
			_fade = clampf(1.0 - _phase_t / dying_time, 0.0, 1.0)
			lit = false
			if _fade <= 0.0:
				phase = Phase.IDLE
				_phase_t = 0.0

	radii = full_radii * _fade
	queue_redraw()


## 玩家在盆边按了打火。判定只看距离：火把在玩家身上 (16,22) 处，
## 不依赖 torch.gd 的 radii（那个是渲染用的，判定读它会在同帧里抢先后）。
func _trying_to_fire() -> bool:
	if not Input.is_action_just_pressed("fire"):
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	var torch := _player.global_position + Vector2(16.0, 22.0)
	return torch.distance_to(global_position) <= reach


func _flash(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("flash"):
		hud.call("flash", text)


func _draw() -> void:
	# ---- 支撑：三根铁腿（盆不放在地上，架起来才好塞柴） ----
	for side in [-1.0, 0.0, 1.0]:
		draw_line(Vector2(side * 9.0, -6.0), Vector2(side * 13.0, 0.0), IRON, 2.0)

	# ---- 盆体：上宽下窄的梯形，加一道高光边 ----
	var bowl := PackedVector2Array([
		Vector2(-14.0, -18.0), Vector2(14.0, -18.0),
		Vector2(9.0, -6.0), Vector2(-9.0, -6.0),
	])
	draw_colored_polygon(bowl, IRON)
	draw_polyline(PackedVector2Array([
		Vector2(-14.0, -18.0), Vector2(-9.0, -6.0),
		Vector2(9.0, -6.0), Vector2(14.0, -18.0),
	]), EDGE, 1.0)
	# 盆口的内沿（暗），让"盆里装着东西"读得出来
	draw_line(Vector2(-13.0, -17.0), Vector2(13.0, -17.0), COAL, 2.0)

	# ---- 盆里的炭：未燃时是一层冷灰，燃着时是暗红余烬 ----
	var ember := COAL.lerp(FLAME, _fade * 0.55)
	for i in 3:
		draw_circle(Vector2(-6.0 + i * 6.0, -16.0), 2.4, ember)

	if _fade <= 0.001:
		# 没点着：只在盆口放一点将熄的红，暗示「这里能点」
		draw_circle(Vector2(0.0, -18.0), 3.0, Color(COAL.r, COAL.g, COAL.b, 0.55))
		return

	# ---- 火焰：三层，外层最宽最透明，内层最亮最小 ----
	# 抖动用 _t 的三个不同频率，避免三层同步摆（同步会像整体缩放，不像火）。
	var h := 26.0 * _fade
	var w := 10.0 * _fade
	var layers := [
		[1.00, FLAME, 0.32],
		[0.68, WARM, 0.55],
		[0.38, SPARK, 0.95],
	]
	for i in layers.size():
		var s: float = layers[i][0]
		var col: Color = layers[i][1]
		var a: float = layers[i][2]
		var sway := sin(_t * (7.0 + i * 2.3)) * 2.2 * _fade
		# 火苗是上尖下宽的水滴形：底三点 + 顶点
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * s + sway * 0.4, -18.0),
			Vector2(w * s + sway * 0.4, -18.0),
			Vector2(w * s * 0.42 + sway, -18.0 - h * s),
			Vector2(-w * s * 0.42 + sway, -18.0 - h * s * 0.86),
		]), Color(col.r, col.g, col.b, a))

	# ---- 光晕：两圈，只在点燃时给，让它在黑幕里像个真光源 ----
	draw_circle(Vector2(0.0, -20.0), 26.0 * _fade, Color(WARM.r, WARM.g, WARM.b, 0.10 * _fade))
	draw_circle(Vector2(0.0, -20.0), 13.0 * _fade, Color(WARM.r, WARM.g, WARM.b, 0.16 * _fade))
	# 飞散的火星：三颗，相位错开，往上飘
	for i in 3:
		var ph := fmod(_t * 0.8 + i * 0.33, 1.0)
		var pos := Vector2(sin(ph * 9.0 + i) * 5.0, -22.0 - ph * 22.0)
		draw_circle(pos, 1.2 * (1.0 - ph), Color(SPARK.r, SPARK.g, SPARK.b, (1.0 - ph) * 0.8 * _fade))
