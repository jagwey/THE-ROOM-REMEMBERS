extends SceneTree
## Faz 2 (oda 01-13) denetimi. Görevler bölümleri ekler: _components, _dialogue, _shade_water, _rooms_*, _softlock.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/phase2_rooms_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("PHASE2 ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PHASE2 SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	await _components()
	await _dialogue()
	await _shade_water()
	await _rooms_01_03()
	quit(1 if failures > 0 else 0)


func _components() -> void:
	var pm := root.get_node("PuzzleManager")
	var cm := root.get_node("CorpseManager")
	var curse := root.get_node("CurseManager")
	var scene: Node = current_scene
	# --- PuzzleManager.gate_open ---
	check(not pm.gate_open(PackedStringArray(["a", "b"]), &""), "gate_open_false_when_none_live")
	pm.set_live(&"a", true)
	check(not pm.gate_open(PackedStringArray(["a", "b"]), &""), "gate_open_false_when_one_live")
	pm.set_live(&"b", true)
	check(pm.gate_open(PackedStringArray(["a", "b"]), &""), "gate_open_true_when_all_live")
	pm.set_live(&"a", false)
	pm.set_live(&"b", false)
	check(not pm.gate_open(PackedStringArray(), &""), "gate_open_false_when_empty")
	pm.mark_solved(&"p2_legacy")
	check(pm.gate_open(PackedStringArray(["x"]), &"p2_legacy"), "gate_open_legacy_solved")
	# --- pressure_plate accept_stone ---
	var plate_script := load("res://scripts/world/pressure_plate.gd")
	var stone_script := load("res://scripts/world/weight_stone.gd")
	var origin := Vector2(6000, 0)
	var plate := Area2D.new()
	plate.set_script(plate_script)
	plate.puzzle_id = &"p2_plate"
	plate.accept_stone = false
	scene.add_child(plate)
	plate.global_position = origin
	var stone := CharacterBody2D.new()
	stone.set_script(stone_script)
	scene.add_child(stone)
	stone.global_position = origin
	stone.set_physics_process(false) ## zemin yok: düşmesin
	await physics_frame
	await physics_frame
	plate._recompute()
	check(not pm.is_live(&"p2_plate"), "plate_accept_stone_false_ignores_stone")
	plate.accept_stone = true
	plate._recompute()
	check(pm.is_live(&"p2_plate"), "plate_accept_stone_true_counts_stone")
	plate.accept_stone = false
	stone.queue_free()
	await physics_frame
	var room_for_corpse: StringName = root.get_node("GameState").character_current_life_knowledge.get("room", &"awakening")
	cm.record_corpse_at(origin, &"p2_test")
	await physics_frame
	var corpse: Node2D = null
	for c in get_nodes_in_group("corpse"):
		corpse = c as Node2D
	check(corpse != null, "plate_corpse_spawned (room %s)" % room_for_corpse)
	if corpse != null:
		plate.global_position = corpse.global_position
		await physics_frame
		await physics_frame
		plate._recompute()
		check(pm.is_live(&"p2_plate"), "plate_accept_stone_false_counts_corpse")
	plate.queue_free()
	await physics_frame
	pm.set_live(&"p2_plate", false)
	# --- gate_blocker puzzle_listen_all ---
	var gate := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	cs.shape = RectangleShape2D.new()
	gate.add_child(cs)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	gate.add_child(spr)
	gate.set_script(load("res://scripts/world/gate_blocker.gd"))
	gate.puzzle_listen = &""
	gate.puzzle_listen_all = PackedStringArray(["p2a", "p2b"])
	var gx := 9000.0
	scene.add_child(gate)
	gate.global_position = Vector2(gx, 288)
	var player := scene.get_node("Player") as Node2D
	var pstart := player.global_position
	player.global_position = Vector2(gx - 50, 288)
	await physics_frame
	check(gate.collision_layer == 1, "gate_all_closed_initially")
	pm.set_live(&"p2a", true)
	await physics_frame
	check(gate.collision_layer == 1, "gate_all_closed_with_one_live")
	pm.set_live(&"p2b", true)
	await physics_frame
	check(gate.collision_layer == 0, "gate_all_open_with_both_live")
	await physics_frame
	await physics_frame
	player.global_position = Vector2(gx + 50, 288)
	await physics_frame
	await physics_frame
	check(pm.is_solved(&"p2a") and pm.is_solved(&"p2b"), "gate_all_solve_on_pass_marks_every_id")
	gate.queue_free()
	player.global_position = pstart
	pm.set_live(&"p2a", false)
	pm.set_live(&"p2b", false)
	# --- code_seal_base penalize_wrong ---
	var seal := Area2D.new()
	seal.set_script(load("res://scripts/world/code_seal_base.gd"))
	scene.add_child(seal)
	var c0: float = curse.curse
	seal.penalize_wrong = false
	seal._apply_wrong_penalty()
	check(is_equal_approx(curse.curse, c0), "seal_wrong_no_penalty_by_default")
	seal.penalize_wrong = true
	seal._apply_wrong_penalty()
	check(is_equal_approx(curse.curse, c0 + 1.0), "seal_wrong_penalizes_curse_plus_one")
	curse.set_curse(c0)
	seal.queue_free()


