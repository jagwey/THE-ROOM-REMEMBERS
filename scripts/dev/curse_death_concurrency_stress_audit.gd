extends SceneTree
## Adversarial Stress Harness: Curse vs Death Loop Separation & Concurrency
## Dispatched to: teamwork_challenger_m1_1
## Target Checks:
## 1. Concurrency Race: Simulate simultaneous lethal damage and 100% curse in the exact same physics frame.
## 2. Interruption: Verify add_curse() / set_curse() strictly blocked during DeathManager.is_dying across all death phases.
## 3. Reload Integrity: Trigger 100% curse possession and verify zero corpses, no death increment, committed safe save reload, curse <= 30.0, UiGate Layer.NONE.
## 4. Re-entrancy Stress: Signal callbacks attempting cross-triggering between Death and Curse.

var failures := 0
var total_checks := 0

var curse: Node
var death: Node
var state: Node
var rm: Node
var sm: Node
var dm: Node
var gate: Node
var player: CharacterBody2D

var death_phases_seen: Array = []
var gate_layers_seen: Array = []


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run_suite")


func check(ok: bool, label: String, detail: String = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if detail != "":
		print("CONCURRENCY_CHALLENGE ", msg, label, " [", detail, "]")
	else:
		print("CONCURRENCY_CHALLENGE ", msg, label)
	if not ok:
		failures += 1


func _wait_sec(sec: float) -> void:
	await create_timer(sec).timeout


func _await_possession_finish(max_sec: float = 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < int(max_sec * 1000):
		await process_frame
	await _wait_sec(0.15)


func _await_death_finish(max_sec: float = 25.0) -> void:
	var t0 := Time.get_ticks_msec()
	while death.is_dying and (Time.get_ticks_msec() - t0) < int(max_sec * 1000):
		await process_frame
	await _wait_sec(0.15)


func _run_suite() -> void:
	sm = root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("CHALLENGE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()

	state = root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true

	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await _wait_sec(0.3)

	curse = root.get_node("CurseManager")
	death = root.get_node("DeathManager")
	rm = root.get_node("RoomManager")
	dm = root.get_node("DialogueManager")
	gate = root.get_node("UiGate")
	player = current_scene.get_node("Player")

	death.phase_changed.connect(func(p: int) -> void: death_phases_seen.append(p))
	gate.gate_changed.connect(func(l: int) -> void: gate_layers_seen.append(l))

	print("\n=======================================================")
	print("SUITE 1: SIMULTANEOUS LETHAL DAMAGE & 100% CURSE IN SAME FRAME")
	print("=======================================================")
	await _test_concurrency_race_damage_first()
	await _test_concurrency_race_curse_first()
	await _test_reentrant_signal_cross_race()

	print("\n=======================================================")
	print("SUITE 2: ADD_CURSE BLOCKED DURING ALL DEATH PHASES")
	print("=======================================================")
	await _test_add_curse_blocked_during_death()
	await _test_fail_curse_possession_during_death()

	print("\n=======================================================")
	print("SUITE 3: 100% CURSE POSSESSION RELOAD & INTEGRITY")
	print("=======================================================")
	await _test_possession_reload_integrity()

	print("\n=======================================================")
	print("CHALLENGE COMPLETE: TOTAL CHECKS=%d, FAILURES=%d" % [total_checks, failures])
	print("=======================================================")
	sm.delete_all_save_files()
	quit(1 if failures > 0 else 0)


## Concurrency Race 1: Lethal damage called FIRST, then 100% curse in the SAME physics frame
func _test_concurrency_race_damage_first() -> void:
	print("\n--- TEST 1.1: Damage(99) then set_curse(100.0) in same frame ---")
	rm.enter_room(&"awakening", &"default")
	await _wait_sec(0.15)
	dm.clear()
	death_phases_seen.clear()

	var deaths_before: int = int(state.player_progress_knowledge.get("deaths", 0))
	var corpses_before: int = (state.world_memory_state["corpses"] as Array).size()
	curse.reset_for_new_life()
	state.hearts = state.max_hearts

	# Execute both calls synchronously in the same frame
	state.damage(99)
	curse.set_curse(100.0)

	check(death.is_dying, "1.1: Death initiated when damage(99) runs first")
	check(not curse.possessing, "1.1: Curse possession blocked by DeathManager.is_dying mutex")
	check(curse.curse == 0.0 or curse.curse == 99.0, "1.1: Curse value clamped or unapplied (was not set to 100.0)", str(curse.curse))

	await _await_death_finish()

	check(not death.is_dying, "1.1: Death completed cleanly")
	check(not curse.possessing, "1.1: Curse possession never started post-death")
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_before + 1, "1.1: Deaths incremented by exactly 1")
	check((state.world_memory_state["corpses"] as Array).size() == corpses_before + 1, "1.1: Exactly 1 corpse placed by death")
	check(curse.curse == 0.0, "1.1: Curse reset to 0.0 for new life")
	check(gate.current_layer() == gate.Layer.NONE, "1.1: UiGate returned to NONE")


## Concurrency Race 2: 100% curse called FIRST, then lethal damage in the SAME physics frame
func _test_concurrency_race_curse_first() -> void:
	print("\n--- TEST 1.2: set_curse(100.0) then damage(99) in same frame ---")
	# First commit a known safe state
	rm.enter_room(&"awakening", &"default")
	await _wait_sec(0.15)
	dm.clear()
	var safe_pos := Vector2(250, 288)
	player.global_position = safe_pos
	sm.commit_save(&"safe_checkpoint_1_2", safe_pos, &"awakening")

	var deaths_before: int = int(state.player_progress_knowledge.get("deaths", 0))
	var corpses_before: int = (state.world_memory_state["corpses"] as Array).size()
	curse.reset_for_new_life()
	state.hearts = state.max_hearts
	death_phases_seen.clear()

	# Execute both calls synchronously in the same frame
	curse.set_curse(100.0)
	state.damage(99)

	check(curse.possessing, "1.2: Curse possession started when set_curse(100.0) runs first")
	check(not death.is_dying, "1.2: Death blocked by CurseManager.possessing mutex")
	check(death_phases_seen.is_empty(), "1.2: No death phases entered")

	await _await_possession_finish()

	check(not curse.possessing, "1.2: Possession completed cleanly")
	check(not death.is_dying, "1.2: Death never initiated")
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_before, "1.2: ZERO death count increment")
	check((state.world_memory_state["corpses"] as Array).size() == corpses_before, "1.2: ZERO corpse placed on curse possession")
	check(curse.curse <= 30.0, "1.2: Curse reset to safe band (<= 30.0)", str(curse.curse))
	check(gate.current_layer() == gate.Layer.NONE, "1.2: UiGate returned to NONE")


## Concurrency Race 3: Re-entrant signal cross-racing (attacking during curse signal, cursing during death signal)
func _test_reentrant_signal_cross_race() -> void:
	print("\n--- TEST 1.3: Re-entrant signal cross-race ---")
	curse.reset_for_new_life()
	death_phases_seen.clear()

	# Connect re-entrant listener: when curse reaches 100, immediately call damage(99)
	var on_curse_reenter := func(val: float) -> void:
		if val >= 100.0:
			state.damage(99)

	curse.curse_changed.connect(on_curse_reenter)
	curse.set_curse(100.0)
	curse.curse_changed.disconnect(on_curse_reenter)

	# Exactly one system must win and other must be rejected
	var death_won: bool = death.is_dying
	var curse_won: bool = curse.possessing
	check(death_won != curse_won, "1.3: Exactly one system won arbitration (death=%s, curse=%s)" % [str(death_won), str(curse_won)])

	if curse_won:
		await _await_possession_finish()
	elif death_won:
		await _await_death_finish()

	check(not death.is_dying and not curse.possessing, "1.3: System resolved cleanly with zero hanging state")
	check(gate.current_layer() == gate.Layer.NONE, "1.3: UiGate returned to Layer.NONE")


## Test Suite 2: add_curse() / set_curse() strictly blocked during DeathManager.is_dying
func _test_add_curse_blocked_during_death() -> void:
	print("\n--- TEST 2.1: add_curse(50.0) blocked across all death phases ---")
	curse.reset_for_new_life()
	state.hearts = state.max_hearts
	rm.enter_room(&"awakening", &"default")
	await _wait_sec(0.15)
	dm.clear()
	death_phases_seen.clear()

	var blocked_in_all_phases := true
	var test_reason := &"forbidden_altar_test"

	# Hook into phase changes during death: call add_curse(50.0) and set_curse(80.0)
	var on_phase := func(phase: int) -> void:
		if death.is_dying:
			var prev_curse: float = curse.curse
			curse.add_curse(50.0, test_reason)
			if curse.curse != prev_curse:
				blocked_in_all_phases = false
			curse.set_curse(80.0)
			if curse.curse != prev_curse:
				blocked_in_all_phases = false

	death.phase_changed.connect(on_phase)

	state.damage(99)
	check(death.is_dying, "2.1: Death initiated")

	# Also attempt direct add_curse(50.0) from test runner while death is in progress
	curse.add_curse(50.0, test_reason)
	check(curse.curse == 0.0, "2.1: add_curse(50.0) directly rejected during death", str(curse.curse))

	curse.set_curse(70.0)
	check(curse.curse == 0.0, "2.1: set_curse(70.0) directly rejected during death", str(curse.curse))

	await _await_death_finish()
	death.phase_changed.disconnect(on_phase)

	check(blocked_in_all_phases, "2.1: add_curse(50.0) and set_curse(80.0) blocked across all death phases")
	var touched: Array = state.world_memory_state.get("forbidden_touched", [])
	check(not touched.has(String(test_reason)), "2.1: forbidden_touched did NOT record curse reason during death")
	check(curse.curse == 0.0, "2.1: curse ended at 0.0 post-rebirth", str(curse.curse))


## Test 2.2: fail_curse_possession() called while DeathManager.is_dying
func _test_fail_curse_possession_during_death() -> void:
	print("\n--- TEST 2.2: fail_curse_possession() during DeathManager.is_dying ---")
	curse.reset_for_new_life()
	state.hearts = state.max_hearts
	rm.enter_room(&"awakening", &"default")
	await _wait_sec(0.15)
	dm.clear()
	death_phases_seen.clear()

	# Start death
	state.damage(99)
	check(death.is_dying, "2.2: Death started")

	# Call fail_curse_possession() during death
	curse.fail_curse_possession()

	# Invariant: Interface Contract 1: Checks if DeathManager.is_dying: return
	check(not curse.possessing, "2.2: fail_curse_possession() does NOT set possessing during death")

	# Critical challenge: Does fail_curse_possession mutate curse to 99.0 or leave it at 0.0?
	print("2.2 Observation: curse value during death after fail_curse_possession() = ", curse.curse)

	await _await_death_finish()

	check(not death.is_dying, "2.2: Death finished")
	check(not curse.possessing, "2.2: Curse possession never started")
	# If curse was set to 99 during death and not reset at rebirth, check if post-rebirth curse is safe (<= 30.0)
	check(curse.curse <= 30.0, "2.2: Post-rebirth curse is in safe band (<= 30.0), not left at critical 99.0", str(curse.curse))


## Test Suite 3: 100% Curse Possession Reload & Integrity
func _test_possession_reload_integrity() -> void:
	print("\n--- TEST 3.1: 100% Curse possession reload & state integrity ---")
	death_phases_seen.clear()
	rm.enter_room(&"library_hall", &"default")
	await _wait_sec(0.18)
	dm.clear()

	var seal_pos: Vector2 = rm._rooms[&"library_hall"].spawns[&"seal_library_hall"]
	player.global_position = seal_pos
	state.set_story_flag(&"first_warning_heard", true)
	state.set_story_flag(&"first_death_completed", false)
	state.set_story_flag(&"core_access_granted", false)
	state.set_world_flag(&"audit_flag_b", false)
	curse.set_curse(15.0)

	# Commit baseline State A
	check(sm.commit_save(&"audit_integrity_a", seal_pos, &"library_hall"), "3.1: commit_save A succeeded")

	var corpses_baseline: int = (state.world_memory_state["corpses"] as Array).size()
	var deaths_baseline: int = int(state.player_progress_knowledge.get("deaths", 0))
	var count_before: int = state.possession_count

	# Transition to State B (different room, modified flags, altered position)
	rm.enter_room(&"decay_garden", &"default")
	await _wait_sec(0.15)
	dm.clear()
	state.set_story_flag(&"core_access_granted", true)
	state.set_world_flag(&"audit_flag_b", true)
	player.global_position = Vector2(700, 288)
	sm.save_game()

	check(rm.get_active_room_id() == &"decay_garden", "3.1: Reached dirty State B (decay_garden)")
	check(state.has_story_flag(&"core_access_granted"), "3.1: State B story flag set")

	# Trigger 100% curse via add_curse
	curse.add_curse(90.0)
	check(curse.possessing, "3.1: Possession started on 100% curse")
	check(gate.current_layer() == gate.Layer.CUTSCENE, "3.1: UiGate layer is CUTSCENE during possession", str(gate.current_layer()))
	check(gate.blocks_gameplay_input(), "3.1: Gameplay input blocked during possession")

	await _await_possession_finish()

	# Assert all reload integrity criteria:
	# 1. Zero new corpses
	var corpses_after: int = (state.world_memory_state["corpses"] as Array).size()
	check(corpses_after == corpses_baseline, "3.1: ZERO corpses left in world_memory_state", "%d vs %d" % [corpses_after, corpses_baseline])

	# 2. Death counter not incremented
	var deaths_after: int = int(state.player_progress_knowledge.get("deaths", 0))
	check(deaths_after == deaths_baseline, "3.1: deaths counter NOT incremented", "%d vs %d" % [deaths_after, deaths_baseline])

	# 3. first_death_completed untouched
	check(not state.has_story_flag(&"first_death_completed"), "3.1: first_death_completed remains false")

	# 4. Committed safe save reloaded (room == library_hall, pos near seal_pos)
	check(rm.get_active_room_id() == &"library_hall", "3.1: Active room reloaded to library_hall", str(rm.get_active_room_id()))
	check(player.global_position.distance_to(seal_pos) < 16.0, "3.1: Player restored to safe commit pos", str(player.global_position))

	# 5. State B reverted
	check(not state.has_story_flag(&"core_access_granted"), "3.1: State B story flag reverted")
	check(not bool(state.get_world_flag(&"audit_flag_b", false)), "3.1: State B world flag reverted")

	# 6. Curse restored to safe value <= 30.0
	check(curse.curse <= 30.0 and curse.curse <= 25.0, "3.1: Curse restored to safe value <= 30.0", str(curse.curse))

	# 7. UiGate returned to NONE
	check(gate.current_layer() == gate.Layer.NONE, "3.1: UiGate returned to Layer.NONE", str(gate.current_layer()))
	check(not gate.blocks_movement(), "3.1: Movement unlocked")
	check(not gate.blocks_gameplay_input(), "3.1: Input unlocked")

	# 8. Possession count incremented and persisted
	check(state.possession_count == count_before + 1, "3.1: Possession count incremented by 1", str(state.possession_count))
	var resume_data: Variant = sm._read_save(sm.resume_path())
	check(resume_data is Dictionary and int((resume_data as Dictionary).get("possession_count", -1)) == state.possession_count, "3.1: Possession count saved to resume file")

	# 9. No death phases occurred
	check(death_phases_seen.is_empty(), "3.1: ZERO death phases entered during possession reload")
	check(player.visible, "3.1: Player node visible")
