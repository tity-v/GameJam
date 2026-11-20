extends RefCounted
## 固定容量的变化帧环形缓冲。持续移动也不需要搬移整个数组。
var keys: Array = []
var head := 0
var count := 0
var length := 0
var capacity: int
func _init(limit: int) -> void:
	capacity = maxi(2, limit)
func key(index: int) -> Array:
	return keys[(head + index) % capacity]
func record(pose: Transform2D, texture: Texture2D, color: Color, state: Array) -> void:
	var oldest := maxi(0, length - capacity + 1)
	while count > 1 and key(1)[0] <= oldest:
		head = (head + 1) % capacity
		count -= 1
	var last := key(count - 1) if count else []
	if last.is_empty() or last[1] != pose or last[2] != texture or last[3] != color or last[4] != state:
		var sample := [length, pose, texture, color, state]
		var slot := (head + count) % capacity
		if slot == keys.size():
			keys.append(sample)
		else:
			keys[slot] = sample
		count += 1
	length += 1
func cursor_at(cursor: int, elapsed: int) -> int:
	var time := elapsed + maxi(0, length - capacity)
	while cursor + 1 < count and key(cursor + 1)[0] <= time:
		cursor += 1
	return cursor