var _picked := -1


func _on_pick(i: int) -> void:
	_picked = i


func _dialogue() -> void:
	var dm := root.get_node("DialogueManager")
	var gs := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	dm.clear()
	_picked = -1
	dm.choice_made.connect(_on_pick)
	dm.ask("@shilda", "?", PackedStringArray(["A", "B", "C"]))
	await process_frame
	check(dm.is_open and dm.has_choices(), "ask_opens_with_choices")
	check(gate.blocks_movement(), "ask_locks_movement")
	dm.choose_now(1)
	check(_picked == 1, "choose_emits_choice_made_1")
	check(not dm.is_open, "choose_closes_box")
	check(not gate.blocks_movement(), "choose_unlocks_movement")
	dm.choose_now(0) ## kapalıyken etkisiz
	check(_picked == 1, "choose_when_closed_ignored")
	dm.choice_made.disconnect(_on_pick)
	# --- vigil trust ---
	check(gs.get_vigil_trust() == 0, "vigil_trust_starts_zero")
	gs.add_vigil_trust(2)
	check(gs.get_vigil_trust() == 2, "vigil_trust_add_2")
	var sm := root.get_node("SaveManager")
	var saved: bool = sm.save_game()
	gs.add_vigil_trust(-2)
	check(gs.get_vigil_trust() == 0, "vigil_trust_reset_before_load")
	var loaded: bool = sm.load_game(false)
	check(saved and loaded and gs.get_vigil_trust() == 2, "vigil_trust_survives_save_load")
	# --- trust eşiği: sayaçlar skor 2 verir (echo + çiçek; eşik 3), +1 vigil eşiği geçirir ---
	gs.add_vigil_trust(-2)
	gs.player_progress_knowledge.erase("keeper_hurt")
	gs.player_progress_knowledge.erase("keeper_withdrew")
	gs.player_progress_knowledge.erase("trusted_keeper")
	var t: Dictionary = gs.get_shilda_trust_state()
	t["warnings_heeded"] = 0
	t["warnings_breached"] = 1
	t["echoes_completed"] = 1
	t["flowers_respected"] = true
	t["sanctuary_peace"] = false
	t["reconciled"] = false
	check(gs.get_vigil_trust() == 0 and not gs.is_shilda_trusted(), "trust_just_below_threshold")
	check(int(gs.get_shilda_trust_state().get("vigil_trust", -1)) == 0, "trust_state_exposes_vigil_trust")
	gs.add_vigil_trust(1)
	check(gs.is_shilda_trusted(), "vigil_plus1_flips_trust_true")
	gs.add_vigil_trust(-3)
	check(not gs.is_shilda_trusted(), "negative_vigil_trust_causes_suspicion")
	gs.player_progress_knowledge.erase("vigil_trust")
	gs.player_progress_knowledge.erase("shilda_trust")
	await _dialogue_lifecycle()


var _shown_count := 0
var _made: Array = []
var _cancelled := 0


func _on_shown(_o) -> void:
	_shown_count += 1


func _on_made_chain(i: int) -> void:
	_made.append(i)
	if _made.size() == 1:
		root.get_node("DialogueManager").ask("@shilda", "again", PackedStringArray(["X", "Y"]))


func _on_cancel() -> void:
	_cancelled += 1


