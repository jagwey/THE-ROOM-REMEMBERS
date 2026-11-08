extends SceneTree
## Hikâye bayrakları + kayıt v6 denetimi: set/has, kaydet-yükle turu, v5 göçü, yeni oyun temizliği.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/story_flags_audit.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("FLAGS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var path := String(sm.SAVE_PATH)
	if not ("qa/" in path):
		print("FLAGS SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(int(sm.SAVE_VERSION) == 6, "SAVE_VERSION == 6")
	check(gs.STORY_FLAGS.size() == 13, "13 known story flags")

	## API
	gs.clear_story_flags()
	check(not gs.has_story_flag(&"intro_completed"), "unset flag is false")
	var seen: Array = []
	gs.story_flag_changed.connect(func(id: StringName, v: bool) -> void: seen.append([id, v]))
	gs.set_story_flag(&"intro_completed")
	gs.set_story_flag(&"intro_completed")
	check(gs.has_story_flag(&"intro_completed"), "set_story_flag stores true")
	check(seen.size() == 1 and seen[0][0] == &"intro_completed" and seen[0][1] == true, "signal fires once on change")
	gs.set_story_flag(&"x_revealed", false)
	check(not gs.has_story_flag(&"x_revealed"), "explicit false stored")
	gs.set_story_flag(&"made_up_flag")
	check(gs.has_story_flag(&"made_up_flag"), "unknown id still stored (warning only)")
	gs.clear_story_flags()
	check(gs.story_flags.is_empty(), "clear_story_flags empties")

	## Kaydet-yükle turu
	gs.set_story_flag(&"first_warning_heard")
	gs.set_story_flag(&"core_access_granted")
	check(sm.commit_save(&"test"), "save_game ok")
	var raw: Variant = sm._read_save(path)
	var sf: Variant = (raw as Dictionary).get("story_flags", null)
	check(sf is Dictionary and (sf as Dictionary).has("first_warning_heard"), "save JSON has String-keyed story_flags")
	gs.clear_story_flags()
	check(sm.load_committed(false), "load_game ok")
	check(gs.has_story_flag(&"first_warning_heard") and gs.has_story_flag(&"core_access_granted"), "flags survive roundtrip")
	check(not gs.has_story_flag(&"game_completed"), "unset flag stays unset after roundtrip")
	check(gs.story_flags.has(&"first_warning_heard") and gs.story_flags.keys()[0] is StringName, "loaded keys are StringName")

	## v5 göçü: story_flags yok, durumdan türetilir
	var v5 := {
		"version": 5,
		"player_progress_knowledge": {
			"deaths": 2, "shilda_named": true, "rooms_visited": ["awakening", "core_threshold"],
			"first_corpse_line_seen": true, "lore_seen": ["crypt_ledger"],
		},
		"world_memory_state": {"puzzles": {"awakening_weight": true}},
		"character_current_life_knowledge": {},
		"hearts": 3,
	}
	_write(path, JSON.stringify(v5))
	gs.clear_story_flags()
	check(sm.load_committed(false), "v5 save loads without error")
	for id in [&"shilda_name_known", &"first_death_completed", &"core_access_granted", &"intro_completed", &"first_corpse_discovered", &"dimension_origin_discovered", &"shilda_past_discovered"]:
		check(gs.has_story_flag(id), "v5 migration derives %s" % String(id))
	check(not gs.has_story_flag(&"game_completed") and not gs.has_story_flag(&"final_seal_broken"), "v5 migration leaves underivable flags unset")
	check(gs.player_progress_knowledge.has("deaths") and gs.world_memory_state.has("flags") and gs.world_memory_state.has("traces"), "v5 migration keeps safe defaults")

	## Bare v5 (sources absent) -> nothing derived, no error
	_write(path, JSON.stringify({"version": 4, "player_progress_knowledge": {}, "hearts": 3}))
	gs.world_memory_state = sm._new_world.duplicate(true)
	gs.set_story_flag(&"x_revealed")
	check(sm.load_committed(false), "bare v4 save loads")
	check(gs.story_flags.is_empty(), "bare old save yields no flags ")

	## Yeni oyun temizler
	gs.set_story_flag(&"game_completed")
	sm.start_new_game()
	check(gs.story_flags.is_empty(), "start_new_game clears story flags")

	for f in [path, path + ".bak", path + ".prev", path + ".tmp", sm.resume_path()]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("FLAGS failures=", failures)
	quit(failures)
