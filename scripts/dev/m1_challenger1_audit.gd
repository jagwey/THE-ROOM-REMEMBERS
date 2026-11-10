extends SceneTree
## Empirical Challenger M1-1 Adversarial Stress Suite:
##
## Challenge 1: Multiple rapid sequential deaths across 5+ different rooms
## Challenge 2: Edge cases in safe floor calculation (zero safe floor fallback, mid-air dash death, re-entrant calls)
## Challenge 3: Possession reload race conditions with 20+ persistent objects & massive world state
## Challenge 4: Exact curse value assertions across death cycles

var total_checks := 0
var failures := 0

func check(ok: bool, challenge: String, label: String, detail: String = "") -> void:
	total_checks += 1
	var status := "PASS" if ok else "FAIL"
	if detail != "":
		print("[%s] %s: %s [%s]" % [status, challenge, label, detail])
	else:
		print("[%s] %s: %s" % [status, challenge, label])
	if not ok:
		failures += 1


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func await_death(death: Node, max_ms: int = 25000) -> bool:
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < max_ms:
		await process_frame
	await create_timer(0.08).timeout
	var curse := root.get_node_or_null("CurseManager")
	if curse and curse.possessing:
		await await_possession(curse)
	var dm := root.get_node_or_null("DialogueManager")
	if dm and dm.has_method("clear"):
		dm.clear()
	return not death.is_dying


func await_possession(curse: Node, max_ms: int = 25000) -> bool:
	var t0 := Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < max_ms:
		await process_frame
	await create_timer(0.12).timeout
	var dm := root.get_node_or_null("DialogueManager")
	if dm and dm.has_method("clear"):
		dm.clear()
	return not curse.possessing


