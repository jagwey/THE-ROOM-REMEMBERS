extends SceneTree
## Günlük (özellikle Harita & Mühürler) yerleşim denetimi: başlık metinleri birbirine / kartlara / kurdeleye binmez,
## her metin control içinde kalır, kartlar asgari yükseklikte, seçili oda şeridi kartın içinde kalır.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/journal_layout_audit.gd
var failures := 0
var _checks := 0
var journal: Node
var GS: GDScript = load("res://scripts/autoload/game_settings.gd")


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		failures += 1
		print("JL FAIL ", label)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("JL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	journal = (load("res://scenes/ui/journal.tscn") as PackedScene).instantiate()
	root.add_child(journal)
	await process_frame
	await process_frame
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		for large in [false, true]:
			root.size = sz
			GS.font_large = large
			var tag := "%dx%d%s" % [sz.x, sz.y, " large" if large else ""]
			var before := failures
			await _audit_all(tag)
			print("JL ", "PASS " if failures == before else "FAIL ", tag, " (map rects=", journal.map_view.debug_rects.size(), ")")
	GS.font_large = false
	print("JL DONE failures=", failures, " checks=", _checks)
	quit(1 if failures > 0 else 0)


## En kötü durum: tüm odalar ziyaretli, 2 mühür, kısayollar açık, sayaçlar dolu, her odada ceset.
func _fill_worst_case(map: Control) -> void:
	var gs := root.get_node("GameState")
	var pk: Dictionary = gs.player_progress_knowledge
	var visited: Array = []
	var corpses: Array = []
	for reg in map._rooms_by_region:
		for rid in map._rooms_by_region[reg]:
			visited.append(String(rid))
			corpses.append({"room": String(rid)})
	pk["rooms_visited"] = visited
	pk["journal_unlocked"] = true
	var ev := {}
	for i in 123:
		ev["ev%d" % i] = {"discovered": true}
	pk["evidence"] = ev
	var nooks := {}
	for i in 8:
		nooks["n%d" % i] = true
	pk["nooks"] = nooks
	var trials := {}
	for i in 6:
		trials["t%d" % i] = true
	pk["trials"] = trials
	var mems := {}
	for i in 5:
		mems["m%d" % i] = true
	pk["memories"] = mems
	for i in 9:
		corpses.append({"room": String(visited[0])}) # iki haneli ceset sayısı
	var flags: Dictionary = gs.world_memory_state.get("flags", {})
	flags["seal_shard_1"] = true
	flags["seal_shard_2"] = true
	flags["shortcut_decay_crypt"] = true
	flags["decay_vine_shortcut"] = true
	gs.world_memory_state["flags"] = flags
	gs.world_memory_state["corpses"] = corpses
	var pm := root.get_node("PuzzleManager")
	for r in map.REGIONS:
		pm.solved[String(r["seal"])] = true


func _draw_now(map: Control) -> void:
	map.debug_collect = true
	map.queue_redraw()
	await process_frame
	await process_frame


func _audit_all(tag: String) -> void:
	journal.visible = true
	journal._show_section("harita")
	var map: Control = journal.map_view
	await process_frame
	await process_frame
	_fill_worst_case(map)
	await _draw_now(map)
	check(map.debug_rects.size() > 20, "%s: map _draw collected rects (%d)" % [tag, map.debug_rects.size()])
	_check_map(map, tag + " harita")
	# Seçili oda şeridi: her bölgenin ilk odası, boş ve en uzun engel nedeni ile.
	var notices := ["", "Bu odayı henüz görmedin.", "Şu an gidilemez: bir sahne sürüyor, bekle."]
	for reg in map.REGIONS:
		var rooms: Array = map._rooms_by_region[String(reg["id"])]
		if rooms.is_empty():
			continue
		for nt in notices:
			map._pending = String(rooms[rooms.size() - 1])
			map._notice = nt
			await _draw_now(map)
			_check_map(map, "%s harita prompt %s '%s'" % [tag, reg["id"], nt])
	map._pending = ""
	map._notice = ""
	await _draw_now(map)
	_check_tabs(tag)
	for sec in ["gunluk", "notlar", "izler"]:
		journal._show_section(sec)
		await process_frame
		await process_frame
		_check_list_page(tag + " " + sec)


func _inter(a: Rect2, b: Rect2) -> bool:
	return a.grow(-0.75).intersects(b.grow(-0.75))


func _check_map(map: Control, tag: String) -> void:
	var ctrl := Rect2(Vector2.ZERO, map.size).grow(0.5)
	var items: Array = map.debug_rects
	var hdr: Array = []
	var cards: Array = []
	var nodes: Array = []
	var prompts: Array = []
	var ribbon := Rect2()
	var links: Array = []
	var page_w := (map.size.x - 26.0) * 0.5
	for it in items:
		var r: Rect2 = it["rect"]
		match String(it["kind"]):
			"text", "mark":
				check(ctrl.encloses(r), "%s: %s inside control (%s %s)" % [tag, it.get("text", it["tag"]), r, map.size])
				if String(it["tag"]) == "hdr":
					hdr.append(it)
			"card": cards.append(it)
			"node": nodes.append(it)
			"prompt": prompts.append(it)
			"ribbon": ribbon = r
			"link": links.append(it)
	# 1) başlık öğeleri birbirine binmez
	for i in hdr.size():
		for j in range(i + 1, hdr.size()):
			check(not _inter(hdr[i]["rect"], hdr[j]["rect"]), "%s: header overlap '%s' x '%s' %s %s" % [tag, hdr[i].get("text", "mark"), hdr[j].get("text", "mark"), hdr[i]["rect"], hdr[j]["rect"]])
	# 2) başlık öğeleri kartlara / kurdeleye değmez
	var min_card_y := 1e9
	for c in cards:
		min_card_y = minf(min_card_y, c["rect"].position.y)
		check(c["rect"].size.y >= map.MIN_CARD_H, "%s: card %s height %.1f >= %.1f" % [tag, c["tag"], c["rect"].size.y, map.MIN_CARD_H])
		check(ctrl.encloses(c["rect"]), "%s: card %s inside control" % [tag, c["tag"]])
		for h in hdr:
			check(not _inter(h["rect"], c["rect"]), "%s: header '%s' hits card %s" % [tag, h.get("text", "mark"), c["tag"]])
	for h in hdr:
		check(not _inter(h["rect"], ribbon), "%s: header '%s' hits ribbon" % [tag, h.get("text", "mark")])
		var r: Rect2 = h["rect"]
		var left_side := r.position.x < page_w
		if left_side:
			check(r.end.x <= page_w - 24.0 + 0.5, "%s: left header '%s' stays on left page (end %.1f)" % [tag, h.get("text", "mark"), r.end.x])
		else:
			check(r.position.x >= page_w + 26.0 - 0.5, "%s: right header '%s' stays on right page" % [tag, h.get("text", "mark")])
		check(r.end.y <= min_card_y + 0.5, "%s: header '%s' ends above first card" % [tag, h.get("text", "mark")])
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			check(not _inter(cards[i]["rect"], cards[j]["rect"]), "%s: cards %s/%s overlap" % [tag, cards[i]["tag"], cards[j]["tag"]])
	# 3) kart içi: ad, mühür elması, düğümler, şerit
	for c in cards:
		var cid: String = c["tag"]
		var crect: Rect2 = c["rect"]
		var card_items: Array = []
		for it in items:
			if String(it["tag"]) == "card:" + cid:
				card_items.append(it)
				check(crect.encloses(it["rect"]), "%s: %s '%s' inside card" % [tag, cid, it.get("text", "seal")])
		if card_items.size() == 2:
			check(not _inter(card_items[0]["rect"], card_items[1]["rect"]), "%s: %s title vs seal diamond" % [tag, cid])
		for n in nodes:
			if n["tag"] != cid:
				continue
			check(crect.encloses(n["rect"]), "%s: %s node inside card (%s)" % [tag, cid, n["rect"]])
			for ci in card_items:
				check(not _inter(ci["rect"], n["rect"]), "%s: %s title hits node %s" % [tag, cid, n["rect"]])
	for p in prompts:
		var host: Rect2
		for c in cards:
			if c["rect"].encloses(p["rect"]):
				host = c["rect"]
		check(host.size.x > 0.0, "%s: prompt band inside a card" % tag)
		var band: Rect2 = p["rect"]
		for it in items:
			if String(it["tag"]) == "prompt" and String(it["kind"]) == "text":
				check(band.encloses(it["rect"]), "%s: prompt text '%s' inside band %s %s" % [tag, it["text"], it["rect"], band])
		for n in nodes:
			check(not _inter(band, n["rect"]) or not host.encloses(n["rect"]), "%s: prompt band covers a node %s" % [tag, n["rect"]])
	# 4) kısayol bağı metne / düğüme değmez
	for l in links:
		for it in items:
			if String(it["kind"]) in ["text", "node"]:
				check(not _inter(l["rect"], it["rect"]), "%s: shortcut link hits %s" % [tag, it.get("text", "node")])


func _check_tabs(tag: String) -> void:
	var book: Control = journal.get_node("BookRoot")
	var tabs: Array = [journal.tab_gunluk, journal.tab_notlar, journal.tab_izler, journal.tab_harita]
	var brect := Rect2(Vector2.ZERO, book.size).grow(0.5)
	for i in tabs.size():
		var b: Button = tabs[i]
		var rr := Rect2(b.position + b.get_parent().position, b.size)
		check(brect.encloses(rr), "%s: tab %s inside book (%s vs %s)" % [tag, b.text, rr, book.size])
		var f: Font = b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		check(tw <= b.size.x - 4.0, "%s: tab '%s' text %.0f fits button %.0f" % [tag, b.text, tw, b.size.x])
		for j in range(i + 1, tabs.size()):
			var o: Button = tabs[j]
			check(not _inter(rr, Rect2(o.position + o.get_parent().position, o.size)), "%s: tabs %s/%s overlap" % [tag, b.text, o.text])


func _check_list_page(tag: String) -> void:
	var lt: Label = journal.list_title
	var f: Font = lt.get_theme_font("font")
	var fs := lt.get_theme_font_size("font_size")
	var tw := f.get_string_size(lt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	check(tw <= lt.size.x + 0.5, "%s: list title '%s' %.0f fits %.0f" % [tag, lt.text, tw, lt.size.x])
	check(f.get_height(fs) <= lt.size.y + 6.0, "%s: list title height" % tag)
	var sc: Control = journal.entry_list.get_parent()
	var lp: Control = journal.left_page
	check(lt.position.y + lt.size.y <= sc.position.y + 1.0, "%s: list title above list" % tag)
	check(sc.size.x <= lp.size.x + 0.5, "%s: list scroll within page" % tag)
	var dt: Label = journal.detail_title
	var dsc: Control = journal.scroll
	check(dt.position.y + dt.size.y <= dsc.position.y + 6.0, "%s: detail title above detail body" % tag)
