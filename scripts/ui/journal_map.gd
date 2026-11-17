class_name JournalMap
extends Control
const NookRecordScript := preload("res://scripts/world/nook_record.gd")
const EchoTrialScript := preload("res://scripts/world/echo_trial.gd")
const MemoryShrineScript := preload("res://scripts/world/memory_shrine.gd")
## "Harita & Mühürler": 6 bölgenin şematik, prosedürel gotik haritası (parşömen üstü koyu mürekkep).
## Veri: GameState (rooms_visited, corpses, flags, evidence) + PuzzleManager. Her çizimde taze okunur.

const INK := Color(0.239, 0.071, 0.125)
const RegionCard := preload("res://scripts/ui/region_title_card.gd")
const GOLD := Color(0.54, 0.35, 0.08)
## Bölge kimliği (oda id önekı) -> görünen ad, sıra, bölge mührü bulmacası.
const REGIONS: Array = [
	{"id": "awakening", "seal": &"awakening_memory_code"},
	{"id": "decay", "seal": &"decay_vine_shortcut"},
	{"id": "library", "seal": &"library_page_order"},
	{"id": "experiment", "seal": &"experiment_authority"},
	{"id": "mirrors", "seal": &"mirrors_unbroken"},
	{"id": "core", "seal": &"core_seal"},
]
## Henüz sahnesi olmayabilecek gelecek odalar (yedek liste); asıl kaynak RoomManager.ROOM_TITLES_TR (40 oda).
const FUTURE_ROOMS: PackedStringArray = [
	"awakening_balcony", "awakening_crypt", "decay_catacombs", "decay_shilda_wall",
	"library_upper_stacks", "library_forbidden_wing", "experiment_quarantine",
	"experiment_core_conduit", "mirrors_labyrinth", "mirrors_shrine", "core_memory_vault", "core_bloom_garden",
]

## Kısayol bayrağı -> bağladığı iki bölge (bayrak adında iki bölge geçmiyorsa).
const SHORTCUT_LINKS := {
	"shortcut_decay_crypt": ["decay", "awakening"],
	"decay_vine_shortcut": ["decay", "library"],
}

var _rooms_by_region: Dictionary = {}
## Hızlı seyahat: ziyaret edilmiş oda düğümlerinin dokunma noktaları (her çizimde yenilenir).
signal travel_requested(room_id: StringName)
const HIT_RADIUS := 18.0
var _hits: Array = [] # [{"pos": Vector2, "room": String, "rect": Rect2}]
var _pending: String = ""
var _notice: String = ""

## Yerleşim sabitleri (control yerel piksel). Kurdele sağ sayfada, control'ün sağ kenarından RIBBON_W içeride.
const RIBBON_W := 80.0
const RIBBON_RECT_W := 37.0
const RIBBON_BOTTOM := 84.0
const HEADER_BUDGET := 84.0
const NODE_ZONE := 20.0
const MIN_CARD_H := 42.0
const VGAP := 6.0
## Denetim kancası: true iken _draw çizilen metin/kart/düğüm dikdörtgenlerini debug_rects'e yazar.
var debug_collect: bool = false
var debug_rects: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_collect_rooms()
	visibility_changed.connect(func(): _clear_pending())


func _clear_pending() -> void:
	_pending = ""
	_notice = ""
	queue_redraw()


## Bir kez dokun: oda seçilir ve sorulur; aynı odaya tekrar dokun: git. Boşluğa dokunmak iptal eder.
func _gui_input(event: InputEvent) -> void:
	## Yalnız fare tıklaması: mobilde dokunuş zaten fareye çevrilir (emulate_mouse_from_touch);
	## ScreenTouch'u da dinlemek tek dokunuşu iki kez sayıp seçimi anında onaylardı.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	accept_event()
	var hit := _hit_at(pos)
	if hit.is_empty():
		_clear_pending()
		return
	var rid := String(hit["room"])
	if rid == _pending:
		var reason := RoomManager.fast_travel_block_reason(StringName(rid))
		if reason != "":
			_notice = reason
			queue_redraw()
			return
		_pending = ""
		_notice = ""
		travel_requested.emit(StringName(rid))
		return
	_pending = rid
	_notice = RoomManager.fast_travel_block_reason(StringName(rid))
	queue_redraw()


