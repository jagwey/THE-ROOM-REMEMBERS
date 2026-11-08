extends SceneTree
## Empirical Stress Test: Feature 3 (Safe Save Overwrite on Windows Desktop, Rapid Bursts, Stale Files, Corruption)
## Run: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/stress_save_system.gd

var failures := 0
var tests_run := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run_audit")

func check(ok: bool, label: String, detail: String = "") -> void:
	tests_run += 1
	if ok:
		print("SAVE_BURST PASS [%03d] %s" % [tests_run, label])
	else:
		failures += 1
		print("SAVE_BURST FAIL [%03d] %s :: %s" % [tests_run, label, detail])

func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()

func _clean_files(base_path: String) -> void:
	var g_target := ProjectSettings.globalize_path(base_path)
	var g_tmp := ProjectSettings.globalize_path(base_path + ".tmp")
	var g_bak := ProjectSettings.globalize_path(base_path + ".bak")
	var g_prev := ProjectSettings.globalize_path(base_path + ".prev")
	if FileAccess.file_exists(base_path): DirAccess.remove_absolute(g_target)
	if FileAccess.file_exists(base_path + ".tmp"): DirAccess.remove_absolute(g_tmp)
	if FileAccess.file_exists(base_path + ".bak"): DirAccess.remove_absolute(g_bak)
	if FileAccess.file_exists(base_path + ".prev"): DirAccess.remove_absolute(g_prev)

