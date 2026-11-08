extends SceneTree
## Oda başlığı, portre eşlemesi, fısıltı konuşmacısı, menü/günlük kapıları, hedef metni.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/ui_header_portrait_audit.gd
var failures := 0
var Portraits = load("res://scripts/ui/dialogue_portraits.gd")


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("UIHP ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("UIHP SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	# Oda numaraları/başlıkları
	check(rm.get_room_number_and_title(&"awakening") == "ODA 01 · Uyanış", "awakening title")
	check(rm.get_room_number_and_title(&"awakening_balcony") == "ODA 02 · Gözlem Balkonu", "balcony title")
	check(rm.get_room_number_and_title(&"awakening_crypt") == "ODA 03 · İlk Bedenler Mahzeni", "crypt title")
	check(rm.get_room_number_and_title(&"awakening_passage") == "ODA 04 · Kırık Geçit", "passage title")
	check(rm.get_room_number_and_title(&"awakening_seal") == "ODA 05 · Mühürlü Eşik", "seal title")
	var missing: PackedStringArray = []
	var seen := {}
	var defs: Dictionary = load("res://scripts/main.gd").get_script_constant_map()["ROOM_DEFS"]
	for rid in defs.keys():
		var t: String = rm.get_room_number_and_title(rid)
		if t.begins_with("ODA ??") or not t.begins_with("ODA "):
			missing.append(String(rid))
		if seen.has(t):
			missing.append("dup:" + String(rid))
		seen[t] = true
	check(missing.is_empty(), "every ROOM_DEFS room has unique number/title %s" % str(missing))
	# Portre eşlemesi
	check(Portraits.key_for("Noroi") == &"noroi" and Portraits.key_for("Sen") == &"", "noroi mapping; legacy Sen has no portrait")
	check(Portraits.key_for("Noroi", true) == &"noroi_sad", "noroi sad mapping")
	check(Portraits.key_for("???") == &"shilda" and Portraits.key_for("Bekçi") == &"", "??? legacy alias -> shilda portrait; Bekçi is no longer a speaker")
	check(Portraits.key_for("") == &"" and Portraits.key_for("Sistem") == &"" and Portraits.key_for("Kayıt") == &"", "narrator/system speakers: no portrait")
	check(Portraits.key_for("Shilda") == &"shilda", "shilda mapping")
	check(Portraits.key_for("Arşivci") == &"" and Portraits.key_for("Kayıt") == &"" and Portraits.key_for("Çekirdek") == &"", "unknown speakers no portrait")
	for k in Portraits.PATHS.keys():
		check(Portraits.texture_for(k) != null, "portrait texture loads: %s" % k)
	# Fısıltı konuşmacısı
	var dmc := root.get_node("DialogueManager")
	check(dmc.resolve_whisper_speaker("Noroi", true, false) == "Noroi", "whisper keeps Noroi")
	check(dmc.resolve_whisper_speaker("Shilda", true, false) == "Shilda", "Shilda whisper never masked")
	check(dmc.resolve_whisper_speaker("???", true, true) == "Shilda" and dmc.resolve_whisper_speaker("???", false, false) == "Shilda", "legacy ??? -> Shilda")
	check(dmc.resolve_whisper_speaker("Noroi", true, true) == "Noroi", "named: Noroi whisper kept")
	# Shilda adı: tek kaynak + göç + keeper_speaker_name
	gs.player_progress_knowledge["shilda_named"] = false
	gs.player_progress_knowledge.erase("shilda_named_partial")
	check(not gs.is_shilda_named(), "unnamed flag false before start")
	gs.player_progress_knowledge["shilda_named_partial"] = true
	check(gs.is_shilda_named() and gs.player_progress_knowledge.get("shilda_named", false) and not gs.player_progress_knowledge.has("shilda_named_partial"), "legacy partial key migrates to shilda_named")
	gs.player_progress_knowledge["shilda_named"] = false
	gs.set_world_flag(&"shilda_named", true)
	check(gs.is_shilda_named() and not bool(gs.get_world_flag(&"shilda_named", false)), "legacy world flag migrates")
	gs.player_progress_knowledge["shilda_named"] = false
	gs.character_current_life_knowledge["room"] = &"awakening"
	gs.player_progress_knowledge["pocket_watch_seen"] = false
	check(("Gölgeyle konuş" in gs.get_current_objective()) and not ("Shilda" in gs.get_current_objective()), "room 1 objective hides name before reveal")
	gs.set_shilda_named(true)
	check(gs.keeper_speaker_name() == "Shilda" and not ("Gölgeyle" in gs.get_current_objective()), "named -> Shilda, objective step dropped")
	gs.set_shilda_named(false)
	# say_with: ad açıklama satırında geri çağrı, konuşmacı anında Shilda
	var dm2 := root.get_node("DialogueManager")
	var seen_speakers: Array = []
	dm2.line_shown.connect(func(sp: String, _t: String): seen_speakers.append(sp))
	dm2.say("???", "Noroi… yine mi?")
	dm2.say("Noroi", "Sen kimsin?")
	dm2.say_with("Shilda", "Ben Shilda.", func(): gs.set_shilda_named(true))
	await create_timer(0.1).timeout
	for _i in range(6):
		dm2.advance()
		await create_timer(0.05).timeout
	check(gs.is_shilda_named() and seen_speakers.size() >= 3 and seen_speakers[0] == "Shilda" and seen_speakers[2] == "Shilda", "legacy ??? speaker resolves to Shilda, same plate throughout %s" % str(seen_speakers))
	dm2.clear()
	gs.set_shilda_named(false)
	# Konuşmacı sözleşmesi: tüm say/whisper ve oda lore satırları izinli kümeden
	_speaker_contract_scan()
	# Intro satırları portresiz
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var intro := main_src.substr(main_src.find("func _play_intro"), 1200)
	var rx := RegEx.new()
	rx.compile('say\\("([^"]*)", "(Gözlerin|Oda seni|…Yine)')
	var intro_hits := rx.search_all(intro)
	var intro_ok := intro_hits.size() == 3
	for m in intro_hits:
		if m.get_string(1) != "" or Portraits.has_portrait(m.get_string(1)):
			intro_ok = false
	check(intro_ok, "intro opening lines: narrator '' with no portrait (%d lines)" % intro_hits.size())
	# Hedef metni
	gs.character_current_life_knowledge["room"] = &"awakening"
	var obj: String = gs.get_current_objective()
	check(not ("Saata" in obj) and not (" · Saat" in obj and obj.begins_with("Uyanış")), "objective has no typo/room prefix: " + obj)
	check(not obj.begins_with("Uyanış"), "objective without room prefix")
	# Menü/günlük kapıları
	var JournalScript = load("res://scripts/ui/journal_ui.gd")
	check(JournalScript.call("can_open_in_layer", 0) and JournalScript.call("can_open_in_layer", 2), "journal opens in NONE/JOURNAL")
	for layer in [1, 3, 5, 4, 6, 7, 8]:
		check(not JournalScript.call("can_open_in_layer", layer), "journal blocked in layer %d" % layer)
	quit(1 if failures else 0)


const ALLOWED_SPEAKERS := ["", "Sistem", "Kayıt", "Shilda", "Noroi", "Arşivci", "Yansıma", "Ses", "Çekirdek", "GameState.keeper_speaker_name()"]


func _scan_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan_files(dir.path_join(d), out)


func _speaker_contract_scan() -> void:
	var files: Array = []
	_scan_files("res://scripts", files)
	_scan_files("res://scenes", files)
	var rx_say := RegEx.new()
	rx_say.compile('(?:say|whisper|say_with)\\((GameState\\.keeper_speaker_name\\(\\)|"[^"]*"),')
	var rx_lore := RegEx.new()
	rx_lore.compile('"([^"|\\n]{1,20})\\|')
	var bad: Array = []
	for f in files:
		if String(f).begins_with("res://scripts/dev/"):
			continue
		var src := FileAccess.get_file_as_string(f)
		for m in rx_say.search_all(src):
			var sp := m.get_string(1)
			if sp.begins_with('"'):
				sp = sp.substr(1, sp.length() - 2)
			if not ALLOWED_SPEAKERS.has(sp):
				bad.append("%s: %s" % [f, sp])
		if String(f).ends_with(".tscn"):
			for m in rx_lore.search_all(src):
				if not ALLOWED_SPEAKERS.has(m.get_string(1)):
					bad.append("%s: lore %s" % [f, m.get_string(1)])
	check(bad.is_empty(), "speaker contract: only allowed speakers %s" % str(bad))
