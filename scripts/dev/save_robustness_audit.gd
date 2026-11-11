extends SceneTree
## Kayıt sağlamlığı (BUG-011/012/030): yanlış tipli alanlar çökmeden güvenli varsayılana düşer,
## bozuk JSON yedeğe düşer, başarısız yazma eski iyi kaydı bozmaz, yeni oyun eski kaydı commit başarısızken silmez.
## Çalıştır (izole kopya + TORIMON_TEST=1): docs/gelistirme/Run-Audit.ps1
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("ROBUSTNESS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _reset_state(gs: Node, sm: Node) -> void:
	gs.player_progress_knowledge = sm._new_progress.duplicate(true)
	gs.world_memory_state = sm._new_world.duplicate(true)
	gs.character_current_life_knowledge = sm._new_life.duplicate(true)
	gs.clear_story_flags()
	gs.hearts = gs.max_hearts


func _run() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var path := String(sm.SAVE_PATH)
	if not ("qa/" in path):
		print("ROBUSTNESS SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	sm.delete_all_save_files()
	var rpath: String = sm.resume_path()

	## (a1) Her alan yanlış tipte: çökme yok, güvenli varsayılan.
	_reset_state(gs, sm)
	_write(path, JSON.stringify({
		"version": 6,
		"save_serial": [5],
		"player_progress_knowledge": "bozuk",
		"world_memory_state": {
			"corpses": "x", "traces": 5, "echo_sites": {"a": 1}, "forbidden_touched": 7,
			"flowers_left": [1], "flags": "bad", "puzzles": [1],
		},
		"character_current_life_knowledge": {
			"interacted": "x", "dialogue_flags": [1], "checkpoint": {"x": [1], "y": "abc"},
			"curse": [1], "curse_visible": "x",
		},
		"story_flags": [1],
		"discovered_seals": "x",
		"possession_count": [1],
		"hearts": {"a": 1},
		"curse": [1],
	}))
	gs.session_loaded_from_save = false
	var ok: Variant = sm.load_committed(false)
	check(ok == true and gs.session_loaded_from_save, "a1: wrong-typed fields -> load completes (returns true, state applied)")
	var pk: Variant = gs.player_progress_knowledge
	check(typeof(pk) == TYPE_DICTIONARY and typeof(pk.get("rooms_visited")) == TYPE_ARRAY and int(pk.get("deaths", -1)) == 0, "a1: progress string -> default dictionary (rooms_visited array, deaths 0)")
	var w: Dictionary = gs.world_memory_state
	check(typeof(w.get("corpses")) == TYPE_ARRAY and typeof(w.get("traces")) == TYPE_ARRAY and typeof(w.get("echo_sites")) == TYPE_ARRAY, "a1: corpses/traces/echo_sites -> arrays")
	check(typeof(w.get("forbidden_touched")) == TYPE_ARRAY, "a1: forbidden_touched -> array")
	check(typeof(w.get("flowers_left")) == TYPE_INT, "a1: flowers_left -> int")
	check(typeof(w.get("flags")) == TYPE_DICTIONARY and typeof(w.get("puzzles")) == TYPE_DICTIONARY, "a1: flags/puzzles -> dictionaries")
	var life: Dictionary = gs.character_current_life_knowledge
	check(typeof(life.get("interacted")) == TYPE_ARRAY and typeof(life.get("dialogue_flags")) == TYPE_DICTIONARY, "a1: interacted array, dialogue_flags dictionary")
	check(life.get("checkpoint") is Vector2, "a1: checkpoint -> Vector2")
	check(gs.hearts >= 1 and gs.hearts <= gs.max_hearts, "a1: hearts clamped")
	check(sm.save_game() and sm._read_save(rpath) != null, "a1: save after bad load round-trips")

	## (a2) Ceset listesinde bozuk öğeler: yalnız sözlükler kalır.
	_reset_state(gs, sm)
	var good_corpse := {"id": "c1", "room": "awakening", "position": {"x": 10, "y": 20}}
	_write(path, JSON.stringify({
		"version": 6,
		"player_progress_knowledge": {"deaths": 2},
		"world_memory_state": {"corpses": [good_corpse, "junk", 5, null], "forbidden_touched": ["a"], "flowers_left": 3},
	}))
	ok = sm.load_committed(false)
	var corpses: Variant = gs.world_memory_state.get("corpses")
	var all_dicts: bool = corpses is Array
	if corpses is Array:
		for c in corpses:
			all_dicts = all_dicts and c is Dictionary
	check(ok == true and all_dicts and (corpses as Array).size() == 1, "a2: non-dictionary corpse entries dropped, good one kept")

	## (a3) Doğru tipler aynen korunur (geriye dönük uyumluluk).
	check(int(gs.player_progress_knowledge.get("deaths", -1)) == 2 and int(gs.world_memory_state.get("flowers_left", -1)) == 3, "a3: valid values preserved")
	check((gs.world_memory_state.get("forbidden_touched") as Array) == ["a"], "a3: valid forbidden_touched preserved")
	check(gs.player_progress_knowledge.has("rooms_visited") and gs.player_progress_knowledge.has("memory_codes"), "a3: missing progress keys filled with defaults")

	## (a4) Bozuk save_serial ana dosyada yükleme/serial okumayı çökertmez.
	var s1: Variant = sm._serial_of({"save_serial": [1, 2]})
	var s2: Variant = sm._serial_of({"save_serial": "7"})
	check(typeof(s1) == TYPE_INT and s1 == 0 and typeof(s2) == TYPE_INT and s2 == 7, "a4: _serial_of tolerant of wrong-typed save_serial")

	## (b) Bozuk JSON -> mevcut yedek/varsayılan davranışı.
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	gs.player_progress_knowledge["deaths"] = 3
	sm.commit_save(&"b1")
	gs.player_progress_knowledge["deaths"] = 4
	sm.commit_save(&"b2")
	_write(path, "{\"player_progress_kno")
	check(sm.load_committed(false) and int(gs.player_progress_knowledge["deaths"]) == 3, "b1: truncated JSON -> .prev")
	_write(path, "[1,2,3]")
	check(sm._read_save(path) == null, "b2: valid JSON, wrong root type -> rejected")
	_write(path, "garbage")
	_write(path + ".prev", "garbage")
	_write(path + ".bak", "garbage")
	check(not sm.load_committed(false), "b3: everything corrupt -> false, no crash")
	_reset_state(gs, sm)
	check(int(gs.player_progress_knowledge.get("deaths", -1)) == 0, "b3: state stays default")

	## (c1) Geçici dosya yolu yazılamıyor (dizin): false döner, eski iyi kayıt bozulmaz.
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	gs.player_progress_knowledge["deaths"] = 8
	check(sm.commit_save(&"c0"), "c1: baseline commit ok")
	var before := _text(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	gs.player_progress_knowledge["deaths"] = 9
	check(sm.commit_save(&"c1") == false, "c1: unwritable temp path -> false")
	check(_text(path) == before and sm._read_save(path) != null, "c1: old good save untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

	## (c2) Yazılamayan hedef klasör: false.
	var bad_dir := "user://qa/yok_dizin_%d/torimon.json" % Time.get_ticks_msec()
	check(sm._write_atomic(bad_dir, {"player_progress_knowledge": {}}) == false, "c2: missing directory -> false")

	## (c3) Test kancası: yazma hatası eski kaydı bozmaz.
	sm.force_fail_for_test = true
	check(sm.commit_save(&"c3") == false and _text(path) == before, "c3: forced failure -> false, old save intact")
	sm.force_fail_for_test = false

	## (c4) Başarılı yazma sonrası artık dosya yok ve yeni veri okunur.
	gs.player_progress_knowledge["deaths"] = 10
	check(sm.commit_save(&"c4") and int(sm._read_save(path)["player_progress_knowledge"]["deaths"]) == 10, "c4: success writes new data")
	check(not FileAccess.file_exists(path + ".tmp"), "c4: no leftover .tmp")

	## (d) Yeni oyun: commit başarısızsa eski committed kayıt silinmez (BUG-030).
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	gs.player_progress_knowledge["deaths"] = 3
	check(sm.commit_save(&"d0"), "d: old game committed")
	var old_text := _text(path)
	sm.force_fail_for_test = true
	sm.start_new_game()
	sm.force_fail_for_test = false
	check(FileAccess.file_exists(path) and _text(path) == old_text, "d1: failed commit in start_new_game keeps old committed save")
	check(sm._read_save(path) != null and int(sm._read_save(path)["player_progress_knowledge"]["deaths"]) == 3, "d1: old save still readable (deaths 3)")

	## (d2) Başarılı yeni oyun: yeni kayıt yazılır, eski oyunun .prev/.bak kopyası kalmaz.
	_reset_state(gs, sm)
	gs.player_progress_knowledge["deaths"] = 3
	check(sm.commit_save(&"d2"), "d2: old game committed again")
	sm.start_new_game()
	var fresh: Variant = sm._read_save(path)
	check(fresh != null and int(fresh["player_progress_knowledge"]["deaths"]) == 0, "d2: new game save written with deaths 0")
	check(not FileAccess.file_exists(path + ".prev") and not FileAccess.file_exists(path + ".bak"), "d2: old game backups removed after successful new game")

	## (e) BUG-031: yetenek/mühür parçası commit_save ile kalıcı; Ana Menüye Dön (discard_resume) sonrası Devam Et korur.
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	gs.player_progress_knowledge["qa_ability"] = true
	sm.save_game()
	check(sm.commit_save(&"ability_pickup"), "e1: ability pickup commit written")
	sm.discard_resume()
	_reset_state(gs, sm)
	check(sm.load_game(false) and gs.player_progress_knowledge.get("qa_ability", false) == true, "e1: ability survives discard_resume + Continue")

	## (f) BUG-032: committed bozuksa _reload_committed resume kaydina duser (cokme yok, warning).
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	gs.character_current_life_knowledge["checkpoint_room"] = "awakening_vigil"
	check(sm.save_game(), "f: resume written")
	_write(path, "garbage")
	_write(path + ".prev", "garbage")
	_write(path + ".bak", "garbage")
	check(sm._read_save(path) == null and sm._read_with_fallback(rpath) is Dictionary, "f1: committed unreadable, resume valid")
	var cm := root.get_node("CurseManager")
	cm._reload_committed()
	check(String(gs.character_current_life_knowledge.get("checkpoint_room", "")) == "awakening_vigil", "f2: _reload_committed fell back to resume checkpoint (no crash)")
	sm.delete_all_save_files()
	_reset_state(gs, sm)
	cm._reload_committed()
	check(true, "f3: _reload_committed with no saves does not crash")

	sm.delete_all_save_files()
	print("ROBUSTNESS failures=", failures)
	quit(1 if failures else 0)
