extends SceneTree
## Faz 4 (oda 28-40) denetimi. Görevler bölümleri ekler: _components, _graph, _rooms_*, _room_40_final, _softlock.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/phase4_rooms_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("PHASE4 ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PHASE4 SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	await _components()
	quit(1 if failures > 0 else 0)


func _components() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var mim := root.get_node("MobileInputManager")
	var scene: Node = current_scene
	var player: Node2D = scene.get_node("Player")
	var home_room: StringName = rm.get_active_room_id()
	# --- control_invert ---
	var inv := Area2D.new()
	inv.set_script(load("res://scripts/world/control_invert.gd"))
	inv.size = Vector2(400, 200)
	scene.add_child(inv)
	inv.global_position = player.global_position
	for i in 4:
		await physics_frame
	check(bool(player.invert_x), "invert_enter_sets_flag")
	mim.set_move_vector(Vector2(1, 0))
	for i in 6:
		await physics_frame
	check(float(player.input_x) < 0.0, "invert_right_axis_gives_negative_input_x", player.input_x)
	mim.clear_held_inputs()
	inv.queue_free()
	await process_frame
	check(not bool(player.invert_x), "invert_zone_freed_clears_flag")
	player.invert_x = true
	rm.enter_room(&"mirrors_dual")
	check(not bool(player.invert_x), "invert_cleared_by_enter_room")
	player.invert_x = true
	player.respawn_at(player.global_position)
	check(not bool(player.invert_x), "invert_cleared_by_respawn")
	mim.set_move_vector(Vector2.ZERO)
	for i in 2:
		await physics_frame
	mim.set_move_vector(Vector2(1, 0))
	for i in 6:
		await physics_frame
	check(float(player.input_x) > 0.0, "invert_off_right_axis_positive", player.input_x)
	mim.clear_held_inputs()
	# --- path_mimic ---
	var pmim := Node2D.new()
	pmim.set_script(load("res://scripts/world/path_mimic.gd"))
	pmim.puzzle_id = &"p4_mimic"
	pmim.checkpoints = PackedVector2Array([Vector2(100, 0), Vector2(200, 0), Vector2(300, 0)])
	pmim.also_solve = PackedStringArray(["p4_mimic_legacy"])
	scene.add_child(pmim)
	pmim.global_position = Vector2.ZERO
	var ghost := Node2D.new()
	ghost.add_to_group("echo_twin_body")
	scene.add_child(ghost)
	ghost.global_position = Vector2(5000, 5000)
	for x in [100.0, 200.0, 300.0]:
		player.global_position = Vector2(x, 0)
		await physics_frame
		await physics_frame
	check(int(pmim.progress()) == 0 and not pm.is_solved(&"p4_mimic"), "mimic_player_body_not_counted")
	ghost.global_position = Vector2(100, 0)
	await physics_frame
	await physics_frame
	ghost.global_position = Vector2(300, 0)
	await physics_frame
	await physics_frame
	check(int(pmim.progress()) == 0, "mimic_skip_resets_progress", pmim.progress())
	for x in [100.0, 200.0, 300.0]:
		ghost.global_position = Vector2(x, 0)
		await physics_frame
		await physics_frame
	check(pm.is_solved(&"p4_mimic") and pm.is_solved(&"p4_mimic_legacy"), "mimic_in_order_solves_and_also_solve")
	ghost.queue_free()
	pmim.queue_free()
	_unsolve(["p4_mimic", "p4_mimic_legacy"])
	# --- echo_altar mirror ---
	var altar := Area2D.new()
	altar.set_script(load("res://scripts/world/echo_altar.gd"))
	altar.puzzle_id = &"p4_mirror"
	altar.mirror_axis_x = 480.0
	altar.live_only = true
	altar.switch_kinds = PackedStringArray(["lever"])
	altar.switch_positions = PackedVector2Array([Vector2(-7020, 0)])
	altar.lever_hold_seconds = 30.0
	scene.add_child(altar)
	altar.global_position = Vector2(7400, 0)
	await process_frame
	await process_frame
	var frames: Array = [
		[0.0, Vector2(700, 0), false, "idle"],
		[0.1, Vector2(700, 0), false, "idle"],
		[0.2, Vector2(580, 0), true, "idle"],
		[0.5, Vector2(580, 0), true, "idle"],
		[0.9, Vector2(580, 0), true, "idle"],
	]
	altar.debug_play(frames, [[0.35, "interact"]])
	await physics_frame
	var twin: Node2D = altar._twin
	check(twin != null and absf(twin.global_position.x - 260.0) < 1.0, "altar_mirror_twin_x_700_becomes_260", twin.global_position if twin else "no twin")
	await create_timer(0.7).timeout
	var lever: Node = altar._switches[0] if altar._switches.size() > 0 else null
	check(lever != null and bool(lever.active), "altar_mirror_event_x_580_pulls_lever_at_380")
	altar.queue_free()
	await process_frame
	pm.set_live(&"p4_mirror", false)
	# --- reach_marker also_solve ---
	var rmk := Area2D.new()
	rmk.set_script(load("res://scripts/world/reach_marker.gd"))
	rmk.puzzle_id = &"p4_reach"
	rmk.also_solve = PackedStringArray(["p4_legacy"])
	scene.add_child(rmk)
	rmk.global_position = player.global_position + Vector2(0, 28)
	for i in 4:
		await physics_frame
	check(pm.is_solved(&"p4_reach") and pm.is_solved(&"p4_legacy"), "reach_marker_also_solve")
	rmk.queue_free()
	_unsolve(["p4_reach", "p4_legacy"])
	# --- sequence_shrine require_live ---
	var shrine := Node2D.new()
	shrine.set_script(load("res://scripts/world/sequence_shrine.gd"))
	shrine.puzzle_id = &"p4_seq"
	shrine.order = PackedStringArray(["a", "b"])
	shrine.require_live = PackedStringArray(["p4_w"])
	scene.add_child(shrine)
	await process_frame
	shrine.press("a")
	check(shrine.get_progress() == 0, "shrine_require_live_rejects_when_not_live")
	pm.set_live(&"p4_w", true)
	shrine.press("a")
	check(shrine.get_progress() == 1, "shrine_require_live_accepts_when_live")
	pm.set_live(&"p4_w", false)
	shrine.press("b")
	check(shrine.get_progress() == 1 and not pm.is_solved(&"p4_seq"), "shrine_rejected_step_keeps_chain")
	pm.set_live(&"p4_w", true)
	shrine.press("b")
	check(pm.is_solved(&"p4_seq"), "shrine_correct_order_solves_when_live")
	pm.set_live(&"p4_w", false)
	shrine.queue_free()
	_unsolve(["p4_seq"])
	# --- built_room door title/mark ---
	var br := Node2D.new()
	br.set_script(load("res://scripts/world/built_room.gd"))
	br.room_id = &"mirrors_shrine"
	br.doors = [{"x": 300.0, "to": "mirrors_dual", "title": "Ayna Tapınağı", "mark": true, "label_dy": -74.0}]
	scene.add_child(br)
	await process_frame
	var bdoor := br.get_node_or_null("Interactive/Door_mirrors_dual")
	check(bdoor != null and String(bdoor.door_title) == "Ayna Tapınağı", "built_room_door_title")
	check(bdoor != null and bdoor.get_node_or_null("DoorMark") != null, "built_room_door_mark")
	check(bdoor != null and is_equal_approx(float(bdoor.label_dy), -74.0), "built_room_door_label_dy")
	br.queue_free()
	await process_frame
	rm.enter_room(home_room)
	await _migrations()


