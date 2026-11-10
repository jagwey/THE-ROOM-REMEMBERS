extends SceneTree
## Milestone 1 Verification Audit: Death, Persistent World & Rebirth Architecture
## Tests:
## 1. Awakening death respawns at rebirth_bed (120, 280)
## 2. In-room death in decay_garden respawns in decay_garden at (130, 288) without room change
## 3. World state, puzzles, and corpses persist seamlessly across death (no scene reload/load_committed)
## 4. Hazard death places corpse on safe floor pos (y < 320)
## 5. Death adds +25 curse and ensures >= 50.0 band
## 6. 100% curse possession teleports to committed seal, preserves world state, and sets curse to 50.0

var failures := 0
var total_checks := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: String = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if detail != "":
		print("M1_AUDIT ", msg, label, " [", detail, "]")
	else:
		print("M1_AUDIT ", msg, label)
	if not ok:
		failures += 1


func _run() -> void:
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
	var gate := root.get_node("UiGate")
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")

	print("\n==================================================")
	print("TEST 1: AWAKENING DEATH RESPAWN AT REBIRTH BED")
	print("==================================================")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.15).timeout
	dm.clear()
	curse.reset_for_new_life()

	player.global_position = Vector2(500, 288)
	state.damage(99)
	check(death.is_dying, "Awakening: Death started")
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await create_timer(0.15).timeout
	dm.clear()

	check(not death.is_dying, "Awakening: Death completed")
	check(rm.get_active_room_id() == &"awakening", "Awakening: Room is awakening", str(rm.get_active_room_id()))
	check(absf(player.global_position.x - 120.0) < 6.0 and absf(player.global_position.y - 280.0) < 14.0, "Awakening: Respawned at rebirth_bed (120, 280)", str(player.global_position))
	check(curse.curse >= 50.0, "Awakening: Curse >= 50.0 after rebirth", str(curse.curse))
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "Awakening: Curse band is FIRST_SIGNS", str(curse.get_band()))

	print("\n==================================================")
	print("TEST 2: FAR ROOM DEATH RESPAWNS IN SAME ROOM")
	print("==================================================")
	# Enter decay_garden
	rm.enter_room(&"decay_garden", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()

	# Set world progress markers
	state.set_world_flag(&"m1_persistent_flag", true)
	pm.mark_solved(&"decay_vine_shortcut")
	player.global_position = Vector2(400, 288)
	var death_spot: Vector2 = player.global_position
	var curse_before: float = float(curse.curse)

	state.damage(99)
	check(death.is_dying, "Far Room: Death started in decay_garden")
	t0 = Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await create_timer(0.15).timeout
	dm.clear()

	check(not death.is_dying, "Far Room: Death completed")
	check(rm.get_active_room_id() == &"decay_garden", "Far Room: Stayed in decay_garden (DID NOT return to awakening)", str(rm.get_active_room_id()))
	check(absf(player.global_position.x - 130.0) < 6.0 and absf(player.global_position.y - 288.0) < 14.0, "Far Room: Respawned at decay_garden checkpoint (130, 288)", str(player.global_position))
	check(state.get_world_flag(&"m1_persistent_flag", false), "Far Room: World flag persisted across death")
	check(pm.is_solved(&"decay_vine_shortcut"), "Far Room: Solved puzzle persisted across death")
	check(curse.curse >= curse_before + 25.0, "Far Room: Curse increased by +25 on death", "%f -> %f" % [curse_before, curse.curse])

	# Check corpse left in decay_garden
	var corpses: Array = state.world_memory_state.get("corpses", [])
	check(not corpses.is_empty(), "Far Room: Corpse list not empty")
	var last_corpse: Dictionary = corpses.back()
	check(String(last_corpse.get("room", "")) == "decay_garden", "Far Room: Corpse recorded in decay_garden", str(last_corpse.get("room", "")))

	print("\n==================================================")
	print("TEST 3: HAZARD/PIT DEATH PLACES CORPSE ON SAFE FLOOR")
	print("==================================================")
	player.global_position = Vector2(250, 288)
	player.velocity = Vector2.ZERO
	await create_timer(0.06).timeout # update safe floor pos
	check(player.get_last_safe_floor_pos().y < 320.0, "Safe floor pos recorded (y < 320)", str(player.get_last_safe_floor_pos()))

	# Simulate falling into pit (y = 355)
	player.global_position = Vector2(250, 355)
	death.request_death(&"hazard")
	check(death.is_dying, "Hazard: Death started")
	t0 = Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await create_timer(0.15).timeout
	dm.clear()

	corpses = state.world_memory_state.get("corpses", [])
	var hazard_corpse: Dictionary = corpses.back()
	var pos_dict: Dictionary = hazard_corpse.get("position", {})
	var c_y: float = float(pos_dict.get("y", 999.0))
	check(c_y < 320.0, "Hazard: Corpse placed on safe floor pos (y < 320.0)", "corpse y=%.1f" % c_y)
	check(absf(c_y - 288.0) <= 2.0, "Hazard: Corpse y matches safe floor (~288.0)", "corpse y=%.1f" % c_y)

	print("\n==================================================")
	print("TEST 4: 100% CURSE POSSESSION PRESERVES WORLD PROGRESS")
	print("==================================================")
	# Commit save at State A in library_hall
	rm.enter_room(&"library_hall", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()
	var seal_pos := Vector2(190, 288)
	player.global_position = seal_pos
	sm.commit_save(&"m1_audit_seal", seal_pos, &"library_hall")

	# Move to decay_catacombs and make changes (State B)
	rm.enter_room(&"decay_catacombs", &"default", false)
	await create_timer(0.15).timeout
	dm.clear()
	state.set_world_flag(&"m1_post_commit_marker", true)
	pm.mark_solved(&"decay_catacomb_seal")
	var deaths_before: int = int(state.player_progress_knowledge.get("deaths", 0))
	var corpses_before: int = (state.world_memory_state["corpses"] as Array).size()

	# Trigger 100% curse possession
	curse.set_curse(100.0)
	check(curse.possessing, "Possession: Possession started on 100% curse")

	t0 = Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await create_timer(0.2).timeout
	dm.clear()

	check(not curse.possessing, "Possession: Completed")
	check(rm.get_active_room_id() == &"library_hall", "Possession: Teleported to committed room library_hall", str(rm.get_active_room_id()))
	check(player.global_position.distance_to(seal_pos) < 16.0, "Possession: Spawned near committed checkpoint", str(player.global_position))
	check(state.get_world_flag(&"m1_post_commit_marker", false), "Possession: World flag preserved (NOT WIPED)")
	check(pm.is_solved(&"decay_catacomb_seal"), "Possession: Solved puzzle preserved (NOT WIPED)")
	check(is_equal_approx(curse.curse, 50.0), "Possession: Curse reset to POSSESSION_SAFE_CURSE (50.0)", str(curse.curse))
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "Possession: Band is FIRST_SIGNS")
	check((state.world_memory_state["corpses"] as Array).size() == corpses_before, "Possession: Zero corpses dropped by possession")
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_before, "Possession: Death counter not incremented")

	print("\n==================================================")
	print("M1 AUDIT SUMMARY")
	print("==================================================")
	print("Total checks: ", total_checks)
	print("Total failures: ", failures)
	sm.delete_all_save_files()
	if failures == 0:
		print("VERDICT: ALL M1 CHECKS PASSED PERFECTLY (0 FAILURES)")
	else:
		print("VERDICT: M1 AUDIT FAILED (%d FAILURES)" % failures)

	quit(1 if failures else 0)