func _run_audit() -> void:
	print("=== STARTING SAVE SYSTEM EMPIRICAL STRESS AUDIT ===")
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var path := String(sm.SAVE_PATH)
	
	check("qa/" in path, "Using QA test isolated save directory (%s)" % path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_clean_files(path)

	# --- TEST SUITE 1: Rapid Consecutive Burst Saves (15 iterations) ---
	print("\n--- Test Suite 1: Rapid Consecutive Burst Saves ---")
	var burst_ok := true
	for i in range(1, 16):
		gs.player_progress_knowledge["deaths"] = i * 10
		gs.player_progress_knowledge["burst_step"] = i
		gs.set_world_flag(&"burst_flag_%d" % i, true)
		var res: bool = sm.commit_save(&"test")
		if not res:
			burst_ok = false
			check(false, "Burst save call #%d failed" % i, "returned false")
	
	check(burst_ok, "All 15 rapid consecutive save_game() calls succeeded (no ERR_ALREADY_EXISTS)")
	check(not FileAccess.file_exists(path + ".tmp"), "No dangling .tmp file after 15 rapid saves")
	check(not FileAccess.file_exists(path + ".bak"), "No dangling .bak file after 15 rapid saves")
	check(FileAccess.file_exists(path), "Main save file exists")
	check(FileAccess.file_exists(path + ".prev"), "Previous save file .prev exists")
	
	# Verify content of main save matches step 15
	var parsed_main: Variant = sm._read_save(path)
	check(parsed_main != null, "Main save parses as valid JSON dictionary")
	if parsed_main is Dictionary:
		var deaths: int = int((parsed_main as Dictionary)["player_progress_knowledge"].get("deaths", -1))
		var step: int = int((parsed_main as Dictionary)["player_progress_knowledge"].get("burst_step", -1))
		check(deaths == 150 and step == 15, "Main save content correctly reflects 15th burst write (deaths=%d, step=%d)" % [deaths, step])
	
	# Verify content of .prev matches step 14
	var parsed_prev: Variant = sm._read_save(path + ".prev")
	check(parsed_prev != null, ".prev save parses as valid JSON dictionary")
	if parsed_prev is Dictionary:
		var prev_deaths: int = int((parsed_prev as Dictionary)["player_progress_knowledge"].get("deaths", -1))
		var prev_step: int = int((parsed_prev as Dictionary)["player_progress_knowledge"].get("burst_step", -1))
		check(prev_deaths == 140 and prev_step == 14, ".prev correctly contains penultimate 14th write (deaths=%d, step=%d)" % [prev_deaths, prev_step])

	# --- TEST SUITE 2: Rapid Resume Saves (10 iterations) ---
	print("\n--- Test Suite 2: Rapid Resume Saves ---")
	var resume_ok := true
	for i in range(1, 11):
		gs.character_current_life_knowledge["resume"] = {
			"room": "decay_weight", "x": 100.0 + i * 5.0, "y": 288.0
		}
		var r_res: bool = sm.save_game()
		if not r_res:
			resume_ok = false
	check(resume_ok, "10 rapid consecutive resume saves succeeded")
	
	# --- TEST SUITE 3: Stale Pre-existing Files Resistance ---
	print("\n--- Test Suite 3: Stale Pre-existing Files Collision Handling ---")
	# Stale .bak exists
	_write_file(path + ".bak", "{\"corrupt\": \"stale_bak_data\"}")
	check(FileAccess.file_exists(path + ".bak"), "Injected stale .bak file")
	gs.player_progress_knowledge["deaths"] = 999
	var bak_save_res: bool = sm.commit_save(&"test")
	check(bak_save_res, "save_game() succeeds even when stale .bak file already exists")
	check(not FileAccess.file_exists(path + ".bak"), "save_game() cleaned up .bak upon completion")
	
	# Stale .tmp exists
	_write_file(path + ".tmp", "INVALID_PARTIAL_WRITE_GARBAGE_TMP")
	check(FileAccess.file_exists(path + ".tmp"), "Injected stale .tmp file")
	gs.player_progress_knowledge["deaths"] = 1000
	var tmp_save_res: bool = sm.commit_save(&"test")
	check(tmp_save_res, "save_game() succeeds even when stale .tmp file already exists")
	check(not FileAccess.file_exists(path + ".tmp"), "save_game() overwritten and cleared .tmp")
	
	var verify_main: Variant = sm._read_save(path)
	check(verify_main != null and int((verify_main as Dictionary)["player_progress_knowledge"].get("deaths", -1)) == 1000, "Main save contains uncorrupted data after clearing stale temp files")

	# --- TEST SUITE 4: Corruption Recovery & Rollback ---
	print("\n--- Test Suite 4: Corruption Recovery & Rollback ---")
	# Ensure good .prev exists with known value (deaths = 1000)
	gs.player_progress_knowledge["deaths"] = 2000
	sm.commit_save(&"test") # now main has 2000, .prev has 1000
	
	# Corrupt main file (truncated JSON)
	_write_file(path, "{\"version\": 5, \"player_progress_knowledge\": {")
	gs.player_progress_knowledge["deaths"] = 0
	var loaded_fallback: bool = sm.load_committed(false)
	check(loaded_fallback, "load_game() succeeds when main is corrupted via .prev fallback")
	check(int(gs.player_progress_knowledge.get("deaths", -1)) == 1000, "State correctly restored from .prev (deaths=1000, got %s)" % str(gs.player_progress_knowledge.get("deaths")))
	
	# Corrupt main file, simulate mid-rename state where .bak exists
	_write_file(path, "GARBAGE_NON_JSON")
	var bak_payload := JSON.stringify({
		"version": 5,
		"player_progress_knowledge": {"deaths": 3000, "recovered_from_bak": true},
		"world_memory_state": {},
		"character_current_life_knowledge": {},
		"hearts": 3
	})
	_write_file(path + ".bak", bak_payload)
	gs.player_progress_knowledge.clear()
	var bak_load_res: bool = sm.load_committed(false)
	check(bak_load_res, "load_game() recovers from .bak when main save is corrupt")
	check(bool(gs.player_progress_knowledge.get("recovered_from_bak", false)), "Recovered state from .bak accurately parsed")
	
	# Total corruption: main, .bak, and .prev are all invalid JSON
	_write_file(path, "NOT_JSON_MAIN")
	_write_file(path + ".bak", "NOT_JSON_BAK")
	_write_file(path + ".prev", "NOT_JSON_PREV")
	var hopeless_load: bool = sm.load_committed(false)
	check(not hopeless_load, "load_game() cleanly returns false without crashing when all saves are unparseable")

	# --- TEST SUITE 5: Interleaved Read/Write Consistency Stress ---
	print("\n--- Test Suite 5: 20-Step Interleaved Save-Load Consistency Stress ---")
	_clean_files(path)
	var consistency_pass := true
	for i in range(1, 21):
		gs.player_progress_knowledge["sync_counter"] = i
		gs.world_memory_state["sync_flag_%d" % i] = i
		if not sm.commit_save(&"test"):
			consistency_pass = false
			break
		# Mutate in-memory state
		gs.player_progress_knowledge["sync_counter"] = -999
		# Load and verify
		if not sm.load_committed(false):
			consistency_pass = false
			break
		if int(gs.player_progress_knowledge.get("sync_counter", -1)) != i:
			consistency_pass = false
			break
	check(consistency_pass, "20-Step interleaved save-modify-load cycle maintained 100% data fidelity")

	# Clean up after test
	_clean_files(path)
	print("=== SAVE SYSTEM AUDIT FINISHED: %d tests, %d failures ===" % [tests_run, failures])
	quit(1 if failures else 0)
