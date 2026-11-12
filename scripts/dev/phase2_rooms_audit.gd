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
	await _rooms_01_03_fix1()
	await _rooms_04_06()
	await _rooms_07_10()
	await _rooms_11_13()
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


## Gercek gecis: tas + ceset ile kapi acilir, oyuncu kapinin iki yanindan gecer; plaka gate_blocker
## yan degistirme mandalindan cozulur (mark_solved elle cagrilmaz). Basari = kapi acikti VE plaka cozuldu.
func _pass_corpse_gate() -> bool:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var cm := root.get_node("CorpseManager")
	_clear_corpses()
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	root.get_node("GameState").set_world_flag(&"awakening_door_opened", false)
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.4).timeout
	var aw := _room_root(&"awakening")
	var stone: Node2D = aw.find_child("WeightStone", true, false)
	var splate: Node2D = aw.find_child("PressurePlate", true, false)
	var cplate: Node2D = aw.find_child("CorpsePlate", true, false)
	var gate: Node2D = aw.find_child("DoorGate", true, false)
	var player: Node2D = current_scene.get_node("Player")
	if stone == null or splate == null or cplate == null or gate == null or player == null:
		return false
	var home: Vector2 = stone.global_position
	player.global_position = Vector2(gate.global_position.x - 100.0, home.y)
	stone.global_position = Vector2(splate.global_position.x, home.y)
	cm.record_corpse_at(Vector2(cplate.global_position.x, home.y), &"audit")
	await create_timer(0.5).timeout
	var was_open: bool = gate._is_open()
	player.global_position.x = gate.global_position.x - 40.0
	await create_timer(0.15).timeout
	player.global_position.x = gate.global_position.x + 40.0
	await create_timer(0.3).timeout
	var ok: bool = was_open and pm.is_solved(&"awakening_corpse_plate")
	stone.global_position = home
	_clear_corpses()
	_unsolve(["awakening_weight"])
	return ok


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


