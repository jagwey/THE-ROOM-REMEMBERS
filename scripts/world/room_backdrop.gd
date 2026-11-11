extends Node2D
## Oda arka planı tamamlayıcı: tavan kemer/kaburga + koyu tavan geçişi, zemin altı taş katmanları,
## süpürgelik (skirting), zemin çizgisi (y=288) derinlik gölgesi. İsteğe bağlı balkon: büyük sivri kemerli
## açıklık (gece göğü) + korkuluk. Tek _draw, hesaplar önbelleksiz ama ucuz (az dikdörtgen).

const FLOOR_Y := 288.0
const ROOM_H := 360.0

var width: float = 960.0
var tint: Color = Color(1, 1, 1, 1)
var balcony: bool = false
var motif: String = "awakening"


func setup(w: float, region_tint: Color, is_balcony: bool, region_motif: String = "awakening") -> void:
	width = maxf(w, 640.0)
	tint = region_tint
	balcony = is_balcony
	motif = region_motif
	queue_redraw()


static func _h(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _tc(c: Color, a: float = 1.0) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, a)


## İki merkezli sivri kemer noktaları (yay + yan duvarlar hariç); sol alt → tepe → sağ alt.
static func arch_points(cx: float, spring: float, a: float, h: float, n: int = 20) -> PackedVector2Array:
	var r := (a * a + h * h) / (2.0 * a)
	var pts := PackedVector2Array()
	var apex_l := atan2(-h, a - r)
	var apex_r := atan2(-h, r - a)
	var lc := Vector2(cx - a + r, spring)
	for i in n + 1:
		var t := lerpf(-PI, apex_l, float(i) / float(n))
		pts.append(lc + Vector2(cos(t), sin(t)) * r)
	var rc := Vector2(cx + a - r, spring)
	for i in n + 1:
		var t2 := lerpf(apex_r, 0.0, float(i) / float(n))
		pts.append(rc + Vector2(cos(t2), sin(t2)) * r)
	return pts


func _draw() -> void:
	_draw_ceiling()
	_draw_motif()
	if balcony:
		_draw_balcony()
	_draw_floor()


