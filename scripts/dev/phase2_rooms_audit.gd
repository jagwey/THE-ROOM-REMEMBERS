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
	dm.choose(1)
	check(_picked == 1, "choose_emits_choice_made_1")
	check(not dm.is_open, "choose_closes_box")
	check(not gate.blocks_movement(), "choose_unlocks_movement")
	dm.choose(0) ## kapalıyken etkisiz
	check(_picked == 1, "choose_when_closed_ignored")
	dm.choice_made.disconnect(_on_pick)
	# --- vigil trust ---
	var before: bool = gs.is_shilda_trusted()
	check(gs.get_vigil_trust() == 0, "vigil_trust_starts_zero")
	gs.add_vigil_trust(2)
	check(gs.get_vigil_trust() == 2, "vigil_trust_add_2")
	var sm := root.get_node("SaveManager")
	var saved: bool = sm.save_game()
	gs.add_vigil_trust(-2)
	check(gs.get_vigil_trust() == 0, "vigil_trust_reset_before_load")
	var loaded: bool = sm.load_game(false)
	check(saved and loaded and gs.get_vigil_trust() == 2, "vigil_trust_survives_save_load")
	check(gs.is_shilda_trusted() or not before, "trust_plus2_not_lower_than_before")
	gs.add_vigil_trust(-2)
	gs.add_vigil_trust(-10)
	check(not gs.is_shilda_trusted(), "negative_vigil_trust_causes_suspicion")
	gs.player_progress_knowledge.erase("vigil_trust")