# ---------------------------------------------------------------- Oda 01-03 fix1
func _rooms_01_03_fix1() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var cm := root.get_node("CorpseManager")
	var dm := root.get_node("DialogueManager")
	dm.clear()
	# ---- balkon: sutun yuksekligi gercek fizik sabitleriyle ----
	rm.enter_room(&"awakening_balcony", &"default")
	await create_timer(0.4).timeout
	var bal: Node = _room_root(&"awakening_balcony")
	var pc: Dictionary = load("res://scripts/player/player_controller.gd").get_script_constant_map()
	var jump_v := absf(float(pc["JUMP_VELOCITY"]))
	var grav := float(pc["GRAVITY"])
	var apex := jump_v * jump_v / (2.0 * grav)
	var corpse_inst := (load("res://scenes/world/corpse.tscn") as PackedScene).instantiate()
	var ccs := corpse_inst.get_node("CollisionShape2D") as CollisionShape2D
	var corpse_top := -(ccs.position.y - (ccs.shape as RectangleShape2D).size.y / 2.0)
	corpse_inst.free()
	var floor_y := 288.0
	var pillars: Array = []
	for n in ["PillarNear", "PillarFar"]:
		var pn := bal.get_node_or_null(n) as StaticBody2D
		check(pn != null and pn.collision_layer == 1, "bal_%s_solid_layer1" % n)
		if pn == null:
			return
		var psz := ((pn.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		var h := floor_y - (pn.position.y - psz.y / 2.0)
		var edges := Vector2(pn.position.x - psz.x / 2.0, pn.position.x + psz.x / 2.0)
		pillars.append({"h": h, "edges": edges})
		check(h > apex + 4.0, "bal_%s_unreachable_without_corpse (H %.1f > apex %.1f)" % [n, h, apex])
		check(h < corpse_top + apex - 4.0, "bal_%s_reachable_with_corpse (H %.1f < %.1f)" % [n, h, corpse_top + apex - 4.0])
	var gap := Vector2(660.0, 724.0)
	check((pillars[0]["edges"] as Vector2).y <= gap.x and gap.x - (pillars[0]["edges"] as Vector2).y <= 8.0, "bal_near_pillar_directly_before_gap")
	check((pillars[1]["edges"] as Vector2).x >= gap.y and (pillars[1]["edges"] as Vector2).x - gap.y <= 8.0, "bal_far_pillar_directly_after_gap")
	var tn: Node = bal.find_child("StepThornNear", true, false)
	var tf: Node = bal.find_child("StepThornFar", true, false)
	check(tn != null and tf != null and tn.is_in_group("blood_thorn") and tf.is_in_group("blood_thorn"), "bal_both_step_thorns_exist")
	if tn != null and tf != null:
		var ne: Vector2 = pillars[0]["edges"]
		var fe: Vector2 = pillars[1]["edges"]
		check(tn.anchor_x < ne.x and ne.x - tn.anchor_x <= 24.0, "bal_near_thorn_anchor_within_24_of_pillar")
		check(tf.anchor_x > fe.y and tf.anchor_x - fe.y <= 24.0, "bal_far_thorn_anchor_within_24_of_pillar")
		check(tn.position.x < ne.x and tf.position.x > fe.y, "bal_thorns_on_correct_sides")
		check(tn.puzzle_hint != tf.puzzle_hint and not pm.is_solved(tf.puzzle_hint), "bal_far_thorn_not_blocked_by_crossed")
	var zone: Node2D = bal.find_child("CrossedZone", true, false)
	check(zone != null and zone.position.x >= 780.0, "bal_crossed_zone_x_ge_780")
	var obs: Node2D = bal.get_node_or_null("Spawns/keeper_observe")
	check(obs != null and obs.position.x >= 760.0, "bal_keeper_observe_still_clear")
	# ceset bosluga itilemez
	_clear_corpses()
	cm.record_corpse_at(Vector2(640, 288), &"audit")
	await create_timer(0.2).timeout
	var bc: Node2D = null
	for c in get_nodes_in_group("corpse"):
		bc = c as Node2D
	if bc != null:
		bc.global_position = Vector2(618, 288)
		bc._push(1.0, null)
		await create_timer(0.4).timeout
		check(bc.global_position.x < gap.x - 10.0, "bal_corpse_not_pushable_into_gap_or_pillar (x %.1f)" % bc.global_position.x)
	var tele: Node = bal.find_child("BalconyTelescope", true, false)
	var lore_tele: Node = bal.get_node_or_null("Interactive/Telescope")
	check(tele != null and lore_tele != null and tele.position.x >= 390.0 and absf(tele.position.x - lore_tele.position.x) >= 90.0, "bal_telescope_echo_x_ge_390_clear_of_lore")
	_clear_corpses()
	# ---- metinler ----
	var ids := [&"awakening_corpse_plate", &"awakening_balcony_crossed", &"awakening_crypt_pages", &"awakening_crypt_bed", &"awakening_weight"]
	var len_ok := true
	for id in ids:
		var hh: Dictionary = pm.get_hints(id)
		for k in ["goal", "orientation", "explicit"]:
			var tx := String(hh.get(k, ""))
			if tx.length() > 70 or tx.length() == 0:
				len_ok = false
				print("PHASE2 HINT too long/empty: ", id, " ", k, " ", tx.length())
		if not String(hh.get("explicit", "")).ends_with("."):
			len_ok = false
	check(len_ok, "hints_len_le_70_and_period")
	check(String(pm.get_hints(&"awakening_balcony_crossed")["explicit"]).contains("basamak"), "hint_balcony_mentions_step")
	check(not _objective("awakening_balcony").contains("köprüle"), "objective_balcony_no_bridge_wording")
	check(_objective("awakening_balcony").contains("basamak"), "objective_balcony_step_wording")
	# ---- hedef: legacy ceset adimi ----
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	gs.player_progress_knowledge["pocket_watch_seen"] = true
	var obj_fresh := _objective("awakening")
	check(obj_fresh.contains("bedenini plakaya bırak") and not obj_fresh.contains("cesedini"), "objective_aw_new_wording")
	pm.mark_solved(&"awakening_weight")
	var obj_legacy := _objective("awakening")
	check(not obj_legacy.contains("plakaya bırak"), "objective_aw_legacy_skips_corpse_step")
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	# ---- kripta metinleri ----
	rm.enter_room(&"awakening_crypt", &"default")
	await create_timer(0.3).timeout
	var cr: Node = _room_root(&"awakening_crypt")
	var shrine: Node = cr.find_child("PagesShrine", true, false)
	var tablet: Node = cr.find_child("RingTablet", true, false)
	var succ := String(shrine.success_line) if shrine != null else ""
	var tl := ""
	if tablet != null:
		tl = String(tablet.lines[0])
	check(succ.contains("Taşın kenarında bir rakam belirdi") and tl.contains("Taşın kenarında bir rakam belirdi"), "crypt_digit_wording_aligned")
	# ---- gercek dikenle ceset + plaka ----
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.5).timeout
	var player: Node2D = current_scene.get_node("Player")
	var aw: Node = _room_root(&"awakening")
	var thorn: Node = aw.find_child("AwakeningThorn", true, false)
	_clear_corpses()
	_unsolve(["awakening_weight", "awakening_corpse_plate"])
	gs.set_world_flag(&"awakening_door_opened", false)
	player.global_position = Vector2(thorn.global_position.x - 30.0, 288.0)
	await create_timer(0.3).timeout
	thorn.on_interact(player)
	dm.clear()
	check(thorn._armed, "thorn_first_interact_arms")
	thorn.on_interact(player)
	var live := false
	for i in 40:
		await create_timer(0.25).timeout
		if pm.is_live(&"awakening_corpse_plate"):
			live = true
			break
	check(live, "thorn_real_path_corpse_plate_live")
	var cs: Array = gs.world_memory_state["corpses"]
	var anchored_ok := cs.size() == 1 and bool((cs[0] as Dictionary).get("anchored", false)) and String((cs[0] as Dictionary).get("anchor_plate", "")) == "awakening_corpse_plate"
	check(anchored_ok, "thorn_real_path_corpse_anchored_to_plate (n=%d)" % cs.size())
	# ---- set_anchoring + setup_from_data ----
	var cn: Node2D = null
	for c in get_nodes_in_group("corpse"):
		cn = c as Node2D
	if cn != null:
		cn.set_anchoring(true, &"plate_A")
		cn.set_anchoring(false, &"plate_B")
		check(cn.is_anchored and cn._anchor_plate == &"plate_A", "anchoring_release_from_other_plate_ignored")
		cn.set_anchoring(false, &"plate_A")
		check(not cn.is_anchored and cn._anchor_plate == &"", "anchoring_release_from_own_plate_works")
		var d: Dictionary = (cn._data as Dictionary).duplicate()
		d["anchored"] = true
		d["anchor_plate"] = "plate_A"
		cn.setup_from_data(d)
		check(cn._anchor_plate == &"plate_A", "setup_from_data_restores_anchor_plate")
		cn.set_anchoring(false, &"plate_B")
		check(cn.is_anchored, "restored_anchor_plate_still_guards_release")
	# ---- kirpma ----
	_clear_corpses()
	_unsolve(["awakening_corpse_plate"])
	var ids3: Array = []
	for i in 3:
		ids3.append(cm.record_corpse_at(Vector2(300 + i * 40, 288), &"audit"))
		await create_timer(0.03).timeout
	var list: Array = gs.world_memory_state["corpses"]
	check(list.size() == 3, "trim_setup_three_corpses")
	(list[0] as Dictionary)["anchored"] = true
	(list[0] as Dictionary)["anchoring"] = true
	(list[0] as Dictionary)["anchor_plate"] = "awakening_corpse_plate"
	pm.mark_solved(&"awakening_corpse_plate")
	await create_timer(0.03).timeout
	cm.record_corpse_at(Vector2(460, 288), &"audit")
	var after_ids: Array = []
	for c in gs.world_memory_state["corpses"]:
		after_ids.append(String((c as Dictionary).get("id", "")))
	check(after_ids.size() == 3 and not after_ids.has(ids3[0]), "trim_evicts_anchor_of_solved_plate_first")
	# korunan: plaka cozulmemis -> ankrajli ceset kalir
	_clear_corpses()
	_unsolve(["awakening_corpse_plate"])
	ids3.clear()
	for i in 3:
		ids3.append(cm.record_corpse_at(Vector2(300 + i * 40, 288), &"audit"))
		await create_timer(0.03).timeout
	list = gs.world_memory_state["corpses"]
	(list[0] as Dictionary)["anchored"] = true
	(list[0] as Dictionary)["anchoring"] = true
	(list[0] as Dictionary)["anchor_plate"] = "awakening_corpse_plate"
	## Bekleme yok: plaka yoklaması sahte ankrajı (ceset plakada degil) bırakır.
	cm.record_corpse_at(Vector2(460, 288), &"audit")
	after_ids.clear()
	for c in gs.world_memory_state["corpses"]:
		after_ids.append(String((c as Dictionary).get("id", "")))
	check(after_ids.has(ids3[0]) and not after_ids.has(ids3[1]), "trim_keeps_anchor_of_unsolved_plate")
	_clear_corpses()
	_unsolve(["awakening_corpse_plate"])


func _shape_size(n: Node) -> Vector2:
	return ((n.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size


func _answer_vigil(dm: Node, answers: Array, keeper: Node) -> int:
	## Keeper konusmasini calistirir; ask() cikinca answers[i] secenegini secer. Secim sayisini dondurur.
	var made := [0]
	var on_made := func(_i): made[0] += 1
	dm.choice_made.connect(on_made)
	var done := [false]
	var runner := func():
		await keeper._run_vigil_meeting()
		done[0] = true
	runner.call()
	var guard := 0
	while not done[0] and guard < 900:
		guard += 1
		if dm.has_choices() and made[0] < answers.size():
			dm.choose_now(int(answers[made[0]]))
		elif dm.is_open and not dm.has_choices():
			dm.advance()
		await process_frame
	dm.choice_made.disconnect(on_made)
	return made[0]


func _drive_dialogue(flag: Array, dm: Node) -> void:
	var gd := 0
	while not flag[0] and gd < 600:
		gd += 1
		if dm.is_open:
			dm.advance()
		await process_frame


func _rooms_04_06() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var cm := root.get_node("CorpseManager")
	var dm := root.get_node("DialogueManager")
	var cu := root.get_node("CurseManager")
	dm.clear()
	_clear_corpses()
	# ---- 04 gecit ----
	rm.enter_room(&"awakening_passage", &"default")
	await create_timer(0.4).timeout
	var pas: Node = _room_root(&"awakening_passage")
	check(is_equal_approx((pas.bounds as Rect2).size.x, 1500.0), "pas_room_width_1500")
	var exit_seal: Node2D = pas.find_child("ExitToSeal", true, false)
	check(exit_seal != null and exit_seal.position.x <= 1460.0, "pas_exit_x_le_1460")
	check(exit_seal != null and exit_seal.required_puzzle == &"awakening_passage_rings", "pas_exit_requires_rings")
	var from_seal: Node2D = pas.get_node_or_null("Spawns/from_seal")
	check(from_seal != null and from_seal.position.x < 1460.0 and from_seal.position.x > 1300.0, "pas_from_seal_spawn_inside_room")
	var shrine: Node = pas.find_child("RingShrine", true, false)
	check(shrine != null and shrine.is_in_group("sequence_shrine"), "pas_ring_shrine_exists")
	if shrine != null:
		check(Array(shrine.order) == ["3", "1", "4"], "pas_shrine_order_314")
		check(shrine.puzzle_id == &"awakening_passage_rings", "pas_shrine_puzzle_id")
		check(String(shrine.fail_line) != "", "pas_shrine_fail_line")
		var sids: Array = []
		for ch in shrine.get_children():
			if "step_id" in ch:
				sids.append(String(ch.step_id))
				check((ch as Node2D).position.x < exit_seal.position.x - 20.0, "pas_ring_%s_before_exit" % String(ch.step_id))
		sids.sort()
		check(sids == ["1", "3", "4"], "pas_ring_steps_134")
		_unsolve(["awakening_passage_rings"])
		dm.clear()
		var steps_by_id := {}
		for ch in shrine.get_children():
			if "step_id" in ch:
				steps_by_id[String(ch.step_id)] = ch
		if steps_by_id.size() == 3:
			shrine.press("3", steps_by_id["3"])
			check(shrine.get_progress() == 1, "pas_ring_press3_progress_1")
			shrine.press("4", steps_by_id["4"])
			var lit_any := false
			for k in steps_by_id:
				if steps_by_id[k]._lit:
					lit_any = true
			check(shrine.get_progress() == 0 and not lit_any and (dm.is_open or dm._queue.size() > 0), "pas_ring_wrong_order_resets_and_fails")
			dm.clear()
			check(not pm.is_solved(&"awakening_passage_rings"), "pas_ring_wrong_order_not_solved")
	var echo_n := 0
	for ch in pas.get_node("Interactive").get_children():
		if ch.has_method("get_interact_label") and "echo_id" in ch:
			echo_n += 1
	check(echo_n == 1 and pas.find_child("OwnVoice", true, false) == null, "pas_single_echo_point_ownvoice_merged")
	var echo_src := FileAccess.get_file_as_string("res://scripts/autoload/echo_manager.gd")
	check(echo_src.contains("Unutmuşum ama oda unutmamış") and echo_src.contains("kendi sesim"), "pas_ownvoice_lines_in_echo")
	var pcs: Dictionary = load("res://scripts/player/player_controller.gd").get_script_constant_map()
	var jv := absf(float(pcs["JUMP_VELOCITY"]))
	var g := float(pcs["GRAVITY"])
	var apex := jv * jv / (2.0 * g)
	var ci := (load("res://scenes/world/corpse.tscn") as PackedScene).instantiate()
	var ccs := ci.get_node("CollisionShape2D") as CollisionShape2D
	var ctop := -(ccs.position.y - (ccs.shape as RectangleShape2D).size.y / 2.0)
	ci.free()
	var hi: StaticBody2D = pas.get_node_or_null("LessonStepHigh")
	check(hi != null, "pas_high_step_exists")
	if hi != null:
		var hsz := _shape_size(hi)
		var hh := 288.0 - (hi.position.y - hsz.y / 2.0)
		check(hh > apex + 4.0, "pas_high_step_unreachable_without_corpse (H %.1f > apex %.1f)" % [hh, apex])
		check(hh < ctop + apex - 4.0, "pas_high_step_reachable_with_corpse (H %.1f < %.1f)" % [hh, ctop + apex - 4.0])
		var left_edge := hi.position.x - hsz.x / 2.0
		var pth: Node = pas.find_child("StepThorn", true, false)
		check(pth != null and pth.is_in_group("blood_thorn"), "pas_step_thorn_exists")
		if pth != null:
			check(pth.anchor_x < left_edge and left_edge - pth.anchor_x <= 24.0, "pas_thorn_anchor_within_24_of_step")
			check(pth.position.x < pth.anchor_x and not pm.is_solved(pth.puzzle_hint), "pas_thorn_before_anchor_unsolved_hint")
		var mass: StaticBody2D = pas.get_node_or_null("LessonMass")
		if mass != null:
			var mh := 288.0 - (mass.position.y - _shape_size(mass).y / 2.0)
			check(mh <= apex - 4.0, "pas_mass_jumpable_without_corpse")
	# ---- 05 muhur ----
	_unsolve(["awakening_seal_weight", "awakening_seal_second", "awakening_memory_code"])
	rm.enter_room(&"awakening_seal", &"default")
	await create_timer(0.4).timeout
	var seal: Node = _room_root(&"awakening_seal")
	var p1: Node = seal.find_child("PressurePlate", true, false)
	var p2: Node = seal.find_child("PressurePlate2", true, false)
	check(p1 != null and p2 != null, "seal_two_plates_exist")
	if p1 != null and p2 != null:
		check(p1.accept_stone == false and p2.accept_stone == false, "seal_both_plates_corpse_only_stone_off")
		check(p1.accept_player == false and p2.accept_player == false, "seal_both_plates_player_off")
		check(p1.puzzle_id == &"awakening_seal_weight" and p2.puzzle_id == &"awakening_seal_second", "seal_plate_ids")
		check(absf(p1.position.x - p2.position.x) >= 80.0, "seal_plates_far_apart")
	var sg: Node = seal.find_child("SideGate", true, false)
	check(sg != null and Array(sg.puzzle_listen_all) == ["awakening_seal_weight", "awakening_seal_second"] and sg.legacy_puzzle == &"awakening_seal_weight", "seal_gate_listens_both_with_legacy")
	var thorns: Array = []
	for t in get_nodes_in_group("blood_thorn"):
		if seal.is_ancestor_of(t):
			thorns.append(t)
	check(thorns.size() == 2, "seal_two_thorns")
	if p1 != null and p2 != null and thorns.size() == 2:
		var anchors: Array = [float(thorns[0].anchor_x), float(thorns[1].anchor_x)]
		anchors.sort()
		var plates: Array = [float(p1.position.x), float(p2.position.x)]
		plates.sort()
		check(absf(anchors[0] - plates[0]) < 1.0 and absf(anchors[1] - plates[1]) < 1.0, "seal_thorn_anchors_on_plates")
		var hints: Array = [String(thorns[0].puzzle_hint), String(thorns[1].puzzle_hint)]
		hints.sort()
		check(hints == ["awakening_seal_second", "awakening_seal_weight"], "seal_thorn_hints_per_plate")
	var mseal: Node = seal.find_child("MemorySeal", true, false)
	check(mseal != null and mseal.penalize_wrong == true, "seal_memory_seal_penalizes_wrong")
	check(pm.get_hints(&"awakening_seal_second").size() > 0, "seal_second_plate_hints")
	if mseal != null:
		var stub := Node.new()
		stub.set_script(load("res://scripts/dev/seal_hud_stub.gd"))
		root.add_child(stub)
		## Gercek HUD gruptan gecici cikar (get_first_node_in_group stub'i bulsun), title katmani kapat.
		var real_huds: Array = get_nodes_in_group("hud")
		for h in real_huds:
			h.remove_from_group("hud")
		stub.add_to_group("hud")
		var title0: bool = root.get_node("UiGate")._title
		root.get_node("UiGate").set_title(false)
		var curse0: float = cu.curse
		stub.next_code = "999"
		var run1 := [false]
		var r1 := func():
			await mseal.on_interact(null)
			run1[0] = true
		r1.call()
		await _drive_dialogue(run1, dm)
		check(cu.curse > curse0 and not pm.is_solved(&"awakening_memory_code"), "seal_wrong_code_penalizes_curse_unsolved")
		stub.next_code = "314"
		run1[0] = false
		r1.call()
		await _drive_dialogue(run1, dm)
		check(pm.is_solved(&"awakening_memory_code"), "seal_right_code_314_solves")
		stub.queue_free()
		root.get_node("UiGate").set_title(title0)
		for h in real_huds:
			if is_instance_valid(h):
				h.add_to_group("hud")
		_unsolve(["awakening_memory_code"])
	# iki ceset butcesi: eski cesetler iki muhur cesedini asla atmaz
	_clear_corpses()
	_unsolve(["awakening_corpse_plate", "awakening_seal_weight", "awakening_seal_second"])
	for i in 3:
		cm.record_corpse_at(Vector2(100 + i * 30, 288), &"audit")
		await create_timer(0.03).timeout
	var lst: Array = gs.world_memory_state["corpses"]
	for e in lst:
		(e as Dictionary)["anchored"] = true
		(e as Dictionary)["anchoring"] = true
		(e as Dictionary)["anchor_plate"] = "awakening_corpse_plate"
	var passed: bool = await _pass_corpse_gate()
	check(passed and pm.is_solved(&"awakening_corpse_plate"), "seal_corpse_plate_solved_by_gate_pass_through")
	rm.enter_room(&"awakening_seal", &"default")
	await create_timer(0.3).timeout
	_clear_corpses()
	for i in 3:
		cm.record_corpse_at(Vector2(100 + i * 30, 288), &"audit")
		await create_timer(0.03).timeout
	lst = gs.world_memory_state["corpses"]
	for e in lst:
		(e as Dictionary)["anchored"] = true
		(e as Dictionary)["anchoring"] = true
		(e as Dictionary)["anchor_plate"] = "awakening_corpse_plate"
	var sid1: String = cm.record_corpse_at(Vector2(330, 288), &"audit")
	lst = gs.world_memory_state["corpses"]
	for e in lst:
		if String((e as Dictionary).get("id", "")) == sid1:
			(e as Dictionary)["anchored"] = true
			(e as Dictionary)["anchoring"] = true
			(e as Dictionary)["anchor_plate"] = "awakening_seal_weight"
	await create_timer(0.03).timeout
	var sid2: String = cm.record_corpse_at(Vector2(440, 288), &"audit")
	lst = gs.world_memory_state["corpses"]
	var ids_now: Array = []
	for e in lst:
		ids_now.append(String((e as Dictionary).get("id", "")))
	check(ids_now.has(sid1) and ids_now.has(sid2) and lst.size() <= cm.MAX_CORPSES, "seal_two_corpses_within_cap_neither_trimmed")
	_clear_corpses()
	_unsolve(["awakening_corpse_plate"])
	# ---- 06 nobet ----
	var keepers := get_nodes_in_group("keeper")
	var keeper: Node = keepers[0] if keepers.size() > 0 else null
	check(keeper != null, "vigil_keeper_exists")
	gs.player_progress_knowledge.erase("vigil_answers")
	gs.player_progress_knowledge.erase("vigil_talk_done")
	gs.player_progress_knowledge.erase("vigil_parted")
	gs.player_progress_knowledge["vigil_trust"] = 0
	_unsolve(["awakening_vigil", "awakening_vigil_trace"])
	rm.enter_room(&"awakening_vigil", &"default")
	await create_timer(0.5).timeout
	var vig: Node = _room_root(&"awakening_vigil")
	var shades_root: Node = vig.find_child("VigilShades", true, false)
	check(shades_root != null, "vigil_shades_root_exists")
	var shades: Array = []
	if shades_root != null:
		for ch in shades_root.get_children():
			if ch.has_method("start") and "fake" in ch:
				shades.append(ch)
	var nfake := 0
	var real: Node = null
	var fake_s: Node = null
	for s in shades:
		if s.fake:
			nfake += 1
			fake_s = s
		else:
			real = s
	check(shades.size() == 3 and nfake >= 1 and nfake < 3, "vigil_three_shades_with_fake (%d/%d)" % [nfake, shades.size()])
	check(real != null and fake_s != null, "vigil_real_and_fake_found")
	var running := false
	for s in shades:
		if s._running:
			running = true
	check(not running, "vigil_shades_idle_before_talk")
	if keeper != null and real != null and fake_s != null:
		var n_made: int = await _answer_vigil(dm, [0, 1, 0], keeper)
		check(n_made == 3, "vigil_three_questions_asked (%d)" % n_made)
		check(gs.get_vigil_trust() == 1, "vigil_trust_plus1_minus1_plus1 (%d)" % gs.get_vigil_trust())
		check(bool(gs.player_progress_knowledge.get("vigil_talk_done", false)), "vigil_talk_done_flag")
		check(not pm.is_solved(&"awakening_vigil"), "vigil_talk_alone_does_not_solve")
		var any_running := false
		for s in shades:
			if s._running:
				any_running = true
		check(any_running, "vigil_shades_start_after_talk")
		real.reached.emit(&"vigil_decoy_probe")
		await process_frame
		check(not pm.is_solved(&"awakening_vigil_trace"), "vigil_unknown_shade_id_does_not_solve")
		fake_s.reached.emit(fake_s.shade_id)
		await process_frame
		check(not pm.is_solved(&"awakening_vigil_trace") and not pm.is_solved(&"awakening_vigil"), "vigil_fake_reached_does_not_solve")
		real.reached.emit(real.shade_id)
		await create_timer(0.1).timeout
		check(pm.is_solved(&"awakening_vigil_trace") and pm.is_solved(&"awakening_vigil"), "vigil_real_shade_solves_trace_and_vigil")
		check(bool(gs.player_progress_knowledge.get("vigil_parted", false)), "vigil_parted_after_solve")
		var n2: int = await _answer_vigil(dm, [1, 1, 1], keeper)
		check(n2 == 0 and gs.get_vigil_trust() == 1, "vigil_not_asked_again_after_done")
		rm.enter_room(&"awakening_seal", &"default")
		await create_timer(0.3).timeout
		rm.enter_room(&"awakening_vigil", &"default")
		await create_timer(0.4).timeout
		var again := false
		var vig2: Node = _room_root(&"awakening_vigil")
		var sr2: Node = vig2.find_child("VigilShades", true, false) if vig2 != null else null
		if sr2 != null:
			for s in sr2.get_children():
				if "_running" in s and s._running:
					again = true
		check(not again, "vigil_trace_solved_shades_not_restarted")
		gs.player_progress_knowledge["vigil_answers"] = [0]
		gs.player_progress_knowledge.erase("vigil_talk_done")
		gs.player_progress_knowledge.erase("vigil_parted")
		gs.player_progress_knowledge["vigil_trust"] = 1
		_unsolve(["awakening_vigil", "awakening_vigil_trace"])
		var n3: int = await _answer_vigil(dm, [0, 0], keeper)
		check(n3 == 2 and (gs.player_progress_knowledge["vigil_answers"] as Array).size() == 3, "vigil_resumes_remaining_questions (%d)" % n3)
		gs.player_progress_knowledge.erase("vigil_answers")
		gs.player_progress_knowledge.erase("vigil_talk_done")
		_unsolve(["awakening_vigil_trace"])
		pm.mark_solved(&"awakening_vigil")
		var n4: int = await _answer_vigil(dm, [0, 0, 0], keeper)
		check(n4 == 0 and pm.is_solved(&"awakening_vigil"), "vigil_legacy_solved_stays_solved_no_questions")
	# varsayilan headless otomatik ilerleme: ask() secenek 0'i secer, takilmaz
	gs.player_progress_knowledge.erase("vigil_answers")
	gs.player_progress_knowledge.erase("vigil_talk_done")
	gs.player_progress_knowledge.erase("vigil_parted")
	gs.player_progress_knowledge["vigil_trust"] = 0
	_unsolve(["awakening_vigil", "awakening_vigil_trace"])
	if keeper != null:
		var env0: String = OS.get_environment("TORIMON_NO_AUTO_DIALOGUE")
		OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "")
		dm.clear()
		var auto_done := [false]
		var ar := func():
			await keeper._run_vigil_meeting()
			auto_done[0] = true
		ar.call()
		var ag := 0
		while not auto_done[0] and ag < 900:
			ag += 1
			await process_frame
		OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", env0)
		check(auto_done[0] and gs.get_vigil_trust() == 3 and bool(gs.player_progress_knowledge.get("vigil_talk_done", false)), "vigil_headless_auto_picks_option0_no_softlock (trust %d)" % gs.get_vigil_trust())
	# vigil kancasi: konusma bayragi + iz cozumu, toplanti calismadan nobeti kapatir
	if keeper != null:
		var hk0: int = pm.puzzle_solved.get_connections().size()
		keeper._vigil_hook()
		check(pm.puzzle_solved.get_connections().size() == hk0 and bool(keeper._vigil_hooked), "vigil_hook_connected_once_idempotent")
		_unsolve(["awakening_vigil", "awakening_vigil_trace"])
		gs.player_progress_knowledge.erase("vigil_parted")
		gs.player_progress_knowledge["vigil_talk_done"] = true
		rm.enter_room(&"awakening_vigil", &"default")
		await create_timer(0.4).timeout
		pm.mark_solved(&"awakening_vigil_trace")
		await create_timer(0.1).timeout
		check(pm.is_solved(&"awakening_vigil") and bool(gs.player_progress_knowledge.get("vigil_parted", false)), "vigil_trace_after_talk_finishes_without_meeting")
		# eski kayit: nobet cozuluyse golgeler kurulmaz
		_unsolve(["awakening_vigil_trace"])
		var legacy := Node2D.new()
		legacy.set_script(load("res://scripts/world/vigil_shades.gd"))
		root.add_child(legacy)
		await process_frame
		check(legacy.get_child_count() == 0, "vigil_shades_not_spawned_when_vigil_solved_legacy")
		legacy.queue_free()
		_unsolve(["awakening_vigil"])
		gs.player_progress_knowledge.erase("vigil_talk_done")
		gs.player_progress_knowledge.erase("vigil_parted")
	for id in [&"awakening_passage_rings", &"awakening_seal_weight", &"awakening_seal_second", &"awakening_vigil_trace"]:
		var hh2: Dictionary = pm.get_hints(id)
		var ok := hh2.size() > 0
		for k in ["goal", "orientation", "explicit"]:
			var tx := String(hh2.get(k, ""))
			if tx.length() > 70 or tx.length() == 0:
				ok = false
		check(ok and String(hh2.get("explicit", "")).ends_with("."), "hints_%s_len_ok" % String(id))
	check(_objective("awakening_passage").length() > 0 and _objective("awakening_vigil").length() > 0, "objectives_nonempty")
	_clear_corpses()
	_unsolve(["awakening_vigil", "awakening_vigil_trace"])
	dm.clear()


## Kapi gecisi: oyuncu kapinin bir yanindan oteki yanina gecer (gate_blocker yan degistirme mandali).
func _cross(gate: Node2D) -> void:
	var player: Node2D = current_scene.get_node("Player")
	player.global_position = Vector2(gate.global_position.x - 40.0, player.global_position.y)
	await create_timer(0.15).timeout
	player.global_position.x = gate.global_position.x + 40.0
	await create_timer(0.3).timeout


func _corpse_at(x: float, y: float, flower: bool = false) -> void:
	var gs := root.get_node("GameState")
	gs.character_current_life_knowledge["flower_in_hand"] = flower
	root.get_node("CorpseManager").record_corpse_at(Vector2(x, y), &"audit")
	gs.character_current_life_knowledge["flower_in_hand"] = false


func _rooms_07_10() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	dm.clear()
	_clear_corpses()
	# ---- 07 sarmasik ----
	_unsolve(["decay_vines", "decay_vine_shortcut"])
	gs.set_world_flag(&"decay_vine_open", false)
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.4).timeout
	var vr: Node = _room_root(&"decay_vines")
	var vgate: Node2D = vr.find_child("ShortcutBlock", true, false)
	var glass: Node2D = vr.find_child("FloorHazard", true, false)
	var lever: Node2D = vr.find_child("VineLever", true, false)
	var fsrc: Node = vr.find_child("FlowerSource", true, false)
	check(fsrc != null and fsrc.has_method("on_interact"), "vines_flower_source_exists")
	check(glass != null and bool(glass.lethal), "vines_glass_hazard_lethal")
	check(vgate != null and glass != null and absf(glass.position.x - vgate.position.x) <= 100.0 and glass.position.x < vgate.position.x, "vines_glass_right_before_gate")
	check(lever != null and vgate != null and lever.position.x > vgate.position.x, "vines_lever_beyond_gate_return_shortcut")
	check(vgate != null and not vgate._is_open(), "vines_gate_closed_initially")
	if vgate != null:
		var gy := vgate.global_position.y + 40.0
		_corpse_at(vgate.global_position.x - 200.0, gy, true)
		await create_timer(0.6).timeout
		check(not pm.is_solved(&"decay_vines") and not vgate._is_open(), "vines_flower_corpse_200px_does_not_burn")
		_corpse_at(vgate.global_position.x - 50.0, gy, false)
		await create_timer(0.6).timeout
		check(not pm.is_solved(&"decay_vines"), "vines_plain_corpse_50px_does_not_burn")
		_corpse_at(vgate.global_position.x - 50.0, gy, true)
		await create_timer(0.6).timeout
		check(pm.is_solved(&"decay_vines") and vgate._is_open() and bool(gs.get_world_flag(&"decay_vine_open", false)), "vines_flower_corpse_50px_burns_vine")
		_clear_corpses()
		_unsolve(["decay_vines"])
		gs.set_world_flag(&"decay_vine_open", false)
		check(not vgate._is_open(), "vines_gate_closes_again_for_legacy_test")
		pm.mark_solved(&"decay_vine_shortcut")
		check(vgate._is_open(), "vines_legacy_shortcut_puzzle_opens_gate")
		_unsolve(["decay_vine_shortcut"])
		gs.set_world_flag(&"decay_vine_open", true)
		check(vgate._is_open(), "vines_legacy_flag_opens_gate")
		gs.set_world_flag(&"decay_vine_open", false)
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src.contains('"x": 896.0, "to": "decay_catacombs"'), "vines_catacombs_side_door_896_kept")
	check(vgate != null and 896.0 > vgate.position.x, "vines_catacombs_door_beyond_gate")
	_clear_corpses()
	# ---- 08 agirlik ----
	_unsolve(["decay_weight_latch", "decay_weight_corpse"])
	gs.set_world_flag(&"decay_weight_latched", false)
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.4).timeout
	var wr: Node = _room_root(&"decay_weight")
	var pgate: Node2D = wr.find_child("PathGate", true, false)
	var wstone: Node2D = wr.find_child("WeightStone", true, false)
	var wexit: Node2D = wr.find_child("ExitToGarden", true, false)
	var cplate: Node2D = null
	for n in wr.find_children("*", "Area2D", true, false):
		if n.is_in_group("pressure_plate") and n.puzzle_id == &"decay_weight_corpse":
			cplate = n
	check(cplate != null and not cplate.accept_player and not cplate.accept_stone, "weight_corpse_plate_corpse_only")
	var wthorn: Node2D = null
	for n in wr.find_children("*", "Area2D", true, false):
		if n.is_in_group("blood_thorn"):
			wthorn = n
	check(wthorn != null and cplate != null and is_equal_approx(wthorn.anchor_x, cplate.position.x), "weight_thorn_anchors_on_corpse_plate")
	check(pgate != null and Array(pgate.puzzle_listen_all) == ["decay_weight_latch", "decay_weight_corpse"] and pgate.legacy_puzzle == &"decay_weight_latch", "weight_gate_listens_both_with_legacy")
	check(pgate != null and not pgate._is_open(), "weight_gate_closed_initially")
	check(wstone != null and wexit != null and wstone.max_x <= wexit.position.x - 48.0 and is_equal_approx(wstone.max_x, 862.0), "weight_stone_max_x_le_exit_minus_48")
	if pgate != null:
		pm.set_live(&"decay_weight_latch", true)
		check(not pgate._is_open(), "weight_latch_alone_keeps_gate_closed")
		pm.set_live(&"decay_weight_latch", false)
		pm.mark_solved(&"decay_weight_latch")
		check(pgate._is_open(), "weight_gate_open_via_legacy_latch_solved")
		_unsolve(["decay_weight_latch"])
		gs.set_world_flag(&"decay_weight_latched", false)
		check(not pgate._is_open(), "weight_gate_closes_after_unsolve")
	_clear_corpses()
	# ---- 09 sera ----
	_unsolve(["decay_greenhouse", "decay_greenhouse_pot", "decay_greenhouse_wrong_1", "decay_greenhouse_wrong_2"])
	rm.enter_room(&"decay_greenhouse", &"default")
	await create_timer(0.4).timeout
	var gr: Node = _room_root(&"decay_greenhouse")
	var plates: Array = []
	var any_player_plate := false
	for n in gr.find_children("*", "Area2D", true, false):
		if n.is_in_group("pressure_plate"):
			plates.append(n)
			if n.accept_player or n.latch_on_press:
				any_player_plate = true
	check(plates.size() == 3 and not any_player_plate, "greenhouse_three_corpse_only_plates")
	var right: Node2D = null
	var wrong: Node2D = null
	for pl in plates:
		if pl.puzzle_id == &"decay_greenhouse_pot":
			right = pl
		elif wrong == null:
			wrong = pl
	var ggate: Node2D = gr.find_child("ExitGate", true, false)
	check(right != null and wrong != null and ggate != null, "greenhouse_pots_and_gate_exist")
	if right != null and wrong != null and ggate != null:
		check(Array(ggate.puzzle_listen_all) == ["decay_greenhouse_pot"] and ggate.legacy_puzzle == &"decay_greenhouse", "greenhouse_gate_listens_pot_with_legacy")
		check(not ggate._is_open(), "greenhouse_gate_closed_initially")
		var py := right.global_position.y
		_corpse_at(wrong.global_position.x, py)
		await create_timer(0.6).timeout
		check(not ggate._is_open() and not pm.is_solved(&"decay_greenhouse"), "greenhouse_wrong_pot_keeps_gate_closed")
		_clear_corpses()
		await create_timer(0.3).timeout
		_corpse_at(right.global_position.x, py)
		await create_timer(0.6).timeout
		check(ggate._is_open(), "greenhouse_right_pot_opens_gate")
		await _cross(ggate)
		check(pm.is_solved(&"decay_greenhouse") and pm.is_solved(&"decay_greenhouse_pot"), "greenhouse_pass_through_marks_legacy_and_pot")
		_clear_corpses()
		await create_timer(0.3).timeout
		_unsolve(["decay_greenhouse", "decay_greenhouse_pot"])
		await create_timer(0.2).timeout
		check(not ggate._is_open(), "greenhouse_gate_closes_after_unsolve")
		pm.mark_solved(&"decay_greenhouse")
		check(ggate._is_open(), "greenhouse_gate_open_via_legacy_solved")
		_unsolve(["decay_greenhouse"])
	var shade_n := 0
	for n in gr.find_children("*", "Node2D", true, false):
		if n.is_in_group("greenhouse_shade"):
			shade_n += 1
	check(shade_n == 1, "greenhouse_trace_shade_spawned_when_unsolved")
	pm.mark_solved(&"decay_greenhouse")
	var skip := Node2D.new()
	skip.set_script(load("res://scripts/world/greenhouse_pots.gd"))
	root.add_child(skip)
	await process_frame
	check(skip.get_child_count() == 0, "greenhouse_shade_skipped_when_legacy_solved")
	skip.queue_free()
	_unsolve(["decay_greenhouse"])
	var inscr: Node = gr.find_child("WallInscription", true, false)
	check(inscr != null and "lines" in inscr and inscr.lines.size() >= 2, "greenhouse_wall_inscription_lore")
	if inscr != null and "lines" in inscr:
		var itxt := " ".join(PackedStringArray(inscr.lines))
		check(itxt.contains("yedi") and itxt.contains("iki") and itxt.contains("dokuz") and not itxt.contains("729"), "greenhouse_inscription_flower_imagery_7_2_9")
	_clear_corpses()
	# ---- 10 shilda duvari ----
	rm.enter_room(&"decay_shilda_wall", &"default")
	await create_timer(0.4).timeout
	var sr: Node = _room_root(&"decay_shilda_wall")
	var cloud: Node2D = null
	for n in sr.find_children("*", "Area2D", true, false):
		if n.is_in_group("curse_cloud"):
			cloud = n
	check(cloud != null, "wall_curse_cloud_exists")
	var curse_max := float(root.get_node("CurseManager").CURSE_MAX)
	var walk_speed := float(load("res://scripts/player/player_controller.gd").get_script_constant_map()["SPEED"])
	if cloud != null:
		var cx0: float = cloud.position.x - cloud.size.x * 0.5
		var cx1: float = cloud.position.x + cloud.size.x * 0.5
		check(cx0 >= 190.0 and cx1 <= 490.0 and cx1 - cx0 >= 240.0, "wall_cloud_spans_x200_480")
		var cost: float = cloud.size.x / walk_speed * cloud.curse_per_second
		print("PHASE2 INFO wall_cloud walk_speed=%.1f width=%.1f cps=%.1f cost=%.1f/%.0f" % [walk_speed, cloud.size.x, cloud.curse_per_second, cost, curse_max])
		check(cost >= curse_max * 0.6 and cost < curse_max, "wall_cloud_straight_walk_cost_60_to_99_percent")
		_corpse_at(cloud.position.x, cloud.position.y)
		await create_timer(0.4).timeout
		var shielded := maxf(cloud.size.x - 2.0 * cloud.safe_radius, 0.0)
		var cost_shield: float = shielded / walk_speed * cloud.curse_per_second
		check(cost_shield <= curse_max * 0.15, "wall_cloud_corpse_shield_makes_walk_cheap")
		var pl2: Node2D = current_scene.get_node("Player")
		check(cloud._is_safe(Vector2(cloud.position.x + cloud.safe_radius - 10.0, pl2.global_position.y)) and not cloud._is_safe(Vector2(cx1 - 5.0, pl2.global_position.y)), "wall_cloud_corpse_shield_live_check")
		_clear_corpses()
		var wthorn2: Node2D = null
		for n in sr.find_children("*", "Area2D", true, false):
			if n.is_in_group("blood_thorn"):
				wthorn2 = n
		check(wthorn2 != null and wthorn2.position.x < cx0 and wthorn2.anchor_x > cx0 and wthorn2.anchor_x < cx1, "wall_thorn_before_cloud_drops_corpse_inside")
	# ---- fix1: dikenler silahli, benzersiz ipucu, eski gunluk ipucu, bulut erisimi ----
	var earlier: Array = ["awakening_weight", "awakening_corpse_plate", "awakening_balcony_crossed", "balcony_step_near", "balcony_step_far", "awakening_crypt_pages", "awakening_crypt_bed", "awakening_passage_rings", "awakening_memory_code", "passage_step_high", "awakening_seal_weight", "awakening_seal_second", "awakening_vigil_trace", "decay_vines", "decay_weight_latch", "decay_weight_corpse"]
	for eid in earlier:
		pm.mark_solved(StringName(eid))
	var hint_seen: Dictionary = {}
	var dup_hint := false
	for rid2 in ["decay_vines", "decay_weight", "decay_greenhouse", "decay_shilda_wall", "decay_garden", "decay_catacombs", "decay_cistern"]:
		if not (root.get_node("RoomManager")._rooms as Dictionary).has(StringName(rid2)):
			check(false, "thorn_room_loaded_%s" % rid2)
			continue
		var rr: Node = _room_root(StringName(rid2))
		for t in rr.find_children("*", "Area2D", true, false):
			if t.is_in_group("blood_thorn"):
				if hint_seen.has(t.puzzle_hint):
					dup_hint = true
				hint_seen[t.puzzle_hint] = true
	check(not dup_hint, "thorns_0710_unique_puzzle_hints")
	var armed_nodes: Array = []
	var wt: Node = sr.find_child("WallThorn", true, false)
	var ta: Node = gr.find_child("ThornA", true, false)
	var tc: Node = gr.find_child("ThornC", true, false)
	for t2 in [wt, ta, tc]:
		if t2 == null:
			check(false, "thorn_exists_fix1")
			continue
		check(not pm.is_solved(t2.puzzle_hint) and not pm.is_live(t2.puzzle_hint), "thorn_%s_hint_unsolved_late_game" % String(t2.name))
		t2.on_interact(current_scene.get_node("Player"))
		check(bool(t2._armed), "thorn_%s_arms_on_interact_late_game" % String(t2.name))
		t2._armed = false
	var spawn_x: float = float(sr.get("checkpoint").x) if sr.get("checkpoint") != null else 120.0
	if cloud != null and wt != null:
		var cxa: float = cloud.position.x - cloud.size.x * 0.5
		check(spawn_x < cxa and wt.position.x < cxa and wt.position.x > spawn_x - 200.0, "wall_thorn_reachable_without_crossing_cloud")
		var shielded2: float = maxf(cloud.size.x - 2.0 * cloud.safe_radius, 0.0)
		check(shielded2 / walk_speed * cloud.curse_per_second <= curse_max * 0.15, "wall_cloud_shield_cost_le_15_percent")
	_unsolve(["decay_vines", "decay_weight_latch", "decay_weight_corpse", "decay_vine_shortcut"])
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.3).timeout
	check(not pm.journal_hint_for_active_room().is_empty(), "journal_vines_hint_when_unsolved")
	pm.mark_solved(&"decay_vine_shortcut")
	check(pm.journal_hint_for_active_room().is_empty(), "journal_vines_no_hint_when_legacy_solved")
	_unsolve(["decay_vine_shortcut"])
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.3).timeout
	check(not pm.journal_hint_for_active_room().is_empty(), "journal_weight_hint_when_unsolved")
	pm.mark_solved(&"decay_weight_latch")
	check(pm.journal_hint_for_active_room().is_empty(), "journal_weight_no_hint_when_legacy_latch_solved")
	_unsolve(["decay_weight_latch", "decay_weight_corpse"])
	var crypt_x := -1.0
	var garden_x := -1.0
	for n in sr.find_children("*", "Area2D", true, false):
		if n.is_in_group("room_door"):
			if String(n.get("target_room_id")) == "awakening_crypt":
				crypt_x = n.position.x
				check(n.required_puzzle == &"decay_shilda_wall_broken", "wall_crypt_door_requires_broken")
			elif String(n.get("target_room_id")) == "decay_garden":
				garden_x = n.position.x
				check(n.required_puzzle == &"decay_shilda_wall_broken", "wall_garden_door_requires_broken")
	check(is_equal_approx(crypt_x, 1120.0) and is_equal_approx(garden_x, 1400.0) and absf(garden_x - crypt_x) >= 280.0, "wall_doors_crypt1120_garden1400_apart_280")
	var enc: Node2D = sr.find_child("Encounter", true, false)
	var cwall: Node2D = sr.find_child("CrackedWall", true, false)
	check(enc != null and is_equal_approx(enc.position.x, 520.0) and cwall != null and is_equal_approx(cwall.position.x, 1000.0) and cwall.shortcut_flag == &"shortcut_decay_crypt", "wall_encounter520_crackedwall1000_kept")
	var froom: Node = sr.find_child("FlowerRoom", true, false)
	check(froom != null and "echo_id" in froom and String(froom.echo_id) != "", "wall_flowerroom_is_echo_point")
	if froom != null and "echo_id" in froom:
		var cat: Dictionary = root.get_node("EchoManager")._catalog
		check(cat.has(froom.echo_id) or cat.has(String(froom.echo_id)), "wall_echo_id_in_catalog")
	# ---- hints / objectives ----
	for id in [&"decay_vines", &"decay_weight_corpse", &"decay_greenhouse_pot", &"decay_greenhouse", &"decay_weight_latch"]:
		var hh3: Dictionary = pm.get_hints(id)
		var ok3 := hh3.size() > 0 and hh3.has("goal")
		for k in ["goal", "orientation", "explicit"]:
			var tx3 := String(hh3.get(k, ""))
			if tx3.length() > 70 or tx3.length() == 0:
				ok3 = false
		check(ok3 and String(hh3.get("explicit", "")).ends_with("."), "hints_%s_len_ok_0710" % String(id))
	for rid in ["decay_vines", "decay_weight", "decay_greenhouse", "decay_shilda_wall"]:
		check(_objective(rid).length() > 0, "objective_%s_nonempty" % rid)
	check(_objective("decay_greenhouse").find("Plakaya bas") == -1, "objective_greenhouse_no_player_plate_text")
	_clear_corpses()
	_unsolve(["decay_vines", "decay_greenhouse", "decay_greenhouse_pot", "decay_weight_latch", "decay_weight_corpse"])
	dm.clear()