## Bölge kimliği: boyalı arka planın üstüne, tavan boşluğunda okunur bir iz.
func _draw_motif() -> void:
	var w := width
	match motif:
		"decay":
			var vine := _tc(Color(0.28, 0.42, 0.22), 0.55)
			var x := 36.0
			var i := 0
			while x < w:
				var h := 28.0 + _h(float(i), 2.0) * 46.0
				draw_line(Vector2(x, 0), Vector2(x + 6.0, h), vine, 2.0)
				draw_line(Vector2(x + 6.0, h), Vector2(x - 8.0, h + 10.0), vine, 1.5)
				draw_line(Vector2(x + 6.0, h), Vector2(x + 16.0, h + 8.0), vine, 1.5)
				x += 70.0 + _h(float(i), 4.0) * 40.0
				i += 1
		"library":
			var wood := _tc(Color(0.45, 0.32, 0.18), 0.7)
			var shelf_y := 18.0
			while shelf_y < 96.0:
				draw_rect(Rect2(8, shelf_y, w - 16.0, 3.0), wood)
				var bx := 16.0
				var bi := 0
				while bx < w - 20.0:
					var bh := 10.0 + _h(float(bi), shelf_y) * 8.0
					var bc := _tc(Color(0.55, 0.28, 0.22), 0.45) if bi % 3 == 0 else _tc(Color(0.25, 0.22, 0.32), 0.4)
					draw_rect(Rect2(bx, shelf_y - bh, 4.0 + _h(float(bi), 1.0) * 3.0, bh), bc)
					bx += 8.0 + _h(float(bi), 8.0) * 6.0
					bi += 1
				shelf_y += 26.0
		"experiment":
			var glass := _tc(Color(0.55, 0.85, 0.9), 0.28)
			var cx := 120.0
			var i2 := 0
			while cx < w - 40.0:
				draw_rect(Rect2(cx, 16, 28, 78), glass)
				draw_rect(Rect2(cx + 4, 24, 6, 52), _tc(Color(0.7, 0.95, 1.0), 0.18))
				draw_line(Vector2(cx + 14, 16), Vector2(cx + 14, 8), glass, 2.0)
				cx += 160.0 + _h(float(i2), 3.0) * 40.0
				i2 += 1
		"mirrors":
			var shard := _tc(Color(0.82, 0.88, 1.0), 0.35)
			for i3 in int(w / 90.0) + 1:
				var sx := float(i3) * 90.0 + 20.0
				draw_line(Vector2(sx, 12), Vector2(sx + 22, 48), shard, 1.5)
				draw_line(Vector2(sx + 22, 48), Vector2(sx + 6, 70), shard, 1.5)
				draw_line(Vector2(sx + 6, 70), Vector2(sx, 12), shard, 1.0)
		"core":
			var glow := _tc(Color(0.75, 0.15, 0.22), 0.22)
			draw_rect(Rect2(0, 96, w, 36), glow)
			var diamond := PackedVector2Array([
				Vector2(w * 0.5, 28), Vector2(w * 0.5 + 14, 48),
				Vector2(w * 0.5, 68), Vector2(w * 0.5 - 14, 48),
			])
			draw_colored_polygon(diamond, _tc(Color(0.9, 0.25, 0.3), 0.45))
		"awakening":
			var wax := _tc(Color(0.85, 0.7, 0.4), 0.35)
			for i4 in int(w / 180.0):
				var lx := 90.0 + float(i4) * 180.0
				draw_rect(Rect2(lx, 20, 3, 22), wax)
				draw_circle(Vector2(lx + 1.5, 16), 3.0, _tc(Color(1.0, 0.82, 0.45), 0.5))
		"bloom":
			var petal := _tc(Color(0.85, 0.22, 0.32), 0.7)
			var stem := _tc(Color(0.28, 0.45, 0.24), 0.65)
			var bx := 48.0
			var bi := 0
			while bx < w - 24.0:
				var bh := 18.0 + _h(float(bi), 3.0) * 22.0
				draw_line(Vector2(bx, 250.0), Vector2(bx, 250.0 - bh), stem, 2.0)
				draw_circle(Vector2(bx, 248.0 - bh), 4.0, petal)
				draw_circle(Vector2(bx - 3.0, 250.0 - bh), 2.2, petal)
				draw_circle(Vector2(bx + 3.0, 250.0 - bh), 2.2, petal)
				bx += 54.0 + _h(float(bi), 6.0) * 28.0
				bi += 1
		"vault":
			var beam := _tc(Color(0.75, 0.82, 1.0), 0.28)
			for vi in 3:
				var vx := w * (0.28 + float(vi) * 0.22)
				draw_rect(Rect2(vx - 6.0, 24.0, 12.0, 150.0), beam)
				draw_circle(Vector2(vx, 28.0), 8.0, _tc(Color(0.9, 0.35, 0.45), 0.55))
		"quarantine":
			var stripe := _tc(Color(0.75, 0.12, 0.16), 0.55)
			var qx := 0.0
			while qx < w:
				draw_rect(Rect2(qx, 258.0, 18.0, 8.0), stripe)
				qx += 36.0
			draw_rect(Rect2(0, 248.0, w, 2.0), _tc(Color(0.9, 0.25, 0.28), 0.35))
		"labyrinth":
			var glass := _tc(Color(0.8, 0.9, 1.0), 0.4)
			draw_line(Vector2(0, 150.0), Vector2(w, 150.0), glass, 2.0)
			for li in int(w / 70.0):
				var lx2 := 20.0 + float(li) * 70.0
				draw_line(Vector2(lx2, 132.0), Vector2(lx2 + 18.0, 168.0), glass, 1.2)
				draw_line(Vector2(lx2 + 18.0, 168.0), Vector2(lx2 + 4.0, 188.0), _tc(Color(1.0, 0.45, 0.4), 0.35), 1.2)
		_:
			var unknown: String = motif
			push_warning("room_backdrop: unknown motif %s" % unknown)


func _draw_ceiling() -> void:
	var w := width
	## Tavan karartması: üstte neredeyse siyah, aşağı doğru şeffaf.
	var steps := 14
	for i in steps:
		var y0 := 120.0 * float(i) / float(steps)
		var k := 1.0 - float(i) / float(steps)
		draw_rect(Rect2(0, y0, w, 120.0 / float(steps) + 1.0), Color(0.02, 0.012, 0.04, 0.94 * k * k))
	## Kaburga kemerleri + sütunlar (bay genişliği 224).
	var bay := 224.0
	var spring := 76.0
	var stone := _tc(Color(0.2, 0.17, 0.235), 0.9)
	var stone_hi := _tc(Color(0.36, 0.31, 0.42), 0.8)
	var stone_dk := _tc(Color(0.07, 0.055, 0.09), 0.95)
	var bays := int(ceil(w / bay)) + 1
	for b in bays:
		var cx := (float(b) + 0.5) * bay
		var pts := arch_points(cx, spring, bay * 0.5, 68.0, 18)
		draw_polyline(pts, stone_dk, 6.0)
		draw_polyline(pts, stone, 4.0)
		draw_polyline(pts, stone_hi, 1.0)
		## İç ince kaburga (çift).
		var pts2 := arch_points(cx, spring + 2.0, bay * 0.5 - 12.0, 52.0, 14)
		draw_polyline(pts2, Color(stone.r, stone.g, stone.b, 0.5), 2.0)
	for b in bays + 1:
		var px := float(b) * bay
		draw_rect(Rect2(px - 6.0, 0, 12.0, spring + 18.0), stone)
		draw_rect(Rect2(px - 6.0, 0, 3.0, spring + 18.0), stone_hi)
		draw_rect(Rect2(px + 3.0, 0, 3.0, spring + 18.0), stone_dk)
		draw_rect(Rect2(px - 9.0, spring + 10.0, 18.0, 5.0), stone_hi)
		draw_rect(Rect2(px - 7.0, spring + 15.0, 14.0, 4.0), stone_dk)
	## Alt sınır: süs silmesi çizgisi.
	draw_rect(Rect2(0, 0, w, 3.0), stone_dk)
	draw_rect(Rect2(0, 3.0, w, 1.0), Color(stone_hi.r, stone_hi.g, stone_hi.b, 0.5))