func _dialogue_lifecycle() -> void:
	var dm := root.get_node("DialogueManager")
	dm.clear()
	dm.choices_shown.connect(_on_shown)
	dm.choice_cancelled.connect(_on_cancel)
	# zincirli ask: choice_made içinden ikinci ask
	_shown_count = 0
	_made.clear()
	dm.choice_made.connect(_on_made_chain)
	await process_frame
	dm.ask("@shilda", "one", PackedStringArray(["A", "B"]))
	dm.choose_now(0)
	check(dm.is_open and dm.has_choices() and _shown_count == 2, "chained_ask_from_handler_keeps_second_prompt")
	dm.choice_made.disconnect(_on_made_chain)
	dm.clear()
	# iptal sinyali tam bir kez
	_cancelled = 0
	dm.ask("@shilda", "c", PackedStringArray(["A", "B"]))
	dm.clear()
	check(_cancelled == 1, "clear_during_ask_emits_cancelled_once")
	dm.clear()
	check(_cancelled == 1, "clear_without_ask_does_not_cancel")
	# çift choose + sıradaki ask
	_made.clear()
	dm.choice_made.connect(func(i): _made.append(i))
	await process_frame
	dm.ask("@shilda", "d1", PackedStringArray(["A", "B"]))
	dm.ask("@shilda", "d2", PackedStringArray(["C", "D"]))
	dm.choose_now(0)
	dm.choose_now(0)
	check(_made.size() == 1 and dm.has_choices(), "double_choose_same_frame_answers_once")
	dm.clear()
	# aralık dışı
	_made.clear()
	dm.ask("@shilda", "r", PackedStringArray(["A", "B"]))
	dm.choose_now(5)
	dm.choose_now(-1)
	check(_made.is_empty() and dm.has_choices(), "out_of_range_choose_ignored")
	# klavye (advance): yazım tamamlanıp 150 ms koruma geçince vurgulu seçenek seçilir
	await create_timer(0.3).timeout
	dm.move_choice(1)
	dm.advance() ## yazım sürüyorsa önce sayfayı tamamlar
	await create_timer(0.2).timeout
	dm.advance()
	check(_made == [1] and not dm.is_open, "keyboard_advance_picks_highlighted")
	dm.clear()
	# kuyruktaki asklar dahil her iptal bir kez bildirilir
	_cancelled = 0
	dm.ask("@shilda", "q1", PackedStringArray(["A"]))
	dm.ask("@shilda", "q2", PackedStringArray(["B"]))
	dm.ask("@shilda", "q3", PackedStringArray(["C"]))
	dm.clear()
	check(_cancelled == 3, "clear_cancels_shown_and_queued_asks (%d)" % _cancelled)
	# gerçek çift dokunuş: choose() zaman korumalı, choose_now() atlar
	_made.clear()
	await process_frame
	dm.ask("@shilda", "g1", PackedStringArray(["A"]))
	dm.ask("@shilda", "g2", PackedStringArray(["B"]))
	dm.choose_now(0) ## g2 şimdi gösterildi
	await process_frame
	dm.choose(0)
	check(_made.size() == 1 and dm.has_choices(), "choose_within_guard_ignored")
	await create_timer(0.2).timeout
	dm.choose(0)
	check(_made.size() == 2 and not dm.is_open, "choose_after_guard_accepted")
	dm.clear()


var _reached_ids: Array = []
var _level_events: Array = []


func _on_reached(id: StringName) -> void:
	_reached_ids.append(id)


func _on_level(l: int) -> void:
	_level_events.append(l)


