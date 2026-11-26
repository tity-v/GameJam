extends RefCounted
## 判断一束光是否「够到」某个点。光敏板和火盆共用这一条判定。
##
## **为什么不能只用水平半径**
## 黑幕是按椭圆画光斑的，但机关判定原先只比较 `distance() <= radii.x`——
## 也就是一个圆。圆会算掉垂直距离，于是出现「光穿楼层」：
## 玩家在底层跳过断口时光心升高 115px，光斑就够到了中层悬挑台上的火盆
## （坑 1 正好在火盆正下方），火盆被点着、板 B 亮起、平台 B 空跑一趟，
## 玩家回来时台子已经在顶上。带手电的虚影重放同一段连跳也会触发。
##
## 所以垂直方向的判定半径压到水平的一半：光斑读作一个**扁椭圆**，
## 人站在同一层才够得着，隔着一层楼板够不着。
## 这跟画面上「光晕是贴着地面的一个椭圆」也一致。

## light_pos / radii 取自 torch_light 组里的光源，point 是机关的中心。
static func covers(light_pos: Vector2, radii: Vector2, point: Vector2) -> bool:
	var rx := radii.x
	if rx <= 0.0:
		return false
	var ry := rx * 0.5
	var dx := absf(light_pos.x - point.x)
	var dy := absf(light_pos.y - point.y)
	if dx > rx or dy > ry:
		return false
	return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0