func _draw_floor() -> void:
	var w := width
	var base := _tc(Color(0.1, 0.085, 0.125), 1.0)
	## Duvar tabanı gölgesi (süpürgelik üstü).
	for i in 8:
		draw_rect(Rect2(0, 236.0 + float(i) * 5.0, w, 5.0), Color(0.02, 0.012, 0.035, 0.05 * float(i + 1)))
	## Süpürgelik: üst silme, gövde, alt gölge.
	var sk_top := _tc(Color(0.36, 0.31, 0.42), 1.0)
	var sk_mid := _tc(Color(0.2, 0.17, 0.235), 1.0)
	var sk_dk := _tc(Color(0.06, 0.045, 0.08), 1.0)
	draw_rect(Rect2(0, 270.0, w, 2.0), sk_top)
	draw_rect(Rect2(0, 272.0, w, 11.0), sk_mid)
	draw_rect(Rect2(0, 283.0, w, 5.0), sk_dk)
	var x := 0.0
	var i2 := 0
	while x < w:
		var seg := 40.0 + _h(float(i2), 3.0) * 40.0
		draw_rect(Rect2(x, 272.0, 1.0, 11.0), Color(sk_dk.r, sk_dk.g, sk_dk.b, 0.7))
		draw_rect(Rect2(x + 2.0, 274.0 + _h(float(i2), 9.0) * 4.0, seg * 0.35, 1.0), Color(sk_top.r, sk_top.g, sk_top.b, 0.25))
		x += seg
		i2 += 1
	## Zemin: koyu taban + üst taş şerit + perspektifli kaldırım taşı sıraları.
	draw_rect(Rect2(0, FLOOR_Y, w, ROOM_H - FLOOR_Y), base)
	var rows := [[FLOOR_Y, 10.0, 56.0], [FLOOR_Y + 10.0, 14.0, 72.0], [FLOOR_Y + 24.0, 20.0, 96.0], [FLOOR_Y + 44.0, 28.0, 128.0]]
	for ri in rows.size():
		var ry: float = rows[ri][0]
		var rh: float = rows[ri][1]
		var sw: float = rows[ri][2]
		var sx := -fposmod(float(ri) * 23.0, sw)
		var si := 0
		while sx < w:
			var wv := sw * (0.8 + 0.4 * _h(float(si), float(ri)))
			var shade := 0.82 + 0.28 * _h(float(si) + 7.0, float(ri) + 1.0)
			var c := Color(base.r * shade * 1.55, base.g * shade * 1.5, base.b * shade * 1.5, 1.0)
			draw_rect(Rect2(sx, ry, wv, rh), c)
			draw_rect(Rect2(sx, ry, wv, 1.0), Color(sk_top.r, sk_top.g, sk_top.b, 0.35))
			draw_rect(Rect2(sx + wv - 1.0, ry, 1.0, rh), sk_dk)
			sx += wv
			si += 1
		draw_rect(Rect2(0, ry + rh - 1.0, w, 1.0), sk_dk)
	## Üst taş şerit (y=288 çizgisi) — oyuncunun bastığı kenar.
	draw_rect(Rect2(0, FLOOR_Y, w, 2.0), sk_top)
	draw_rect(Rect2(0, FLOOR_Y + 2.0, w, 2.0), sk_mid)
	## Derinlik gölgesi: aşağı doğru kararır.
	var shade_pts := PackedVector2Array([Vector2(0, FLOOR_Y), Vector2(w, FLOOR_Y), Vector2(w, ROOM_H), Vector2(0, ROOM_H)])
	var shade_cols := PackedColorArray([Color(0.02, 0.012, 0.035, 0.0), Color(0.02, 0.012, 0.035, 0.0), Color(0.02, 0.012, 0.035, 0.78), Color(0.02, 0.012, 0.035, 0.78)])
	draw_polygon(shade_pts, shade_cols)


