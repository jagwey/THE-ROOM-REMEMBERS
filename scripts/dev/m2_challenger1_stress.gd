extends SceneTree
## Adversarial Challenger 1 Stress Suite for Milestone 2 (R2: Memory Seal Points & Curse Mechanics)
##
## Challenge 1: Rapid button spamming with negative and 0.0 curse (zero save leaks, no checkpoint corruption)
## Challenge 2: Danger condition transitions (enemies, keeper modes, dialogue, active vs cleared danger)
## Challenge 3: Precision curse absorption across edge values (0.0001% to 99.9999%), exact 0.0 residue, disk persistence
## Challenge 4: Complete eradication of fast travel from seals (no methods, no variables, no modals, UiGate unaffected)
## Challenge 5: Rebirth and save reload anchoring at newly committed seal across multiple rooms

const SEAL_SCRIPT := "memory_seal_point.gd"
const PRIMARY_ROOMS: Array[StringName] = [
	&"awakening", &"decay_garden", &"library_hall", &"experiment_cells",
	&"mirrors_reverse", &"core_threshold", &"awakening_crypt", &"decay_catacombs"
]

var total_checks := 0
var failures := 0

var sm: Node
var gs: Node
var dm: Node
var rm: Node
var curse: Node
var death: Node
var main: Node
var player: CharacterBody2D


func check(ok: bool, challenge: String, label: String, detail: Variant = "") -> void:
	total_checks += 1
	var status := "PASS" if ok else "FAIL"
	if str(detail) != "":
		print("[%s] [%s] %s [%s]" % [status, challenge, label, str(detail)])
	else:
		print("[%s] [%s] %s" % [status, challenge, label])
	if not ok:
		failures += 1


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _serial(path: String) -> int:
	var d: Variant = sm._read_save(path)
	return int((d as Dictionary).get("save_serial", -1)) if d is Dictionary else -1


func _find_seal(room_id: StringName) -> Node2D:
	if not rm._rooms.has(room_id):
		return null
	var rt: Node = rm._rooms[room_id].root
	for n in rt.find_children("*", "Area2D", true, false):
		var sc: Script = n.get_script()
		if sc != null and String(sc.resource_path).ends_with(SEAL_SCRIPT):
			return n as Node2D
	return null


func _clean_banners() -> void:
	for b in get_nodes_in_group("seal_banner"):
		b.queue_free()


func _await_death(max_ms: int = 25000) -> bool:
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < max_ms:
		await process_frame
	await create_timer(0.08).timeout
	if curse.possessing:
		while curse.possessing and (Time.get_ticks_msec() - t0) < max_ms:
			await process_frame
		await create_timer(0.08).timeout
	if dm and dm.has_method("clear"):
		dm.clear()
	return not death.is_dying


