extends SceneTree
## Diyalog JSON: ayrıştırma, when anahtarları, boş satır, @shilda çözümü, eksik set.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/dialogue_data_audit.gd

var failures := 0
const WHEN_OK := ["min_deaths", "flag", "not_flag", "named", "solved"]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("DIALOGUE ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	check(dir != null, "res://data/dialogue açıldı")
	if dir == null:
		quit(1)
		return
	var files: PackedStringArray = dir.get_files()
	var json_count := 0
	var lines := 0
	var words := 0
	for file_name in files:
		if not String(file_name).ends_with(".json"):
			continue
		json_count += 1
		var path := "res://data/dialogue/%s" % file_name
		var text := FileAccess.get_file_as_string(path)
		check(not text.is_empty(), "res:// okundu %s" % file_name)
		var parsed: Variant = JSON.parse_string(text)
		check(typeof(parsed) == TYPE_DICTIONARY, "JSON %s" % file_name)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var sets: Variant = (parsed as Dictionary).get("sets", {})
		if typeof(sets) != TYPE_DICTIONARY:
			check(false, "sets sözlük %s" % file_name)
			continue
		for set_id in (sets as Dictionary).keys():
			for entry in (sets as Dictionary)[set_id]:
				if typeof(entry) != TYPE_DICTIONARY:
					check(false, "satır sözlük değil %s/%s" % [file_name, set_id])
					continue
				if (entry as Dictionary).has("variants"):
					for variant in (entry as Dictionary)["variants"]:
						_check_line(file_name, set_id, variant)
						lines += 1
						words += _words(variant)
				else:
					_check_line(file_name, set_id, entry)
					lines += 1
					words += _words(entry)
	print("DIALOGUE lines=", lines, " words=", words, " files=", json_count)
	check(json_count > 0, "en az bir diyalog dosyası")
	var data := root.get_node("DialogueData")
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["deaths"] = 0
	gs.set_shilda_named(false)
	var unnamed: Array = data.get_set(&"awakening_vigil", &"first_meeting")
	check(unnamed.size() == 2 and String(unnamed[0][0]) == "???", "adsız @shilda → ???", unnamed)
	gs.set_shilda_named(true)
	var named: Array = data.get_set(&"awakening_vigil", &"first_meeting")
	check(named.size() == 2 and String(named[0][0]) == "Shilda", "adlı @shilda → Shilda", named)
	gs.player_progress_knowledge["deaths"] = 4
	var after_deaths: Array = data.get_set(&"awakening_vigil", &"first_meeting")
	check(after_deaths.size() == 2 and String(after_deaths[0][1]).contains("Duvar saydı"), "min_deaths varyantı", after_deaths)
	var missing: Array = data.get_set(&"awakening_vigil", &"yok_boyle_set")
	check(missing.is_empty(), "eksik set boş dizi")
	var missing_file: Array = data.get_set(&"yok_boyle_oda", &"first_meeting")
	check(missing_file.is_empty(), "eksik dosya boş dizi")
	_check_phase0_text()
	print("DIALOGUE done failures=", failures)
	quit(1 if failures else 0)


func _check_line(file_name: String, set_id: String, entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		check(false, "varyant sözlük değil %s/%s" % [file_name, set_id])
		return
	var body := String((entry as Dictionary).get("t", ""))
	check(not body.is_empty(), "boş t yok %s/%s" % [file_name, set_id])
	var when: Variant = (entry as Dictionary).get("when", {})
	if typeof(when) != TYPE_DICTIONARY:
		check(false, "when sözlük değil %s/%s" % [file_name, set_id])
		return
	for key in (when as Dictionary).keys():
		check(WHEN_OK.has(String(key)), "bilinmeyen when %s (%s/%s)" % [key, file_name, set_id])


func _words(entry: Variant) -> int:
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	var n := 0
	for part in String((entry as Dictionary).get("t", "")).split(" ", false):
		if not part.is_empty():
			n += 1
	return n


func _scan_text(dir_path: String, needles: Array, hits: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if not (f.ends_with(".gd") or f.ends_with(".tscn")):
			continue
		var path := dir_path.path_join(f)
		if path.ends_with("dialogue_data_audit.gd"):
			continue
		var t := FileAccess.get_file_as_string(path)
		for n in needles:
			if t.contains(String(n)):
				hits.append("%s:%s" % [path, n])
	for sub in d.get_directories():
		_scan_text(dir_path.path_join(sub), needles, hits)


func _check_phase0_text() -> void:
	var pm := root.get_node("PuzzleManager")
	var bloom := String(pm.get_hints(&"core_bloom_order").get("orientation", ""))
	check(bloom.contains("en çok") and bloom.contains("en az") and not bloom.contains("Çoktan aza"), "bloom_hint_matches_order", bloom)
	var altar_script: GDScript = load("res://scripts/world/echo_altar.gd")
	var altar: Node = altar_script.new()
	var rs: float = altar.record_seconds
	altar.free()
	var hits: Array = []
	_scan_text("res://scenes", ["record_seconds", "altı saniye", "Altı saniye"], hits)
	_scan_text("res://scripts", ["altı saniye", "Altı saniye", "6 saniyelik", "_relay_seconds = 6"], hits)
	check(is_equal_approx(rs, 8.0) and hits.is_empty(), "record_seconds_single", [rs, hits])
	var fc: Array = []
	_scan_text("res://scenes", ["Forward" + "Circuit"], fc)
	_scan_text("res://scripts", ["Forward" + "Circuit"], fc)
	check(fc.is_empty(), "no_forward_circuit", fc)
	var page := String(pm.get_hints(&"library_page_order").get("orientation", ""))
	var i1 := page.find("deney")
	var i2 := page.find("kapı")
	var i3 := page.find("mühür")
	var page_order: Array = load("res://scripts/story/page_order_puzzle.gd").get_script_constant_map().get("ORDER", [])
	var order_ok := page_order == ["experiment_started", "door_closed", "seal_engaged"]
	check(i1 >= 0 and i2 > i1 and i3 > i2 and not page.contains("Mühül") and order_ok, "page_hint_matches_order", [page, page_order])
	check(not FileAccess.file_exists("res://scripts/world/core_portal.gd"), "core_portal_gone")
	check(not FileAccess.file_exists("res://scripts/world/mirror_relay.gd"), "mirror_relay_gone")
	check(not FileAccess.file_exists("res://scripts/world/archive_door.gd"), "archive_door_gone")