func _hit_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := HIT_RADIUS
	for h in _hits:
		var d := pos.distance_to(h["pos"])
		if d <= best_d:
			best_d = d
			best = h
	return best


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
	for f in RoomManager.ROOM_TITLES_TR.keys():
		if not ids.has(String(f)):
			ids.append(String(f))
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


func _text(pos: Vector2, s: String, size: int, col: Color, bold: bool = false, tag: String = "") -> void:
	var f: Font = UiTheme.font_bold if bold and UiTheme.font_bold else _font()
	draw_string(f, pos + Vector2(0, f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if debug_collect:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		debug_rects.append({"kind": "text", "tag": tag, "text": s, "rect": Rect2(pos, Vector2(w, f.get_height(size)))})


func _text_w(s: String, size: int, bold: bool = false) -> float:
	var f: Font = UiTheme.font_bold if bold and UiTheme.font_bold else _font()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _text_h(size: int, bold: bool = false) -> float:
	var f: Font = UiTheme.font_bold if bold and UiTheme.font_bold else _font()
	return f.get_height(size)


func _dbg(kind: String, tag: String, rect: Rect2) -> void:
	if debug_collect:
		debug_rects.append({"kind": kind, "tag": tag, "rect": rect})


func _diamond(c: Vector2, r: float, filled: bool, col: Color, tag: String = "") -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col, 1.5)
	if tag != "":
		_dbg("mark", tag, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))


## Sığmayan metni sondan keser ve "…" ekler (taşma yerine).
func _fit_text(s: String, size: int, max_w: float, bold: bool = false) -> String:
	if _text_w(s, size, bold) <= max_w:
		return s
	var t := s
	while t.length() > 1 and _text_w(t + "…", size, bold) > max_w:
		t = t.substr(0, t.length() - 1)
	return t + "…"