func _run() -> void:
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	curse = root.get_node("CurseManager")
	death = root.get_node("DeathManager")

	if not ("qa/" in String(sm.SAVE_PATH)):
		print("CHALLENGER_M2 SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()

	change_scene_to_file("res://scenes/main/main.tscn")
	await _wait(0.3)
	main = current_scene
	player = main.get_node("Player")
	dm.clear()

	var save_path := String(sm.SAVE_PATH)

	# =========================================================================
	# CHALLENGE 1: RAPID SPAMMING UNDER 0.0 AND NEGATIVE CURSE
	# =========================================================================
	print("\n==================================================")
	print("CHALLENGE 1: RAPID SPAMMING UNDER 0.0 AND NEGATIVE CURSE")
	print("==================================================")
	rm.enter_room(&"awakening", &"default")
	await _wait(0.15)
	dm.clear()

	var a_seal := _find_seal(&"awakening")
	check(a_seal != null, "CHALLENGE_1", "Awakening seal found")

	# Test 1.1: 50 rapid calls with curse == 0.0
	curse.curse = 0.0
	dm.clear()
	var s_baseline := _serial(save_path)
	var cp_baseline: Vector2 = gs.get_checkpoint()
	var was_known: bool = gs.discovered_seals.has(&"awakening")

	for i in range(50):
		a_seal.on_interact(player)

	check(_serial(save_path) == s_baseline, "CHALLENGE_1", "50 rapid calls with curse=0.0 do NOT write save file", [s_baseline, _serial(save_path)])
	check(gs.get_checkpoint() == cp_baseline, "CHALLENGE_1", "50 rapid calls with curse=0.0 do NOT alter checkpoint", gs.get_checkpoint())
	check(get_nodes_in_group("seal_banner").is_empty(), "CHALLENGE_1", "50 rapid calls with curse=0.0 spawn zero banners")
	check(a_seal._glow == 0.0, "CHALLENGE_1", "50 rapid calls with curse=0.0 do NOT trigger seal glow", a_seal._glow)
	check(curse.curse == 0.0, "CHALLENGE_1", "Curse remains exactly 0.0 after spam", curse.curse)
	dm.clear()

	# Test 1.2: 50 rapid calls with negative curse values (-0.0001, -1.0, -50.0)
	var neg_curses := [-0.0001, -1.0, -25.0, -99.9]
	for neg in neg_curses:
		curse.curse = neg
		dm.clear()
		check(a_seal.get_interact_label() == "Sessiz Mühür", "CHALLENGE_1", "Negative curse (%s) returns 'Sessiz Mühür'" % neg, a_seal.get_interact_label())
		for i in range(10):
			a_seal.on_interact(player)
		check(_serial(save_path) == s_baseline, "CHALLENGE_1", "Negative curse (%s) does NOT commit save" % neg)
		check(gs.get_checkpoint() == cp_baseline, "CHALLENGE_1", "Negative curse (%s) does NOT alter checkpoint" % neg)
		check(get_nodes_in_group("seal_banner").is_empty(), "CHALLENGE_1", "Negative curse (%s) spawns zero banners" % neg)
		dm.clear()

	# Test 1.3: Frame-by-frame spam over 20 frames with alternating dialogue advance
	curse.curse = 0.0
	for f in range(20):
		a_seal.on_interact(player)
		if dm.is_open:
			dm.advance()
		await process_frame

	check(_serial(save_path) == s_baseline, "CHALLENGE_1", "Frame-by-frame spam over 20 frames preserves save isolation")
	check(gs.get_checkpoint() == cp_baseline, "CHALLENGE_1", "Frame-by-frame spam preserves checkpoint isolation")
	dm.clear()

	# =========================================================================
	# CHALLENGE 2: DANGER STATE STRESS & TRANSITIONS
	# =========================================================================
	print("\n==================================================")
	print("CHALLENGE 2: DANGER STATE STRESS & DYNAMIC TRANSITIONS")
	print("==================================================")
	dm.clear()
	curse.curse = 55.0

	# Test 2.1: DeathManager.is_dying blocks seal interaction
	death.is_dying = true
	var s_danger_start := _serial(save_path)
	a_seal.on_interact(player)
	check(_serial(save_path) == s_danger_start, "CHALLENGE_2", "is_dying=true blocks save commit")
	check(curse.curse == 55.0, "CHALLENGE_2", "is_dying=true leaves curse untouched", curse.curse)
	death.is_dying = false
	dm.clear()

	# Test 2.2: Enemy distance boundary test
	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	current_scene.add_child(enemy)

	# Sub-case: enemy at exact boundaries: 0px, 60px, 119.9px, 120.0px, 120.1px, 200px
	var distances := [
		{"dist": 0.0, "expect_danger": true},
		{"dist": 60.0, "expect_danger": true},
		{"dist": 119.9, "expect_danger": true},
		{"dist": 120.0, "expect_danger": true},
		{"dist": 120.1, "expect_danger": false},
		{"dist": 200.0, "expect_danger": false},
	]
	for d in distances:
		enemy.global_position = player.global_position + Vector2(float(d.dist), 0)
		var is_d: bool = a_seal._is_danger()
		check(is_d == bool(d.expect_danger), "CHALLENGE_2", "Enemy at %s px danger is %s" % [d.dist, d.expect_danger], is_d)

	# Sub-case: enemy invisible in tree should NOT trigger danger even if close (50px)
	enemy.global_position = player.global_position + Vector2(50.0, 0)
	enemy.visible = false
	check(not a_seal._is_danger(), "CHALLENGE_2", "Invisible enemy within 50px does NOT trigger danger")
	enemy.visible = true
	check(a_seal._is_danger(), "CHALLENGE_2", "Visible enemy within 50px DOES trigger danger")
	enemy.queue_free()
	await _wait(0.05)

	# Test 2.3: Keeper mode and distance boundary tests
	var k_script := GDScript.new()
	k_script.source_code = "extends Node2D\nvar mode := 5\n"
	k_script.reload()
	var keeper_node := Node2D.new()
	keeper_node.set_script(k_script)
	keeper_node.add_to_group("keeper")
	current_scene.add_child(keeper_node)

	# Sub-case: Keeper modes at 200px
	keeper_node.global_position = player.global_position + Vector2(200.0, 0)
	var modes_to_test := [
		{"mode": 5, "danger": true, "name": "COMBAT"},
		{"mode": 2, "danger": true, "name": "INTERVENE"},
		{"mode": 0, "danger": false, "name": "OBSERVE"},
		{"mode": 1, "danger": false, "name": "PATROL"},
		{"mode": 3, "danger": false, "name": "WARN"},
		{"mode": 4, "danger": false, "name": "SEARCH"},
	]
	for m in modes_to_test:
		keeper_node.set("mode", m.mode)
		var is_d: bool = a_seal._is_danger()
		check(is_d == bool(m.danger), "CHALLENGE_2", "Keeper in %s mode (%d) danger is %s" % [m.name, m.mode, m.danger], is_d)

	# Sub-case: Keeper distance boundary under COMBAT (mode 5)
	keeper_node.set("mode", 5)
	var k_dists := [
		{"dist": 319.9, "expect_danger": true},
		{"dist": 320.0, "expect_danger": true},
		{"dist": 320.1, "expect_danger": false},
		{"dist": 400.0, "expect_danger": false},
	]
	for kd in k_dists:
		keeper_node.global_position = player.global_position + Vector2(float(kd.dist), 0)
		var is_d: bool = a_seal._is_danger()
		check(is_d == bool(kd.expect_danger), "CHALLENGE_2", "Combat keeper at %s px danger is %s" % [kd.dist, kd.expect_danger], is_d)

	# Sub-case: Invisible keeper in COMBAT should NOT trigger danger
	keeper_node.global_position = player.global_position + Vector2(100.0, 0)
	keeper_node.visible = false
	check(not a_seal._is_danger(), "CHALLENGE_2", "Invisible combat keeper does NOT trigger danger")
	keeper_node.visible = true
	check(a_seal._is_danger(), "CHALLENGE_2", "Visible combat keeper DOES trigger danger")

	# Test 2.4: Dynamic Transition from Danger ON -> Danger OFF
	curse.curse = 60.0
	dm.clear()
	var s_trans_before := _serial(save_path)

	# Danger is ON: interact should fail
	a_seal.on_interact(player)
	await _wait(0.05)
	check(_serial(save_path) == s_trans_before, "CHALLENGE_2", "Interaction blocked while keeper danger active")
	check(curse.curse == 60.0, "CHALLENGE_2", "Curse preserved while keeper danger active", curse.curse)
	check(dm.is_open and dm._full_line == "Tehlike varken mühür tepki vermiyor.", "CHALLENGE_2", "Danger warning dialogue shown")
	dm.clear()

	# Transition danger to OFF: remove keeper
	keeper_node.queue_free()
	await _wait(0.05)
	check(not a_seal._is_danger(), "CHALLENGE_2", "Danger successfully transitioned to inactive")

	# Danger is OFF: interact should now immediately succeed!
	a_seal.on_interact(player)
	var glow_on_transition: float = a_seal._glow
	await _wait(0.1)
	check(curse.curse == 0.0, "CHALLENGE_2", "Curse cleared to 0.0 after danger resolved", curse.curse)
	check(_serial(save_path) > s_trans_before, "CHALLENGE_2", "Save successfully committed after danger resolved", _serial(save_path))
	check(glow_on_transition == 1.0, "CHALLENGE_2", "Seal glow triggered upon successful transition", glow_on_transition)
	_clean_banners()
	dm.clear()

	# =========================================================================
	# CHALLENGE 3: EDGE VALUES OF CURSE ABSORPTION & FLOAT PRECISION
	# =========================================================================
	print("\n==================================================")
	print("CHALLENGE 3: EDGE VALUES OF CURSE ABSORPTION & FLOAT PRECISION")
	print("==================================================")
	# Test exact float edge values to verify zero residue, band reset, and save fidelity
	var edge_values := [
		0.0001,
		0.01,
		0.1,
		1.0,
		25.0,
		49.9999,
		50.0,
		70.0,
		89.9999,
		90.0,
		99.0,
		99.99,
		99.9999
	]

	for val in edge_values:
		dm.clear()
		_clean_banners()
		curse.curse = float(val)

		# 1. Verify get_interact_label formatting
		var expected_pct := int(round(float(val)))
		var expected_label := "Laneti Mühürle (%d%%)" % expected_pct
		var actual_label: String = a_seal.get_interact_label()
		check(actual_label == expected_label, "CHALLENGE_3", "Label for edge value %s is '%s'" % [val, expected_label], actual_label)

		# 2. Interact and absorb
		var s_edge_pre := _serial(save_path)
		a_seal.on_interact(player)
		await _wait(0.08)

		# 3. Assert zero residue
		check(curse.curse == 0.0, "CHALLENGE_3", "Curse absorbed with exact 0.0 residue for %s" % val, curse.curse)
		check(curse.band == curse.Band.CONTROL, "CHALLENGE_3", "Curse band reset to CONTROL (0) for %s" % val, curse.band)

		# 4. Assert save increment & file persistence
		var s_edge_post := _serial(save_path)
		check(s_edge_post > s_edge_pre, "CHALLENGE_3", "Save serial incremented for %s" % val, [s_edge_pre, s_edge_post])
		var disk_data: Variant = sm._read_save(save_path)
		if disk_data is Dictionary:
			var disk_curse: float = float((disk_data as Dictionary).get("curse", -999.0))
			check(disk_curse == 0.0, "CHALLENGE_3", "Committed save has exact 0.0 curse on disk for input %s" % val, disk_curse)

		# 5. Assert banner displays expected percentage
		var banners := get_nodes_in_group("seal_banner")
		check(banners.size() >= 1, "CHALLENGE_3", "SealBanner displayed for %s" % val)
		if banners.size() > 0:
			var labels := banners[0].find_children("*", "Label", true, false)
			if labels.size() > 1:
				var expected_sub := "Lanet etkisi temizlendi (%d%%) ve mühre kazındı." % expected_pct
				check((labels[1] as Label).text == expected_sub, "CHALLENGE_3", "Banner subtitle matches expected percentage %d%% for %s" % [expected_pct, val], (labels[1] as Label).text)
		_clean_banners()
		dm.clear()

	# =========================================================================
	# CHALLENGE 4: COMPLETE TRAVEL MODAL & METHOD ERADICATION
	# =========================================================================
	print("\n==================================================")
	print("CHALLENGE 4: COMPLETE TRAVEL MODAL & METHOD ERADICATION")
	print("==================================================")
	for rid in PRIMARY_ROOMS:
		rm.enter_room(rid, &"default")
		await _wait(0.08)
		dm.clear()
		var seal := _find_seal(rid)
		check(seal != null, "CHALLENGE_4", "Seal exists in %s" % rid)
		if seal == null:
			continue

		# Verify all fast travel methods and properties are completely absent
		check(not seal.has_method("_open_travel"), "CHALLENGE_4", "Seal in %s has no _open_travel()" % rid)
		check(not seal.has_method("_close_travel"), "CHALLENGE_4", "Seal in %s has no _close_travel()" % rid)
		check(not seal.has_method("_travel_to"), "CHALLENGE_4", "Seal in %s has no _travel_to()" % rid)
		check(not seal.has_method("_other_seals"), "CHALLENGE_4", "Seal in %s has no _other_seals()" % rid)
		check(seal.get("_travel_layer") == null, "CHALLENGE_4", "Seal in %s has no _travel_layer" % rid)
		check(seal.get("TRAVEL_LAYER") == null, "CHALLENGE_4", "Seal in %s has no TRAVEL_LAYER" % rid)
		check(seal.get("TRAVEL_GROUP") == null, "CHALLENGE_4", "Seal in %s has no TRAVEL_GROUP" % rid)

		# Interact with seal while cursed: ensure no travel modal or travel layer is created
		curse.curse = 35.0
		seal.on_interact(player)
		await _wait(0.08)

		check(get_nodes_in_group("seal_travel_modal").is_empty(), "CHALLENGE_4", "No seal_travel_modal in %s" % rid)
		check(root.get_node("UiGate").current_layer() != 3, "CHALLENGE_4", "UiGate layer is NOT Layer.SEAL (3) in %s" % rid, root.get_node("UiGate").current_layer())
		_clean_banners()
		dm.clear()

	# =========================================================================
	# CHALLENGE 5: REBIRTH & SAVE RELOAD SPAWN AT NEWLY COMMITTED SEAL
	# =========================================================================
	print("\n==================================================")
	print("CHALLENGE 5: REBIRTH & SAVE RELOAD SPAWN AT NEWLY COMMITTED SEAL")
	print("==================================================")
	# Sub-test 5.1: Seal in decay_garden, reload committed save, verify room, pos, and curse=0.0
	sm.delete_all_save_files()
	rm.enter_room(&"decay_garden", &"default")
	await _wait(0.15)
	dm.clear()
	var d_seal := _find_seal(&"decay_garden")
	check(d_seal != null, "CHALLENGE_5", "Decay garden seal found")

	curse.curse = 65.0
	d_seal.on_interact(player)
	await _wait(0.15)
	_clean_banners()
	dm.clear()

	# Check GameState and committed save file
	check(curse.curse == 0.0, "CHALLENGE_5", "Curse cleared at decay_garden seal")
	check(gs.get_checkpoint().distance_to(d_seal.global_position) < 1.0, "CHALLENGE_5", "GameState checkpoint set to decay_garden seal pos")

	var d_saved: Variant = sm._read_save(save_path)
	check(d_saved is Dictionary, "CHALLENGE_5", "Committed save file exists on disk")
	if d_saved is Dictionary:
		var d_life: Dictionary = (d_saved as Dictionary).get("character_current_life_knowledge", {})
		check(str(d_life.get("checkpoint_room", "")) == "decay_garden", "CHALLENGE_5", "Save checkpoint_room is decay_garden")
		check(str(d_life.get("room", "")) == "decay_garden", "CHALLENGE_5", "Save room is decay_garden")
		check(float((d_saved as Dictionary).get("curse", -1.0)) == 0.0, "CHALLENGE_5", "Save curse is 0.0")

	# Sub-test 5.2: Ordinary death in decay_garden: stays in decay_garden, respawns at room checkpoint
	death.request_death(&"challenger_test_decay")
	var death_ok := await _await_death()
	check(death_ok, "CHALLENGE_5", "Death sequence completed")
	check(rm.get_active_room_id() == &"decay_garden", "CHALLENGE_5", "Rebirth stayed in decay_garden (did not bounce to awakening)", rm.get_active_room_id())
	check(curse.curse >= 25.0, "CHALLENGE_5", "Death added penalty curse upon rebirth", curse.curse)

	# Sub-test 5.3: Possession transport at 100% curse transports Noroi to committed seal
	curse._reload_committed()
	await _wait(0.15)
	check(rm.get_active_room_id() == &"decay_garden", "CHALLENGE_5", "Possession reloaded to decay_garden")
	var seal_pos_d := d_seal.global_position
	check(player.global_position.distance_to(seal_pos_d) < 6.0, "CHALLENGE_5", "Possession transported player to committed decay_garden seal", player.global_position)

	# Sub-test 5.4: Move to library_hall, seal with new curse, verify save updated to library_hall seal
	rm.enter_room(&"library_hall", &"default")
	await _wait(0.15)
	dm.clear()
	var l_seal := _find_seal(&"library_hall")
	check(l_seal != null, "CHALLENGE_5", "Library hall seal found")

	curse.curse = 80.0
	l_seal.on_interact(player)
	await _wait(0.15)
	_clean_banners()
	dm.clear()

	check(curse.curse == 0.0, "CHALLENGE_5", "Curse cleared at library_hall seal")
	check(gs.get_checkpoint().distance_to(l_seal.global_position) < 1.0, "CHALLENGE_5", "Checkpoint updated to library_hall seal")

	# Sub-test 5.5: Ordinary death in library_hall stays in library_hall
	death.request_death(&"challenger_test_library")
	var death2_ok := await _await_death()
	check(death2_ok, "CHALLENGE_5", "Second death sequence completed")
	check(rm.get_active_room_id() == &"library_hall", "CHALLENGE_5", "Rebirth stayed in library_hall", rm.get_active_room_id())
	check(curse.curse >= 25.0, "CHALLENGE_5", "Death added penalty curse upon rebirth", curse.curse)

	# Sub-test 5.6: Possession transport transports Noroi to newly committed library_hall seal
	curse._reload_committed()
	await _wait(0.15)
	check(rm.get_active_room_id() == &"library_hall", "CHALLENGE_5", "Possession reloaded to library_hall")
	var seal_pos_l := l_seal.global_position
	check(player.global_position.distance_to(seal_pos_l) < 3.0, "CHALLENGE_5", "Possession transported player to newly committed library_hall seal", player.global_position)

	# Sub-test 5.7: Verify committed save on disk is anchored to library_hall seal with 0.0 curse
	var loaded_save: Variant = sm._read_save(save_path)
	if loaded_save is Dictionary:
		var l_life: Dictionary = (loaded_save as Dictionary).get("character_current_life_knowledge", {})
		check(str(l_life.get("checkpoint_room", "")) == "library_hall", "CHALLENGE_5", "Latest committed save anchored to library_hall")
		var cp_dict: Dictionary = l_life.get("checkpoint", {})
		var saved_cp := Vector2(float(cp_dict.get("x", 0)), float(cp_dict.get("y", 0)))
		check(saved_cp.distance_to(seal_pos_l) < 1.0, "CHALLENGE_5", "Committed save persists library_hall seal coords", saved_cp)
		check(float((loaded_save as Dictionary).get("curse", -1.0)) == 0.0, "CHALLENGE_5", "Latest committed save persists exactly 0.0 curse")

	sm.delete_all_save_files()
	print("\n==================================================")
	print("CHALLENGER M2 STRESS SUMMARY: Total checks = ", total_checks, " | Failures = ", failures)
	print("==================================================")
	quit(1 if failures > 0 else 0)
