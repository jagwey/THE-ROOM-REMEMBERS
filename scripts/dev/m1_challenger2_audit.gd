extends SceneTree
## Empirical Challenger M1-2 Audit:
## Adversarial Stress Testing of Corpse Pushing, Room Clamping, and Plate Anchor Protection.
##
## Challenges:
## 1. Wide Room Pushing: Test pushing a corpse in Awakening (width 1280px) past x=620 to plate at x=940.
##    Assert no premature clamping at 620px and verify boundary limits [32, 1248].
## 2. Excess Trimming Anchor Protection: Place a corpse on an active unsolved pressure plate.
##    Force 5 subsequent deaths in other rooms. Assert that the anchored corpse on the plate
##    is NEVER converted to a trace and plate remains pressed.
## 3. Save/Load Persistence: Save with corpse on plate, reload save, assert plate triggers immediately.

var total_checks := 0
var failures := 0

func check(ok: bool, challenge: String, label: String, detail: String = "") -> void:
	total_checks += 1
	var status := "PASS" if ok else "FAIL"
	if detail != "":
		print("[%s] %s: %s (%s)" % [status, challenge, label, detail])
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

func _run() -> void:
	var state := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var cm := root.get_node("CorpseManager")
	var pm := root.get_node("PuzzleManager")
	var save := root.get_node("SaveManager")

	save.delete_all_save_files()
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()

	print("\n====================================================================")
	print("CHALLENGE 1: WIDE ROOM PUSHING & BOUNDARY CLAMPING (AWAKENING 1280px)")
	print("====================================================================")

	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()

	var bounds: Rect2 = rm.get_active_room_bounds()
	check(bounds.size.x == 1280.0, "CHALLENGE 1", "Awakening room bounds width is 1280px", "width=%.1f" % bounds.size.x)

	# Place corpse at x=550.0 (before old buggy 620px clamp)
	state.character_current_life_knowledge["room"] = &"awakening"
	var cid1: String = cm.record_corpse_at(Vector2(550.0, 288.0), "challenge1_push")
	await create_timer(0.2).timeout

	var corpse1: Node2D = null
	for c in get_nodes_in_group("corpse"):
		if c.get("corpse_id") == cid1:
			corpse1 = c
			break
	check(corpse1 != null, "CHALLENGE 1", "Corpse instantiated in Awakening", "id=%s" % cid1)

	# Step 1: Push 1 (550 -> 586)
	corpse1._push(1.0)
	await create_timer(0.3).timeout
	check(corpse1.global_position.x > 580.0, "CHALLENGE 1", "Push 1 advances corpse", "x=%.1f" % corpse1.global_position.x)

	# Step 2: Push 2 (586 -> 622) - under old bug this clamped to 620.0
	corpse1._push(1.0)
	await create_timer(0.3).timeout
	check(corpse1.global_position.x > 620.0, "CHALLENGE 1", "Push 2 advances past 620px without premature clamping", "x=%.1f" % corpse1.global_position.x)

	# Kefaret taşı koridorda duruyor; kelepçe testi için yolu aç (taş odada kalır).
	var stone := rm._rooms[&"awakening"].root.get_node_or_null("WeightStone") as Node2D
	if stone:
		stone.global_position = Vector2(200, 288)
	# Step 3: Push to plate at x=940
	var plate1: Area2D = rm._rooms[&"awakening"].root.get_node("Interactive/PressurePlate")
	check(plate1 != null, "CHALLENGE 1", "Pressure plate exists at x=940", "pos=(%.1f, %.1f)" % [plate1.global_position.x, plate1.global_position.y])

	var push_count := 0
	while corpse1.global_position.x < 930.0 and push_count < 15:
		corpse1._push(1.0)
		await create_timer(0.28).timeout
		push_count += 1

	check(absf(corpse1.global_position.x - 940.0) <= 30.0, "CHALLENGE 1", "Corpse reached pressure plate area at x=940", "x=%.1f" % corpse1.global_position.x)
	plate1._recompute()
	check(plate1._pressed, "CHALLENGE 1", "Pressure plate triggered by corpse", "pressed=%s" % str(plate1._pressed))

	# Step 4: Push to right room boundary (1248px)
	push_count = 0
	while push_count < 20 and corpse1.global_position.x < 1247.0:
		corpse1._push(1.0)
		await create_timer(0.28).timeout
		push_count += 1

	check(corpse1.global_position.x <= 1248.0, "CHALLENGE 1", "Corpse respects room boundary max_x=1248px", "x=%.1f" % corpse1.global_position.x)
	check(corpse1.global_position.x >= 1240.0, "CHALLENGE 1", "Corpse reached vicinity of max_x boundary", "x=%.1f" % corpse1.global_position.x)

	# Step 5: Boundary refusal
	var pre_bound_x := corpse1.global_position.x
	corpse1._push(1.0)
	await create_timer(0.3).timeout
	check(absf(corpse1.global_position.x - pre_bound_x) < 0.5, "CHALLENGE 1", "Corpse stops at boundary and refuses further forward pushes", "dx=%.2f" % absf(corpse1.global_position.x - pre_bound_x))

	# Step 6: Left boundary clamp (32px)
	corpse1.global_position.x = 45.0
	corpse1._persist_position()
	corpse1._push(-1.0)
	await create_timer(0.3).timeout
	check(corpse1.global_position.x == 32.0, "CHALLENGE 1", "Corpse clamped at left boundary min_x=32px", "x=%.1f" % corpse1.global_position.x)


	print("\n====================================================================")
	print("CHALLENGE 2: EXCESS TRIMMING ANCHOR PROTECTION ACROSS 5 DEATHS")
	print("====================================================================")

	# Clean slate for challenge 2
	save.delete_all_save_files()
	state.world_memory_state["corpses"] = []
	state.world_memory_state["traces"] = []
	state.world_memory_state["puzzles"] = {}
	state.set_world_flag(&"awakening_door_opened", false)
	pm.sync_from_world()
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()

	var plate2: Area2D = rm._rooms[&"awakening"].root.get_node("Interactive/PressurePlate")
	check(not pm.is_solved(&"awakening_weight"), "CHALLENGE 2", "Plate puzzle starts UNSOLVED")

	# Place corpse on pressure plate at x=940
	state.character_current_life_knowledge["room"] = &"awakening"
	var plate_cid: String = cm.record_corpse_at(Vector2(940.0, 300.0), "plate_anchor_test")
	await create_timer(0.2).timeout
	plate2._recompute()
	await create_timer(0.1).timeout

	check(plate2._pressed, "CHALLENGE 2", "Plate triggers when corpse is placed on it", "pressed=%s" % str(plate2._pressed))

	# Verify corpse anchor flag
	var corpse_entry: Dictionary = {}
	for c in state.world_memory_state["corpses"]:
		if c.get("id") == plate_cid:
			corpse_entry = c
			break
	var is_anchored_in_memory: bool = bool(corpse_entry.get("anchored", false)) or bool(corpse_entry.get("anchoring", false))
	check(is_anchored_in_memory, "CHALLENGE 2", "Corpse on plate is marked anchored in world memory", "anchored=%s, anchoring=%s" % [str(corpse_entry.get("anchored")), str(corpse_entry.get("anchoring"))])

	# Now force 5 subsequent deaths in other rooms (decay_vines)
	state.character_current_life_knowledge["room"] = &"decay_vines"
	for i in range(5):
		cm.record_corpse_at(Vector2(200.0 + i * 25.0, 288.0), "hearts")

	# Assert that anchored corpse on plate was NEVER converted to a trace
	var plate_corpse_survived := false
	for c in state.world_memory_state["corpses"]:
		if c.get("id") == plate_cid:
			plate_corpse_survived = true
			break

	var plate_corpse_in_traces := false
	for t in state.world_memory_state["traces"]:
		if t.get("from_corpse") == plate_cid:
			plate_corpse_in_traces = true
			break

	check(plate_corpse_survived, "CHALLENGE 2", "Corpse on plate SURVIVED in corpses array across 5 excess deaths", "survived=%s" % str(plate_corpse_survived))
	check(not plate_corpse_in_traces, "CHALLENGE 2", "Corpse on plate was NEVER converted to a decorative trace", "in_traces=%s" % str(plate_corpse_in_traces))

	# Return to Awakening and assert plate remains pressed
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	plate2._recompute()
	check(plate2._pressed, "CHALLENGE 2", "Pressure plate REMAINS pressed after 5 excess deaths", "pressed=%s" % str(plate2._pressed))


	print("\n====================================================================")
	print("CHALLENGE 3: SAVE/LOAD PERSISTENCE WITH CORPSE ON PRESSURE PLATE")
	print("====================================================================")

	# Clean slate for challenge 3
	save.delete_all_save_files()
	state.world_memory_state["corpses"] = []
	state.world_memory_state["traces"] = []
	state.world_memory_state["puzzles"] = {}
	state.set_world_flag(&"awakening_door_opened", false)
	pm.sync_from_world()
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()

	var plate3: Area2D = rm._rooms[&"awakening"].root.get_node("Interactive/PressurePlate")
	state.character_current_life_knowledge["room"] = &"awakening"
	var cid3: String = cm.record_corpse_at(Vector2(940.0, 300.0), "save_load_test")
	await create_timer(0.2).timeout
	plate3._recompute()
	check(plate3._pressed, "CHALLENGE 3", "Plate triggers with corpse on it before save", "pressed=%s" % str(plate3._pressed))

	# Save game
	var save_ok: bool = save.save_game()
	check(save_ok, "CHALLENGE 3", "SaveManager.save_game succeeded")

	# Despawn corpse nodes and reset plate state
	for c in get_nodes_in_group("corpse"):
		c.global_position = Vector2(-1000, -1000)
		c.queue_free()
	await process_frame
	await process_frame
	plate3._recompute()
	check(not plate3._pressed, "CHALLENGE 3", "Plate reset to unpressed before load")

	# Reload save
	var load_ok: bool = save.load_game(true)
	check(load_ok, "CHALLENGE 3", "SaveManager.load_game succeeded")
	await process_frame
	await create_timer(0.3).timeout

	# Verify corpse re-instantiated
	var reloaded_corpse: Node2D = null
	for c in get_nodes_in_group("corpse"):
		if c.get("corpse_id") == cid3:
			reloaded_corpse = c
			break
	check(reloaded_corpse != null, "CHALLENGE 3", "Corpse re-instantiated on plate from save file", "id=%s" % cid3)
	if reloaded_corpse:
		check(absf(reloaded_corpse.global_position.x - 940.0) < 5.0, "CHALLENGE 3", "Reloaded corpse position preserved at x=940", "pos=%s" % str(reloaded_corpse.global_position))

	# Assert plate triggers immediately
	check(plate3._pressed, "CHALLENGE 3", "Pressure plate triggers immediately upon reload", "pressed=%s" % str(plate3._pressed))


	print("\n====================================================================")
	print("CHALLENGE EMPIRICAL SUMMARY")
	print("====================================================================")
	print("Total checks: ", total_checks)
	print("Total failures: ", failures)
	if failures == 0:
		print("FINAL VERDICT: APPROVE (ALL CHALLENGES PASSED)")
	else:
		print("FINAL VERDICT: REJECT (%d CHALLENGES FAILED)" % failures)

	quit(1 if failures > 0 else 0)