func _shade_water() -> void:
	var scene: Node = current_scene
	var gs := root.get_node("GameState")
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(5000, 5000)
	scene.add_child(player)
	var shade_script := load("res://scripts/world/trace_shade.gd")
	var water_script := load("res://scripts/world/water_level.gd")
	var valve_script := load("res://scripts/world/valve.gd")
	check(shade_script != null and water_script != null and valve_script != null, "shade_water_scripts_load")
	if shade_script == null or water_script == null or valve_script == null:
		player.queue_free()
		return
	# --- trace_shade (gercek) ---
	var shade: Node2D = Node2D.new()
	shade.set_script(shade_script)
	shade.shade_id = &"s_real"
	shade.waypoints = PackedVector2Array([Vector2(7000, 0), Vector2(7200, 0)])
	shade.speed = 200.0
	shade.wait_radius = 120.0
	shade.global_position = Vector2(6900, 0)
	scene.add_child(shade)
	shade.reached.connect(_on_reached)
	shade.start()
	await create_timer(1.0).timeout
	check(shade.global_position.distance_to(Vector2(7000, 0)) < 8.0 and _reached_ids.is_empty(), "shade_waits_at_first_waypoint_when_player_far")
	player.global_position = Vector2(7100, 0)
	await create_timer(1.2).timeout
	check(_reached_ids == [&"s_real"], "shade_reached_emitted_when_player_near")
	shade.start()
	await create_timer(3.0).timeout
	check(_reached_ids == [&"s_real"], "shade_start_after_done_does_not_re_emit")
	shade.queue_free()
	# --- trace_shade: son waypoint'te de bekler ---
	_reached_ids.clear()
	player.global_position = Vector2(5000, 5000)
	var sh2: Node2D = Node2D.new()
	sh2.set_script(shade_script)
	sh2.shade_id = &"s_last"
	sh2.waypoints = PackedVector2Array([Vector2(7000, 300)])
	sh2.speed = 400.0
	sh2.global_position = Vector2(6900, 300)
	scene.add_child(sh2)
	sh2.reached.connect(_on_reached)
	sh2.start()
	sh2.start()
	await create_timer(1.0).timeout
	check(_reached_ids.is_empty(), "shade_waits_at_last_waypoint_when_player_far")
	player.global_position = Vector2(7050, 300)
	await create_timer(0.5).timeout
	check(_reached_ids == [&"s_last"], "shade_reached_once_after_player_near_at_last")
	await create_timer(3.0).timeout
	check(_reached_ids == [&"s_last"], "shade_double_start_emits_once")
	sh2.queue_free()
	# --- trace_shade: bos waypoint ---
	_reached_ids.clear()
	var sh3: Node2D = Node2D.new()
	sh3.set_script(shade_script)
	sh3.shade_id = &"s_empty"
	scene.add_child(sh3)
	sh3.reached.connect(_on_reached)
	sh3.start()
	await create_timer(0.5).timeout
	check(_reached_ids.is_empty(), "shade_empty_waypoints_no_reached")
	sh3.queue_free()
	# --- trace_shade (sahte) ---
	_reached_ids.clear()
	var fake: Node2D = Node2D.new()
	fake.set_script(shade_script)
	fake.shade_id = &"s_fake"
	fake.fake = true
	fake.fake_line = "…Burada değildi."
	fake.waypoints = PackedVector2Array([Vector2(7000, 100)])
	fake.speed = 400.0
	fake.global_position = Vector2(6900, 100)
	player.global_position = Vector2(7000, 100)
	scene.add_child(fake)
	fake.reached.connect(_on_reached)
	fake.start()
	await create_timer(2.5).timeout
	check(_reached_ids.is_empty(), "fake_shade_does_not_emit_reached")
	check(is_instance_valid(fake) and not fake.visible, "fake_shade_faded_out")
	root.get_node("DialogueManager").clear()
	if is_instance_valid(fake):
		fake.queue_free()
	player.global_position = Vector2(5000, 5000)
	# --- water_level ---
	gs.world_memory_state["flags"].erase("p2w_level")
	var water: Node2D = Node2D.new()
	water.set_script(water_script)
	water.puzzle_key = &"p2w"
	water.level_y = PackedFloat32Array([400.0, 300.0, 200.0, 100.0])
	water.start_level = 1
	scene.add_child(water)
	water.level_changed.connect(_on_level)
	check(water.level == 1, "water_starts_at_start_level")
	water.step(1)
	water.step(1)
	water.step(1)
	check(water.level == 3, "water_clamps_at_3")
	water.step(-5)
	check(water.level == 1, "water_step_minus5_drain_closed_stops_at_1")
	water.set_drain(true)
	water.step(-1)
	check(water.level == 0, "water_drain_open_allows_level_0")
	water.set_drain(false)
	check(water.level == 1, "water_drain_closing_returns_to_1")
	check(_level_events.size() > 0 and _level_events[-1] == 1, "water_level_changed_emitted")
	var raft := water.get_node_or_null("Raft")
	check(raft is AnimatableBody2D and raft.sync_to_physics, "water_raft_animatable_sync")
	await create_timer(1.2).timeout
	check(raft != null and absf(raft.position.y - 300.0) < 1.0, "water_raft_tweens_to_level_y")
	# mid-tween: 300 -> 200
	water.step(1)
	await create_timer(0.2).timeout
	check(raft != null and raft.position.y < 299.0 and raft.position.y > 201.0, "water_raft_mid_tween")
	# step during tween -> ends at final level_y
	water.step(1)
	await create_timer(1.0).timeout
	check(water.level == 3 and absf(raft.position.y - 100.0) < 1.0, "water_step_during_tween_ends_at_final")
	water.step(-2)
	await create_timer(1.0).timeout
	check(water.level == 1 and absf(raft.position.y - 300.0) < 1.0, "water_back_to_1_after_tween_test")
	# valve
	var valve := Area2D.new()
	valve.set_script(valve_script)
	valve.delta = 1
	scene.add_child(valve)
	valve.water = valve.get_path_to(water)
	valve.on_interact(player)
	valve.on_interact(player)
	check(water.level == 2, "valve_interact_steps_water")
	check(water.level == 2, "valve_cooldown_blocks_second_step_same_frame")
	check(valve.has_method("on_interact") and valve.collision_layer == 8, "valve_uses_interact_convention")
	# kalicilik
	check(gs.get_world_flag(&"p2w_level", -1) == 2, "water_level_persisted_in_flag")
	var water2: Node2D = Node2D.new()
	water2.set_script(water_script)
	water2.puzzle_key = &"p2w"
	water2.level_y = PackedFloat32Array([400.0, 300.0, 200.0, 100.0])
	water2.start_level = 1
	scene.add_child(water2)
	check(water2.level == 2, "water_level_restored_from_flag")
	# clamp restore: flag 0 -> level 1
	gs.set_world_flag(&"p2w_level", 0)
	var water3: Node2D = Node2D.new()
	water3.set_script(water_script)
	water3.puzzle_key = &"p2w"
	water3.level_y = PackedFloat32Array([400.0, 300.0, 200.0, 100.0])
	scene.add_child(water3)
	check(water3.level == 1, "water_restore_flag_0_clamped_to_1")
	# short level_y: no crash, clamped index
	gs.world_memory_state["flags"].erase("p2s_level")
	var water4: Node2D = Node2D.new()
	water4.set_script(water_script)
	water4.puzzle_key = &"p2s"
	water4.level_y = PackedFloat32Array([400.0, 300.0])
	scene.add_child(water4)
	water4.step(1)
	water4.step(1)
	await create_timer(0.8).timeout
	var raft4 := water4.get_node_or_null("Raft")
	check(water4.level == 3 and raft4 != null and absf(raft4.position.y - 300.0) < 1.0, "water_short_level_y_clamps_index")
	gs.world_memory_state["flags"].erase("p2s_level")
	gs.world_memory_state["flags"].erase("p2w_level")
	for n in [water, water2, water3, water4, valve, player]:
		n.queue_free()


