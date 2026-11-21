extends RefCounted
## Prosedürel gotik kemerli kapı sanatı (piksel stili, bir kez üretilir, önbelleğe alınır).
## Kemer, duvar taşları ve eşik sabit. Kilitli kanatlar ve açık niş aynı açıklığı kullanır.

const STANDARD := {"iw": 52.0, "t": 10.0, "h": 116, "grand": false, "cusp": 5.0, "plinth": 8}
const GRAND := {"iw": 60.0, "t": 14.0, "h": 150, "grand": true, "cusp": 7.0, "plinth": 13}

const STONE_DARK := Color(0.085, 0.07, 0.105)
const STONE_MID := Color(0.2, 0.17, 0.235)
const STONE_LIGHT := Color(0.31, 0.27, 0.36)
const STONE_HI := Color(0.46, 0.4, 0.52)
const MORTAR := Color(0.055, 0.045, 0.075)
const VOID_TOP := Color(0.0196, 0.0118, 0.0392) ## #05030a
const VOID_BOTTOM := Color(0.051, 0.031, 0.086) ## #0d0816
const WALL_RETURN := 16
const WOOD := Color(0.18, 0.123, 0.17)
const IRON := Color(0.14, 0.12, 0.16)

static var _cache: Dictionary = {}


static func get_textures(grand: bool) -> Dictionary:
	var key := "g" if grand else "s"
	if not _cache.has(key):
		_cache[key] = _build(GRAND if grand else STANDARD)
	return _cache[key]


static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## Kemer "derinliği": içeride >= 0, dışarıda < 0 (yaklaşık piksel uzaklığı).
static func _depth(cx: float, sy: float, iw: float, hw: float, r: float, px: float, py: float) -> float:
	if py >= sy:
		return hw - absf(px - cx)
	var d1 := Vector2(px - (cx + iw * 0.5), py - sy).length()
	var d2 := Vector2(px - (cx - iw * 0.5), py - sy).length()
	return minf(r - d1, r - d2)


static func _build(sp: Dictionary) -> Dictionary:
	var iw: float = sp["iw"]
	var t: float = sp["t"]
	var h: int = sp["h"]
	var grand: bool = sp["grand"]
	var cusp_r: float = sp["cusp"]
	var plinth: int = sp["plinth"]
	var w := int(iw + 2.0 * t) + 2 * WALL_RETURN
	var cx := float(w) * 0.5
	var r_out := iw + t
	var sy := ceilf(sqrt(r_out * r_out - iw * iw * 0.25))
	var hw_out := iw * 0.5 + t
	var rear_width := iw * 0.6
	var rear_x := cx + 4.0
	var rear_spring := sy + 2.0
	var frame := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var back := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var leaves := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var threshold := Image.create(w, h, false, Image.FORMAT_RGBA8)
	_paint_wall_returns(frame, h, w)
	var cusp_pts: Array[Vector2] = []
	for f in [0.34, 0.7]:
		var a: float = -PI + (PI / 3.0) * f
		cusp_pts.append(Vector2(cx + iw * 0.5 + iw * cos(a), sy + iw * sin(a)))
	var key_top := -1
	for y in h:
		for x in w:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var d_open := _depth(cx, sy, iw, iw * 0.5, iw, px, py)
			var d_out := _depth(cx, sy, iw, hw_out, r_out, px, py)
			var d_back := _depth(cx, sy, iw, iw * 0.5 + 3.0, iw + 3.0, px, py)
			if d_back >= 0.0 and d_out >= 0.0:
				var rear_depth := _depth(rear_x, rear_spring, rear_width, rear_width * 0.5,
					rear_width, px, py)
				back.set_pixel(x, y, _passage_color(px - cx, y, h, iw, rear_depth))
			if d_open >= 0.0:
				if d_open > 3.0 and y < h - 5:
					leaves.set_pixel(x, y, _leaf_color(x, y, int(cx), h, d_open - 3.0))
				if y >= h - 18:
					threshold.set_pixel(x, y, _threshold_light(px - cx, h - y, iw))
			var is_stone := d_out >= 0.0 and d_open < 0.0
			if not is_stone and d_open >= 0.0 and py < sy:
				for cp in cusp_pts:
					for mirror in [false, true]:
						var q: Vector2 = Vector2(2.0 * cx - cp.x, cp.y) if mirror else cp
						var dd := Vector2(px, py).distance_to(q)
						if dd < cusp_r and d_open <= cusp_r - dd - 0.5:
							is_stone = true
			if not is_stone:
				continue
			frame.set_pixel(x, y, _stone_color(x, y, px, py, cx, sy, iw, t, hw_out, d_open, d_out, h, grand, plinth))
			if key_top < 0 and absf(px - cx) < 1.0:
				key_top = y
	## Kilit taşı (keystone) + oyma elmas.
	var kh := 15 if grand else 12
	var kw := 4 if grand else 3
	if key_top >= 0:
		for y in range(key_top, mini(key_top + kh, h)):
			for x in range(int(cx) - kw, int(cx) + kw):
				if frame.get_pixel(x, y).a > 0.5:
					var edge := (y == key_top or x == int(cx) - kw or x == int(cx) + kw - 1)
					frame.set_pixel(x, y, STONE_HI if edge else STONE_LIGHT.lightened(0.08))
		var dcy := key_top + int(kh * 0.5)
		for oy in range(-2, 3):
			for ox in range(-2, 2):
				var m := absi(ox) + absi(oy)
				if m >= 1 and m <= 2:
					var xx := int(cx) + ox
					if frame.get_pixel(xx, dcy + oy).a > 0.5:
						frame.set_pixel(xx, dcy + oy, MORTAR)
	## Aşınmış söve, zeminle aynı düzlemde açıklığın altını tamamlar.
	var sill_x := int(cx - hw_out)
	frame.fill_rect(Rect2i(sill_x, h - 3, int(hw_out * 2), 1), STONE_LIGHT)
	frame.fill_rect(Rect2i(sill_x, h - 2, int(hw_out * 2), 2), STONE_DARK)
	return {
		"frame": ImageTexture.create_from_image(frame),
		"back": ImageTexture.create_from_image(back),
		"leaves": ImageTexture.create_from_image(leaves),
		"threshold": ImageTexture.create_from_image(threshold),
		"seal": _build_seal(),
		"size": Vector2(w, h),
		"seal_y": roundf(float(h) * 0.49),
		"opening_w": iw,
	}