func _rooms_11_13() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var cur := root.get_node("CurseManager")
	var dm := root.get_node("DialogueManager")
	var sm := root.get_node("SaveManager")
	var cm := root.get_node("CorpseManager")
	var player: Node2D = current_scene.get_node("Player")
	dm.clear()
	_clear_corpses()
	# ---- 11 garden ----
	_unsolve(["decay_garden_bloom", "decay_archive_key"])
	gs.set_world_flag(&"decay_archive_open", false)
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.4).timeout
	if not (rm._rooms as Dictionary).has(&"decay_garden"):
		check(false, "rooms_11_13_garden_loaded")
		return
	var g: Node = _room_root(&"decay_garden")
	var shrine: Node = g.find_child("BloomShrine", true, false)
	check(shrine != null and shrine.has_method("press"), "garden_bloom_shrine_exists")
	check(g.find_child("ArchiveSeal", true, false) == null, "garden_archive_keypad_removed")
	var door: Node = g.find_child("ArchiveDoor", true, false)
	if shrine != null:
		check(Array(shrine.order) == ["7", "2", "9"] and shrine.puzzle_id == &"decay_garden_bloom", "garden_shrine_order_729")
		check(bool(shrine.penalize_wrong), "garden_shrine_penalizes")
	check(door != null and Array(door.puzzle_listen_all) == ["decay_garden_bloom"] and door.legacy_puzzle == &"decay_archive_key", "garden_door_listens_bloom_with_legacy")
	check(g.find_child("ShildaGarden", true, false) != null, "garden_shilda_kept")
	if shrine != null and door != null:
		check(not door._is_open(), "garden_door_closed_before_bloom")
		var before: float = float(cur.get("curse"))
		shrine.press("2", null)
		check(float(cur.get("curse")) > before, "garden_wrong_bloom_penalizes")
		shrine.press("7", null)
		shrine.press("2", null)
		shrine.press("9", null)
		await create_timer(0.2).timeout
		check(pm.is_solved(&"decay_garden_bloom") and pm.is_solved(&"decay_archive_key"), "garden_bloom_solves_bloom_and_archive_key")
		check(bool(gs.get_world_flag(&"decay_archive_open", false)), "garden_bloom_sets_archive_open_flag")
		check(door._is_open(), "garden_door_open_after_bloom")
	var petals: Array = []
	for n in g.find_children("*", "Node2D", true, false):
		if n.is_in_group("hidden_symbol"):
			petals.append(n)
	var texts: Array = []
	for pn in petals:
		texts.append(String(pn.symbol_text))
	texts.sort()
	check(texts == ["2", "7", "9"], "garden_petals_are_hidden_symbols_279")
	var steps := 0
	for n in g.find_children("*", "Area2D", true, false):
		if n.has_method("on_interact") and "step_id" in n:
			steps += 1
	check(steps == 3, "garden_three_bloom_steps")
	var okp := petals.size() == 3
	var bthorn: Node = g.find_child("BloomThorn", true, false)
	check(bthorn != null and bthorn.puzzle_hint == &"decay_garden_bloom", "garden_bloom_thorn_hint")
	if bthorn != null and okp:
		for pn in petals:
			var d: Vector2 = pn.global_position - Vector2(bthorn.anchor_x, 288.0)
			var best := Vector2(d.x, maxf(0.0, absf(d.y) - 120.0)).length()
			if best > 0.6 * float(pn.reveal_radius) + 0.2 * 0.4 * float(pn.reveal_radius) - 1.0:
				okp = false
	else:
		okp = false
	check(okp, "garden_one_flower_corpse_reads_all_petals")
	_unsolve(["decay_garden_bloom", "decay_archive_key"])
	gs.set_world_flag(&"decay_archive_open", false)
	if door != null:
		check(not door._is_open(), "garden_door_closed_after_reset")
		check(not pm.journal_hint_for_active_room().is_empty(), "garden_hint_when_unsolved")
		pm.mark_solved(&"decay_archive_key")
		check(door._is_open(), "garden_legacy_archive_key_opens_door")
		check(pm.journal_hint_for_active_room().is_empty(), "garden_legacy_skips_journal_hint")
	_unsolve(["decay_garden_bloom", "decay_archive_key"])
	gs.set_world_flag(&"decay_archive_open", false)
	# garden answer leak: no evidence/garden text may state 7, 2 and 9 together
	var leak := false
	var lre := RegEx.new()
	lre.compile("\"([^\"\n]*)\"")
	for lpath in ["res://scripts/story/decay_flower_evidence.gd", "res://scenes/rooms/decay_garden.tscn"]:
		for ln in FileAccess.get_file_as_string(lpath).split("\n"):
			if ln.find("memory_code") != -1 or ln.find("order") != -1 or ln.begins_with("[") or ln.find("StringName") != -1 or ln.find("&\"") != -1:
				continue
			for mt in lre.search_all(ln):
				var lit: String = mt.get_string(1)
				if lit.find("7") != -1 and lit.find("2") != -1 and lit.find("9") != -1:
					leak = true
	check(not leak, "garden_texts_do_not_leak_729")
	var fev: String = FileAccess.get_file_as_string("res://scripts/story/decay_flower_evidence.gd")
	check(fev.to_lower().find("mühür") == -1 and fev.to_lower().find("muhur") == -1, "garden_evidence_no_keypad_reference")
	# ---- 12 catacombs ----
	_unsolve(["decay_catacomb_seal"])
	rm.enter_room(&"decay_catacombs", &"default")
	await create_timer(0.4).timeout
	var cat: Node = _room_root(&"decay_catacombs")
	var fsrc: Node = cat.find_child("FlowerSource", true, false)
	check(fsrc != null and fsrc.has_method("on_interact"), "cata_flower_source_exists")
	var syms: Array = []
	var s6: Node = null
	for n in cat.find_children("*", "Node2D", true, false):
		if n.is_in_group("hidden_symbol"):
			syms.append(n.global_position.x)
			if String(n.memory_code_key) == "catacomb":
				s6 = n
	syms.sort()
	check(syms.size() == 3, "cata_three_symbols")
	var spaced := syms.size() == 3
	for i in range(syms.size() - 1):
		if syms[i + 1] - syms[i] < 200.0:
			spaced = false
	check(spaced, "cata_symbols_ge_200_apart")
	check(s6 != null and String(s6.memory_code_value) == "586", "cata_seal_code_586_kept")
	var seal: Node = cat.find_child("CatacombSeal", true, false)
	check(seal != null and String(seal.story_code) == "586", "cata_seal_story_code_586")
	var gaps: PackedVector2Array = cat.floor_gaps
	var pcm: Dictionary = load("res://scripts/player/player_controller.gd").get_script_constant_map()
	var speed := float(pcm["SPEED"])
	var grav := float(pcm["GRAVITY"])
	var jv := absf(float(pcm["JUMP_VELOCITY"]))
	var coyote := float(pcm["COYOTE_TIME"])
	var apex_spd := float(pcm["APEX_SPEED"])
	var apex_mult := float(pcm["APEX_GRAVITY_MULT"])
	var dash_reach := float(pcm["DASH_SPEED"]) * float(pcm["DASH_TIME"])
	var vy := -jv
	var yy := 0.0
	var air_t := 0.0
	while air_t < 3.0:
		var gm := apex_mult if absf(vy) < apex_spd else 1.0
		vy += grav * gm / 60.0
		yy += vy / 60.0
		air_t += 1.0 / 60.0
		if yy >= 0.0:
			break
	var reach_max := speed * (air_t + coyote) + dash_reach + 28.0
	var ci := (load("res://scenes/world/corpse.tscn") as PackedScene).instantiate()
	var ccs := ci.get_node("CollisionShape2D") as CollisionShape2D
	var cw := (ccs.shape as RectangleShape2D).size.x
	ci.free()
	var wide := Vector2.ZERO
	for gv in gaps:
		if gv.y - gv.x > wide.y - wide.x:
			wide = gv
	check(wide.y - wide.x > reach_max, "cata_big_gap_unjumpable (%.0f > %.1f)" % [wide.y - wide.x, reach_max])
	var half := (wide.y - wide.x - cw) * 0.5
	## Zıplama corpse tepesinden (~15 px yukarı) başlar/biter: başlangıçtan 15 px yukarıdaki seviyeye dönüşe kadar süre.
	var corpse_top := 15.0
	var vy2 := -jv
	var y2 := 0.0
	var t15 := 0.0
	while t15 < 3.0:
		var gm2 := apex_mult if absf(vy2) < apex_spd else 1.0
		vy2 += grav * gm2 / 60.0
		y2 += vy2 / 60.0
		t15 += 1.0 / 60.0
		if vy2 > 0.0 and y2 >= -corpse_top:
			break
	check(half < speed * t15 - 4.0, "cata_gap_halves_jumpable_from_corpse_top (%.1f < %.1f, t15 %.3f)" % [half, speed * t15 - 4.0, t15])
	## Not: tam headless fizik simulasyonu (Player sahnesi kare kare) bilincli atlandi; sabit-turev aritmetigi + e2e yeterli.
	var th: Node = cat.find_child("Thorn", true, false)
	check(th != null and th.is_in_group("blood_thorn") and th.puzzle_hint == &"catacomb_bridge_thorn", "cata_thorn_hint")
	if th != null:
		check(th.anchor_x - cw * 0.5 > wide.x and th.anchor_x + cw * 0.5 < wide.y, "cata_thorn_anchor_inside_gap")
		check(bool(th.hold_corpse) and float(th.anchor_y) >= 0.0, "cata_thorn_holds_corpse")
		check(th.position.x < wide.x, "cata_thorn_before_gap")
		check(not pm.is_solved(th.puzzle_hint), "cata_thorn_hint_unsolved")
		_clear_corpses()
		cm.record_corpse_at(Vector2(th.anchor_x, th.anchor_y), &"thorn")
		var ids_h: Array = th._corpse_ids()
		ids_h.pop_back()
		th._hold_new_corpse(ids_h)
		var cl: Array = gs.world_memory_state["corpses"]
		var held := false
		var ok_pos := false
		if cl.size() > 0:
			var c: Dictionary = cl.back()
			held = bool(c.get("anchored", false)) and not bool(c.get("usable_for_puzzle", true)) and String(c.get("anchor_plate", "")) != ""
			ok_pos = absf(float((c.get("position", {}) as Dictionary).get("x", 0.0)) - th.anchor_x) < 1.0
		check(held and ok_pos, "cata_bridge_corpse_anchored_not_pickable_in_gap")
		check(th._bridge_exists(), "cata_thorn_detects_existing_bridge")
		# refused death: no NEW corpse -> previous corpse stays unanchored
		_clear_corpses()
		cm.record_corpse_at(Vector2(100.0, 288.0), &"unknown")
		var before_ids: Array = th._corpse_ids()
		var got: bool = th._hold_new_corpse(before_ids)
		var prev: Dictionary = (gs.world_memory_state["corpses"] as Array).back()
		check(not got and not bool(prev.get("anchored", false)) and String(prev.get("anchor_plate", "")) == "", "thorn_hold_ignores_old_corpse_when_death_refused")
		# legacy save: seal already solved, no corpses -> bridge thorn still armed and bridges
		_clear_corpses()
		pm.mark_solved(&"decay_catacomb_seal")
		check(not pm.is_solved(th.puzzle_hint) and not pm.is_live(th.puzzle_hint) and not th._bridge_exists(), "cata_thorn_armed_on_legacy_seal_save")
		th._armed = true
		th.on_interact(player)
		var tl := 0.0
		while tl < 5.0 and gs.world_memory_state["corpses"].is_empty():
			await create_timer(0.1).timeout
			tl += 0.1
		var lc: Array = gs.world_memory_state["corpses"]
		var lheld := false
		if lc.size() > 0:
			var lcd: Dictionary = lc.back()
			lheld = bool(lcd.get("anchored", false)) and absf(float((lcd.get("position", {}) as Dictionary).get("x", 0.0)) - th.anchor_x) < 1.0
		check(lheld and th._bridge_exists(), "cata_legacy_seal_save_bridge_corpse_anchored_in_gap")
		tl = 0.0
		while tl < 6.0 and bool(root.get_node("DeathManager").is_dying):
			await create_timer(0.1).timeout
			tl += 0.1
		_unsolve(["decay_catacomb_seal"])
	_clear_corpses()
	var hc: Dictionary = pm.get_hints(&"decay_catacomb_seal")
	check(hc.size() > 0 and String(hc.get("explicit", "")).length() <= 90, "cata_hints_ok")
	# each symbol shows one digit; 586 learned only after all three are lit
	var sym_nodes: Dictionary = {}
	for n in cat.find_children("*", "Node2D", true, false):
		if n.is_in_group("hidden_symbol"):
			sym_nodes[String(n.symbol_text)] = n
	check(sym_nodes.size() == 3 and sym_nodes.has("5") and sym_nodes.has("8") and sym_nodes.has("6"), "cata_symbols_one_digit_each_586")
	if sym_nodes.size() == 3:
		var mc: Dictionary = gs.player_progress_knowledge.get("memory_codes", {})
		mc.erase("catacomb")
		for sk in sym_nodes:
			sym_nodes[sk]._seen = false
		var lamp := Node2D.new()
		lamp.add_to_group("lantern_corpse")
		current_scene.add_child(lamp)
		var learned_early := false
		for dk in ["5", "8"]:
			lamp.global_position = Vector2(sym_nodes[dk].global_position.x, 288.0)
			await create_timer(0.7).timeout
		if (gs.player_progress_knowledge.get("memory_codes", {}) as Dictionary).has("catacomb"):
			learned_early = true
		lamp.global_position = Vector2(sym_nodes["6"].global_position.x, 288.0)
		await create_timer(0.7).timeout
		var learned: bool = (gs.player_progress_knowledge.get("memory_codes", {}) as Dictionary).get("catacomb", "") == "586"
		lamp.queue_free()
		check(sym_nodes["5"].is_seen() and sym_nodes["8"].is_seen() and sym_nodes["6"].is_seen(), "cata_all_three_symbols_lit_by_separate_corpses")
		check(not learned_early and learned, "cata_code_586_learned_only_after_all_three")
	# remote held corpse is trimmed first (budget)
	_clear_corpses()
	var thb: Node = cat.find_child("Thorn", true, false)
	cm.record_corpse_at(Vector2(thb.anchor_x, thb.anchor_y), &"thorn")
	var idsb: Array = thb._corpse_ids()
	idsb.pop_back()
	thb._hold_new_corpse(idsb)
	var bridge_id: String = String((gs.world_memory_state["corpses"] as Array).back().get("id", ""))
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.4).timeout
	for ti in 2:
		cm.record_corpse_at(Vector2(200.0 + 60.0 * ti, 288.0), &"unknown")
		var cc: Dictionary = (gs.world_memory_state["corpses"] as Array).back()
		cc["anchored"] = true
		cc["anchor_plate"] = "audit_plate_%d" % ti
		await create_timer(0.02).timeout
	cm.record_corpse_at(Vector2(400.0, 288.0), &"unknown")
	var left_ids: Array = []
	var anch := 0
	for cd in gs.world_memory_state["corpses"]:
		left_ids.append(String((cd as Dictionary).get("id", "")))
		if bool((cd as Dictionary).get("anchored", false)) and String((cd as Dictionary).get("room", "")) == "decay_garden":
			anch += 1
	check(not left_ids.has(bridge_id) and anch == 2, "trim_prefers_remote_held_corpse_keeps_active_room_anchors")
	_clear_corpses()
	rm.enter_room(&"decay_catacombs", &"default")
	await create_timer(0.3).timeout
	# ---- 13 cistern ----
	_unsolve(["decay_cistern", "decay_cistern_drain"])
	for k in ["cistern_page_1", "cistern_page_2", "cistern_page_3"]:
		gs.set_world_flag(StringName(k), false)
	gs.set_world_flag(&"cistern_level", 1)
	rm.enter_room(&"decay_cistern", &"default")
	await create_timer(0.4).timeout
	var cis: Node = _room_root(&"decay_cistern")
	var water: Node = cis.find_child("Water", true, false)
	check(water != null and water.has_method("set_drain") and int(water.start_level) == 1, "cist_water_level_start1")
	var deltas: Array = []
	for n in cis.find_children("*", "Area2D", true, false):
		if n.is_in_group("valve"):
			deltas.append(int(n.delta))
	deltas.sort()
	check(deltas == [-1, 1, 1], "cist_three_valves_plus1_plus1_minus1")
	var plate: Node = cis.find_child("DrainPlate", true, false)
	check(plate != null and plate.puzzle_id == &"decay_cistern_drain" and not plate.accept_player and not plate.accept_stone, "cist_drain_plate_corpse_only")
	var rawtxt := FileAccess.get_file_as_string("res://scenes/rooms/decay_cistern.tscn")
	check(rawtxt.find("need_dash") == -1 and rawtxt.find("need_soul") == -1, "cist_no_ability_requirement")
	check(rawtxt.find("solve_puzzle") == -1, "cist_wetpages_no_direct_solve")
	var pages: Array = []
	for n in cis.find_children("*", "Area2D", true, false):
		if n.is_in_group("cistern_page"):
			pages.append(n)
	pages.sort_custom(func(a, b): return int(a.page_id) < int(b.page_id))
	check(pages.size() == 3, "cist_three_pages")
	if water != null and pages.size() == 3 and plate != null:
		check(water.level == 1, "cist_starts_level_1")
		pages[0].on_interact(player)
		check(not bool(gs.get_world_flag(&"cistern_page_1", false)), "cist_p1_unreachable_above_level0")
		water.set_drain(true)
		water.step(-1)
		check(water.level == 0, "cist_level0_with_drain")
		pages[0].on_interact(player)
		check(bool(gs.get_world_flag(&"cistern_page_1", false)), "cist_p1_collect_level0")
		water.set_drain(false)
		check(water.level == 1, "cist_drain_closed_returns_level1")
		water.step(1)
		check(water.level == 2, "cist_level2")
		pages[1].on_interact(player)
		check(not pm.is_solved(&"decay_cistern"), "cist_two_pages_do_not_solve")
		water.step(1)
		pages[2].on_interact(player)
		await create_timer(0.2).timeout
		check(pm.is_solved(&"decay_cistern"), "cist_three_pages_solve")
		var rt: Dictionary = sm._deserialize_world(sm._serialize_world(gs.world_memory_state))
		var fl: Dictionary = rt.get("flags", {})
		check(bool(fl.get("cistern_page_1", false)) and bool(fl.get("cistern_page_2", false)) and bool(fl.get("cistern_page_3", false)), "cist_pages_persist_save_roundtrip")
	_unsolve(["decay_cistern"])
	for k in ["cistern_page_1", "cistern_page_2", "cistern_page_3"]:
		gs.set_world_flag(StringName(k), false)
	if water != null:
		# raise to 3, leave and re-enter: level resets to 1 and a valve is reachable from the floor
		water.step(1)
		water.step(1)
		await create_timer(0.1).timeout
		check(water.level == 3, "cist_raised_to_3_before_reload")
		rm.enter_room(&"decay_garden", &"default")
		await create_timer(0.3).timeout
		rm.enter_room(&"decay_cistern", &"default")
		await create_timer(0.4).timeout
		check(water.level == 1 and int(gs.get_world_flag(&"cistern_level", 1)) == 1, "cist_reenter_resets_level_1")
		var vmin := 9999.0
		for n in cis.find_children("*", "Area2D", true, false):
			if n.is_in_group("valve"):
				vmin = minf(vmin, absf(288.0 - (n as Node2D).global_position.y))
		check(vmin <= 60.0, "cist_valve_reachable_from_floor_at_level1 (%.0f px)" % vmin)
		water.step(1)
		water.step(1)
		await create_timer(0.1).timeout
		check(water.level == 3, "cist_raised_to_3_before_death")
		root.get_node("DeathManager").rebirth_completed.emit()
		check(water.level == 1, "cist_rebirth_resets_level_1")
	check(not pm.journal_hint_for_active_room().is_empty(), "cist_hint_when_unsolved")
	pm.mark_solved(&"decay_cistern")
	check(pm.journal_hint_for_active_room().is_empty(), "cist_legacy_solved_skips_hint")
	# ---- thorns 11-13 ----
	var seen: Dictionary = {}
	for rid3 in ["decay_garden", "decay_catacombs", "decay_cistern"]:
		var rr3: Node = _room_root(StringName(rid3))
		for t in rr3.find_children("*", "Area2D", true, false):
			if t.is_in_group("blood_thorn"):
				check(not seen.has(t.puzzle_hint), "thorn_%s_unique_hint" % String(t.name))
				seen[t.puzzle_hint] = true
				## Cistern thorn uses decay_cistern_drain (not the page puzzle decay_cistern), so every thorn hint must be unsolved.
				check(not pm.is_solved(t.puzzle_hint), "thorn_%s_hint_live" % String(t.name))
	check(seen.has(&"decay_garden_bloom") and seen.has(&"decay_cistern_drain") and seen.has(&"catacomb_bridge_thorn"), "thorns_1113_use_room_puzzles")
	for id in [&"decay_garden_bloom", &"decay_cistern", &"decay_catacomb_seal", &"decay_catacombs"]:
		var hh: Dictionary = pm.get_hints(id)
		var ok4 := hh.size() > 0 and hh.has("goal")
		for k in ["goal", "orientation"]:
			var tl := String(hh.get(k, "")).length()
			if tl > 70 or tl == 0:
				ok4 = false
		check(ok4, "hints_%s_len_ok_1113" % String(id))
	for rid4 in ["decay_garden", "decay_catacombs", "decay_cistern"]:
		check(_objective(rid4).length() > 0 and _objective(rid4).length() <= 70, "objective_%s_le70" % rid4)
	_clear_corpses()
	_unsolve(["decay_garden_bloom", "decay_archive_key", "decay_catacomb_seal", "decay_cistern", "decay_cistern_drain"])
	dm.clear()


func _objective(room: String) -> String:
	var gs := root.get_node("GameState")
	var prev: Variant = gs.character_current_life_knowledge.get("room", &"")
	gs.character_current_life_knowledge["room"] = StringName(room)
	var t: String = gs.get_current_objective()
	gs.character_current_life_knowledge["room"] = prev
	return t