func _migrations() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var prog_bak: Dictionary = gs.player_progress_knowledge.duplicate(true)
	var life_bak: Dictionary = gs.character_current_life_knowledge.duplicate(true)
	var world_bak: Dictionary = gs.world_memory_state.duplicate(true)
	var new_ids := ["mirrors_labyrinth_crossed", "mirrors_shrine_trial", "mirrors_1927_walk", "mirrors_1927"]
	var vault_ids := ["core_vault_order", "core_bloom_order"]
	# core_threshold: eski kayıt (yeni kimlikler yok, dash yok, trusted_keeper erken yazılmış)
	gs.world_memory_state["puzzles"] = {}
	_apply_old("core_threshold", {"trusted_keeper": true, "truth_seen": true, "ability_shadow_dash": false, "migrated_v118": false})
	var puz: Dictionary = gs.world_memory_state["puzzles"]
	check(bool(puz.get("mirrors_labyrinth_crossed", false)) and bool(puz.get("mirrors_shrine_trial", false)), "mig_threshold_gets_labyrinth_shrine")
	check(bool(puz.get("mirrors_1927", false)) and bool(puz.get("mirrors_1927_walk", false)), "mig_threshold_gets_1927")
	check(bool(gs.player_progress_knowledge.get("ability_shadow_dash", false)), "mig_threshold_gets_shadow_dash")
	check(not bool(gs.player_progress_knowledge.get("trusted_keeper", true)), "mig_threshold_trusted_keeper_reset")
	check(not bool(gs.player_progress_knowledge.get("truth_seen", true)), "mig_threshold_truth_seen_reset")
	check(bool(gs.get_shilda_trust_state().get("reconciled", false)), "mig_threshold_reconciled_set")
	check(not vault_ids.any(func(i): return puz.has(i)), "mig_threshold_no_vault_ids")
	var snap := puz.duplicate(true)
	var psnap: Dictionary = gs.player_progress_knowledge.duplicate(true)
	sm._migrate_side_room_puzzles_for_late_rooms()
	sm._migrate_shadow_dash_for_late_rooms()
	sm._migrate_trust_flags_v118()
	check(puz == snap and gs.player_progress_knowledge == psnap, "mig_idempotent")
	# işaretli kayıt: erken odada bile güven bayrakları korunur
	gs.world_memory_state["puzzles"] = {}
	_apply_old("core_threshold", {"trusted_keeper": true, "truth_seen": true, "migrated_v118": true})
	check(bool(gs.player_progress_knowledge.get("trusted_keeper", false)) and bool(gs.player_progress_knowledge.get("truth_seen", false)), "mig_marked_save_keeps_trust_flags")
	# eski kayıt (işaret yok): bir kez temizlenir, ikinci yükleme kararlı
	_apply_old("core_threshold", {"trusted_keeper": true, "truth_seen": true, "migrated_v118": false})
	check(not bool(gs.player_progress_knowledge.get("trusted_keeper", true)) and bool(gs.player_progress_knowledge.get("migrated_v118", false)), "mig_legacy_save_clears_once")
	gs.player_progress_knowledge["trusted_keeper"] = true
	var sd: Dictionary = sm._build_data()
	check(bool((sd["player_progress_knowledge"] as Dictionary).get("migrated_v118", false)), "save_writes_marker")
	sm._apply_data(sd, false)
	check(bool(gs.player_progress_knowledge.get("trusted_keeper", false)), "mig_second_load_stable")
	# core: vault/bloom çözülü, güven korunur
	gs.world_memory_state["puzzles"] = {}
	_apply_old("core", {"trusted_keeper": true, "truth_seen": true, "ability_shadow_dash": false, "migrated_v118": false})
	puz = gs.world_memory_state["puzzles"]
	check(bool(puz.get("core_vault_order", false)) and bool(puz.get("core_bloom_order", false)), "mig_core_gets_vault_bloom")
	check(bool(gs.player_progress_knowledge.get("trusted_keeper", false)), "mig_core_keeps_trusted_keeper")
	check(bool(gs.player_progress_knowledge.get("truth_seen", false)), "mig_core_keeps_truth_seen")
	# mirrors_unbroken: hiçbiri eklenmez
	gs.world_memory_state["puzzles"] = {}
	_apply_old("mirrors_unbroken", {"ability_shadow_dash": false, "migrated_v118": false})
	puz = gs.world_memory_state["puzzles"]
	check(not new_ids.any(func(i): return puz.has(i)) and not vault_ids.any(func(i): return puz.has(i)), "mig_unbroken_adds_nothing")
	check(not bool(gs.player_progress_knowledge.get("ability_shadow_dash", false)), "mig_unbroken_no_shadow_dash")
	gs.player_progress_knowledge = prog_bak
	gs.character_current_life_knowledge = life_bak
	gs.world_memory_state = world_bak
	root.get_node("PuzzleManager").sync_from_world()


