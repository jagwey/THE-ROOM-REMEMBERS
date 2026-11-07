class_name JournalMap
extends Control
## "Harita & Mühürler": 6 bölgenin şematik, prosedürel gotik haritası (parşömen üstü koyu mürekkep).
## Veri: GameState (rooms_visited, corpses, flags, evidence) + PuzzleManager. Her çizimde taze okunur.

const INK := Color(0.239, 0.071, 0.125)
const GOLD := Color(0.54, 0.35, 0.08)
## Bölge kimliği (oda id önekı) -> görünen ad, sıra, bölge mührü bulmacası.
const REGIONS: Array = [
	{"id": "awakening", "name": "Uyanış Kanadı", "seal": &"awakening_memory_code"},
	{"id": "decay", "name": "Çürüme Koridorları", "seal": &"decay_vine_shortcut"},
	{"id": "library", "name": "Hafıza Kütüphanesi", "seal": &"library_page_order"},
	{"id": "experiment", "name": "Deney Alanı", "seal": &"experiment_authority"},
	{"id": "mirrors", "name": "Aynalar Salonu", "seal": &"mirrors_unbroken"},
	{"id": "core", "name": "Çekirdek Dairesi", "seal": &"core_seal"},
]
## Henüz sahnesi olmayabilecek gelecek odalar: haritada soluk gösterilir.
const FUTURE_ROOMS: PackedStringArray = [
	"awakening_balcony", "awakening_crypt", "decay_catacombs", "decay_shilda_wall",
	"library_upper_stacks", "library_forbidden_wing", "experiment_quarantine",
	"experiment_core_conduit", "mirrors_labyrinth", "mirrors_shrine", "core_memory_vault", "core_bloom_garden",
]

var _rooms_by_region: Dictionary = {}


func _ready() -> void:
	anchor_right = 1.0
	_collect_rooms()


func refresh() -> void:
	queue_redraw()


## main.gd ROOM_DEFS anahtarları + gelecek kimlikler; bölge = ilk "_" öncesi.
func _collect_rooms() -> void:
	_rooms_by_region.clear()
	for r in REGIONS:
		_rooms_by_region[r["id"]] = []
	var ids: Array = []
	var scr := load("res://scripts/main.gd") as GDScript
	if scr:
		var consts: Dictionary = scr.get_script_constant_map()
		if consts.has("ROOM_DEFS"):
			for k in (consts["ROOM_DEFS"] as Dictionary).keys():
				ids.append(String(k))
	for f in FUTURE_ROOMS:
		if not ids.has(f):
			ids.append(f)
	for id in ids:
		_add_room(id)
	# Ziyaret edilmiş ama listede olmayan (ör. yeni eklenen) odalar da görünsün.
	for v in GameState.player_progress_knowledge.get("rooms_visited", []):
		_add_room(String(v))


func _region_of(room_id: String) -> String:
	var i := room_id.find("_")
	return room_id if i < 0 else room_id.substr(0, i)


func _add_room(room_id: String) -> void:
	var reg := _region_of(room_id)
	if not _rooms_by_region.has(reg):
		return
	var arr: Array = _rooms_by_region[reg]
	if not arr.has(room_id):
		arr.append(room_id)


func _font() -> Font:
	return UiTheme.font_regular if UiTheme.font_regular else ThemeDB.fallback_font