# ---------------------------------------------------------------- Oda 01-03
func _room_root(rid: StringName) -> Node:
	return (root.get_node("RoomManager")._rooms[rid] as Dictionary)["root"]


func _clear_corpses() -> void:
	var gs := root.get_node("GameState")
	(gs.world_memory_state["corpses"] as Array).clear()
	root.get_node("CorpseManager").rebuild_world_corpses()


func _unsolve(ids: Array) -> void:
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	for id in ids:
		pm.solved.erase(String(id))
		(gs.world_memory_state["puzzles"] as Dictionary).erase(String(id))
		pm.set_live(StringName(id), false)


func _rooms_01_03() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var cm := root.get_node("CorpseManager")
	var em := root.get_node("EchoManager")
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	# ---- 01 awakening ----
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.4).timeout
	var player: Node2D = current_scene.get_node("Player")
	var aw: Node = _room_root(&"awakening")
	var stone: Node = aw.find_child("WeightStone", true, false)
	var splate: Node = aw.find_child("PressurePlate", true, false)
	var cplate: Node = aw.find_child("CorpsePlate", true, false)
	var gate: Node = aw.find_child("DoorGate", true, false)
	var thorn: Node = aw.find_child("AwakeningThorn", true, false)
	var clock: Node = aw.find_child("ClockHint", true, false)
	check(stone != null and splate != null and cplate != null and gate != null, "aw_nodes_exist")
	check(thorn != null and thorn.is_in_group("blood_thorn"), "aw_thorn_exists")
	check(clock != null, "aw_clock_hint_exists")
	if stone == null or splate == null or cplate == null or gate == null:
		return
	check(float(stone.max_x) == 880.0 and float(stone.max_x) <= 1220.0 - 48.0, "aw_stone_max_x_880")
	check(cplate.accept_stone == false and cplate.accept_player == false, "aw_corpse_plate_corpse_only")
	check(cplate.puzzle_id == &"awakening_corpse_plate" and splate.puzzle_id == &"awakening_weight", "aw_plate_ids")
	check(Array(gate.puzzle_listen_all) == ["awakening_weight", "awakening_corpse_plate"] and gate.legacy_puzzle == &"awakening_weight", "aw_gate_listens_both_with_legacy")
	check(thorn != null and absf(float(thorn.anchor_x) - cplate.global_position.x) < 1.0 and thorn.puzzle_hint == &"awakening_corpse_plate", "aw_thorn_anchors_on_corpse_plate")
	var clock_ok := false
	if clock != null:
		clock_ok = clock.lines.size() >= 1
		for l in clock.lines:
			var t := String(l).get_slice("|", 1)
			if t.length() > 70 or not t.ends_with("."):
				clock_ok = false
	check(clock_ok, "aw_clock_hint_lines_le_70")
	# mantik: yalniz tas -> kapali; + ceset -> acik; legacy -> acik
	_clear_corpses()
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	gs.set_world_flag(&"awakening_door_opened", false)
	var home: Vector2 = stone.global_position
	player.global_position = Vector2(home.x - 300.0, home.y)
	stone.global_position = Vector2(splate.global_position.x, home.y)
	await create_timer(0.5).timeout
	check(pm.is_live(&"awakening_weight") and not gate._is_open(), "aw_stone_only_gate_closed")
	cm.record_corpse_at(Vector2(cplate.global_position.x, home.y), &"audit")
	await create_timer(0.5).timeout
	check(pm.is_live(&"awakening_corpse_plate") and gate._is_open(), "aw_stone_plus_corpse_gate_open")
	stone.global_position = home
	await create_timer(0.5).timeout
	check(not gate._is_open(), "aw_corpse_only_gate_closed")
	_clear_corpses()
	await create_timer(0.3).timeout
	pm.mark_solved(&"awakening_weight")
	check(gate._is_open(), "aw_legacy_solved_gate_open")
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	gs.set_world_flag(&"awakening_door_opened", false)
	# ---- 02 balcony ----
	rm.enter_room(&"awakening_balcony", &"default")
	await create_timer(0.4).timeout
	var bal: Node = _room_root(&"awakening_balcony")
	check(bal.find_child("SoulSeal", true, false) == null, "bal_no_soul_seal_node")
	var bad_req := false
	var gate_req := ""
	for d in bal.doors:
		var req := String(d.get("req", ""))
		if req == "soul_seal_balcony" or req.contains("soul_slash"):
			bad_req = true
		if float(d.get("x", 0.0)) == 920.0:
			gate_req = req
	check(not bad_req, "bal_no_soul_door_req")
	check(gate_req == "awakening_balcony_crossed", "bal_crypt_door_req_crossed")
	var tele: Node = bal.find_child("BalconyTelescope", true, false)
	check(tele != null and tele.echo_id == &"balcony_telescope", "bal_telescope_echo_point")
	var cat: Dictionary = em._catalog
	var tele_text := ""
	for pair in (cat.get("balcony_telescope", {}) as Dictionary).get("lines", []):
		tele_text += String(pair[1]) + " "
	check(cat.has("balcony_telescope") and tele_text.contains("üç"), "bal_telescope_echo_shows_first_digit")
	var obs: Node2D = bal.get_node_or_null("Spawns/keeper_observe")
	check(obs != null and obs.position.x >= 760.0, "bal_keeper_observe_clear_of_gap")
	var zone: Node2D = bal.find_child("CrossedZone", true, false)
	check(zone != null and zone.position.x >= 760.0, "bal_crossed_zone_beyond_gap")
	_unsolve(["awakening_balcony_crossed"])
	check(not pm.is_solved(&"awakening_balcony_crossed"), "bal_crossed_starts_unsolved")
	if zone != null:
		player.global_position = Vector2(300, 288)
		await create_timer(0.3).timeout
		check(not pm.is_solved(&"awakening_balcony_crossed"), "bal_crossed_not_before_gap")
		player.global_position = Vector2(zone.global_position.x, 288)
		await create_timer(0.4).timeout
		check(pm.is_solved(&"awakening_balcony_crossed"), "bal_crossed_solved_on_entry")
		player.global_position = Vector2(300, 288)
	# legacy: soul_seal_balcony cozulu kayit kapidan gecmeli
	_unsolve(["awakening_balcony_crossed"])
	(gs.world_memory_state["puzzles"] as Dictionary)["soul_seal_balcony"] = true
	pm.sync_from_world()
	check(pm.is_solved(&"awakening_balcony_crossed"), "bal_legacy_soul_seal_save_passes")
	_unsolve(["awakening_balcony_crossed", "soul_seal_balcony"])
	# ---- 03 crypt ----
	rm.enter_room(&"awakening_crypt", &"default")
	await create_timer(0.4).timeout
	var cr: Node = _room_root(&"awakening_crypt")
	var shrine: Node = cr.find_child("PagesShrine", true, false)
	check(shrine != null and shrine.puzzle_id == &"awakening_crypt_pages" and shrine.order.size() == 3, "crypt_shrine_order_3")
	var bed: Node = cr.find_child("BedPlate", true, false)
	check(bed != null and bed.puzzle_id == &"awakening_crypt_bed" and bed.accept_stone == false and bed.accept_player == false, "crypt_bed_plate_corpse_only")
	var shortcut_ok := false
	for d in cr.doors:
		if float(d.get("x", 0.0)) == 920.0:
			shortcut_ok = String(d.get("req", "")) == "decay_shilda_wall_broken" and String(d.get("to", "")) == "decay_shilda_wall"
	check(shortcut_ok, "crypt_x920_shortcut_unchanged")
	var tablet: Node = cr.find_child("RingTablet", true, false)
	var memory: Node = cr.find_child("BedMemory", true, false)
	check(tablet != null and tablet.requires_puzzle == &"awakening_crypt_pages", "crypt_tablet_gated_by_pages")
	check(memory != null and memory.requires_puzzle == &"awakening_crypt_bed" and memory.lines.size() >= 3, "crypt_memory_scene_gated_by_bed")
	if shrine != null:
		_unsolve(["awakening_crypt_pages"])
		var steps: Dictionary = {}
		for c in shrine.get_children():
			if "step_id" in c:
				steps[String(c.step_id)] = c
		var order: PackedStringArray = shrine.order
		var ok_steps := steps.size() == 3 and order.size() == 3
		if ok_steps:
			for s in order:
				if not steps.has(s):
					ok_steps = false
		check(ok_steps, "crypt_pages_three_steps_match_order")
		if ok_steps:
			# yanlis sira: sonuncuyu once bas -> cozulmez
			shrine.press(order[2], steps[order[2]])
			shrine.press(order[1], steps[order[1]])
			check(not pm.is_solved(&"awakening_crypt_pages"), "crypt_wrong_order_not_solved")
			for s in order:
				shrine.press(s, steps[s])
			check(pm.is_solved(&"awakening_crypt_pages"), "crypt_chronological_order_solves")
			# etiketler tarih tasir; order kronolojik
			var keys: Array = []
			var rx := RegEx.create_from_string("(\\d+) (\\S+) (\\d{4})")
			var months := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
			for s in order:
				var m := rx.search(String((steps[s] as Node).label))
				keys.append(int(m.get_string(3)) * 10000 + months.find(m.get_string(2)) * 100 + int(m.get_string(1)) if m else -1)
			check(keys.size() == 3 and keys[0] > 0 and keys[0] < keys[1] and keys[1] < keys[2], "crypt_order_is_chronological_by_label")
		_unsolve(["awakening_crypt_pages"])
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
