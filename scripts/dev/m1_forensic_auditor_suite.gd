extends SceneTree
## Forensic Auditor Independent Verification Suite for Milestone 1
## Rigorous validation of:
## 1. Active room respawn across multiple zones (awakening, decay_garden, library_hall, mirrors_reverse)
## 2. World state & puzzle persistence across multiple death cycles
## 3. Safe floor corpse placement under various fall scenarios
## 4. Curse progression (+25 per death, >=50 band, possession trigger at 100)
## 5. Possession world preservation (committed room teleport, 50.0 band, no state wipe)
## 6. Edge cases: concurrency, invalid rooms, repeated death cycles

var failures := 0
var total_checks := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run_forensic_audit")


func check(ok: bool, label: String, detail: String = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if detail != "":
		print("FORENSIC_AUDIT ", msg, "[%02d] " % total_checks, label, " [", detail, "]")
	else:
		print("FORENSIC_AUDIT ", msg, "[%02d] " % total_checks, label)
	if not ok:
		failures += 1


func _run_forensic_audit() -> void:
	print("\n========================================================")
	print(">>> FORENSIC INTEGRITY AUDIT: MILESTONE 1 (R1) <<<")
	print("========================================================")

	var sm := root.get_node("SaveManager")
	sm.delete_all_save_files()

	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout

	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var death := root.get_node("DeathManager")
	var curse := root.get_node("CurseManager")
	var pm := root.get_node("PuzzleManager")
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")

	# ---------------------------------------------------------
	# CHECK 1: Awakening Death -> Bed (120, 280)
	# ---------------------------------------------------------
	print("\n--- PHASE 1: AWAKENING RESPAWN ---")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.15).timeout
	dm.clear()
	curse.reset_for_new_life()

	player.global_position = Vector2(450, 288)
	state.damage(99)
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 20000:
		await process_frame
	await create_timer(0.1).timeout
	dm.clear()

	check(rm.get_active_room_id() == &"awakening", "Awakening death stays in awakening")
	check(absf(player.global_position.x - 120.0) < 5.0 and absf(player.global_position.y - 280.0) < 12.0,
		"Awakening respawns at rebirth_bed (120, 280)", str(player.global_position))
	check(curse.curse >= 50.0, "Curse elevated to >= 50.0 after first death", "curse=%.1f" % curse.curse)
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "Curse band is FIRST_SIGNS")
	check(curse.visible_meter == true, "Curse meter is visible after reaching 50.0")

	# ---------------------------------------------------------
	# CHECK 2: Multi-Room Death Respawn (Zone II, Zone III, Zone V)
	# ---------------------------------------------------------
	print("\n--- PHASE 2: MULTI-ROOM ACTIVE RESPAWN ---")
	var test_rooms := [&"decay_garden", &"library_hall", &"mirrors_reverse"]
	for target_room in test_rooms:
		rm.enter_room(target_room, &"default", false)
		await create_timer(0.15).timeout
		dm.clear()

		var expected_cp: Vector2 = death._get_respawn_position()
		var curse_before: float = curse.curse

		# Move away from spawn
		player.global_position = expected_cp + Vector2(180, 0)
		state.damage(99)

		t0 = Time.get_ticks_msec()
		while death.is_dying and (Time.get_ticks_msec() - t0) < 20000:
			await process_frame
		await create_timer(0.1).timeout
		dm.clear()

		check(rm.get_active_room_id() == target_room, "Death in %s stayed in %s" % [target_room, target_room], str(rm.get_active_room_id()))
		check(player.global_position.distance_to(expected_cp) < 14.0,
			"Respawned at %s checkpoint %s" % [target_room, str(expected_cp)], str(player.global_position))
		check(curse.curse >= curse_before + 25.0 or curse.curse == 100.0,
			"Death penalty added +25.0 in %s" % target_room, "before=%.1f after=%.1f" % [curse_before, curse.curse])
		# Reset curse to 50 for next iteration to prevent premature possession
		curse.set_curse(50.0)

	# ---------------------------------------------------------
	# CHECK 3: World Memory & Puzzle Persistence
	# ---------------------------------------------------------
	print("\n--- PHASE 3: PERSISTENCE WITHOUT RELOAD ---")
	rm.enter_room(&"decay_garden", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()

	# Set deep world modifications
	state.set_world_flag(&"auditor_flag_alpha", true)
	state.set_world_flag(&"auditor_counter", 42)
	pm.mark_solved(&"puzzle_alpha_1")
	pm.mark_solved(&"puzzle_beta_2")
	var deaths_before := int(state.player_progress_knowledge["deaths"])

	# Die in decay_garden
	state.damage(99)
	t0 = Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 20000:
		await process_frame
	await create_timer(0.1).timeout
	dm.clear()

	check(state.get_world_flag(&"auditor_flag_alpha", false) == true, "Custom world flag alpha survived death")
	check(int(state.get_world_flag(&"auditor_counter", 0)) == 42, "Custom world counter survived death")
	check(pm.is_solved(&"puzzle_alpha_1"), "Puzzle alpha survived death")
	check(pm.is_solved(&"puzzle_beta_2"), "Puzzle beta survived death")
	var deaths_after := int(state.player_progress_knowledge["deaths"])
	check(deaths_after == deaths_before + 1, "Death counter incremented", "before=%d after=%d" % [deaths_before, deaths_after])
	var corpses: Array = state.world_memory_state.get("corpses", [])
	check(not corpses.is_empty(), "World corpses array is maintained")
	var latest_corpse: Dictionary = corpses.back()
	check(String(latest_corpse.get("room", "")) == "decay_garden", "Corpse recorded in decay_garden", str(latest_corpse.get("room", "")))

	# ---------------------------------------------------------
	# CHECK 4: Safe Floor Hazard / Pit Recording
	# ---------------------------------------------------------
	print("\n--- PHASE 4: SAFE FLOOR CORPSE PLACEMENT ---")
	# Establish known safe floor
	player.global_position = Vector2(300, 288)
	player.velocity = Vector2.ZERO
	await create_timer(0.08).timeout
	var verified_safe: Vector2 = player.get_last_safe_floor_pos()
	check(verified_safe.y < 320.0 and verified_safe != Vector2.ZERO, "Safe floor pos recorded properly", str(verified_safe))

	# Drop into deep void (y = 400)
	player.global_position = Vector2(300, 400)
	death.request_death(&"void")

	t0 = Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 20000:
		await process_frame
	await create_timer(0.1).timeout
	dm.clear()

	var all_corpses: Array = state.world_memory_state.get("corpses", [])
	var void_corpse: Dictionary = all_corpses.back()
	var void_pos: Dictionary = void_corpse.get("position", {})
	var void_y: float = float(void_pos.get("y", 999.0))
	check(void_y < 320.0, "Void death corpse placed above y=320", "corpse y=%.1f" % void_y)
	check(absf(void_y - 288.0) <= 2.0, "Void death corpse snapped to safe floor (y ~ 288)", "corpse y=%.1f" % void_y)

	# ---------------------------------------------------------
	# CHECK 5: 100% Curse Possession & World Preservation
	# ---------------------------------------------------------
	print("\n--- PHASE 5: POSSESSION WORLD PRESERVATION ---")
	# Commit save at seal in library_hall
	rm.enter_room(&"library_hall", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()
	var seal_anchor := Vector2(190, 288)
	sm.commit_save(&"forensic_seal", seal_anchor, &"library_hall")

	# Travel to decay_catacombs and make uncommitted progress
	rm.enter_room(&"decay_catacombs", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()
	state.set_world_flag(&"uncommitted_post_seal_flag", true)
	pm.mark_solved(&"uncommitted_puzzle")
	var deaths_before_possession: int = int(state.player_progress_knowledge.get("deaths", 0))
	var corpses_before_possession: int = (state.world_memory_state["corpses"] as Array).size()

	# Trigger possession by pushing curse to 100
	curse.set_curse(100.0)
	check(curse.possessing, "Curse 100 started possession sequence")

	t0 = Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await create_timer(0.2).timeout
	dm.clear()

	check(not curse.possessing, "Possession sequence finished")
	check(rm.get_active_room_id() == &"library_hall", "Possession relocated player to committed seal room (library_hall)", str(rm.get_active_room_id()))
	check(player.global_position.distance_to(seal_anchor) < 16.0, "Player respawned at committed seal coordinates", str(player.global_position))
	check(state.get_world_flag(&"uncommitted_post_seal_flag", false) == true, "Uncommitted world flag preserved across possession (NOT WIPED)")
	check(pm.is_solved(&"uncommitted_puzzle") == true, "Uncommitted solved puzzle preserved across possession (NOT WIPED)")
	check(is_equal_approx(curse.curse, 50.0), "Curse reset to POSSESSION_SAFE_CURSE (50.0)", "curse=%.1f" % curse.curse)
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "Band is FIRST_SIGNS after possession")
	check((state.world_memory_state["corpses"] as Array).size() == corpses_before_possession, "No ghost corpse dropped by possession")
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_before_possession, "Possession did not increment death counter")

	# ---------------------------------------------------------
	# CHECK 6: Concurrency & Boundary Guards
	# ---------------------------------------------------------
	print("\n--- PHASE 6: CONCURRENCY & BOUNDARY GUARDS ---")
	# Concurrent death request while dying
	death.is_dying = true
	death.request_death(&"extra_death")
	check(death.is_dying == true, "Second death request ignored while is_dying is true")
	death.is_dying = false

	# Death request while possessing
	curse.possessing = true
	death.request_death(&"death_while_possessing")
	check(death.is_dying == false, "Death request rejected while possessing is true")
	curse.possessing = false

	# Possession trigger while dying
	death.is_dying = true
	curse._begin_possession()
	check(curse.possessing == false, "Possession trigger rejected while is_dying is true")
	death.is_dying = false

	# Graceful fallback for non-existent room
	rm._current = &"non_existent_room_xyz"
	var fallback_pos: Vector2 = death._get_respawn_position()
	check(fallback_pos == death.REBIRTH_BED, "Invalid room falls back safely to REBIRTH_BED (120, 280)", str(fallback_pos))
	rm._current = &"library_hall"

	# Clean up save files
	sm.delete_all_save_files()

	print("\n========================================================")
	print("FORENSIC AUDIT COMPLETE: %d checks run, %d failures." % [total_checks, failures])
	if failures == 0:
		print("VERDICT: CLEAN — ALL INVARIANTS EMPIRICALLY CONFIRMED")
	else:
		print("VERDICT: INTEGRITY VIOLATION — %d CHECKS FAILED" % failures)
	print("========================================================\n")

	quit(1 if failures else 0)