func _apply_old(room: String, prog: Dictionary) -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var p: Dictionary = gs.player_progress_knowledge.duplicate(true)
	for k in prog.keys():
		p[k] = prog[k]
	var data := {
		"version": 5,
		"player_progress_knowledge": p,
		"world_memory_state": gs.world_memory_state.duplicate(true),
		"character_current_life_knowledge": {"room": room, "checkpoint_room": room},
	}
	sm._apply_data(data, false)


func _min_dx(door_xs: Array, props: Array) -> float:
	var m := 99999.0
	for dx in door_xs:
		for p in props:
			m = minf(m, absf(float(dx) - float(p.position.x)))
	return m


func _plates_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "Area2D", true, false):
		if "accept_stone" in n and "puzzle_id" in n:
			out.append(n)
	out.sort_custom(func(a, b): return a.position.x < b.position.x)
	return out


func _veins_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "StaticBody2D", true, false):
		if n.is_in_group("soul_seal"):
			out.append(n)
	out.sort_custom(func(a, b): return a.position.x < b.position.x)
	return out



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


func _drive_dialogue(flag: Array, dm: Node) -> void:
	var gd := 0
	while not flag[0] and gd < 600:
		gd += 1
		if dm.is_open:
			dm.advance()
		await process_frame


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


func _doors_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "Area2D", true, false):
		if "target_room_id" in n and n.has_method("is_locked"):
			out.append(n)
	return out


func _gates_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "StaticBody2D", true, false):
		if "legacy_puzzle" in n and n.has_method("_is_open"):
			out.append(n)
	return out

func _ids_of_room(rid: StringName, room: Node) -> Array:
	var ids: Array = []
	var add := func(v: Variant) -> void:
		var t := String(v)
		if t != "" and not ids.has(t):
			ids.append(t)
	for id in root.get_node("PuzzleManager").ROOM_PUZZLES.get(String(rid), []):
		add.call(id)
	for d in _doors_of(room):
		add.call(d.required_puzzle)
	for g in _gates_of(room):
		add.call(g.legacy_puzzle)
		for id in g.puzzle_listen_all:
			add.call(id)
		for id in g.also_solve:
			add.call(id)
	for v in _veins_of(room):
		add.call(v.puzzle_id)
	for n in room.find_children("*", "Node2D", true, false):
		if "targets" in n and n.has_method("turn"):
			add.call(n.puzzle_id)
			for id in n.also_solve:
				add.call(id)
	for p in _plates_of(room):
		add.call(p.puzzle_id)
	return ids