func _text(pos: Vector2, s: String, size: int, col: Color, bold: bool = false) -> void:
	var f: Font = UiTheme.font_bold if bold and UiTheme.font_bold else _font()
	draw_string(f, pos + Vector2(0, f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_w(s: String, size: int) -> float:
	return _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _diamond(c: Vector2, r: float, filled: bool, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col, 1.5)


func _draw() -> void:
	if _rooms_by_region.is_empty():
		_collect_rooms()
	# Yeni ziyaret edilen odalar listeye eklensin.
	var visited: Array = GameState.player_progress_knowledge.get("rooms_visited", [])
	for v in visited:
		_add_room(String(v))
	var flags: Dictionary = GameState.world_memory_state.get("flags", {})
	var corpses_by_room: Dictionary = {}
	for c in GameState.world_memory_state.get("corpses", []):
		if c is Dictionary:
			var rid := String(c.get("room", ""))
			corpses_by_room[rid] = int(corpses_by_room.get(rid, 0)) + 1
	var evidence: Dictionary = GameState.player_progress_knowledge.get("evidence", {})
	var ev_count := 0
	for k in evidence:
		var e: Variant = evidence[k]
		if e is Dictionary and bool(e.get("discovered", true)):
			ev_count += 1

	# --- Sol sayfa üstü: başlık + özet. Sağ sayfada yer imi kurdelesi var (x ~ 328-373, y < 84). ---
	var gap_spine := 26.0
	var page_w := (size.x - gap_spine) * 0.5
	var right_x := page_w + gap_spine
	_text(Vector2(0, 0), "Harita & Mühürler", UiTheme.SPEAKER, INK, true)
	var shard1 := bool(flags.get("seal_shard_1", false))
	var shard2 := bool(flags.get("seal_shard_2", false))
	_diamond(Vector2(7, 37), 6.0, shard1, INK)
	_diamond(Vector2(25, 37), 6.0, shard2, INK)
	_text(Vector2(40, 29), "Mühür %d/2" % (int(shard1) + int(shard2)), UiTheme.HINT, INK)
	var shortcuts: Array = []
	for k in flags.keys():
		if String(k).contains("shortcut") and bool(flags[k]):
			shortcuts.append(String(k))
	for r in REGIONS:
		var sid := String(r["seal"])
		if sid.contains("shortcut") and PuzzleManager.is_solved(StringName(sid)) and not shortcuts.has(sid):
			shortcuts.append(sid)
	_text(Vector2(0, 50), "Kanıt %d" % ev_count, UiTheme.HINT, INK)
	_text(Vector2(0, 68), "Kısayol %d" % shortcuts.size(), UiTheme.HINT, GOLD if shortcuts.size() > 0 else Color(INK, 0.55))
	# Gösterge (sağ sayfa, kurdelenin solu)
	var lx := right_x + 4.0
	draw_circle(Vector2(lx + 7, 11), 7.0, INK)
	_text(Vector2(lx + 20, 3), "Oda", UiTheme.HINT, INK)
	draw_circle(Vector2(lx + 7, 33), 7.0, Palette.CRIMSON)
	_text(Vector2(lx + 20, 25), "Ceset", UiTheme.HINT, INK)
	_diamond(Vector2(lx + 7, 55), 6.0, true, Palette.CRIMSON)
	_text(Vector2(lx + 20, 47), "Mühür", UiTheme.HINT, INK)

	# --- Bölge ızgarası: sol sayfa 3, sağ sayfa 3 (kurdele ve cilt payı dışında) ---
	var gy := 88.0
	var vgap := 5.0
	var ch := (size.y - gy - vgap * 2.0) / 3.0
	var cell_rect: Dictionary = {}
	for i in REGIONS.size():
		var reg: Dictionary = REGIONS[i]
		var col := floori(i / 3.0)
		var row := i % 3
		cell_rect[String(reg["id"])] = Rect2(0.0 if col == 0 else right_x, gy + row * (ch + vgap), page_w, ch)
	# Kısayol çizgileri (altın kesikli) — anahtardaki iki bölge adı bulunursa.
	for key in shortcuts:
		var found: Array = []
		for r in REGIONS:
			if String(key).contains(String(r["id"])):
				found.append(String(r["id"]))
		if found.size() >= 2:
			var a: Vector2 = (cell_rect[found[0]] as Rect2).get_center()
			var b: Vector2 = (cell_rect[found[1]] as Rect2).get_center()
			_dashed(a, b, GOLD)
	for i in REGIONS.size():
		var reg: Dictionary = REGIONS[i]
		_draw_region(reg, cell_rect[String(reg["id"])], visited, corpses_by_room)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var dir := b - a
	var dist := dir.length()
	if dist < 1.0:
		return
	dir /= dist
	var t := 0.0
	while t < dist:
		draw_line(a + dir * t, a + dir * minf(t + 6.0, dist), col, 2.0)
		t += 11.0


func _draw_region(reg: Dictionary, rect: Rect2, visited: Array, corpses_by_room: Dictionary) -> void:
	var rooms: Array = _rooms_by_region.get(String(reg["id"]), [])
	var seen := 0
	for rid in rooms:
		if visited.has(rid):
			seen += 1
	var any_seen := seen > 0
	var tone := 1.0 if any_seen else 0.45
	draw_rect(rect, Color(INK, 0.07 if any_seen else 0.02), true)
	draw_rect(rect, Color(INK, tone), false, 2.0)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		_diamond(corner, 3.0, true, Color(INK, tone))
	_text(rect.position + Vector2(8, 3), String(reg["name"]), UiTheme.HINT, Color(INK, tone), any_seen)
	# Bölge mührü (sağ üst): çözülmüşse dolu.
	var solved := PuzzleManager.is_solved(reg["seal"])
	_diamond(rect.position + Vector2(rect.size.x - 14.0, 12.0), 5.0, solved, Color(Palette.CRIMSON, 1.0 if solved else 0.55))
	# Oda düğümleri: zincir + daireler; cesetli oda crimson dolu, içinde sayı.
	var n := maxi(1, rooms.size())
	var left := rect.position.x + 16.0
	var span := maxf(1.0, rect.size.x - 32.0)
	var cy := rect.position.y + rect.size.y - 17.0
	for j in range(n - 1):
		var x1 := left + span * float(j) / float(n - 1)
		var x2 := left + span * float(j + 1) / float(n - 1)
		var lit := visited.has(rooms[j]) and visited.has(rooms[j + 1])
		draw_line(Vector2(x1, cy), Vector2(x2, cy), Color(INK, 0.8 if lit else 0.25), 2.0)
	for j in n:
		var x := left + (span * float(j) / float(n - 1) if n > 1 else span * 0.5)
		var rid := String(rooms[j]) if j < rooms.size() else ""
		var c := Vector2(x, cy)
		var dead := int(corpses_by_room.get(rid, 0))
		if visited.has(rid):
			draw_circle(c, 8.0, Palette.CRIMSON if dead > 0 else INK)
			draw_arc(c, 10.0, 0.0, TAU, 20, Color(INK, 0.55), 1.5)
			if dead > 0:
				var label := str(dead)
				var tw := _text_w(label, UiTheme.HINT)
				_text(Vector2(x - tw * 0.5, cy - 8.0), label, UiTheme.HINT, Palette.IVORY, true)
		else:
			draw_arc(c, 7.0, 0.0, TAU, 20, Color(INK, 0.3), 1.5)