func _run() -> void:
	var state := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var death := root.get_node("DeathManager")
	var curse := root.get_node("CurseManager")
	var pm := root.get_node("PuzzleManager")
	var cm := root.get_node("CorpseManager")
	var sm := root.get_node("SaveManager")

	sm.delete_all_save_files()
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()

	var player: CharacterBody2D = current_scene.get_node("Player")
	var corpses: Array = []

	# ====================================================================
	# CHALLENGE 1: MULTIPLE RAPID SEQUENTIAL DEATHS ACROSS 5+ ROOMS
	# ====================================================================
	print("\n====================================================================")
	print("CHALLENGE 1: MULTIPLE RAPID SEQUENTIAL DEATHS ACROSS 5+ ROOMS")
	print("====================================================================")

	var test_rooms: Array[StringName] = [
		&"awakening",
		&"decay_garden",
		&"library_hall",
		&"experiment_circuit",
		&"mirrors_reverse"
	]

	var deaths_initial: int = int(state.player_progress_knowledge.get("deaths", 0))
	var expected_total_deaths := deaths_initial

	for r_id in test_rooms:
		rm.enter_room(r_id, &"default", false)
		await create_timer(0.12).timeout
		dm.clear()
		check(rm.get_active_room_id() == r_id, "CHALLENGE 1", "Entered room successfully", String(r_id))

		# Rapid Death 1 in room
		curse.reset_for_new_life()
		player.global_position = Vector2(300, 288)
		death.request_death(&"enemy_combat")
		check(death.is_dying, "CHALLENGE 1", "Rapid Death 1 initiated in %s" % String(r_id))
		await await_death(death)
		expected_total_deaths += 1

		check(not death.is_dying, "CHALLENGE 1", "Rapid Death 1 completed in %s" % String(r_id))
		check(rm.get_active_room_id() == r_id, "CHALLENGE 1", "Respawned in same room %s" % String(r_id), String(rm.get_active_room_id()))

		if r_id == &"awakening":
			check(absf(player.global_position.x - 120.0) < 8.0 and absf(player.global_position.y - 280.0) < 14.0,
				"CHALLENGE 1", "Awakening respawns precisely at rebirth_bed (120, 280)", str(player.global_position))
		else:
			# Non-awakening rooms MUST NOT revert to rebirth_bed
			var dist_to_bed := player.global_position.distance_to(Vector2(120, 280))
			check(dist_to_bed > 2.0 or r_id == &"awakening", "CHALLENGE 1", "Non-awakening room stayed in-room", str(player.global_position))

		# Check corpse recorded in room
		corpses = state.world_memory_state.get("corpses", [])
		check(not corpses.is_empty(), "CHALLENGE 1", "Corpse list has entries")
		var last_corpse: Dictionary = corpses.back()
		check(StringName(str(last_corpse.get("room", ""))) == r_id, "CHALLENGE 1", "Corpse room matches active room", str(last_corpse.get("room", "")))

		# Immediate Rapid Death 2 in SAME room
		player.global_position = Vector2(350, 288)
		death.request_death(&"enemy_combat_2")
		check(death.is_dying, "CHALLENGE 1", "Rapid Death 2 initiated in %s" % String(r_id))
		await await_death(death)
		expected_total_deaths += 1

		check(not death.is_dying, "CHALLENGE 1", "Rapid Death 2 completed in %s" % String(r_id))
		check(rm.get_active_room_id() == r_id, "CHALLENGE 1", "Respawned in same room after second rapid death", String(rm.get_active_room_id()))

	var final_deaths: int = int(state.player_progress_knowledge.get("deaths", 0))
	check(final_deaths == expected_total_deaths, "CHALLENGE 1", "Death counter matches 10 sequential deaths perfectly", "%d == %d" % [final_deaths, expected_total_deaths])
	var current_corpses: Array = state.world_memory_state.get("corpses", [])
	check(current_corpses.size() <= 3, "CHALLENGE 1", "Corpse pool capped to max 3 physical corpses", "%d <= 3" % current_corpses.size())
	var traces: Array = state.world_memory_state.get("traces", [])
	check(traces.size() > 0, "CHALLENGE 1", "Excess corpses gracefully trimmed to decorative traces without crash", "traces=%d" % traces.size())

	# ====================================================================
	# CHALLENGE 2: EDGE CASES IN SAFE FLOOR CALCULATION
	# ====================================================================
	print("\n====================================================================")
	print("CHALLENGE 2: EDGE CASES IN SAFE FLOOR CALCULATION")
	print("====================================================================")

	rm.enter_room(&"decay_garden", &"default", false)
	await create_timer(0.12).timeout
	dm.clear()
	curse.reset_for_new_life()

	# Edge Case 2.1: Spawn / Void fall when safe floor is Vector2.ZERO
	player.set("_safe_floor_pos", Vector2.ZERO)
	player.set("_last_safe_floor_pos", Vector2.ZERO)
	player.global_position = Vector2(250, 360) # Void position
	var void_pos := player.global_position

	death.request_death(&"void")
	check(death.is_dying, "CHALLENGE 2", "Void death initiated with Vector2.ZERO safe floor")
	await await_death(death)
	check(not death.is_dying, "CHALLENGE 2", "Void death completed safely without null pointer/crash")

	corpses = state.world_memory_state.get("corpses", [])
	var void_corpse: Dictionary = corpses.back()
	var vc_pos: Dictionary = void_corpse.get("position", {})
	check(vc_pos.has("x") and vc_pos.has("y"), "CHALLENGE 2", "Void corpse has valid coordinates despite ZERO safe floor", str(vc_pos))

	# Edge Case 2.2: Mid-air Dash Death
	# Ground player firmly first so safe floor is at y ≈ 288
	player.global_position = Vector2(200, 288)
	player.velocity = Vector2.ZERO
	await create_timer(0.08).timeout
	var ground_safe_pos: Vector2 = player.get_last_safe_floor_pos()
	check(ground_safe_pos.y < 320.0, "CHALLENGE 2", "Firmly grounded on safe floor (y < 320.0)", str(ground_safe_pos))

	# Jump into mid-air and trigger dash over pit
	state.player_progress_knowledge["ability_shadow_dash"] = true
	player.set("_dash_cd", 0.0)
	player.global_position = Vector2(400, 160) # Mid-air
	player._on_dash()
	check(player.is_dashing(), "CHALLENGE 2", "Player in active mid-air dash state")
	check(player.collision_mask == 1, "CHALLENGE 2", "Dash temporarily reduced collision_mask to 1")

	# Dying while dashing mid-air
	death.request_death(&"hazard")
	check(death.is_dying, "CHALLENGE 2", "Hazard death triggered mid-air during dash")
	await await_death(death)
	check(not death.is_dying, "CHALLENGE 2", "Mid-air dash death completed")

	# Safe floor must NOT have been updated to the mid-air position during dash
	corpses = state.world_memory_state.get("corpses", [])
	var dash_corpse: Dictionary = corpses.back()
	var dc_pos: Dictionary = dash_corpse.get("position", {})
	var dc_y: float = float(dc_pos.get("y", 999.0))
	check(dc_y < 320.0 and absf(dc_y - ground_safe_pos.y) <= 4.0, "CHALLENGE 2",
		"Corpse placed on grounded safe floor, NOT mid-air dash pos", "corpse_y=%.1f vs ground_y=%.1f" % [dc_y, ground_safe_pos.y])
	check(player.collision_mask == 17, "CHALLENGE 2", "Player collision_mask restored to 17 after dash death", "mask=%d" % player.collision_mask)
	check(not player.is_dashing(), "CHALLENGE 2", "Player is NOT dashing after rebirth")

	# Edge Case 2.3: Re-entrant simultaneous request_death calls
	var deaths_before_burst: int = int(state.player_progress_knowledge.get("deaths", 0))
	death.request_death(&"spike")
	death.request_death(&"spike")
	death.request_death(&"spike")
	death.request_death(&"spike")
	death.request_death(&"spike")
	await await_death(death)
	var deaths_after_burst: int = int(state.player_progress_knowledge.get("deaths", 0))
	check(deaths_after_burst == deaths_before_burst + 1, "CHALLENGE 2", "Re-entrant death calls cleanly locked; exactly 1 death processed",
		"%d -> %d" % [deaths_before_burst, deaths_after_burst])

	# ====================================================================
	# CHALLENGE 3: POSSESSION RELOAD RACE CONDITIONS WITH 20+ PERSISTENT OBJECTS
	# ====================================================================
	print("\n====================================================================")
	print("CHALLENGE 3: POSSESSION RELOAD RACE CONDITIONS & MASSIVE WORLD STATE")
	print("====================================================================")

	# Establish committed anchor at Library Hall
	rm.enter_room(&"library_hall", &"default", false)
	await create_timer(0.12).timeout
	dm.clear()
	var committed_point := Vector2(190, 288)
	player.global_position = committed_point
	sm.commit_save(&"adversarial_seal", committed_point, &"library_hall")

	# Move to a distant room (mirrors_reverse)
	rm.enter_room(&"mirrors_reverse", &"default", false)
	await create_timer(0.12).timeout
	dm.clear()
	check(rm.get_active_room_id() == &"mirrors_reverse", "CHALLENGE 3", "Moved to distant room mirrors_reverse")

	# Populate massive world memory state with 25 flags, 12 puzzles, corpses, traces
	for i in range(25):
		state.set_world_flag(StringName("adversarial_flag_%d" % i), true)
	for i in range(12):
		pm.mark_solved(StringName("adversarial_puzzle_%d" % i))
	state.world_memory_state["forbidden_touched"].append("adversarial_relic_alpha")
	state.world_memory_state["forbidden_touched"].append("adversarial_relic_beta")

	var flag_count_before: int = (state.world_memory_state["flags"] as Dictionary).size()
	var puzzle_count_before: int = (state.world_memory_state["puzzles"] as Dictionary).size()
	check(flag_count_before >= 25, "CHALLENGE 3", "Over 20 persistent world flags populated", "flags=%d" % flag_count_before)
	check(puzzle_count_before >= 12, "CHALLENGE 3", "Over 10 persistent puzzles solved", "puzzles=%d" % puzzle_count_before)

	# Trigger possession sequence via 100% curse
	curse.set_curse(100.0)
	check(curse.possessing, "CHALLENGE 3", "Possession sequence actively started at 100% curse")

	# RACE ATTACK: Attempt invalid actions during possession
	death.request_death(&"spike_race_attack")
	check(not death.is_dying, "CHALLENGE 3", "DeathManager rejects request_death while possession is active")

	curse.set_curse(20.0)
	check(curse.possessing, "CHALLENGE 3", "CurseManager rejects set_curse(20.0) while possession is active")

	curse.add_curse(50.0)
	check(curse.possessing, "CHALLENGE 3", "CurseManager rejects add_curse while possession is active")

	# Wait for possession to complete
	await await_possession(curse)
	check(not curse.possessing, "CHALLENGE 3", "Possession sequence completed cleanly")

	# Verify player returned to committed room and point
	check(rm.get_active_room_id() == &"library_hall", "CHALLENGE 3", "Player teleported to committed room library_hall", String(rm.get_active_room_id()))
	check(player.global_position.distance_to(committed_point) < 16.0, "CHALLENGE 3", "Player spawned at committed checkpoint", str(player.global_position))

	# Verify ALL 25 flags survived
	var flags_intact := true
	for i in range(25):
		if not state.get_world_flag(StringName("adversarial_flag_%d" % i), false):
			flags_intact = false
			break
	check(flags_intact, "CHALLENGE 3", "All 25 persistent flags preserved intact across possession")

	# Verify ALL 12 puzzles survived
	var puzzles_intact := true
	for i in range(12):
		if not pm.is_solved(StringName("adversarial_puzzle_%d" % i)):
			puzzles_intact = false
			break
	check(puzzles_intact, "CHALLENGE 3", "All 12 persistent puzzles preserved intact across possession")

	# Verify curse reset to exactly 50.0 (POSSESSION_SAFE_CURSE) and band is FIRST_SIGNS
	check(is_equal_approx(curse.curse, 50.0), "CHALLENGE 3", "Curse reset to exactly POSSESSION_SAFE_CURSE (50.0)", str(curse.curse))
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "CHALLENGE 3", "Curse band is FIRST_SIGNS (Band 1)")

	# ====================================================================
	# CHALLENGE 4: EXACT CURSE VALUE ASSERTIONS ACROSS DEATH CYCLES
	# ====================================================================
	print("\n====================================================================")
	print("CHALLENGE 4: EXACT CURSE VALUE ASSERTIONS ACROSS DEATH CYCLES")
	print("====================================================================")

	# Test 4.1: Starting curse = 0.0 -> Death -> Curse MUST be exactly 50.0
	curse.reset_for_new_life()
	check(is_equal_approx(curse.curse, 0.0), "CHALLENGE 4", "Starting curse is 0.0")
	death.request_death(&"curse_test_1")
	await await_death(death)
	check(is_equal_approx(curse.curse, 50.0), "CHALLENGE 4", "Death at 0.0 curse elevates to exactly 50.0", str(curse.curse))
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "CHALLENGE 4", "Band is FIRST_SIGNS")

	# Test 4.2: Starting curse = 30.0 -> Death -> 30 + 25 = 55.0 >= 50.0 -> Curse MUST be exactly 55.0
	curse.restore_curse(30.0)
	check(is_equal_approx(curse.curse, 30.0), "CHALLENGE 4", "Starting curse set to 30.0")
	death.request_death(&"curse_test_2")
	await await_death(death)
	check(is_equal_approx(curse.curse, 55.0), "CHALLENGE 4", "Death at 30.0 curse adds +25 to reach exactly 55.0", str(curse.curse))
	check(curse.get_band() == curse.Band.FIRST_SIGNS, "CHALLENGE 4", "Band is FIRST_SIGNS")

	# Test 4.3: Starting curse = 55.0 -> Death -> 55 + 25 = 80.0 >= 50.0 -> Curse MUST be exactly 80.0 (DANGER)
	curse.restore_curse(55.0)
	check(is_equal_approx(curse.curse, 55.0), "CHALLENGE 4", "Starting curse set to 55.0")
	death.request_death(&"curse_test_3")
	await await_death(death)
	check(is_equal_approx(curse.curse, 80.0), "CHALLENGE 4", "Death at 55.0 curse adds +25 to reach exactly 80.0", str(curse.curse))
	check(curse.get_band() == curse.Band.DANGER, "CHALLENGE 4", "Band elevated to DANGER (Band 2)")

	# Test 4.4: Starting curse = 75.0 -> Death -> 75 + 25 = 100.0 -> Smooth transition to possession
	curse.restore_curse(75.0)
	check(is_equal_approx(curse.curse, 75.0), "CHALLENGE 4", "Starting curse set to 75.0")
	death.request_death(&"curse_test_4")
	await await_death(death)
	# Upon rebirth, curse reached 100.0 which automatically initiated possession
	if curse.possessing:
		print("[INFO] CHALLENGE 4: Possession automatically triggered after rebirth reached 100.0 curse. Awaiting finish...")
		await await_possession(curse)
	check(not curse.possessing, "CHALLENGE 4", "Possession resolved smoothly after 100.0 curse rebirth")
	check(is_equal_approx(curse.curse, 50.0), "CHALLENGE 4", "Curse reset to 50.0 after possession resolution", str(curse.curse))

	# ====================================================================
	# FINAL EMPIRICAL VERDICT
	# ====================================================================
	print("\n====================================================================")
	print("CHALLENGER 1 ADVERSARIAL STRESS VERDICT SUMMARY")
	print("====================================================================")
	print("Total adversarial checks: ", total_checks)
	print("Total failures: ", failures)
	sm.delete_all_save_files()

	if failures == 0:
		print("FINAL VERDICT: APPROVE (ALL 4 ADVERSARIAL STRESS CHALLENGES PASSED)")
	else:
		print("FINAL VERDICT: REJECT (%d ADVERSARIAL FAILURES DETECTED)" % failures)

	quit(1 if failures else 0)
