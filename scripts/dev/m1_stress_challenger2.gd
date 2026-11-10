extends SceneTree
## Empirical Stress Test Suite for Milestone 1 (Challenger 2)
## Tests the 4 required Milestone 1 invariants:
## 1. Room change immediately after death trigger (death interruption resilience).
## 2. Corpse persistence across room transitions after in-room death.
## 3. Possession reload retaining puzzle solve flags in PuzzleManager.
## 4. Ensure awakening bed (120, 280) is ONLY used when dying in awakening.

var failures := 0
var total_checks := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, suite: String, label: String, detail: String = "") -> void:
	total_checks += 1
	var status := "PASS" if ok else "FAIL"
	if detail != "":
		print("[%s] %s: %s [%s]" % [status, suite, label, detail])
	else:
		print("[%s] %s: %s" % [status, suite, label])
	if not ok:
		failures += 1


func _wait_death(death: Node, max_ms: int = 25000) -> bool:
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < max_ms:
		await process_frame
	await create_timer(0.12).timeout
	return not death.is_dying


func _wait_possession(curse: Node, max_ms: int = 25000) -> bool:
	var t0 := Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < max_ms:
		await process_frame
	await create_timer(0.12).timeout
	return not curse.possessing


func _run() -> void:
	print("====================================================================")
	print("CHALLENGER 2: EMPIRICAL STRESS TEST SUITE FOR MILESTONE 1")
	print("====================================================================")

	var save := root.get_node("SaveManager")
	save.delete_all_save_files()

	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout

	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var death := root.get_node("DeathManager")
	var curse := root.get_node("CurseManager")
	var cm := root.get_node("CorpseManager")
	var pm := root.get_node("PuzzleManager")
	var gate := root.get_node("UiGate")
	dm.clear()

	var player: CharacterBody2D = current_scene.get_node("Player")
	check(player != null, "BOOT", "Player instance found in Main scene")
	if player == null:
		quit(1)
		return

	# =========================================================================
	# SUITE 1: ROOM CHANGE IMMEDIATELY AFTER DEATH TRIGGER (INTERRUPTION RESILIENCE)
	# =========================================================================
	print("\n--------------------------------------------------------------------")
	print("SUITE 1: ROOM CHANGE IMMEDIATELY AFTER DEATH TRIGGER")
	print("--------------------------------------------------------------------")

	# Test 1.1: Immediate room change in the same frame as request_death
	curse.reset_for_new_life()
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	player.global_position = Vector2(500, 288)

	death.request_death(&"hazard")
	check(death.is_dying, "SUITE 1.1", "Death initiated (is_dying = true)")
	# Adversarial action: Immediately force enter_room to decay_vines
	rm.enter_room(&"decay_vines", &"default")
	check(rm.get_active_room_id() == &"decay_vines", "SUITE 1.1", "Adversarial enter_room switched active room to decay_vines")

	var finished := await _wait_death(death)
	check(finished, "SUITE 1.1", "Death sequence completed without hanging or freezing", "time_ok=%s" % str(finished))
	check(not death.is_dying, "SUITE 1.1", "DeathManager.is_dying is false after completion")
	check(death.phase == death.Phase.ALIVE, "SUITE 1.1", "DeathManager.phase is ALIVE")
	check(player.visible, "SUITE 1.1", "Player is visible after rebirth")
	check(not gate.blocks_movement(), "SUITE 1.1", "UiGate cutscene lock released after rebirth")
	check(curse.curse >= 50.0, "SUITE 1.1", "Curse is >= 50.0 after rebirth", "curse=%.1f" % curse.curse)

	# Test 1.2: Room change during SOUL_RELEASE phase
	curse.reset_for_new_life()
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.15).timeout
	dm.clear()
	player.global_position = Vector2(600, 288)

	death.request_death(&"hazard")
	# Wait until SOUL_RELEASE or SOUL_TRANSITION phase
	var p_timeout := Time.get_ticks_msec()
	while death.phase == death.Phase.DYING and (Time.get_ticks_msec() - p_timeout) < 5000:
		await process_frame

	check(death.phase != death.Phase.DYING, "SUITE 1.2", "Reached soul phase", "phase=%s" % death.phase_name())
	# Adversarial action: Force room change while soul is rising/transitioning
	rm.enter_room(&"decay_garden", &"default")
	finished = await _wait_death(death)
	check(finished, "SUITE 1.2", "Death completed after mid-soul room change")
	check(death._soul == null or not is_instance_valid(death._soul), "SUITE 1.2", "Soul node cleaned up (no leak)")
	check(not death.is_dying, "SUITE 1.2", "DeathManager.is_dying is false")
	check(rm.get_active_room_id() == &"decay_garden", "SUITE 1.2", "Active room is decay_garden")

	# Test 1.3: Door interact refused during death
	curse.reset_for_new_life()
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.15).timeout
	dm.clear()
	death.request_death(&"hazard")
	check(death.is_dying, "SUITE 1.3", "Death active")

	var doors: Array = get_nodes_in_group("room_door")
	var door_found: Node = null
	for d in doors:
		if d.is_inside_tree() and d.is_visible_in_tree():
			door_found = d
			break
	if door_found != null:
		door_found.on_interact(player)
		check(not door_found.is_transitioning(), "SUITE 1.3", "Door refused interaction during is_dying")
	else:
		check(true, "SUITE 1.3", "No active door in awakening (test passed)")

	await _wait_death(death)
	check(not death.is_dying, "SUITE 1.3", "Death finished cleanly")


	# =========================================================================
	# SUITE 2: CORPSE PERSISTENCE ACROSS ROOM TRANSITIONS AFTER IN-ROOM DEATH
	# =========================================================================
	print("\n--------------------------------------------------------------------")
	print("SUITE 2: CORPSE PERSISTENCE ACROSS ROOM TRANSITIONS")
	print("--------------------------------------------------------------------")

	# Clean world corpses for isolation
	curse.reset_for_new_life()
	state.world_memory_state["corpses"] = []
	state.world_memory_state["traces"] = []
	cm.rebuild_world_corpses()

	# 2.1: Die in decay_garden at (400, 288)
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	player.global_position = Vector2(400, 288)
	curse.reset_for_new_life()

	state.damage(99)
	check(death.is_dying, "SUITE 2.1", "Death initiated in decay_garden")
	finished = await _wait_death(death)
	check(finished, "SUITE 2.1", "Death in decay_garden completed")
	check(rm.get_active_room_id() == &"decay_garden", "SUITE 2.1", "Respawned in decay_garden")

	var garden_corpses: Array = []
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			garden_corpses.append(c)
	check(garden_corpses.size() == 1, "SUITE 2.1", "Exactly 1 active corpse rendered in decay_garden", "count=%d" % garden_corpses.size())
	if garden_corpses.size() >= 1:
		var cpos: Vector2 = garden_corpses[0].global_position
		check(absf(cpos.x - 400.0) < 15.0, "SUITE 2.1", "Corpse in decay_garden is near death spot x=400", "x=%.1f" % cpos.x)

	check(state.world_memory_state["corpses"].size() == 1, "SUITE 2.1", "1 corpse in world_memory_state", "size=%d" % state.world_memory_state["corpses"].size())

	# 2.2: Move to decay_weight. Corpse from garden must NOT be instantiated here.
	rm.enter_room(&"decay_weight", &"from_garden")
	await create_timer(0.2).timeout
	dm.clear()

	var weight_corpses: Array = []
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			weight_corpses.append(c)
	check(weight_corpses.size() == 0, "SUITE 2.2", "No corpses instantiated in decay_weight yet", "count=%d" % weight_corpses.size())
	check(state.world_memory_state["corpses"].size() == 1, "SUITE 2.2", "world_memory_state still retains decay_garden corpse")

	# 2.3: Die in decay_weight at (500, 288)
	curse.reset_for_new_life()
	player.global_position = Vector2(500, 288)
	state.damage(99)
	check(death.is_dying, "SUITE 2.3", "Death initiated in decay_weight")
	finished = await _wait_death(death)
	check(finished, "SUITE 2.3", "Death in decay_weight completed")
	check(rm.get_active_room_id() == &"decay_weight", "SUITE 2.3", "Respawned in decay_weight")
	check(state.world_memory_state["corpses"].size() == 2, "SUITE 2.3", "world_memory_state now contains 2 corpses", "size=%d" % state.world_memory_state["corpses"].size())

	weight_corpses.clear()
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			weight_corpses.append(c)
	check(weight_corpses.size() == 1, "SUITE 2.3", "decay_weight now renders its 1 corpse", "count=%d" % weight_corpses.size())

	# 2.4: Die in decay_vines at (600, 288)
	rm.enter_room(&"decay_vines", &"from_weight")
	await create_timer(0.2).timeout
	dm.clear()
	curse.reset_for_new_life()
	player.global_position = Vector2(600, 288)
	state.damage(99)
	check(death.is_dying, "SUITE 2.4", "Death initiated in decay_vines")
	finished = await _wait_death(death)
	check(finished, "SUITE 2.4", "Death in decay_vines completed")
	check(rm.get_active_room_id() == &"decay_vines", "SUITE 2.4", "Respawned in decay_vines")
	check(state.world_memory_state["corpses"].size() == 3, "SUITE 2.4", "world_memory_state contains 3 corpses across 3 rooms", "size=%d" % state.world_memory_state["corpses"].size())

	# 2.5: Round-trip stress test across rooms
	# Return to decay_garden
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	garden_corpses.clear()
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			garden_corpses.append(c)
	check(garden_corpses.size() == 1, "SUITE 2.5", "decay_garden re-instantiates exactly 1 corpse upon return", "count=%d" % garden_corpses.size())
	if garden_corpses.size() == 1:
		check(absf(garden_corpses[0].global_position.x - 400.0) < 15.0, "SUITE 2.5", "decay_garden corpse is at original pos x=400", "x=%.1f" % garden_corpses[0].global_position.x)

	# Return to decay_weight
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	weight_corpses.clear()
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			weight_corpses.append(c)
	check(weight_corpses.size() == 1, "SUITE 2.5", "decay_weight re-instantiates exactly 1 corpse upon return", "count=%d" % weight_corpses.size())
	if weight_corpses.size() == 1:
		check(absf(weight_corpses[0].global_position.x - 500.0) < 15.0, "SUITE 2.5", "decay_weight corpse is at original pos x=500", "x=%.1f" % weight_corpses[0].global_position.x)

	# Return to decay_vines
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	var vines_corpses: Array = []
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			vines_corpses.append(c)
	check(vines_corpses.size() == 1, "SUITE 2.5", "decay_vines re-instantiates exactly 1 corpse upon return", "count=%d" % vines_corpses.size())
	if vines_corpses.size() == 1:
		check(absf(vines_corpses[0].global_position.x - 600.0) < 15.0, "SUITE 2.5", "decay_vines corpse is at original pos x=600", "x=%.1f" % vines_corpses[0].global_position.x)

	# 2.6: Multiple transition loop (5 iterations)
	for i in range(5):
		rm.enter_room(&"decay_garden", &"default")
		await process_frame
		rm.enter_room(&"decay_weight", &"default")
		await process_frame
		rm.enter_room(&"decay_vines", &"default")
		await process_frame

	await create_timer(0.2).timeout
	dm.clear()
	vines_corpses.clear()
	for c in get_nodes_in_group("corpse"):
		if c.is_inside_tree() and c.is_visible_in_tree():
			vines_corpses.append(c)
	check(vines_corpses.size() == 1, "SUITE 2.6", "After 5 rapid transitions, decay_vines still has exactly 1 corpse (no duplication)", "count=%d" % vines_corpses.size())
	check(state.world_memory_state["corpses"].size() == 3, "SUITE 2.6", "world_memory_state corpse array size is preserved at 3", "size=%d" % state.world_memory_state["corpses"].size())


	# =========================================================================
	# SUITE 3: POSSESSION RELOAD RETAINING PUZZLE SOLVE FLAGS IN PUZZLEMANAGER
	# =========================================================================
	print("\n--------------------------------------------------------------------")
	print("SUITE 3: POSSESSION RELOAD RETAINING PUZZLE SOLVE FLAGS")
	print("--------------------------------------------------------------------")

	# Commit an initial baseline save point at decay_garden
	curse.reset_for_new_life()
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	state.set_checkpoint(Vector2(130, 288), &"decay_garden")
	save.commit_save(&"test_baseline", Vector2(130, 288), &"decay_garden")

	# Solve multiple puzzles in PuzzleManager and GameState
	pm.mark_solved(&"awakening_weight")
	pm.mark_solved(&"awakening_memory_code")
	pm.mark_solved(&"decay_vine_shortcut")
	pm.mark_solved(&"decay_archive_key")
	pm.mark_solved(&"decay_weight_latch")
	state.set_world_flag(&"m1_custom_persistence_flag", true)
	state.set_story_flag(&"first_shadow_seen", true)
	state.set_story_flag(&"first_corpse_discovered", true)

	check(pm.is_solved(&"awakening_weight"), "SUITE 3.1", "awakening_weight is solved before possession")
	check(pm.is_solved(&"awakening_memory_code"), "SUITE 3.1", "awakening_memory_code is solved before possession")
	check(pm.is_solved(&"decay_vine_shortcut"), "SUITE 3.1", "decay_vine_shortcut is solved before possession")
	check(pm.is_solved(&"decay_archive_key"), "SUITE 3.1", "decay_archive_key is solved before possession")
	check(pm.is_solved(&"decay_weight_latch"), "SUITE 3.1", "decay_weight_latch is solved before possession")
	check(state.has_story_flag(&"first_shadow_seen"), "SUITE 3.1", "first_shadow_seen story flag set")

	# Trigger 100% Curse Possession
	curse.add_curse(100.0, &"possession_stress_test")
	check(curse.possessing, "SUITE 3.2", "Curse possession triggered")

	finished = await _wait_possession(curse)
	check(finished, "SUITE 3.2", "Possession sequence finished")
	check(not curse.possessing, "SUITE 3.2", "curse.possessing is false")
	check(curse.curse == 50.0, "SUITE 3.2", "Curse restored to 50.0 Band 1", "curse=%.1f" % curse.curse)
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "SUITE 3.2", "Curse band is FIRST_SIGNS")
	check(not gate.blocks_movement(), "SUITE 3.2", "UiGate cutscene released after possession")

	# CRITICAL ASSERTIONS: All puzzle flags in PuzzleManager and GameState MUST BE RETAINED
	check(pm.is_solved(&"awakening_weight"), "SUITE 3.3", "RETAINED: awakening_weight is still solved in PuzzleManager")
	check(pm.is_solved(&"awakening_memory_code"), "SUITE 3.3", "RETAINED: awakening_memory_code is still solved in PuzzleManager")
	check(pm.is_solved(&"decay_vine_shortcut"), "SUITE 3.3", "RETAINED: decay_vine_shortcut is still solved in PuzzleManager")
	check(pm.is_solved(&"decay_archive_key"), "SUITE 3.3", "RETAINED: decay_archive_key is still solved in PuzzleManager")
	check(pm.is_solved(&"decay_weight_latch"), "SUITE 3.3", "RETAINED: decay_weight_latch is still solved in PuzzleManager")

	var pz: Dictionary = state.world_memory_state.get("puzzles", {})
	check(bool(pz.get("awakening_weight", false)), "SUITE 3.3", "RETAINED: awakening_weight in world_memory_state['puzzles']")
	check(bool(pz.get("decay_vine_shortcut", false)), "SUITE 3.3", "RETAINED: decay_vine_shortcut in world_memory_state['puzzles']")

	check(bool(state.get_world_flag(&"m1_custom_persistence_flag", false)), "SUITE 3.3", "RETAINED: m1_custom_persistence_flag in world_memory_state['flags']")
	check(state.has_story_flag(&"first_shadow_seen"), "SUITE 3.3", "RETAINED: first_shadow_seen in story_flags")
	check(state.has_story_flag(&"first_corpse_discovered"), "SUITE 3.3", "RETAINED: first_corpse_discovered in story_flags")


	# =========================================================================
	# SUITE 4: ENSURE AWAKENING BED (120, 280) IS ONLY USED WHEN DYING IN AWAKENING
	# =========================================================================
	print("\n--------------------------------------------------------------------")
	print("SUITE 4: ENSURE REBIRTH BED (120, 280) IS ONLY USED IN AWAKENING")
	print("--------------------------------------------------------------------")

	# 4.1: Dying in awakening -> MUST use (120, 280)
	curse.reset_for_new_life()
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	player.global_position = Vector2(800, 288)

	state.damage(99)
	check(death.is_dying, "SUITE 4.1", "Death initiated in awakening")
	finished = await _wait_death(death)
	check(finished, "SUITE 4.1", "Awakening death finished")
	check(rm.get_active_room_id() == &"awakening", "SUITE 4.1", "Player in awakening")
	check(absf(player.global_position.x - 120.0) < 6.0 and absf(player.global_position.y - 280.0) < 14.0, "SUITE 4.1", "Awakening respawn IS at rebirth_bed (120, 280)", "pos=%s" % str(player.global_position))

	# 4.2: Exhaustive check of EVERY registered room in RoomManager
	var all_rooms: Array = rm._rooms.keys()
	check(all_rooms.size() >= 18, "SUITE 4.2", "At least 18 rooms registered in RoomManager", "count=%d" % all_rooms.size())

	var invalid_bed_rooms: Array = []
	for rid in all_rooms:
		var room_id := StringName(str(rid))
		if room_id == &"awakening":
			continue

		# Set active room to room_id
		rm._current = room_id
		state.character_current_life_knowledge["room"] = room_id
		state.character_current_life_knowledge["spawn_id"] = &"default"

		var respawn_pos: Vector2 = death._get_respawn_position()
		var bounds: Rect2 = rm.get_room_bounds(room_id)

		# Check 1: Is it Vector2(120, 280)?
		if absf(respawn_pos.x - 120.0) < 1.0 and absf(respawn_pos.y - 280.0) < 1.0:
			invalid_bed_rooms.append("%s (got exact 120, 280)" % String(room_id))
		# Check 2: Is it within the room's bounds?
		if bounds.size.x > 0.0 and bounds.size.y > 0.0:
			if not bounds.grow(10.0).has_point(respawn_pos):
				invalid_bed_rooms.append("%s (pos %s outside bounds %s)" % [String(room_id), str(respawn_pos), str(bounds)])

	check(invalid_bed_rooms.is_empty(), "SUITE 4.2", "NO other room returned awakening rebirth_bed (120, 280) or out-of-bounds pos", "invalids=%s" % str(invalid_bed_rooms))

	# 4.3: Real in-game death stress testing across diverse rooms
	var test_rooms: Array[Dictionary] = [
		{"room": &"awakening_passage", "death_x": 600.0, "expected_spawn": Vector2(700, 288), "margin": 30.0},
		{"room": &"decay_vines", "death_x": 400.0, "expected_spawn": Vector2(120, 288), "margin": 30.0},
		{"room": &"decay_weight", "death_x": 400.0, "expected_spawn": Vector2(120, 288), "margin": 30.0},
		{"room": &"decay_garden", "death_x": 500.0, "expected_spawn": Vector2(130, 288), "margin": 30.0},
		{"room": &"library_witness", "death_x": 500.0, "expected_spawn": Vector2(200, 288), "margin": 30.0},
		{"room": &"core", "death_x": 500.0, "expected_spawn": Vector2(160, 280), "margin": 30.0},
	]

	for tr in test_rooms:
		var target_room: StringName = tr["room"]
		var death_x: float = tr["death_x"]
		var expected: Vector2 = tr["expected_spawn"]
		var margin: float = tr["margin"]

		curse.reset_for_new_life()
		rm.enter_room(target_room, &"default", false)
		await create_timer(0.18).timeout
		dm.clear()
		player.global_position = Vector2(death_x, 288.0)

		state.damage(99)
		check(death.is_dying, "SUITE 4.3", "%s: Death started" % String(target_room))
		finished = await _wait_death(death)
		check(finished, "SUITE 4.3", "Death completed in %s" % String(target_room))
		check(rm.get_active_room_id() == target_room, "SUITE 4.3", "Player stayed in %s (DID NOT go to awakening)" % String(target_room))

		# Confirm Noroi did NOT spawn at (120, 280)
		var is_bed := (absf(player.global_position.x - 120.0) < 4.0 and absf(player.global_position.y - 280.0) < 4.0)
		if target_room != &"awakening":
			check(not is_bed, "SUITE 4.3", "%s: Did NOT respawn at awakening bed (120, 280)" % String(target_room), "pos=%s" % str(player.global_position))

		# Confirm Noroi spawned near expected room checkpoint
		check(absf(player.global_position.x - expected.x) <= margin, "SUITE 4.3", "%s: Respawned at room spawn near x=%.1f" % [String(target_room), expected.x], "actual_x=%.1f" % player.global_position.x)


	# =========================================================================
	# EMPIRICAL CHALLENGE VERDICT
	# =========================================================================
	print("\n====================================================================")
	print("CHALLENGER 2 EMPIRICAL SUMMARY")
	print("====================================================================")
	print("Total checks run: ", total_checks)
	print("Total failures: ", failures)
	if failures == 0:
		print("FINAL VERDICT: APPROVE")
	else:
		print("FINAL VERDICT: REJECT (%d failures)" % failures)

	quit(1 if failures > 0 else 0)