## Sözcük sarma: max_w'ye sığan satırlar.
func _wrap_words(s: String, size: int, max_w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in s.split(" "):
		var cand: String = w if cur == "" else cur + " " + w
		if cur != "" and _text_w(cand, size) > max_w:
			lines.append(cur)
			cur = w
		else:
			cur = cand
	if cur != "":
		lines.append(cur)
	return lines


## Başlık düzeni: yazı ölçülerinden (yükseklik = font.get_height) hesaplanır; sabit y yok.
## hs = özet satırı boyutu; sığmazsa çağıran hs'yi küçültür.
func _header_plan(hs: int, lw: float, right_x: float, texts: Dictionary) -> Dictionary:
	var p := {"hs": hs}
	var ts := hs + 5
	while ts > 9 and _text_w("Harita & Mühürler", ts, true) > lw:
		ts -= 1
	p["ts"] = ts
	var y := 0.0
	p["y_title"] = y
	y += _text_h(ts, true) + 1.0
	p["y_seal"] = y
	y += maxf(_text_h(hs), 13.0) + 1.0
	p["y_stat"] = y
	var wk := _text_w(texts["kanit"], hs)
	var wsx := _text_w(texts["kisa"], hs)
	var stacked: bool = wk + 14.0 + wsx > lw
	p["stacked"] = stacked
	y += _text_h(hs) + 1.0
	if stacked:
		p["y_stat2"] = y
		y += _text_h(hs) + 1.0
	var cs := hs
	var parts: Array = texts["cnt"]
	while cs > 8 and _text_w(parts[0], cs) + _text_w(parts[1], cs) + _text_w(parts[2], cs) + 12.0 > lw:
		cs -= 1
	p["cs"] = cs
	if cs <= 8 and _text_w(parts[0], cs) + _text_w(parts[1], cs) + _text_w(parts[2], cs) + 12.0 > lw:
		p["short"] = true
		parts = [parts[0].replace("Kayıtlar", "Kayıt"), parts[1].replace("Sınavlar", "Sınav"), parts[2].replace("Anılar", "Anı")]
		texts["cnt"] = parts
	p["y_cnt"] = y
	y += _text_h(cs)
	p["left_bottom"] = y
	# Sağ sayfa: gösterge (3 satır) + sarılmış ipucu, kurdelenin solunda.
	var lh := maxf(_text_h(hs), 14.0)
	p["lh"] = lh
	var lx := right_x + 6.0
	var avail := size.x - RIBBON_W - 4.0 - lx
	p["avail"] = avail
	var tip_size := mini(hs, 11)
	var lines := _wrap_words("Odaya dokun: hızlı git", tip_size, avail)
	while tip_size > 9 and lines.size() > 2:
		tip_size -= 1
		lines = _wrap_words("Odaya dokun: hızlı git", tip_size, avail)
	p["tip_size"] = tip_size
	p["tip_lines"] = lines
	p["y_tip"] = lh * 3.0 + 2.0
	p["right_bottom"] = lh * 3.0 + 2.0 + float(lines.size()) * _text_h(tip_size)
	p["bottom"] = maxf(p["left_bottom"], p["right_bottom"])
	return p


## Başlığı çizer; en alt öğenin alt kenarını (y) döndürür.
func _draw_header(flags: Dictionary, ev_count: int, shortcuts: Array, page_w: float, right_x: float) -> float:
	var lw := page_w - 24.0
	var shard1 := bool(flags.get("seal_shard_1", false))
	var shard2 := bool(flags.get("seal_shard_2", false))
	var texts := {
		"kanit": "Kanıt %d" % ev_count,
		"kisa": "Kısayol %d" % shortcuts.size(),
		"cnt": [
			"Kayıtlar %d/%d" % [NookRecordScript.count(), NookRecordScript.TOTAL],
			"Sınavlar %d/%d" % [EchoTrialScript.count(), EchoTrialScript.TOTAL],
			"Anılar %d/%d" % [MemoryShrineScript.count(), MemoryShrineScript.TOTAL],
		],
	}
	var hs: int = UiTheme.HINT
	var p := _header_plan(hs, lw, right_x, texts)
	while float(p["bottom"]) > HEADER_BUDGET and hs > 10:
		hs -= 1
		p = _header_plan(hs, lw, right_x, texts)
	var dim := Color(INK, 0.55)
	_text(Vector2(0, p["y_title"]), "Harita & Mühürler", int(p["ts"]), INK, true, "hdr")
	var sh := maxf(_text_h(hs), 13.0)
	var cy_seal: float = float(p["y_seal"]) + sh * 0.5
	_diamond(Vector2(7, cy_seal), 6.0, shard1, INK, "hdr")
	_diamond(Vector2(25, cy_seal), 6.0, shard2, INK, "hdr")
	_text(Vector2(40, float(p["y_seal"]) + (sh - _text_h(hs)) * 0.5), "Mühür %d/2" % (int(shard1) + int(shard2)), hs, INK, false, "hdr")
	_text(Vector2(0, p["y_stat"]), texts["kanit"], hs, INK, false, "hdr")
	var kcol := GOLD if shortcuts.size() > 0 else dim
	if bool(p["stacked"]):
		_text(Vector2(0, p["y_stat2"]), texts["kisa"], hs, kcol, false, "hdr")
	else:
		_text(Vector2(_text_w(texts["kanit"], hs) + 14.0, p["y_stat"]), texts["kisa"], hs, kcol, false, "hdr")
	var cs: int = int(p["cs"])
	if p.get("short", false):
		texts["cnt"] = ["Kayıt %d/%d" % [NookRecordScript.count(), NookRecordScript.TOTAL], "Sınav %d/%d" % [EchoTrialScript.count(), EchoTrialScript.TOTAL], "Anı %d/%d" % [MemoryShrineScript.count(), MemoryShrineScript.TOTAL]]
	var cnt_x := 0.0
	var counts := [NookRecordScript.count(), EchoTrialScript.count(), MemoryShrineScript.count()]
	for i in 3:
		_text(Vector2(cnt_x, p["y_cnt"]), texts["cnt"][i], cs, GOLD if int(counts[i]) > 0 else dim, false, "hdr")
		cnt_x += _text_w(texts["cnt"][i], cs) + 6.0
	# Gösterge (sağ sayfa, kurdelenin solu) + ipucu (gösterge altında, sığacak kadar küçülür/sarılır).
	var lx := right_x + 6.0
	var lh: float = float(p["lh"])
	var th := _text_h(hs)
	for i in 3:
		var cyy := lh * (float(i) + 0.5)
		var label: String = ["Oda", "Ceset", "Mühür"][i]
		if i == 0:
			draw_circle(Vector2(lx + 7, cyy), 7.0, INK)
			_dbg("mark", "hdr", Rect2(lx, cyy - 7.0, 14, 14))
		elif i == 1:
			draw_circle(Vector2(lx + 7, cyy), 7.0, Palette.CRIMSON)
			_dbg("mark", "hdr", Rect2(lx, cyy - 7.0, 14, 14))
		else:
			_diamond(Vector2(lx + 7, cyy), 6.0, true, Palette.CRIMSON, "hdr")
		_text(Vector2(lx + 20, cyy - th * 0.5), label, hs, INK, false, "hdr")
	var tip_size: int = int(p["tip_size"])
	var ty: float = p["y_tip"]
	for ln in p["tip_lines"]:
		_text(Vector2(lx, ty), ln, tip_size, Color(INK, 0.6), false, "hdr")
		ty += _text_h(tip_size)
	_dbg("ribbon", "ribbon", Rect2(size.x - RIBBON_W, 0.0, RIBBON_RECT_W, RIBBON_BOTTOM - 2.0))
	return float(p["bottom"])


func _draw() -> void:
	if _rooms_by_region.is_empty():
		_collect_rooms()
	_hits.clear()
	if debug_collect:
		debug_rects.clear()
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
	var shortcuts: Array = []
	for k in flags.keys():
		if (String(k).contains("shortcut") or String(k).begins_with("shortcut_")) and bool(flags[k]):
			shortcuts.append(String(k))
	for r in REGIONS:
		var sid := String(r["seal"])
		if sid.contains("shortcut") and PuzzleManager.is_solved(StringName(sid)) and not shortcuts.has(sid):
			shortcuts.append(sid)

	# --- Başlık: sol sayfa özet, sağ sayfa gösterge + ipucu (kurdele sağ sayfada, y < RIBBON_BOTTOM). ---
	var gap_spine := 26.0
	var page_w := (size.x - gap_spine) * 0.5
	var right_x := page_w + gap_spine
	var hdr_bottom := _draw_header(flags, ev_count, shortcuts, page_w, right_x)

	# --- Bölge ızgarası: sol sayfa 3, sağ sayfa 3 (kurdele ve cilt payı dışında) ---
	var gy := maxf(hdr_bottom, RIBBON_BOTTOM) + 2.0
	var ch := (size.y - gy - VGAP * 2.0) / 3.0
	var cell_rect: Dictionary = {}
	for i in REGIONS.size():
		var reg: Dictionary = REGIONS[i]
		var col := floori(i / 3.0)
		var row := i % 3
		# Kağıt alanı: sol sayfa ciltten (x ~ page_w-24) önce biter; sağ sayfa kurdele hizasından başlar ve çerçeveye taşmaz.
		var bx := 0.0 if col == 0 else right_x + 4.0
		var bw := page_w - 24.0 if col == 0 else page_w - 14.0
		cell_rect[String(reg["id"])] = Rect2(bx, gy + row * (ch + VGAP), bw, ch)
	for i in REGIONS.size():
		var reg: Dictionary = REGIONS[i]
		_draw_region(reg, cell_rect[String(reg["id"])], visited, corpses_by_room)
	# Kısayol çizgileri (altın kesikli): kartların ÜSTÜNE değil, kartlar arasındaki boşluğa.
	for key in shortcuts:
		var found: Array = []
		for r in REGIONS:
			if String(key).contains(String(r["id"])):
				found.append(String(r["id"]))
		if found.size() < 2 and SHORTCUT_LINKS.has(String(key)):
			found = (SHORTCUT_LINKS[String(key)] as Array).duplicate()
		if found.size() >= 2:
			_draw_shortcut_link(cell_rect[found[0]], cell_rect[found[1]])


## İki kart arasındaki boşlukta altın kesikli bağ: aynı sütunda alt alta -> yatay boşluk, yan yana -> dikey boşluk.
func _draw_shortcut_link(a: Rect2, b: Rect2) -> void:
	var up := a if a.position.y <= b.position.y else b
	var lo := b if a.position.y <= b.position.y else a
	if is_equal_approx(up.position.x, lo.position.x):
		var gy_mid := up.end.y + (lo.position.y - up.end.y) * 0.5
		var x1 := up.position.x + 9.0
		var x2 := up.end.x - 9.0
		_dashed(Vector2(x1, gy_mid), Vector2(x2, gy_mid), GOLD)
		_diamond(Vector2(x1 - 3.0, gy_mid), 2.5, true, GOLD)
		_diamond(Vector2(x2 + 3.0, gy_mid), 2.5, true, GOLD)
		_dbg("link", "link", Rect2(x1 - 5.5, gy_mid - 2.5, x2 - x1 + 11.0, 5.0))
	elif is_equal_approx(up.position.y, lo.position.y):
		var l := up if up.position.x <= lo.position.x else lo
		var r := lo if up.position.x <= lo.position.x else up
		var gx_mid := l.end.x + (r.position.x - l.end.x) * 0.5
		_dashed(Vector2(gx_mid, l.position.y + 9.0), Vector2(gx_mid, l.end.y - 9.0), GOLD)
		_dbg("link", "link", Rect2(gx_mid - 1.0, l.position.y + 9.0, 2.0, l.size.y - 18.0))


## Seçili oda kartının üst şeridi: oda adı + "tekrar dokun" ya da engel nedeni (kartın düğüm bölgesine inmez).
func _draw_travel_prompt(rect: Rect2) -> void:
	var sz := 9
	var th := _text_h(sz, true)
	var avail := rect.size.y - NODE_ZONE - 2.0
	var two := avail >= th * 2.0 + 3.0
	var band := Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4.0, (th * 2.0 + 3.0) if two else maxf(th + 4.0, minf(avail, th + 6.0))))
	draw_rect(band, Palette.IVORY, true)
	draw_rect(band, INK, false, 2.0)
	_dbg("prompt", "prompt", band)
	var title := RoomManager.get_room_number_and_title(StringName(_pending))
	var second := _notice if _notice != "" else "Gitmek için tekrar dokun"
	var col2 := Palette.CRIMSON if _notice != "" else INK
	var iw := band.size.x - 12.0
	if two:
		var y0 := band.position.y + (band.size.y - th * 2.0) * 0.5
		_text(Vector2(band.position.x + 6.0, y0), _fit_text(title, sz, iw, true), sz, INK, true, "prompt")
		_text(Vector2(band.position.x + 6.0, y0 + th), _fit_text(second, sz, iw), sz, col2, false, "prompt")
	else:
		# Dar kart: tek satır (engel nedeni varsa o, yoksa oda adı).
		var one := second if _notice != "" else title
		_text(Vector2(band.position.x + 6.0, band.position.y + (band.size.y - th) * 0.5), _fit_text(one, sz, iw, _notice == ""), sz, col2 if _notice != "" else INK, _notice == "", "prompt")


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
	_dbg("card", String(reg["id"]), rect)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		_diamond(corner, 3.0, true, Color(INK, tone))
	var rname := RegionCard.region_name(String(reg["id"]))
	# Ad: genişlik (mühür elmasına değmeden) VE yükseklik (düğüm bölgesine inmeden) sınırına göre küçülür.
	var name_max := rect.size.x - 8.0 - 26.0
	var avail_h := rect.size.y - NODE_ZONE - 3.0
	var name_size: int = UiTheme.HINT
	while name_size > 9 and (_text_w(rname, name_size, any_seen) + (4.0 if any_seen else 0.0) > name_max or _text_h(name_size, any_seen) > avail_h):
		name_size -= 1
	rname = _fit_text(rname, name_size, name_max, any_seen)
	var name_h := _text_h(name_size, any_seen)
	_text(rect.position + Vector2(8, 2), rname, name_size, Color(INK, tone), any_seen, "card:" + String(reg["id"]))
	# Bölge mührü (sağ üst köşe), adla aynı dikey ortada.
	var solved := PuzzleManager.is_solved(reg["seal"])
	var seal_c := Vector2(rect.end.x - 12.0, rect.position.y + 2.0 + name_h * 0.5)
	_diamond(seal_c, 4.5, solved, Color(Palette.CRIMSON, 1.0 if solved else 0.55), "card:" + String(reg["id"]))
	# Oda düğümleri: zincir + daireler; boyut, kart genişliğine ve oda sayısına göre uyar.
	var n := maxi(1, rooms.size())
	var left := rect.position.x + 22.0
	var span := maxf(1.0, rect.size.x - 44.0)
	var cy := rect.end.y - NODE_ZONE * 0.5 - 1.0
	var spacing := span / float(n - 1) if n > 1 else span
	var r_dot := clampf(spacing * 0.5 - 2.5, 3.5, 7.0)
	var r_halo := r_dot + 2.0
	for j in range(n - 1):
		var x1 := left + span * float(j) / float(n - 1)
		var x2 := left + span * float(j + 1) / float(n - 1)
		var lit := visited.has(rooms[j]) and visited.has(rooms[j + 1])
		draw_line(Vector2(x1, cy), Vector2(x2, cy), Color(INK, 0.8 if lit else 0.25), 2.0)
	# Seçili odanın şeridi düğümlerin üstüne inmez; önce şerit, sonra düğümler.
	if _pending != "" and rooms.has(_pending):
		_draw_travel_prompt(rect)
	var lab_size := 9 if r_dot >= 5.5 else 8
	for j in n:
		var x := left + (span * float(j) / float(n - 1) if n > 1 else span * 0.5)
		var rid := String(rooms[j]) if j < rooms.size() else ""
		var c := Vector2(x, cy)
		var dead := int(corpses_by_room.get(rid, 0))
		_dbg("node", String(reg["id"]), Rect2(c - Vector2(r_halo, r_halo), Vector2(r_halo, r_halo) * 2.0))
		if visited.has(rid):
			_hits.append({"pos": c, "room": rid, "rect": rect})
			if rid == _pending:
				draw_arc(c, r_halo + 1.5, 0.0, TAU, 24, GOLD, 2.0)
			if rid == String(RoomManager.get_active_room_id()):
				draw_arc(c, r_halo + 1.5, 0.0, TAU, 24, Color(GOLD, 0.7), 1.5)
			draw_circle(c, r_dot, Palette.CRIMSON if dead > 0 else INK)
			draw_arc(c, r_halo, 0.0, TAU, 20, Color(INK, 0.55), 1.5)
			if dead > 0:
				# Çift haneli sayı daireye sığmazsa küçült; yine sığmazsa "+" yaz (taşma yok).
				var label := str(dead)
				var ls := lab_size
				var tw := _text_w(label, ls, true)
				while tw > r_dot * 2.0 + 1.0 and ls > 7:
					ls -= 1
					tw = _text_w(label, ls, true)
				if tw > r_dot * 2.0 + 1.0:
					label = "+"
					tw = _text_w(label, ls, true)
				_text(Vector2(x - tw * 0.5, cy - _text_h(ls, true) * 0.5), label, ls, Palette.IVORY, true, "node_label")
		else:
			draw_arc(c, r_dot, 0.0, TAU, 20, Color(INK, 0.3), 1.5)
