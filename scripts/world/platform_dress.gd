extends Node2D
## Yürünebilir basamağı duvara, zemine ya da tavana bağlar.
## Havada duran taş dilimi bırakmaz. Çarpışması yoktur; yalnız çizilir.

var origin_x: float = 0.0
var y_top: float = 248.0
var span: float = 80.0
var room_w: float = 960.0
var gaps: PackedVector2Array = PackedVector2Array()
var reflect: bool = false
var lie: bool = false
var mirror_y: float = 160.0


func configure(x: float, y: float, w: float, room_width: float, floor_gaps: PackedVector2Array = PackedVector2Array(), as_reflection: bool = false, is_lie: bool = false, mirror_line: float = 160.0) -> void:
	origin_x = x
	y_top = y
	span = w
	room_w = room_width
	gaps = floor_gaps
	reflect = as_reflection
	lie = is_lie
	mirror_y = mirror_line
	queue_redraw()


func _over_gap() -> bool:
	var a := origin_x
	var b := origin_x + span
	for g in gaps:
		if a < g.y - 4.0 and b > g.x + 4.0:
			return true
	return false


func _draw() -> void:
	if reflect:
		_draw_reflection()
		return
	var stone := Color(0.26, 0.22, 0.3, 1.0)
	var dark := Color(0.07, 0.05, 0.09, 1.0)
	var hi := Color(0.42, 0.36, 0.48, 1.0)
	if _over_gap():
		_abutment(origin_x, stone, dark, hi)
		_abutment(origin_x + span - 16.0, stone, dark, hi)
		_chain_at(origin_x + 10.0, stone, dark)
		_chain_at(origin_x + span - 10.0, stone, dark)
	elif y_top >= 232.0:
		_piers(stone, dark, hi)
	elif origin_x <= 48.0 or origin_x + span >= room_w - 48.0:
		_ledge(stone, dark, hi)
	else:
		_chain_at(origin_x + 10.0, stone, dark)
		_chain_at(origin_x + span - 10.0, stone, dark)


func _piers(stone: Color, dark: Color, hi: Color) -> void:
	var top := y_top + 10.0
	var foot := 288.0
	var h := foot - top
	if h < 6.0:
		return
	for px in [origin_x + 8.0, origin_x + span - 16.0]:
		draw_rect(Rect2(px, top, 8.0, h), stone)
		draw_rect(Rect2(px, top, 2.0, h), hi)
		draw_rect(Rect2(px + 6.0, top, 2.0, h), dark)
		draw_rect(Rect2(px - 3.0, foot - 5.0, 14.0, 5.0), dark)


func _ledge(stone: Color, dark: Color, hi: Color) -> void:
	var left_wall := origin_x <= 48.0
	var right_wall := origin_x + span >= room_w - 48.0
	if left_wall:
		draw_rect(Rect2(0.0, y_top + 4.0, origin_x + 14.0, 8.0), stone)
		draw_rect(Rect2(0.0, y_top + 12.0, maxf(10.0, origin_x * 0.55), 6.0), dark)
		draw_rect(Rect2(0.0, y_top + 4.0, origin_x + 14.0, 2.0), hi)
	if right_wall:
		var x := origin_x + span - 14.0
		draw_rect(Rect2(x, y_top + 4.0, room_w - x, 8.0), stone)
		draw_rect(Rect2(origin_x + span * 0.55, y_top + 12.0, room_w - (origin_x + span * 0.55), 6.0), dark)
		draw_rect(Rect2(x, y_top + 4.0, room_w - x, 2.0), hi)
	if left_wall and not right_wall:
		_chain_at(origin_x + span - 10.0, stone, dark)
	elif right_wall and not left_wall:
		_chain_at(origin_x + 10.0, stone, dark)


func _abutment(x: float, stone: Color, dark: Color, hi: Color) -> void:
	var top := y_top + 8.0
	var foot := 288.0
	if foot - top < 4.0:
		return
	draw_rect(Rect2(x, top, 16.0, foot - top), stone)
	draw_rect(Rect2(x, top, 3.0, foot - top), hi)
	draw_rect(Rect2(x + 13.0, top, 3.0, foot - top), dark)
	draw_rect(Rect2(x - 2.0, foot - 5.0, 20.0, 5.0), dark)


func _chain_at(cx: float, stone: Color, dark: Color) -> void:
	var y := 86.0
	var link := 0
	draw_rect(Rect2(cx - 5.0, y - 4.0, 10.0, 4.0), stone)
	while y < y_top - 1.0:
		var w := 5.0 if link % 2 == 0 else 3.0
		draw_rect(Rect2(cx - w * 0.5, y, w, 3.0), stone if link % 2 == 0 else dark)
		y += 5.0
		link += 1
	draw_rect(Rect2(cx - 4.0, y_top - 2.0, 8.0, 5.0), stone)


func _draw_reflection() -> void:
	var stone := Color(1.0, 0.45, 0.42, 0.45) if lie else Color(0.62, 0.78, 0.95, 0.55)
	var dark := Color(0.4, 0.15, 0.16, 0.4) if lie else Color(0.2, 0.28, 0.4, 0.45)
	var y := y_top + 12.0
	var y1 := mirror_y - 6.0
	if y1 <= y + 4.0:
		return
	for cx in [origin_x + 10.0, origin_x + span - 10.0]:
		var yy := y
		var link := 0
		while yy < y1:
			var w := 5.0 if link % 2 == 0 else 3.0
			draw_rect(Rect2(cx - w * 0.5, yy, w, 3.0), stone if link % 2 == 0 else dark)
			yy += 5.0
			link += 1
		draw_rect(Rect2(cx - 5.0, y1, 10.0, 3.0), stone)
