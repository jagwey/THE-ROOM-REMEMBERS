extends RefCounted
## Prosedürel gotik kemerli kapı sanatı (piksel stili, bir kez üretilir, önbelleğe alınır).
## Katmanlar: frame (taş sütun/söve + sivri kemer + ince tracery), back (simsiyah iç, #05030a → #0d0816),
## seal (kemer merkezinde parlayan mühür/rün). Görseller alt-orta tabanlıdır: taban = zemin çizgisi.

const STANDARD := {"iw": 52.0, "t": 10.0, "h": 116, "grand": false, "cusp": 5.0, "plinth": 8}
const GRAND := {"iw": 60.0, "t": 14.0, "h": 150, "grand": true, "cusp": 7.0, "plinth": 13}

const STONE_DARK := Color(0.085, 0.07, 0.105)
const STONE_MID := Color(0.2, 0.17, 0.235)
const STONE_LIGHT := Color(0.31, 0.27, 0.36)
const STONE_HI := Color(0.46, 0.4, 0.52)
const MORTAR := Color(0.055, 0.045, 0.075)
const VOID_TOP := Color(0.0196, 0.0118, 0.0392) ## #05030a
const VOID_BOTTOM := Color(0.051, 0.031, 0.086) ## #0d0816

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
	var w := int(iw + 2.0 * t)
	var cx := float(w) * 0.5
	var r_out := iw + t
	var sy := ceilf(sqrt(r_out * r_out - iw * iw * 0.25))
	var hw_out := iw * 0.5 + t
	var frame := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var back := Image.create(w, h, false, Image.FORMAT_RGBA8)
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
				var k := clampf(float(y) / float(h - 1), 0.0, 1.0)
				var c := VOID_TOP.lerp(VOID_BOTTOM, k)
				var n := (_hash(float(x), float(y)) - 0.5) * 0.012
				back.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n * 1.4, 1.0))
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
		var dcy := key_top + kh / 2
		for oy in range(-2, 3):
			for ox in range(-2, 2):
				var m := absi(ox) + absi(oy)
				if m >= 1 and m <= 2:
					var xx := int(cx) + ox
					if frame.get_pixel(xx, dcy + oy).a > 0.5:
						frame.set_pixel(xx, dcy + oy, MORTAR)
	return {
		"frame": ImageTexture.create_from_image(frame),
		"back": ImageTexture.create_from_image(back),
		"seal": _build_seal(),
		"size": Vector2(w, h),
		"seal_y": float(h) - (sy - iw * 0.22), ## tabandan yukarı yükseklik
		"opening_w": iw,
	}


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


## Kemer merkezi için parlayan gotik mühür: çift halka, sekiz diş, merkezde göz/elmas rün.
static func _build_seal() -> ImageTexture:
	var s := 40
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c0 := Vector2(float(s) * 0.5, float(s) * 0.5)
	var crimson := Color(1.0, 0.27, 0.4)
	var violet := Color(0.72, 0.55, 1.0)
	for y in s:
		for x in s:
			var v := Vector2(float(x) + 0.5, float(y) + 0.5) - c0
			var d := v.length()
			var ang := atan2(v.y, v.x)
			var col := Color(0, 0, 0, 0)
			if d < 19.5:
				var a := 1.0 - d / 19.5
				col = Color(0.8, 0.15, 0.3, a * a * 0.45)
			if absf(d - 14.5) < 0.9:
				col = crimson
			if absf(d - 10.0) < 0.7 and fposmod(ang * 8.0 / TAU, 1.0) < 0.62:
				col = violet
			if d > 14.8 and d < 18.0 and fposmod(ang * 8.0 / TAU + 0.5, 1.0) < 0.2:
				col = crimson.lerp(Color.WHITE, 0.25)
			var m := absf(v.x) + absf(v.y)
			if m <= 5.2:
				col = violet if m >= 3.8 else Color(0.12, 0.03, 0.08, 1.0)
			if absf(v.x) < 0.9 and absf(v.y) < 3.0:
				col = Color(1.0, 0.85, 0.9)
			if d < 1.4:
				col = Color(1.0, 0.95, 0.98)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
