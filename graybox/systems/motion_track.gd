extends RefCounted
## 连续相同的操作只存一次。每半段留一个起点，滚动时同步裁掉旧操作。
var keys: Array[Array] = []
var count: int:
	get: return keys.size()
var length := 0
var capacity: int
var origin := Transform2D.IDENTITY
var velocity := Vector2.ZERO
var phase := 0.0
var _mid_origin := Transform2D.IDENTITY
var _mid_velocity := Vector2.ZERO
var _mid_phase := 0.0
var _mid_key := 0

func _init(limit: int) -> void:
	capacity = maxi(2, limit)

func record(pose: Transform2D, speed: Vector2, route_phase: float, texture: Texture2D, color: Color, state: Array) -> void:
	var cut := ceili(capacity * 0.5)
	if length == capacity:
		keys = keys.slice(_mid_key)
		for key in keys: key[0] -= cut
		length -= cut
		origin = _mid_origin
		velocity = _mid_velocity
		phase = _mid_phase
	if length == 0:
		origin = pose
		velocity = speed
		phase = route_phase
	if length == cut:
		_mid_origin = pose
		_mid_velocity = speed
		_mid_phase = route_phase
		_mid_key = count
	var last := keys.back() as Array if count else []
	if length == cut or last.is_empty() or last[1] != texture or last[2] != color or last[3] != state:
		keys.append([length, texture, color, state])
	length += 1

func cursor_at(cursor: int, elapsed: int) -> int:
	while cursor + 1 < count and keys[cursor+1][0] <= elapsed:
		cursor += 1
	return cursor
