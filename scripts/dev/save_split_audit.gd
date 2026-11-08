extends SceneTree
## Committed kayıt / resume ayrımı: commit A, durum B + autosave, load_committed -> A ve resume geçersiz;
## yalnız resume -> B; bozuk committed -> .prev/.bak; eksik alanlar -> varsayılan; eski tek dosya kaydı çalışır.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/save_split_audit.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("SPLIT ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(sm: Node) -> void:
	sm.delete_all_save_files()


func _run() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var path := String(sm.SAVE_PATH)
	if not ("qa/" in path):
		print("SPLIT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_clean(sm)
	var rpath: String = sm.resume_path()
	check(rpath != path and rpath.ends_with("_resume.json"), "resume path distinct: %s" % rpath)

	## State A -> commit (explicit seal position)
	gs.player_progress_knowledge["deaths"] = 1
	gs.clear_story_flags()
	gs.set_story_flag(&"first_warning_heard")
	gs.character_current_life_knowledge["resume"] = {"room": "awakening", "x": 999.0, "y": 111.0}
	check(sm.commit_save(&"seal", Vector2(333, 222), &"awakening"), "commit_save ok")
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(rpath), "commit writes only committed file")
	var c: Variant = sm._read_save(path)
	var life: Dictionary = c["character_current_life_knowledge"]
	check(float(life["checkpoint"]["x"]) == 333.0 and float(life["checkpoint"]["y"]) == 222.0, "committed stores safe position, not raw")
	check(not life.has("resume") and str(life["spawn_id"]) == "checkpoint", "committed has no resume position, spawn=checkpoint")
	check(gs.character_current_life_knowledge.has("resume"), "commit does not mutate live state")
	var serial_a := int(c["save_serial"])

	## State B -> autosave (resume only)
	gs.character_current_life_knowledge.erase("resume")
	gs.player_progress_knowledge["deaths"] = 2
	gs.set_story_flag(&"core_access_granted")
	check(sm.save_game(), "autosave ok")
	var r: Variant = sm._read_save(rpath)
	check(r != null and int(r["save_serial"]) > serial_a, "resume serial newer than committed")
	check((r["story_flags"] as Dictionary).has("core_access_granted") and int(r["version"]) == int(sm.SAVE_VERSION), "resume carries story_flags + version")
	check(int((sm._read_save(path))["player_progress_knowledge"]["deaths"]) == 1, "autosave left committed file untouched")

	## Devam Et -> newer (B)
	gs.player_progress_knowledge["deaths"] = 0
	check(sm.load_game(false), "load_game (Devam Et) ok")
	check(int(gs.player_progress_knowledge["deaths"]) == 2 and gs.has_story_flag(&"core_access_granted"), "load_game picks resume (B)")

	## load_committed -> A, resume invalidated
	check(sm.load_committed(false), "load_committed ok")
	check(int(gs.player_progress_knowledge["deaths"]) == 1 and not gs.has_story_flag(&"core_access_granted") and gs.has_story_flag(&"first_warning_heard"), "load_committed restores A")
	check(not FileAccess.file_exists(rpath), "resume invalidated after load_committed")
	gs.player_progress_knowledge["deaths"] = 0
	check(sm.load_game(false) and int(gs.player_progress_knowledge["deaths"]) == 1, "later Devam Et gets A, not B")

	## Committed newer than resume -> committed wins
	gs.player_progress_knowledge["deaths"] = 5
	sm.save_game()
	gs.player_progress_knowledge["deaths"] = 6
	sm.commit_save(&"save_quit")
	gs.player_progress_knowledge["deaths"] = 0
	sm.load_game(false)
	check(int(gs.player_progress_knowledge["deaths"]) == 6, "newer committed beats older resume")

	## Resume-only (no committed file)
	_clean(sm)
	gs.player_progress_knowledge["deaths"] = 9
	sm.save_game()
	check(not FileAccess.file_exists(path) and sm.has_save(), "resume-only: has_save true")
	gs.player_progress_knowledge["deaths"] = 0
	check(sm.load_game(false) and int(gs.player_progress_knowledge["deaths"]) == 9, "resume-only loads B")
	check(not sm.load_committed(false), "load_committed false when no committed file")

	## Corrupt committed -> .prev / .bak
	_clean(sm)
	gs.player_progress_knowledge["deaths"] = 3
	sm.commit_save(&"t1")
	gs.player_progress_knowledge["deaths"] = 4
	sm.commit_save(&"t2")
	_write(path, "{\"player_progress_kno")
	check(sm.load_committed(false) and int(gs.player_progress_knowledge["deaths"]) == 3, "corrupt committed falls back to .prev")
	_write(path, "garbage")
	_write(path + ".bak", JSON.stringify({"player_progress_knowledge": {"deaths": 77}}))
	check(sm.load_committed(false) and int(gs.player_progress_knowledge["deaths"]) == 77, "corrupt committed falls back to .bak")

	## load_game() own fallbacks: resume .prev/.bak, corrupt resume + good committed, both corrupt
	_clean(sm)
	gs.player_progress_knowledge["deaths"] = 10
	sm.commit_save(&"c")
	gs.player_progress_knowledge["deaths"] = 11
	sm.save_game()
	gs.player_progress_knowledge["deaths"] = 12
	sm.save_game()
	_write(rpath, "{\"player_progress_kno")
	check(sm.load_game(false) and int(gs.player_progress_knowledge["deaths"]) == 11, "corrupt resume falls back to its own .prev")
	_write(rpath, "garbage")
	_write(rpath + ".prev", "garbage")
	_write(rpath + ".bak", JSON.stringify({"player_progress_knowledge": {"deaths": 55}, "save_serial": 9999}))
	check(sm.load_game(false) and int(gs.player_progress_knowledge["deaths"]) == 55, "corrupt resume falls back to its own .bak")
	_write(rpath + ".bak", "garbage")
	check(sm.load_game(false) and int(gs.player_progress_knowledge["deaths"]) == 10, "fully corrupt resume + good committed -> committed")
	_write(path, "garbage")
	_write(path + ".prev", "garbage")
	_write(path + ".bak", "garbage")
	check(not sm.load_game(false), "both corrupt -> safe false, no crash")
	_clean(sm)
	var burst_ok := true
	_write(rpath + ".tmp", "stale")
	_write(rpath + ".bak", "{\"stale\": 1}")
	for i in range(8):
		burst_ok = burst_ok and sm.save_game()
	check(burst_ok and not FileAccess.file_exists(rpath + ".tmp") and not FileAccess.file_exists(rpath + ".bak"), "resume burst with stale .tmp/.bak ok and cleaned")

	## Legacy single file (no save_serial) + missing fields -> defaults
	_clean(sm)
	_write(path, JSON.stringify({"version": 5, "player_progress_knowledge": {"deaths": 4}}))
	gs.hearts = 1
	check(sm.has_save() and sm.load_game(false), "legacy single save loads via Devam Et")
	check(int(gs.player_progress_knowledge["deaths"]) == 4, "legacy progress restored")
	check(gs.hearts == gs.max_hearts, "missing hearts -> default")
	check(str(gs.character_current_life_knowledge.get("checkpoint_room")) == "awakening", "missing life -> default checkpoint room")
	check(sm.commit_save(&"after_legacy") and int(sm._read_save(path)["save_serial"]) >= 1, "serial continues after legacy save")

	_clean(sm)
	print("SPLIT failures=", failures)
	quit(1 if failures else 0)