static func _paint_wall_returns(frame: Image, h: int, w: int) -> void:
	## En geniş sıra tabanda. Üstte taşlar kısalarak söveye girer.
	var widths := [16, 12, 8, 6]
	for row in widths.size():
		var reach: int = widths[row]
		var top := h - (row + 1) * 9
		var left := WALL_RETURN - reach
		for side in 2:
			var start := left if side == 0 else w - left - reach - 3
			for y in range(top, top + 9):
				for x in range(start, start + reach + 3):
					var noise := (_hash(float(x), float(y)) - 0.5) * 0.045
					var stone := STONE_MID.lightened(noise)
					if y == top:
						stone = STONE_LIGHT.lerp(STONE_MID, 0.35)
					elif y == top + 8 or (reach >= 12 and (x - start) == int(reach * 0.5) - row):
						stone = MORTAR
					frame.set_pixel(x, y, stone)


static func _leaf_color(x: int, y: int, cx: int, h: int, depth: float) -> Color:
	if depth < 3.0 or x == cx or x == cx - 1:
		return MORTAR
	var board := posmod(absi(x - cx) - 1, 7)
	var band := y - int(h * 0.6) if y < int(h * 0.72) else y - (h - 18)
	if band >= 0 and band < 5:
		if band == 2 and board == 3:
			return STONE_LIGHT
		return IRON.lightened(0.10) if band == 0 else IRON
	if board == 0:
		return WOOD.darkened(0.36)
	var grain := (_hash(float(x), floorf(float(y) / 3.0)) - 0.5) * 0.05
	return WOOD.lightened(grain + float(posmod(x, 5)) * 0.012)


## The outer arch and the narrower throat share one horizon. The overlap exposes the masonry
## inside the opening; shortening the first few floor treads sells distance at native pixel scale.
static func _passage_color(x: float, y: int, h: int, iw: float, rear_depth: float) -> Color:
	var above_floor := h - y
	var throat_half := iw * 0.3
	var rear_center := 4.0
	var left_t := inverse_lerp(-iw * 0.5, rear_center - throat_half, x)
	var right_t := inverse_lerp(iw * 0.5, rear_center + throat_half, x)
	var floor_depth := lerpf(3.0, 18.0, clampf(minf(left_t, right_t), 0.0, 1.0))
	if float(above_floor) <= floor_depth:
		var tread := Color("#403442").lerp(Color("#29212d"), float(above_floor) / 18.0)
		if above_floor in [5, 11, 15, 18]:
			return tread.darkened(0.42)
		if above_floor in [4, 10, 14]:
			return tread.lightened(0.045)
		return tread
	if rear_depth >= 1.0:
		return VOID_TOP.lerp(VOID_BOTTOM, float(y) / float(h))
	var face := Color("#423544") if x < rear_center else Color("#302735")
	if y < int(h * 0.4):
		face = face.darkened(0.26)
	var bed := posmod(y - roundi((x - rear_center) * 0.33), 11)
	if bed == 0 or absf(rear_depth) < 1.4:
		return face.darkened(0.52)
	if bed == 1:
		return face.lightened(0.035)
	return face.darkened(clampf(1.0 + rear_depth / 11.0, 0.0, 1.0) * 0.32)