func _draw_balcony() -> void:
	var stone := _tc(Color(0.22, 0.19, 0.26), 1.0)
	var stone_hi := _tc(Color(0.4, 0.35, 0.46), 1.0)
	var stone_dk := _tc(Color(0.07, 0.055, 0.09), 1.0)
	var spring := 168.0
	var cxs := [width * 0.5 - 170.0, width * 0.5 + 170.0]
	for cx in cxs:
		## Taş çerçeve (dış kemer) → gece göğü (iç kemer).
		var outer := arch_points(cx, spring, 150.0, 128.0, 22)
		outer.append(Vector2(cx + 150.0, 262.0))
		outer.append(Vector2(cx - 150.0, 262.0))
		draw_colored_polygon(outer, stone)
		var inner := arch_points(cx, spring, 136.0, 118.0, 22)
		var sky := PackedVector2Array(inner)
		sky.append(Vector2(cx + 136.0, 262.0))
		sky.append(Vector2(cx - 136.0, 262.0))
		var cols := PackedColorArray()
		for p in sky:
			var k := clampf((p.y - 40.0) / 222.0, 0.0, 1.0)
			cols.append(Color(0.04, 0.03, 0.1).lerp(Color(0.2, 0.12, 0.22), k * k))
		draw_polygon(sky, cols)
		## Yıldızlar + uzak tesis siluetleri.
		for s in 18:
			var sx: float = cx - 120.0 + _h(float(s), cx) * 240.0
			var sy: float = 60.0 + _h(cx, float(s)) * 110.0
			if Geometry2D.is_point_in_polygon(Vector2(sx, sy), sky):
				draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(0.9, 0.85, 1.0, 0.3 + 0.5 * _h(float(s), 5.0)))
		var tx: float = cx - 130.0
		var ti := 0
		while tx < cx + 130.0:
			var tw: float = 18.0 + _h(float(ti), cx) * 26.0
			var th: float = 24.0 + _h(cx, float(ti)) * 46.0
			draw_rect(Rect2(tx, 262.0 - th, tw, th), Color(0.035, 0.025, 0.06, 1.0))
			if _h(float(ti), 2.0) > 0.45:
				draw_rect(Rect2(tx + tw * 0.5 - 1.0, 262.0 - th + 6.0, 2.0, 3.0), Color(0.9, 0.5, 0.4, 0.55))
			tx += tw + 2.0
			ti += 1
		## Gül pencere kemere ve söveye bağlı; boşta halka yok.
		var rose := Vector2(cx, spring - 64.0)
		var rose_r := 12.0
		draw_arc(rose, rose_r, 0.0, TAU, 20, stone, 3.0)
		draw_line(rose + Vector2(-rose_r, -2.0), Vector2(cx - 36.0, spring - 28.0), stone, 2.0)
		draw_line(rose + Vector2(rose_r, -2.0), Vector2(cx + 36.0, spring - 28.0), stone, 2.0)
		draw_line(rose + Vector2(0.0, -rose_r), Vector2(cx, spring - 96.0), stone, 2.0)
		var mull_top := rose.y + rose_r - 1.0
		draw_rect(Rect2(cx - 2.0, mull_top, 4.0, 262.0 - mull_top), stone)
		draw_polyline(inner, stone_hi, 1.0)
		draw_polyline(arch_points(cx, spring, 150.0, 128.0, 22), stone_dk, 1.0)
	## Ay + hale (sol kemerin sağ üstü).
	draw_circle(Vector2(cxs[1] + 50.0, 96.0), 11.0, Color(0.85, 0.82, 0.95, 0.85))
	draw_circle(Vector2(cxs[1] + 50.0, 96.0), 22.0, Color(0.7, 0.65, 0.9, 0.12))
	## Korkuluk: üst küpeşte, balusterler, alt kaide, pilastr.
	var w := width
	draw_rect(Rect2(0, 244.0, w, 6.0), stone_hi)
	draw_rect(Rect2(0, 250.0, w, 2.0), stone_dk)
	draw_rect(Rect2(0, 276.0, w, 12.0), stone)
	draw_rect(Rect2(0, 276.0, w, 2.0), stone_hi)
	var bx := 10.0
	while bx < w - 8.0:
		draw_rect(Rect2(bx, 250.0, 4.0, 26.0), stone)
		draw_rect(Rect2(bx, 250.0, 1.0, 26.0), stone_hi)
		draw_rect(Rect2(bx + 3.0, 250.0, 1.0, 26.0), stone_dk)
		bx += 16.0
	var pil := 0.0
	while pil <= w:
		draw_rect(Rect2(pil - 8.0, 236.0, 16.0, 52.0), stone)
		draw_rect(Rect2(pil - 8.0, 236.0, 3.0, 52.0), stone_hi)
		draw_rect(Rect2(pil - 10.0, 232.0, 20.0, 6.0), stone_hi)
		draw_rect(Rect2(pil + 5.0, 236.0, 3.0, 52.0), stone_dk)
		pil += 240.0