static func _threshold_light(x: float, above_floor: int, iw: float) -> Color:
	var depth := float(above_floor) / 18.0
	var center := lerpf(-3.0, 4.0, depth)
	var width := iw * lerpf(0.36, 0.17, depth)
	if absf(x - center) >= width or above_floor in [5, 11, 15, 18]:
		return Color.TRANSPARENT
	var strength := 1.0 - absf(x - center) / width
	return Color(0.72, 0.59, 0.72, strength * lerpf(0.28, 0.09, depth))


static func _stone_color(x: int, y: int, px: float, py: float, cx: float, sy: float, iw: float, t: float,
		hw_out: float, d_open: float, d_out: float, h: int, grand: bool, plinth: int) -> Color:
	var base := STONE_MID
	var side := clampf((px - cx) / hw_out, -1.0, 1.0)
	base = base.lerp(STONE_LIGHT if side < 0.0 else STONE_DARK, absf(side) * 0.35)
	var mortar := false
	if py >= sy:
		var course := 14.0 if grand else 12.0
		var ry := fposmod(py - sy, course)
		if ry < 1.0:
			mortar = true
		else:
			var row := int(floor((py - sy) / course))
			var j1 := cx - hw_out + t * (0.5 if row % 2 == 0 else 0.3)
			var j2 := cx + hw_out - t * (0.5 if row % 2 == 0 else 0.3)
			if absf(px - j1) < 0.6 or absf(px - j2) < 0.6:
				mortar = true
	else:
		var mx := px if px < cx else 2.0 * cx - px
		var c1x := cx + iw * 0.5
		var a := atan2(py - sy, mx - c1x)
		var r_mid := iw + t * 0.5
		var span := acos(clampf(iw * 0.5 / r_mid, -1.0, 1.0))
		var n := 6.0 if grand else 5.0
		var u := clampf((a + PI) / span, 0.0, 1.0) * n
		var arc_len := Vector2(mx - c1x, py - sy).length() * span / n
		if fposmod(u, 1.0) * arc_len < 0.9:
			mortar = true
	if mortar:
		return MORTAR.lerp(STONE_DARK, 0.3)
	var n2 := (_hash(float(x), float(y)) - 0.5) * 0.06
	var c := Color(base.r + n2, base.g + n2, base.b + n2 * 1.2, 1.0)
	var d_in := -d_open
	if d_in < 1.3:
		c = STONE_DARK
	elif d_in >= 2.4 and d_in < 3.4:
		c = STONE_HI.lerp(c, 0.45) ## ince tracery silmesi
	if d_out < 1.3:
		c = STONE_HI if side < 0.3 else STONE_LIGHT
	if grand:
		var band := t * 0.55
		if d_in > band and d_in < band + 1.0:
			c = MORTAR.lerp(STONE_MID, 0.35)
	if py >= sy - 2.0 and py < sy + 5.0 and absf(px - cx) > iw * 0.5 - 0.5:
		c = STONE_LIGHT.lerp(c, 0.25)
		if py >= sy + 3.5:
			c = STONE_DARK
		elif py < sy - 0.5:
			c = STONE_HI
	if y >= h - plinth:
		var k := y - (h - plinth)
		c = STONE_LIGHT.lerp(STONE_MID, 0.35)
		if k == 0:
			c = STONE_HI
		elif k >= plinth - 2:
			c = STONE_DARK
	return c


## Kanatların birleştiği yerdeki fiziksel mühür.
static func _build_seal() -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c0 := Vector2(float(s) * 0.5, float(s) * 0.5)
	var crimson := Color(0.78, 0.28, 0.36)
	for y in s:
		for x in s:
			var v := Vector2(float(x) + 0.5, float(y) + 0.5) - c0
			var m := absf(v.x) + absf(v.y)
			var col := Color.TRANSPARENT
			if m <= 7.0:
				col = MORTAR
			if m <= 6.0:
				col = crimson.lightened(0.17) if v.y < 0.0 else crimson
			if m <= 4.0:
				col = crimson.darkened(0.57)
			if m <= 2.0:
				col = crimson.lightened(0.25)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
