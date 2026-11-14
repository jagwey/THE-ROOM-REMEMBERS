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
	await _graph()
	await _rooms_28_31()
	await _rooms_32_34()
	await _rooms_35_37()
	await _rooms_38_39()
	await _room_40_final()
	await _softlock()
	await _main_path_walk()
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


func _graph() -> void:
	var rm := root.get_node("RoomManager")
	var order: Array = Array(rm.ROOM_ORDER)
	var main_script: Script = current_scene.get_script()
	var side_doors: Dictionary = main_script.get_script_constant_map()["SIDE_DOORS"]
	var src: Dictionary = load("res://scripts/dev/release_audit.gd").get_script_constant_map()["PUZZLE_SOURCE"]
	for i in range(27, 40):
		var rid := String(order[i])
		var room: Node = _room_root(StringName(rid))
		var doors := _doors_of(room)
		check(not side_doors.has(rid), "graph_no_side_door_entry_%s" % rid)
		if i < 39:
			var nxt := String(order[i + 1])
			var fwd := doors.filter(func(d): return String(d.target_room_id) == nxt)
			check(fwd.size() == 1, "graph_one_forward_door_%s" % rid, fwd.size())
			if fwd.size() == 1:
				var sp := StringName(fwd[0].target_spawn_id)
				check((rm._rooms[StringName(nxt)].spawns as Dictionary).has(sp), "graph_forward_spawn_exists_%s" % rid, sp)
				check(sp == StringName("from_%s" % rid), "graph_forward_spawn_name_%s" % rid, sp)
				var req := String(fwd[0].required_puzzle)
				check(req != "" and src.has(req), "graph_forward_req_in_puzzle_source_%s" % rid, req)
		var prev := String(order[i - 1])
		var back := doors.filter(func(d): return String(d.target_room_id) == prev)
		check(back.size() == 1, "graph_one_back_door_%s" % rid, back.size())
		if back.size() == 1:
			var bsp := StringName(back[0].target_spawn_id)
			check((rm._rooms[StringName(prev)].spawns as Dictionary).has(bsp), "graph_back_spawn_exists_%s" % rid, bsp)
			check(bsp == StringName("from_%s" % rid), "graph_back_spawn_name_%s" % rid, bsp)
		var close: Array = []
		for n in room.find_children("*", "Node2D", true, false):
			if not n.has_method("on_interact") or n.is_in_group("room_door"):
				continue
			for d in doors:
				if (d as Node2D).global_position.distance_to((n as Node2D).global_position) < 96.0:
					close.append("%s<->%s" % [d.name, n.name])
		check(close.is_empty(), "graph_door_interactable_96px_%s" % rid, close)
	var lab_fwd := _doors_of(_room_root(&"mirrors_labyrinth")).filter(func(d): return String(d.target_room_id) == "mirrors_shrine")
	check(lab_fwd.size() == 1 and String(lab_fwd[0].door_title) == "Ayna Tapınağı", "graph_labyrinth_door_title")
	check(lab_fwd.size() == 1 and lab_fwd[0].get_node_or_null("DoorMark") != null, "graph_labyrinth_door_marked")
	check(lab_fwd.size() == 1 and is_equal_approx(float(lab_fwd[0].label_dy), -74.0), "graph_labyrinth_door_label_dy")


func _fwd_door_open(rid: StringName) -> bool:
	var rm := root.get_node("RoomManager")
	var order: Array = Array(rm.ROOM_ORDER)
	var nxt := String(order[order.find(String(rid)) + 1])
	var room := _room_root(rid)
	for d in _doors_of(room):
		if String(d.target_room_id) == nxt:
			return not d.is_locked()
	return false


func _play_pass(altar: Node, plate_sw_x: float, frames: Array) -> void:
	var player: Node2D = current_scene.get_node("Player")
	root.get_node("DialogueManager").clear()
	player.global_position = Vector2(plate_sw_x, 288)
	altar.debug_play(frames, [[0.35, "interact"]])
	await create_timer(0.7).timeout
	player.global_position = Vector2(plate_sw_x, 288)
	for i in 8:
		await physics_frame


func _beat_run(beat: Node, player: Node2D) -> void:
	var dm := root.get_node("DialogueManager")
	var f := [false]
	dm.dialogue_finished.connect(func(_ok): f[0] = true, CONNECT_ONE_SHOT)
	beat.on_interact(player)
	await _drive_dialogue(f, dm)


func _rooms_28_31() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	var scene: Node = current_scene
	var player: Node2D = scene.get_node("Player")
	var truth_before: Variant = gs.get_world_flag(&"truth_seen", false)
	# --- 28 mirrors_reverse ---
	_unsolve(["mirrors_reverse", "mirrors_reverse_crossed"])
	rm.enter_room(&"mirrors_reverse")
	await process_frame
	var rv := _room_root(&"mirrors_reverse")
	var sb_src := FileAccess.get_file_as_string("res://scripts/story/story_beat.gd")
	check(not sb_src.contains("_open_mirror_choice"), "r28_no_mirror_menu")
	check(rv.find_children("ReverseBeat", "", true, false).is_empty(), "r28_no_reverse_beat")
	var zone: Node = null
	var hz: Array = []
	var mk: Node = null
	for n in rv.find_children("*", "Area2D", true, false):
		if "passage_one_heart_cap" in n:
			hz.append(n)
		elif "also_solve" in n and "puzzle_id" in n:
			mk = n
		elif "enter_line" in n and "size" in n:
			zone = n
	check(zone != null and absf(zone.global_position.x - 500.0) < 1.0 and zone.size == Vector2(400, 200), "r28_invert_zone_geometry")
	check(zone != null and String(zone.enter_line) == "Burada sağ sola dönüyor, adımlarımı ters atmalıyım.", "r28_invert_enter_line")
	check(hz.size() == 2, "r28_two_hazard_strips", hz.size())
	check(mk != null and String(mk.puzzle_id) == "mirrors_reverse_crossed" and absf(mk.global_position.x - 760.0) < 1.0, "r28_marker_geometry")
	check(mk != null and Array(mk.also_solve).has("mirrors_reverse"), "r28_marker_also_solve")
	player.global_position = Vector2(500, 288)
	for i in 5:
		await physics_frame
	check(bool(player.invert_x), "r28_invert_in_zone")
	rm.enter_room(&"mirrors_dual")
	check(not bool(player.invert_x), "r28_invert_cleared_after_enter_room")
	rm.enter_room(&"mirrors_reverse")
	await process_frame
	check(not pm.is_solved(&"mirrors_reverse") and not _fwd_door_open(&"mirrors_reverse"), "r28_locked_before_marker")
	player.global_position = Vector2(760, 288)
	for i in 5:
		await physics_frame
	check(pm.is_solved(&"mirrors_reverse_crossed") and pm.is_solved(&"mirrors_reverse"), "r28_marker_solves")
	rm.enter_room(&"mirrors_dual")
	rm.enter_room(&"mirrors_reverse")
	await process_frame
	check(_fwd_door_open(&"mirrors_reverse"), "r28_door_open_on_reentry")
	root.get_node("DialogueManager").clear()
	# --- 29 mirrors_dual ---
	_unsolve(["mirrors_dual", "mirrors_dual_echo", "mirrors_dual_weight"])
	_clear_corpses()
	rm.enter_room(&"mirrors_dual")
	await process_frame
	await process_frame
	var du := _room_root(&"mirrors_dual")
	var altar: Node = null
	for n in du.find_children("*", "Area2D", true, false):
		if n.is_in_group("echo_altar"):
			altar = n
	check(altar != null and String(altar.puzzle_id) == "mirrors_dual_echo" and bool(altar.live_only) and absf(altar.mirror_axis_x - 480.0) < 0.1, "r29_altar_config")
	check(altar != null and String(altar.intro_text) == "Yankın ters yürür. Sen düz git.", "r29_intro_line")
	var plates := _plates_of(du)
	check(plates.size() == 1 and String(plates[0].puzzle_id) == "mirrors_dual_weight" and not plates[0].accept_player and not plates[0].accept_stone, "r29_weight_plate")
	var dgate: Node2D = null
	if _gates_of(du).size() > 0:
		dgate = _gates_of(du)[0]
	check(dgate != null and Array(dgate.puzzle_listen_all) == ["mirrors_dual_echo", "mirrors_dual_weight"] and Array(dgate.also_solve) == ["mirrors_dual"], "r29_gate_config")
	# Oyuncu x=700'de durup 580'de kolu çeker; aynalı yankı (eksen 480) plakada 260, kolda 380 olur.
	var idle_x: float = 100.0
	var frames: Array = [
		[0.0, Vector2(700, 288), false, "idle"],
		[0.1, Vector2(700, 288), false, "idle"],
		[0.2, Vector2(580, 288), true, "idle"],
		[0.5, Vector2(580, 288), true, "idle"],
		[0.9, Vector2(580, 288), true, "idle"],
	]
	var plate_x: float = altar.global_position.x + 100.0
	await _play_pass(altar, idle_x, frames)
	var plate_on := false
	var lever_on := false
	for sw in altar._switches:
		if String(sw.kind) == "plate":
			plate_on = bool(sw.active)
		elif String(sw.kind) == "lever":
			lever_on = bool(sw.active)
	check(absf(player.global_position.x - plate_x) > 60.0, "r29_player_off_plate")
	check(plate_on and lever_on, "r29_mirrored_twin_presses_plate_and_lever")
	check(pm.is_live(&"mirrors_dual_echo"), "r29_mirrored_twin_alone_is_live")
	await _cross(dgate)
	check(not pm.is_solved(&"mirrors_dual"), "r29_twin_alone_does_not_solve")
	_unsolve(["mirrors_dual", "mirrors_dual_echo", "mirrors_dual_weight"])
	_clear_corpses()
	_corpse_at(620.0, 288.0)
	for i in 8:
		await physics_frame
	check(pm.is_live(&"mirrors_dual_weight") or pm.is_solved(&"mirrors_dual_weight"), "r29_corpse_holds_weight_plate")
	await _cross(dgate)
	check(not pm.is_solved(&"mirrors_dual"), "r29_corpse_alone_does_not_solve")
	_unsolve(["mirrors_dual", "mirrors_dual_echo", "mirrors_dual_weight"])
	_clear_corpses()
	for i in 4:
		await physics_frame
	_corpse_at(620.0, 288.0)
	await create_timer(6.6).timeout
	for i in 8:
		await physics_frame
	await _play_pass(altar, idle_x, frames)
	check(pm.is_live(&"mirrors_dual_echo") and (pm.is_live(&"mirrors_dual_weight") or pm.is_solved(&"mirrors_dual_weight")), "r29_both_layers_live")
	await _cross(dgate)
	check(pm.is_solved(&"mirrors_dual") and pm.is_solved(&"mirrors_dual_echo") and pm.is_solved(&"mirrors_dual_weight"), "r29_both_layers_solve_on_pass")
	rm.enter_room(&"mirrors_reverse")
	rm.enter_room(&"mirrors_dual")
	await process_frame
	check(_fwd_door_open(&"mirrors_dual"), "r29_door_open_on_reentry")
	_clear_corpses()
	# --- 30 mirrors_gallery ---
	_unsolve(["mirrors_gallery", "mirrors_gallery_plate_1", "mirrors_gallery_plate_2", "mirrors_gallery_plate_3"])
	rm.enter_room(&"mirrors_gallery")
	await process_frame
	await process_frame
	var ga := _room_root(&"mirrors_gallery")
	var gplates := _plates_of(ga)
	check(gplates.size() == 3, "r30_three_plates", gplates.size())
	var gxs := [360.0, 640.0, 920.0]
	for i in mini(3, gplates.size()):
		var pl: Node = gplates[i]
		check(absf(pl.position.x - gxs[i]) < 1.0 and bool(pl.latch_on_press) and not pl.accept_player and not pl.accept_stone and String(pl.puzzle_id) == "mirrors_gallery_plate_%d" % (i + 1), "r30_plate_%d_config" % (i + 1))
	var thorns := 0
	for n in ga.find_children("*", "Area2D", true, false):
		if "anchor_x" in n and "puzzle_hint" in n:
			thorns += 1
	check(thorns == 3, "r30_three_thorns", thorns)
	var ggate: Node2D = null
	if _gates_of(ga).size() > 0:
		ggate = _gates_of(ga)[0]
	check(ggate != null and absf(ggate.global_position.x - 1120.0) < 1.0 and Array(ggate.puzzle_listen_all).size() == 3 and Array(ggate.also_solve) == ["mirrors_gallery"], "r30_gate_config")
	var wall: Node = null
	for n in ga.find_children("*", "Area2D", true, false):
		if "count_line" in n:
			wall = n
	check(wall != null and bool(wall.count_line) and String(wall.solve_puzzle) == "", "r30_wall_config")
	player.global_position = Vector2(wall.global_position.x, 288)
	await _beat_run(wall, player)
	check(not pm.is_solved(&"mirrors_gallery"), "r30_wall_alone_does_not_solve")
	for i in 3:
		_clear_corpses()
		_corpse_at(gxs[i], 288.0)
		for k in 8:
			await physics_frame
		check(pm.is_solved(StringName("mirrors_gallery_plate_%d" % (i + 1))), "r30_plate_%d_latches" % (i + 1))
	_clear_corpses()
	for k in 4:
		await physics_frame
	check(pm.is_solved(&"mirrors_gallery_plate_1") and pm.is_solved(&"mirrors_gallery_plate_3"), "r30_latch_survives_corpse_removal")
	check(not pm.is_solved(&"mirrors_gallery"), "r30_plates_alone_do_not_solve_room")
	await _cross(ggate)
	check(pm.is_solved(&"mirrors_gallery"), "r30_gate_pass_solves")
	rm.enter_room(&"mirrors_dual")
	rm.enter_room(&"mirrors_gallery")
	await process_frame
	check(_fwd_door_open(&"mirrors_gallery"), "r30_door_open_on_reentry")
	# --- 31 mirrors_unbroken ---
	_unsolve(["mirrors_unbroken", "mirrors_unbroken_mimic", "mirrors_unbroken_echo"])
	rm.enter_room(&"mirrors_unbroken")
	await process_frame
	await process_frame
	var un := _room_root(&"mirrors_unbroken")
	var ualt: Node = null
	var beat: Node = null
	var mim: Node = null
	for n in un.find_children("*", "Area2D", true, false):
		if n.is_in_group("echo_altar"):
			ualt = n
		elif "beat_id" in n:
			beat = n
	for n in un.find_children("*", "Node2D", true, false):
		if n.is_in_group("path_mimic"):
			mim = n
	check(ualt != null and String(ualt.puzzle_id) == "mirrors_unbroken_echo" and bool(ualt.live_only) and ualt.switch_kinds.size() == 0, "r31_altar_config")
	check(mim != null and String(mim.puzzle_id) == "mirrors_unbroken_mimic" and mim.checkpoints.size() == 3 and bool(mim.echo_only), "r31_mimic_config")
	check(beat != null and absf(beat.global_position.x - 780.0) < 1.0, "r31_beat_at_780")
	var refl: Node = null
	for n in un.find_children("*", "Node2D", true, false):
		if "shade_id" in n and String(n.shade_id) == "mirrors_unbroken_reflection":
			refl = n
	check(refl != null and absf(refl.global_position.x - 260.0) < 40.0, "r31_reflection_spawned")
	check(refl != null and refl.waypoints == PackedVector2Array([Vector2(340, 288), Vector2(520, 246), Vector2(700, 288)]), "r31_reflection_waypoints")
	player.global_position = Vector2(780, 288)
	await _beat_run(beat, player)
	check(not pm.is_solved(&"mirrors_unbroken"), "r31_beat_before_mimic_does_not_solve")
	var ghost := Node2D.new()
	ghost.add_to_group("echo_twin_body")
	un.add_child(ghost)
	ghost.global_position = Vector2(5000, 5000)
	for pt in [Vector2(340, 288), Vector2(520, 246), Vector2(700, 288)]:
		ghost.global_position = pt
		await physics_frame
		await physics_frame
	check(pm.is_solved(&"mirrors_unbroken_mimic"), "r31_echo_path_solves_mimic")
	ghost.queue_free()
	for trusted in [true, false]:
		_unsolve(["mirrors_unbroken"])
		gs.player_progress_knowledge["keeper_hurt"] = not trusted
		gs.player_progress_knowledge["trusted_keeper"] = trusted
		check(bool(gs.is_shilda_trusted()) == trusted, "r31_variant_setup_trusted_%s" % trusted)
		await _beat_run(beat, player)
		check(pm.is_solved(&"mirrors_unbroken"), "r31_beat_solves_trusted_%s" % trusted)
	gs.player_progress_knowledge["keeper_hurt"] = false
	gs.player_progress_knowledge["trusted_keeper"] = false
	check(gs.get_world_flag(&"truth_seen", false) == truth_before, "r31_truth_seen_unchanged")
	rm.enter_room(&"mirrors_gallery")
	rm.enter_room(&"mirrors_unbroken")
	await process_frame
	check(_fwd_door_open(&"mirrors_unbroken"), "r31_door_open_on_reentry")


func _x_words(text: String) -> int:
	var re := RegEx.new()
	re.compile("(^|[^A-Za-zÇĞİÖŞÜçğıöşü])X([^A-Za-zÇĞİÖŞÜçğıöşü]|$)")
	return re.search_all(text).size()


func _rooms_32_34() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	var cm := root.get_node("CorpseManager")
	var player: Node2D = current_scene.get_node("Player")
	# --- 32 mirrors_labyrinth ---
	_unsolve(["mirrors_labyrinth_crossed"])
	_clear_corpses()
	rm.enter_room(&"mirrors_labyrinth")
	await process_frame
	await process_frame
	var lb := _room_root(&"mirrors_labyrinth")
	var lb_fwd := _doors_of(lb).filter(func(d): return String(d.target_room_id) == "mirrors_shrine")
	check(lb_fwd.size() == 1 and String(lb_fwd[0].required_puzzle) == "mirrors_labyrinth_crossed", "r32_fwd_door_needs_crossed")
	var gaps: PackedVector2Array = lb.floor_gaps
	check(gaps.has(Vector2(300, 1080)), "r32_floor_gaps", gaps)
	check(lb.invisible_platforms.size() == 6 and lb.false_reflections.size() == 1, "r32_invisible_platforms_and_false_reflection_kept")
	var th: Node = null
	for n in lb.find_children("*", "Area2D", true, false):
		if n.is_in_group("blood_thorn"):
			th = n
	check(th != null and absf(th.position.x - 940.0) < 2.0 and bool(th.hold_corpse) and String(th.hold_id) == "mirrors_labyrinth_bridge" and float(th.anchor_y) >= 0.0, "r32_bridge_thorn_config")
	check(th != null and absf(th.anchor_x - 990.0) < 2.0, "r32_thorn_anchor_over_gap", th.anchor_x if th != null else -1)
	var crossed: Node = null
	var reward: Node = null
	var hint: Node = null
	var regret: Node = null
	for n in lb.find_children("*", "Area2D", true, false):
		if "puzzle_id" in n and String(n.puzzle_id) == "mirrors_labyrinth_crossed" and "also_solve" in n:
			crossed = n
		elif "lore_id" in n and String(n.lore_id) == "labyrinth_mirror":
			reward = n
		elif "lore_id" in n and String(n.lore_id) == "labyrinth_hint":
			hint = n
		elif "npc_id" in n and String(n.npc_id) == "echo_regret":
			regret = n
	check(crossed != null and absf(crossed.position.x - 1100.0) < 1.0, "r32_crossed_marker_1100")
	check(reward != null and absf(reward.position.x - 1130.0) < 1.0 and String(reward.requires_puzzle) == "mirrors_labyrinth_crossed", "r32_reward_lore_gated_1130")
	check(regret != null and absf(regret.position.x - 240.0) < 1.0, "r32_regret_echo_240_left_bank")
	var rm_src := FileAccess.get_file_as_string("res://scripts/autoload/room_manager.gd")
	check(not rm_src.contains('"mirrors_labyrinth": [Vector2('), "r32_no_shielded_shade")
	var plat_end := 0.0
	for pv in lb.invisible_platforms:
		plat_end = maxf(plat_end, pv.x + pv.z)
	var far_bank: float = (gaps[0].y if gaps.size() > 0 else 0.0)
	check(far_bank - plat_end >= 170.0 and plat_end <= 900.0, "r32_bridge_void_run_ge_170", far_bank - plat_end)
	var on_foot := true
	for n in lb.find_children("*", "Area2D", true, false):
		if n.get_parent() != null and n.get_parent().name == "Interactive" and n.position.y >= 270.0 and n != th:
			for g in gaps:
				if n.position.x > g.x and n.position.x < g.y:
					on_foot = false
	check(on_foot, "r32_interactives_on_solid_ground")
	var kc: Dictionary = load("res://scripts/keeper/keeper_controller.gd").get_script_constant_map()["ROOM_PRESENCE"]
	check(kc.has("mirrors_labyrinth") and kc["mirrors_labyrinth"]["mode"] == "present" and absf(kc["mirrors_labyrinth"]["pos"].x - 160.0) < 1.0, "r32_shilda_presence_160")
	var hint_lines: PackedStringArray = hint.lines if hint != null else PackedStringArray()
	var shilda_line := ""
	for l in hint_lines:
		if String(l).begins_with("Shilda|"):
			shilda_line = String(l)
	check(shilda_line.contains("Tapınak"), "r32_shilda_line_names_shrine", shilda_line)
	var all_text := FileAccess.get_file_as_string("res://scenes/rooms/mirrors_labyrinth.tscn")
	check(not all_text.contains("1927"), "r32_no_1927_code_in_labyrinth_text")
	check(all_text.contains("gecenin odasında kapıya en yakın duvarda"), "r32_reward_names_brick_location")
	# ödül kilitli: çözüm öncesi okunamaz, çözülünce okunur
	player.global_position = Vector2(1130, 288)
	var seen_before: Array = (gs.player_progress_knowledge.get("lore_seen", []) as Array).duplicate()
	seen_before.erase("labyrinth_mirror")
	gs.player_progress_knowledge["lore_seen"] = seen_before
	await _beat_run(reward, player)
	check(not (gs.player_progress_knowledge.get("lore_seen", []) as Array).has("labyrinth_mirror"), "r32_reward_locked_before_solve")
	# ceset köprüsü (1 ceset) varken marker'a ulaşılır
	_clear_corpses()
	cm.record_corpse_at(Vector2(th.anchor_x, th.anchor_y), &"thorn")
	var ids_h: Array = th._corpse_ids()
	ids_h.pop_back()
	th._hold_new_corpse(ids_h)
	check(th._bridge_exists(), "r32_bridge_corpse_held")
	check((gs.world_memory_state["corpses"] as Array).size() == 1, "r32_bridge_is_one_corpse")
	player.global_position = Vector2(1100, 288)
	for i in 6:
		await physics_frame
	check(pm.is_solved(&"mirrors_labyrinth_crossed"), "r32_marker_reachable_with_bridge")
	check(_fwd_door_open(&"mirrors_labyrinth"), "r32_door_opens_after_crossed")
	await _beat_run(reward, player)
	check((gs.player_progress_knowledge.get("lore_seen", []) as Array).has("labyrinth_mirror"), "r32_reward_readable_after_solve")
	_clear_corpses()
	# --- 33 mirrors_shrine ---
	_unsolve(["mirrors_shrine_trial"])
	gs.player_progress_knowledge["ability_shadow_dash"] = false
	rm.enter_room(&"mirrors_shrine")
	await process_frame
	await process_frame
	var sh := _room_root(&"mirrors_shrine")
	var sps: Dictionary = rm._rooms[&"mirrors_shrine"].spawns
	check(sps.has(&"from_mirrors_labyrinth") and sps[&"from_mirrors_labyrinth"] == Vector2(88, 288), "r33_spawn_88")
	check(sps.has(&"seal_mirrors_shrine") and sps[&"seal_mirrors_shrine"] == Vector2(330, 288), "r33_seal_marker_330")
	var echo: Node = null
	var dash: Node = null
	var seal: Node = null
	var shard2: Node = null
	var trial: Node = null
	var barriers: Array = []
	for n in sh.find_children("*", "Node2D", true, false):
		if n.is_in_group("curse_barrier"):
			barriers.append(n)
		elif "npc_id" in n and String(n.npc_id) == "echo_shrine":
			echo = n
		elif "grant_key" in n and String(n.grant_key) == "ability_shadow_dash":
			dash = n
		elif "grant_world_flag" in n and String(n.grant_world_flag) == "seal_shard_2":
			shard2 = n
		elif "puzzle_id" in n and String(n.puzzle_id) == "mirrors_shrine_trial":
			trial = n
		elif n.has_method("on_interact") and "room_id" in n and String(n.room_id) == "mirrors_shrine":
			seal = n
	check(echo != null and absf(echo.position.x - 160.0) < 1.0, "r33_echo_160")
	check(dash != null and absf(dash.position.x - 220.0) < 1.0, "r33_dash_220")
	check(seal != null and absf(seal.position.x - 330.0) < 1.0, "r33_seal_330")
	barriers.sort_custom(func(a, b): return a.position.x < b.position.x)
	var bxs: Array = barriers.map(func(b): return b.position.x)
	check(bxs == [420.0, 520.0, 620.0], "r33_three_barriers", bxs)
	var refusal_ok := not barriers.is_empty()
	for b in barriers:
		refusal_ok = refusal_ok and String(b.refusal_line) == "Gölge Atılması bu tapınakta. Önce sunağa dokunmalıyım."
	check(refusal_ok, "r33_refusal_line_names_shrine")
	check((sh.floor_gaps as PackedVector2Array).has(Vector2(660, 740)), "r33_floor_gap_660_740")
	check(trial != null and absf(trial.position.x - 780.0) < 1.0, "r33_trial_marker_780")
	check(shard2 != null and absf(shard2.position.x - 800.0) < 1.0, "r33_shard2_800")
	var sh_fwd := _doors_of(sh).filter(func(d): return String(d.target_room_id) == "mirrors_1927")
	check(sh_fwd.size() == 1 and String(sh_fwd[0].required_puzzle) == "mirrors_shrine_trial" and not _fwd_door_open(&"mirrors_shrine"), "r33_fwd_door_needs_trial")
	check(shard2 != null and absf(920.0 - shard2.position.x) >= 96.0, "r33_shard2_clear_of_door")
	# MemorySeal kuralları
	check(seal != null and _min_dx([40.0, 920.0], [seal]) >= 56.0 and seal.position.y >= 270.0 and seal.position.x > 150.0, "r33_seal_rules_doors_floor")
	var crowd: Array = []
	var foes: Array = []
	for n in sh.find_children("*", "Node2D", true, false):
		if n == seal:
			continue
		var d := (n as Node2D).global_position.distance_to(seal.global_position)
		if n.has_method("on_interact") and d < 80.0:
			crowd.append("%s@%d" % [n.name, int(d)])
		if n.is_in_group("enemy") and d < 160.0:
			foes.append("%s@%d" % [n.name, int(d)])
	check(crowd.is_empty() and foes.is_empty(), "r33_seal_no_crowd_no_foe", [crowd, foes])
	# bariyer: yetenek yokken ret, varken geçiş
	var b0: Node = barriers[0]
	b0._hint_done = false
	b0._touch(player)
	check(bool(b0._hint_done), "r33_barrier_refuses_without_dash")
	b0._hint_done = false
	gs.player_progress_knowledge["ability_shadow_dash"] = true
	b0._touch(player)
	check(not bool(b0._hint_done), "r33_barrier_lets_dash_through")
	dm.clear()
	player.global_position = Vector2(780, 288)
	for i in 6:
		await physics_frame
	check(pm.is_solved(&"mirrors_shrine_trial"), "r33_trial_solved_at_marker")
	check(_fwd_door_open(&"mirrors_shrine"), "r33_fwd_door_open_after_trial")
	gs.player_progress_knowledge["ability_shadow_dash"] = false
	# --- 34 mirrors_1927 ---
	_unsolve(["mirrors_1927_walk", "mirrors_1927"])
	var rel: Dictionary = gs.player_progress_knowledge.get("relics", {})
	rel.erase("night_1927")
	gs.player_progress_knowledge["relics"] = rel
	dm.clear()
	rm.enter_room(&"mirrors_1927")
	for i in 20:
		await process_frame
	var n7 := _room_root(&"mirrors_1927")
	check(not dm.is_open and dm._queue.is_empty(), "r34_silent_on_entry")
	var shade: Node = null
	var brick: Node = null
	var night: Node = null
	for n in n7.find_children("*", "Node2D", true, false):
		if "shade_id" in n and String(n.shade_id) == "mirrors_1927_night":
			shade = n
		elif "symbol_text" in n and String(n.symbol_text) == "1927":
			brick = n
		elif "relic_id" in n and String(n.relic_id) == "night_1927":
			night = n
	check(shade != null and not bool(shade.fake) and shade.waypoints == PackedVector2Array([Vector2(260, 288), Vector2(430, 250), Vector2(600, 288), Vector2(760, 288)]), "r34_night_shade_config")
	check(shade != null and absf(shade.global_position.x - 120.0) < 60.0, "r34_night_shade_starts_near_120", shade.global_position if shade != null else null)
	check((n7.platforms as PackedVector3Array).has(Vector3(380, 250, 120)), "r34_platform_380_250_120")
	check(night != null and absf(night.position.x - 700.0) < 1.0 and String(night.requires_puzzle) == "mirrors_1927_walk", "r34_night_echo_700_gated")
	check(brick != null and absf(brick.position.x - 820.0) < 1.0 and brick.position.y < 240.0 and String(brick.memory_code_key) == "vault_brick" and String(brick.memory_code_value) == "1927" and String(brick.reveal_line) == "", "r34_brick_config")
	check(brick != null and not brick.is_visible_in_tree(), "r34_brick_hidden_before_walk")
	player.global_position = Vector2(700, 288)
	await _beat_run(night, player)
	check(not (gs.player_progress_knowledge.get("relics", {}) as Dictionary).get("night_1927", false) and not pm.is_solved(&"mirrors_1927"), "r34_echo_inert_before_walk")
	check(not pm.is_solved(&"mirrors_1927_walk"), "r34_walk_unsolved_on_entry")
	shade.speed = 4000.0
	for wp in shade.waypoints:
		player.global_position = wp
		for i in 8:
			await physics_frame
	check(pm.is_solved(&"mirrors_1927_walk"), "r34_walk_solves_by_following_shade")
	check(brick != null and brick.is_visible_in_tree(), "r34_brick_visible_after_walk")
	player.global_position = Vector2(820, 288)
	for i in 30:
		await physics_frame
	check(String((gs.player_progress_knowledge.get("memory_codes", {}) as Dictionary).get("vault_brick", "")) == "1927", "r34_brick_teaches_code_silently")
	check(not dm.is_open, "r34_brick_silent")
	player.global_position = Vector2(700, 288)
	await _beat_run(night, player)
	check(pm.is_solved(&"mirrors_1927"), "r34_night_echo_solves_room")
	check(_fwd_door_open(&"mirrors_1927"), "r34_fwd_door_open")
	# --- kanon: X kelimesi ---
	for rid in ["mirrors_reverse", "mirrors_dual", "mirrors_gallery", "mirrors_unbroken", "mirrors_labyrinth", "mirrors_shrine"]:
		var txt := FileAccess.get_file_as_string("res://scenes/rooms/%s.tscn" % rid)
		var jp := "res://data/dialogue/%s.json" % rid
		if FileAccess.file_exists(jp):
			txt += FileAccess.get_file_as_string(jp)
		check(_x_words(txt) == 0, "canon_no_x_in_%s" % rid, _x_words(txt))
	var t27 := FileAccess.get_file_as_string("res://scenes/rooms/mirrors_1927.tscn")
	var cut := t27.find('[node name="NightEcho"')
	var rest := t27.substr(0, cut) if cut >= 0 else t27
	var after := t27.find("[node name=", cut + 10) if cut >= 0 else -1
	if after >= 0:
		rest += t27.substr(after)
	check(_x_words(rest) == 0, "canon_x_1927_only_in_night_echo_scene", _x_words(rest))
	var jd = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/mirrors_1927.json"))
	var other_x := 0
	for set_id in (jd["sets"] as Dictionary).keys():
		if set_id == "echo":
			continue
		for ln in jd["sets"][set_id]:
			other_x += _x_words(String(ln["t"])) + (1 if String(ln["s"]) == "X" else 0)
	check(other_x == 0, "canon_x_1927_only_in_echo_set", other_x)


func _rooms_35_37() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	var cur := root.get_node("CurseManager")
	var player: Node2D = current_scene.get_node("Player")
	# --- 35 core_threshold ---
	_unsolve(["core_threshold", "core_threshold_crossed"])
	_clear_corpses()
	rm.enter_room(&"core_threshold")
	await process_frame
	await process_frame
	var ct := _room_root(&"core_threshold")
	var cloud: Node = null
	var marker: Node = null
	var tbeat: Node = null
	var tseal: Node = null
	for n in ct.find_children("*", "Node2D", true, false):
		if n.is_in_group("curse_cloud"):
			cloud = n
		elif "puzzle_id" in n and String(n.puzzle_id) == "core_threshold_crossed":
			marker = n
		elif "beat_id" in n and String(n.beat_id) == "core_threshold":
			tbeat = n
		elif n.has_method("on_interact") and "room_id" in n and String(n.room_id) == "core_threshold":
			tseal = n
	check(cloud != null and absf(cloud.position.x - 590.0) < 2.0 and cloud.size == Vector2(420, 150) and is_equal_approx(cloud.safe_radius, 120.0), "r35_cloud_config")
	check(marker != null and absf(marker.position.x - 840.0) < 2.0 and Array(marker.also_solve).has("core_threshold"), "r35_marker_also_solves_legacy")
	check(tbeat != null and absf(tbeat.position.x - 280.0) < 2.0, "r35_threshbeat_x280")
	check(tseal != null and tseal.position == Vector2(200, 288), "r35_memory_seal_200")
	var ctsp: Dictionary = rm._rooms[&"core_threshold"].spawns
	check(ctsp.has(&"seal_core_threshold") and ctsp[&"seal_core_threshold"] == Vector2(200, 288), "r35_seal_marker_200")
	# cesetsiz bulut lanet yer
	cur.curse = 0.0
	player.global_position = Vector2(590, 288)
	for i in 30:
		await physics_frame
	check(cur.curse > 5.0, "r35_cloud_without_corpse_adds_curse", cur.curse)
	check(cloud != null and not cloud._is_safe(Vector2(590, 288)), "r35_unshielded_not_safe")
	# golge atilmasi tek basina bulutu gecemez
	var dash_dist: float = float(player.DASH_SPEED) * float(player.DASH_TIME)
	check(cloud != null and dash_dist < float(cloud.size.x) * 0.5, "r35_dash_cannot_cross_cloud", dash_dist)
	# gercek oda ici olum: iki kan dikeni -> iki ceset -> bulut guvenli
	var thorns: Array = []
	for n in ct.find_children("*", "Area2D", true, false):
		if n.is_in_group("blood_thorn"):
			thorns.append(n)
	thorns.sort_custom(func(a, c): return a.position.x < c.position.x)
	check(thorns.size() == 2 and absf(thorns[0].anchor_x - 480.0) < 1.0 and absf(thorns[1].anchor_x - 700.0) < 1.0, "r35_two_thorns_anchor_480_700", thorns.size())
	if thorns.size() == 2:
		var tsp: Dictionary = rm._rooms[&"core_threshold"].spawns
		var spacing_ok := true
		for t in thorns:
			for n in ct.find_children("*", "Area2D", true, false):
				if n == t or n.get_parent() != t.get_parent():
					continue
				var need := 96.0 if n.get_script() == load("res://scripts/world/room_transition.gd") else 80.0
				if absf(n.position.x - t.position.x) < need:
					spacing_ok = false
			for sk in tsp:
				if absf(Vector2(tsp[sk]).x - t.position.x) < 20.0:
					spacing_ok = false
			spacing_ok = spacing_ok and t.position.y >= 270.0 and t.position.x > 150.0 and t.position.x < 880.0
		check(spacing_ok, "r35_thorn_spacing_and_floor")
		var death := root.get_node("DeathManager")
		var kill_idx := 0
		for t in thorns:
			cur.curse = 0.0 if kill_idx == 0 else cur.curse
			player.global_position = Vector2(t.position.x, 288)
			t._armed = true
			await t.on_interact(player)
			var tw := 0.0
			while death.is_dying and tw < 30.0:
				await process_frame
				tw += 0.016
			await process_frame
			await process_frame
			kill_idx += 1
		var cs: Array = gs.world_memory_state["corpses"]
		check(cs.size() == 2, "r35_thorn_deaths_make_two_corpses", cs.size())
		var cloud2: Node = null
		for n in _room_root(&"core_threshold").find_children("*", "Node2D", true, false):
			if n.is_in_group("curse_cloud"):
				cloud2 = n
		var cov2 := cloud2 != null
		var xq := 384.0
		while cloud2 != null and xq <= 796.0:
			cov2 = cov2 and cloud2._is_safe(Vector2(xq, 288))
			xq += 4.0
		check(cov2, "r35_thorn_corpses_cover_cloud")
		check(cur.curse < 100.0, "r35_curse_below_100_after_two_deaths", cur.curse)
		var base_curse: float = cur.curse
		player.global_position = Vector2(590, 288)
		for i in 30:
			await physics_frame
		check(cur.curse <= base_curse + 1.0, "r35_thorn_corridor_adds_no_curse", cur.curse)
		_unsolve(["core_threshold", "core_threshold_crossed"])
		player.global_position = Vector2(840, 288)
		for i in 8:
			await physics_frame
		check(pm.is_solved(&"core_threshold"), "r35_thorn_route_solves_threshold")
	_clear_corpses()
	await process_frame
	# 2 ceset (x480, x700) koridoru kapatir: bulutun tamami guvenli
	_corpse_at(480, 288)
	_corpse_at(700, 288)
	await process_frame
	var cov := true
	var xs := 384.0
	while xs <= 796.0:
		cov = cov and cloud._is_safe(Vector2(xs, 288))
		xs += 4.0
	check(cov, "r35_two_corpses_cover_cloud")
	cur.curse = 0.0
	player.global_position = Vector2(590, 288)
	for i in 30:
		await physics_frame
	check(cur.curse < 1.0, "r35_corridor_safe_with_two_corpses", cur.curse)
	check((gs.world_memory_state["corpses"] as Array).size() <= 2, "r35_needs_at_most_two_corpses")
	# ThreshBeat tek basina cozmez
	_unsolve(["core_threshold", "core_threshold_crossed"])
	await _beat_run(tbeat, player)
	check(not pm.is_solved(&"core_threshold"), "r35_threshbeat_does_not_solve")
	# marker cozer
	player.global_position = Vector2(840, 288)
	for i in 8:
		await physics_frame
	check(pm.is_solved(&"core_threshold_crossed") and pm.is_solved(&"core_threshold"), "r35_marker_solves_threshold")
	check(_fwd_door_open(&"core_threshold"), "r35_door_opens_after_marker")
	_clear_corpses()
	cur.curse = 0.0
	# --- 36 core_ascent ---
	rm.enter_room(&"core_ascent")
	await process_frame
	await process_frame
	var ca := _room_root(&"core_ascent")
	var ca_doors := _doors_of(ca)
	var ca_back := ca_doors.filter(func(d): return String(d.target_room_id) == "core_threshold")
	var ca_fwd := ca_doors.filter(func(d): return String(d.target_room_id) == "core_seal_chamber")
	check(ca_back.size() == 1 and String(ca_back[0].target_spawn_id) == "from_core_ascent", "r36_back_door")
	check(ca_fwd.size() == 1 and String(ca_fwd[0].target_spawn_id) == "from_core_ascent" and String(ca_fwd[0].required_puzzle) == "core_ascent", "r36_fwd_door")
	var ss_ok := false
	var cb_ok := false
	for n in ca.find_children("*", "Node2D", true, false):
		if n.is_in_group("soul_seal") and "refusal_line" in n and String(n.refusal_line).contains("Yasak Kanat"):
			ss_ok = true
		if n.is_in_group("curse_barrier") and "refusal_line" in n and String(n.refusal_line).contains("Ayna Tapınağı"):
			cb_ok = true
	check(ss_ok and cb_ok, "r36_refusal_lines_name_rooms")
	# --- 37 core_seal_chamber ---
	_unsolve(["core_seal", "core_seal_bond_1", "core_seal_bond_2", "core_seal_bond_3"])
	gs.player_progress_knowledge["trusted_keeper"] = false
	rm.enter_room(&"core_seal_chamber")
	await process_frame
	await process_frame
	var sc := _room_root(&"core_seal_chamber")
	var by_id := {}
	for b in _veins_of(sc):
		by_id[String(b.puzzle_id)] = b
	var has3: bool = by_id.has("core_seal_bond_1") and by_id.has("core_seal_bond_2") and by_id.has("core_seal_bond_3")
	check(has3, "r37_three_bonds", by_id.keys())
	if has3:
		var b1: Node = by_id["core_seal_bond_1"]
		var b2: Node = by_id["core_seal_bond_2"]
		var b3: Node = by_id["core_seal_bond_3"]
		check(absf(b1.position.x - 300.0) < 2.0 and absf(b2.position.x - 470.0) < 2.0 and absf(b3.position.x - 640.0) < 2.0, "r37_bond_positions")
		check(not b1.blocking and not b2.blocking and not b3.blocking, "r37_bonds_not_blocking")
		check(String(b1.requires) == "" and String(b2.requires) == "core_seal_bond_1" and String(b3.requires) == "core_seal_bond_2", "r37_bond_chain")
		check(b2.wrong_line == "Bağ direniyor. Önce yakındakini kes." and b3.wrong_line == b2.wrong_line, "r37_wrong_line")
		b2.receive_soul_slash(player)
		b3.receive_soul_slash(player)
		check(not pm.is_solved(&"core_seal_bond_2") and not pm.is_solved(&"core_seal_bond_3"), "r37_out_of_order_refused")
		var sbeat: Node = null
		var sseal: Node = null
		for n in sc.find_children("*", "Node2D", true, false):
			if "beat_id" in n and String(n.beat_id) == "core_seal_chamber":
				sbeat = n
			elif n.has_method("on_interact") and "room_id" in n and String(n.room_id) == "core_seal_chamber":
				sseal = n
		check(sbeat != null and absf(sbeat.position.x - 780.0) < 2.0, "r37_sealbeat_x780")
		check(sseal != null and sseal.position == Vector2(160, 288), "r37_memory_seal_160")
		var scsp: Dictionary = rm._rooms[&"core_seal_chamber"].spawns
		check(scsp.has(&"seal_core_seal_chamber") and scsp[&"seal_core_seal_chamber"] == Vector2(160, 288), "r37_seal_marker_160")
		var doors_x: Array = []
		for d in _doors_of(sc):
			doors_x.append(d.position.x)
		check(_min_dx(doors_x, [sseal]) >= 56.0 and _min_dx([sseal.position.x], [b1, b2, b3, sbeat]) >= 80.0, "r37_memory_seal_spacing")
		_unsolve(["core_seal"])
		await _beat_run(sbeat, player)
		check(not pm.is_solved(&"core_seal"), "r37_beat_refuses_before_bonds")
		b1.receive_soul_slash(player)
		b2.receive_soul_slash(player)
		b3.receive_soul_slash(player)
		check(pm.is_solved(&"core_seal_bond_1") and pm.is_solved(&"core_seal_bond_2") and pm.is_solved(&"core_seal_bond_3"), "r37_bonds_in_order")
		await _beat_run(sbeat, player)
		check(pm.is_solved(&"core_seal"), "r37_beat_solves_core_seal_after_bonds")
		check(not bool(gs.player_progress_knowledge.get("trusted_keeper", false)), "r37_trusted_keeper_unchanged")
		check(_fwd_door_open(&"core_seal_chamber"), "r37_door_opens")
	var src_txt := FileAccess.get_file_as_string("res://scripts/story/story_beat.gd")
	var fn_at := src_txt.find("func _core_seal_chamber")
	var fn_end := src_txt.find("func _evidence", fn_at)
	check(fn_at >= 0 and not src_txt.substr(fn_at, fn_end - fn_at).contains("trusted_keeper"), "r37_no_trusted_keeper_writer")
	_clear_corpses()


func _word_hits(text: String, pattern: String) -> int:
	return RegEx.create_from_string(pattern).search_all(text).size()


func _src_files(dir_path: String, ext: String, skip_dev: bool, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		if skip_dev and sub == "dev":
			continue
		_src_files(dir_path.path_join(sub), ext, skip_dev, out)


func _bloom_nodes(gr: Node) -> Dictionary:
	var out := {"mem": null, "rec": null, "plate": null, "thorn": null, "shrine": null, "steps": {}}
	for n in gr.find_children("*", "Node2D", true, false):
		if "lore_id" in n and String(n.lore_id) == "bloom_memory":
			out["mem"] = n
		elif "lore_id" in n and String(n.lore_id) == "bloom_reconcile":
			out["rec"] = n
		elif "accept_stone" in n and String(n.puzzle_id) == "core_bloom_weight":
			out["plate"] = n
		elif n.is_in_group("blood_thorn"):
			out["thorn"] = n
		elif "order" in n and "puzzle_id" in n and String(n.puzzle_id) == "core_bloom_order":
			out["shrine"] = n
		elif "step_id" in n:
			(out["steps"] as Dictionary)[String(n.step_id)] = n
	return out


func _rooms_38_39() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	var cur := root.get_node("CurseManager")
	var dm := root.get_node("DialogueManager")
	var player: Node2D = current_scene.get_node("Player")
	var seen: Array = gs.player_progress_knowledge.get("lore_seen", [])
	for sid in ["memory_vault", "bloom_reconcile", "bloom_memory"]:
		seen.erase(sid)
	gs.player_progress_knowledge["lore_seen"] = seen
	# --- 38 core_memory_vault ---
	_unsolve(["core_vault_order"])
	gs.player_progress_knowledge["truth_seen"] = false
	_clear_corpses()
	rm.enter_room(&"core_memory_vault")
	await process_frame
	await process_frame
	var vr := _room_root(&"core_memory_vault")
	var v_echo: Node = null
	var v_shrine: Node = null
	var v_lore: Node = null
	var v_steps := {}
	for n in vr.find_children("*", "Node2D", true, false):
		if "npc_id" in n and String(n.npc_id) == "vault_voice":
			v_echo = n
		elif "order" in n and "puzzle_id" in n and String(n.puzzle_id) == "core_vault_order":
			v_shrine = n
		elif "lore_id" in n and String(n.lore_id) == "memory_vault":
			v_lore = n
		elif "step_id" in n:
			v_steps[String(n.step_id)] = n
	check(v_echo != null and absf(v_echo.position.x - 200.0) < 1.0, "r38_echo_x200")
	check(v_shrine != null and v_shrine.order == PackedStringArray(["1927", "1995", "son"]), "r38_order_1927_1995_son")
	var steps_ok: bool = v_steps.size() == 3
	if steps_ok:
		steps_ok = absf(v_steps["1927"].position.x - 360.0) < 1.0 and absf(v_steps["1995"].position.x - 500.0) < 1.0 and absf(v_steps["son"].position.x - 640.0) < 1.0
	check(steps_ok, "r38_steps_360_500_640")
	check(v_lore != null and absf(v_lore.position.x - 780.0) < 1.0 and String(v_lore.requires_puzzle) == "core_vault_order" and String(v_lore.set_progress_key) == "truth_seen", "r38_lore_780_gated_truth")
	check(v_shrine != null and v_shrine.fail_line == "Kasa susuyor. Sıra yanlış." and not bool(v_shrine.penalize_wrong), "r38_fail_line_and_no_penalty")
	if v_echo == null or v_shrine == null or v_lore == null or not steps_ok:
		return
	var vtexts: Array = []
	vtexts.append_array(Array(v_echo.dialogue_sets))
	vtexts.append(String(v_shrine.fail_line))
	vtexts.append_array(Array(v_lore.locked_lines))
	var objs := FileAccess.get_file_as_string("res://scripts/story/campaign_objectives.gd")
	var vo := RegEx.create_from_string('"core_memory_vault":\\s*"([^"]*)"').search(objs)
	var bo := RegEx.create_from_string('"core_bloom_garden":\\s*"([^"]*)"').search(objs)
	if vo != null:
		vtexts.append(vo.get_string(1))
	check(vo != null and bo != null, "r38_objectives_found")
	var vleak := []
	for t in vtexts:
		if _word_hits(String(t), "1927|1995|\\b[Ss]on\\b") > 0:
			vleak.append(t)
	check(vleak.is_empty(), "r38_no_answer_leak_in_texts", vleak)
	# kilitli: bayrak yok
	await _beat_run(v_lore, player)
	check(not bool(gs.player_progress_knowledge.get("truth_seen", false)), "r38_truth_false_when_locked")
	# yanlis sira
	cur.curse = 0.0
	v_steps["1995"].on_interact(player)
	v_steps["son"].on_interact(player)
	check(not pm.is_solved(&"core_vault_order") and cur.curse < 0.5, "r38_wrong_order_unsolved_no_curse", cur.curse)
	v_steps["1927"].on_interact(player)
	v_steps["son"].on_interact(player)
	check(not pm.is_solved(&"core_vault_order"), "r38_skip_step_unsolved")
	dm.clear()
	check(not _fwd_door_open(&"core_memory_vault"), "r38_fwd_door_closed_before")
	v_steps["1927"].on_interact(player)
	v_steps["1995"].on_interact(player)
	v_steps["son"].on_interact(player)
	check(pm.is_solved(&"core_vault_order"), "r38_correct_order_solves_after_retry")
	check(_fwd_door_open(&"core_memory_vault"), "r38_fwd_door_opens")
	dm.clear()
	check(not bool(gs.player_progress_knowledge.get("truth_seen", false)), "r38_truth_false_until_last_memory")
	await _beat_run(v_lore, player)
	check(bool(gs.player_progress_knowledge.get("truth_seen", false)), "r38_truth_true_after_last_memory")
	check(v_lore.lines.size() >= 4 and v_lore.lines.size() <= 6, "r38_memory_4_to_6_lines", v_lore.lines.size())
	var vdx: Array = []
	for d in _doors_of(vr):
		vdx.append(d.position.x)
	check(_min_dx(vdx, [v_lore, v_steps["1927"], v_steps["son"], v_echo]) >= 96.0, "r38_door_clearance")
	# --- 39 core_bloom_garden ---
	_unsolve(["core_bloom_order", "core_bloom_weight"])
	gs.player_progress_knowledge["trusted_keeper"] = false
	gs.player_progress_knowledge["keeper_hurt"] = false
	gs.player_progress_knowledge["keeper_withdrew"] = false
	_clear_corpses()
	dm.clear()
	rm.enter_room(&"core_bloom_garden")
	await process_frame
	await process_frame
	var gr := _room_root(&"core_bloom_garden")
	var g := _bloom_nodes(gr)
	var gok: bool = g["mem"] != null and g["rec"] != null and g["plate"] != null and g["thorn"] != null and g["shrine"] != null and (g["steps"] as Dictionary).size() == 3
	check(gok, "r39_nodes_present")
	if not gok:
		return
	check(absf(g["mem"].position.x - 200.0) < 1.0, "r39_memory_x200")
	var pips := {}
	for sk in g["steps"]:
		var sn: Node = g["steps"][sk]
		pips[sk] = [int(sn.pips), sn.position.x, sn.position.y]
	check(pips == {"4": [4, 400.0, 246.0], "1": [1, 520.0, 246.0], "2": [2, 660.0, 246.0]}, "r39_crowns_unchanged", pips)
	var gp: Node = g["plate"]
	check(absf(gp.position.x - 260.0) < 1.0 and not bool(gp.accept_player) and not bool(gp.accept_stone), "r39_weight_plate_config")
	var gt: Node = g["thorn"]
	check(absf(gt.anchor_x - 260.0) < 1.0 and String(gt.puzzle_hint) == "core_bloom_weight", "r39_thorn_anchor_260")
	var gs_: Node = g["shrine"]
	check(Array(gs_.require_live) == ["core_bloom_weight"] and gs_.require_line == "Taşlar ağırlık bekliyor. Bedenim plakada kalmalı." and gs_.fail_line == "Taç soldu. Baştan say.", "r39_shrine_requires_weight")
	var grec: Node = g["rec"]
	check(absf(grec.position.x - 790.0) < 1.0 and String(grec.requires_puzzle) == "core_bloom_order" and bool(grec.trust_gate) and String(grec.set_progress_key) == "trusted_keeper", "r39_reconcile_790_gated")
	var gtexts: Array = [String(gs_.fail_line), String(gs_.require_line)]
	gtexts.append_array(Array(grec.locked_lines))
	gtexts.append_array(Array(grec.untrusted_lines))
	if bo != null:
		gtexts.append(bo.get_string(1))
	var gleak := []
	for t in gtexts:
		if _word_hits(String(t), "\\b([Dd]ört|[Bb]ir|[Ii]ki)\\b|[0-9]") > 0:
			gleak.append(t)
	check(gleak.is_empty(), "r39_no_answer_leak_in_texts", gleak)
	var gdx: Array = []
	for d in _doors_of(gr):
		gdx.append(d.position.x)
	check(_min_dx(gdx, [grec, g["mem"], gp, gt]) >= 96.0, "r39_door_clearance")
	# cesetsiz: adim reddi
	g["steps"]["4"].on_interact(player)
	check(gs_.get_progress() == 0 and not pm.is_solved(&"core_bloom_order"), "r39_step_refused_without_corpse")
	g["steps"]["1"].on_interact(player)
	g["steps"]["2"].on_interact(player)
	check(not pm.is_solved(&"core_bloom_order"), "r39_no_solve_without_corpse")
	dm.clear()
	# gercek olum
	var death := root.get_node("DeathManager")
	player.global_position = Vector2(gt.position.x, 288)
	gt._armed = true
	await gt.on_interact(player)
	var tw := 0.0
	while death.is_dying and tw < 30.0:
		await process_frame
		tw += 0.016
	for i in 6:
		await physics_frame
	dm.clear()
	var cs: Array = gs.world_memory_state["corpses"]
	var cx := -1.0
	if cs.size() > 0:
		cx = float(((cs[0] as Dictionary).get("position", {}) as Dictionary).get("x", -1.0))
	check(cs.size() == 1 and absf(cx - 260.0) < 3.0, "r39_thorn_death_one_corpse_on_plate", [cs.size(), cx])
	check(pm.is_live(&"core_bloom_weight"), "r39_corpse_holds_plate")
	gr = _room_root(&"core_bloom_garden")
	g = _bloom_nodes(gr)
	player = current_scene.get_node("Player")
	g["steps"]["1"].on_interact(player)
	g["steps"]["4"].on_interact(player)
	g["steps"]["2"].on_interact(player)
	check(not pm.is_solved(&"core_bloom_order"), "r39_wrong_order_unsolved")
	dm.clear()
	g["steps"]["4"].on_interact(player)
	g["steps"]["1"].on_interact(player)
	g["steps"]["2"].on_interact(player)
	check(pm.is_solved(&"core_bloom_order"), "r39_corpse_then_4_1_2_solves")
	check((gs.world_memory_state["corpses"] as Array).size() <= 1, "r39_needs_at_most_one_corpse")
	check(_fwd_door_open(&"core_bloom_garden"), "r39_fwd_door_opens")
	dm.clear()
	# Uzlasma: guvensiz -> yazmaz
	gs.player_progress_knowledge["trusted_keeper"] = false
	gs.player_progress_knowledge["keeper_hurt"] = true
	check(not gs.is_shilda_trusted(), "r39_untrusted_precondition")
	await _beat_run(g["rec"], player)
	check(not bool(gs.player_progress_knowledge.get("trusted_keeper", false)), "r39_untrusted_reconcile_writes_nothing")
	gs.player_progress_knowledge["keeper_hurt"] = false
	check(gs.is_shilda_trusted(), "r39_trusted_precondition")
	await _beat_run(g["rec"], player)
	check(bool(gs.player_progress_knowledge.get("trusted_keeper", false)), "r39_trusted_reconcile_sets_flag")
	# tek yazici
	var bad: Array = []
	var gd_files: Array = []
	_src_files("res://scripts", ".gd", true, gd_files)
	var wr := RegEx.create_from_string('"(trusted_keeper|truth_seen)"\\]\\s*=\\s*true')
	for f in gd_files:
		if wr.search(FileAccess.get_file_as_string(f)) != null:
			bad.append(f)
	check(bad.is_empty(), "single_writer_no_gd_true_writes", bad)
	var tscn_files: Array = []
	_src_files("res://scenes", ".tscn", false, tscn_files)
	var tk := []
	var ts := []
	for f in tscn_files:
		var tx := FileAccess.get_file_as_string(f)
		if tx.contains('set_progress_key = "trusted_keeper"'):
			tk.append(String(f).get_file())
		if tx.contains('set_progress_key = "truth_seen"'):
			ts.append(String(f).get_file())
	check(tk == ["core_bloom_garden.tscn"] and ts == ["core_memory_vault.tscn"], "single_writer_scene_keys", [tk, ts])
	var sg := FileAccess.get_file_as_string("res://scripts/story/shilda_garden_trust.gd")
	var kc := FileAccess.get_file_as_string("res://scripts/keeper/keeper_controller.gd")
	check(not sg.contains("trusted_keeper") and sg.contains("add_vigil_trust(1)"), "garden_trust_uses_vigil_trust")
	check(kc.contains("add_vigil_trust(1)"), "keeper_controller_uses_vigil_trust")
	check(not FileAccess.get_file_as_string("res://scripts/story/story_beat.gd").contains("truth_seen"), "story_beat_no_truth_seen")
	_clear_corpses()
	gs.player_progress_knowledge["trusted_keeper"] = false
	gs.player_progress_knowledge["truth_seen"] = false


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



func _shade_count_in(room: Node) -> int:
	var n := 0
	for s in room.find_children("*", "CharacterBody2D", true, false):
		if s.is_in_group("memory_shade") and not s.is_queued_for_deletion():
			n += 1
	return n


func _drive_final(em: Node, dm: Node) -> void:
	em.trigger(em.Ending.PART_ONE, true)
	var t0 := Time.get_ticks_msec()
	while em.current != em.Ending.NONE and Time.get_ticks_msec() - t0 < 90000:
		if dm.is_open:
			dm.advance()
		await process_frame


func _room_40_final() -> void:
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	var em := root.get_node("EndingManager")
	var dm := root.get_node("DialogueManager")
	var dth := root.get_node("DeathManager")
	var player: Node2D = current_scene.get_node("Player")
	_unsolve(["core_defense"])
	_clear_corpses()
	dm.clear()
	gs.story_flags.erase(&"game_completed")
	gs.story_flags.erase(&"final_together")
	em.reset_for_smoke()
	rm.enter_room(&"core")
	await process_frame
	await process_frame
	var cr := _room_root(&"core")
	var df: Node = null
	var crystal: Node = null
	for n in cr.find_children("*", "Node2D", true, false):
		if n.is_in_group("core_defense"):
			df = n
		elif n.is_in_group("core_crystal"):
			crystal = n
	check(df != null and crystal != null, "r40_defense_and_crystal_present")
	if df == null or crystal == null:
		return
	check(df.waves == PackedInt32Array([2, 3, 4]) and df.crystal_hp == 5 and df.puzzle_id == &"core_defense", "r40_defense_exports")
	check(df.fail_line == "Kristal titriyor. Dalgalar yeniden geliyor.", "r40_fail_line")
	var hints: Dictionary = pm.HINTS.get(&"core_defense", {})
	check(hints.has("goal") and hints.has("orientation") and hints.has("explicit"), "r40_hints_present")
	# --- savunma: dalga 0 = 2 golge, oyuncudan uzak ---
	player.global_position = Vector2(480, 288)
	var hearts0: int = int(gs.hearts)
	var corpses0: int = (gs.world_memory_state["corpses"] as Array).size()
	var done := [false]
	df.defended.connect(func(): done[0] = true)
	df.start()
	await process_frame
	check(df.wave_index() == 0 and df.shade_count() == 2 and _shade_count_in(cr) == 2, "r40_wave0_two_shades", df.shade_count())
	var far_ok := true
	for s in cr.find_children("*", "CharacterBody2D", true, false):
		if s.is_in_group("memory_shade") and absf(s.global_position.x - player.global_position.x) < 80.0:
			far_ok = false
	check(far_ok, "r40_shades_not_on_player")
	# golge kristale degince can duser, oyuncuya dokunmaz
	var s0: Node2D = df._shades[0]
	s0.global_position = Vector2(470, 288)
	for i in 10:
		await physics_frame
	check(df.hp() == 4 and df.shade_count() == 1, "r40_shade_hits_crystal_only", [df.hp(), df.shade_count()])
	check(int(gs.hearts) == hearts0 and not dth.is_dying, "r40_player_unharmed")
	# son golge de kristale degerse dalga ilerler (softlock korumasi)
	var s1: Node2D = df._shades[0]
	s1.global_position = Vector2(470, 288)
	for i in 10:
		await physics_frame
	await process_frame
	check(df.hp() == 3 and df.wave_index() == 1 and df.shade_count() == 3, "r40_last_shade_reach_advances_wave", [df.hp(), df.wave_index(), df.shade_count()])
	check(df.is_active(), "r40_wave_active_after_reach")
	# gercek kilic yolu: bir golge oldurulunce sayi duser
	var sw: Node = df._shades[0]
	sw.receive_sword_hit(player, 1.0, 2)
	await create_timer(0.6).timeout
	check(df.shade_count() == 2 and df.wave_index() == 1, "r40_sword_kill_drops_count", [df.shade_count(), df.wave_index()])
	# 3 dalga
	df.debug_clear_wave()
	await process_frame
	await process_frame
	check(df.wave_index() == 2 and df.shade_count() == 4, "r40_wave2_four_early", [df.wave_index(), df.shade_count()])
	check(not pm.is_solved(&"core_defense"), "r40_not_solved_before_last")
	df.debug_clear_wave()
	await process_frame
	check(pm.is_solved(&"core_defense") and done[0] and not df.is_active(), "r40_three_waves_solve")
	check(_shade_count_in(cr) == 0, "r40_no_shades_after_defense")
	check(dm.is_open and dm._full_line == df.finish_line and dm._speaker == gs.keeper_speaker_name(), "r40_defended_feedback_line", [dm.is_open, dm._speaker])
	check(df.finish_line.contains("dokun") and FileAccess.get_file_as_string("res://scripts/story/campaign_objectives.gd").contains("sonra kristale yeniden dokun"), "r40_objective_mentions_second_touch")
	dm.clear()
	# --- kayip: dalgalar sifirlanir, oyuncu canli, ceset yok ---
	_unsolve(["core_defense"])
	df.start()
	await process_frame
	for i in 5:
		await process_frame
		if df.shade_count() > 0:
			df.shade_reached(df._shades[0])
	await process_frame
	await process_frame
	check(df.wave_index() == 0 and df.hp() == df.crystal_hp, "r40_loss_resets_waves", [df.wave_index(), df.hp()])
	check(not dth.is_dying and int(gs.hearts) == hearts0 and (gs.world_memory_state["corpses"] as Array).size() == corpses0, "r40_loss_no_death_no_corpse")
	check(df.is_active() and df.shade_count() == 2, "r40_loss_restarts_wave0", df.shade_count())
	dm.clear()
	# --- oda degisimi: dalga iptal, orphan yok, yeniden giris bastan ---
	rm.enter_room(&"core_bloom_garden")
	await process_frame
	await process_frame
	check(not df.is_active() and df.shade_count() == 0 and _shade_count_in(cr) == 0, "r40_leave_cancels_wave")
	rm.enter_room(&"core")
	await process_frame
	await process_frame
	check(not df.is_active() and df.wave_index() == 0 and _shade_count_in(cr) == 0, "r40_reenter_clean")
	df.start()
	await process_frame
	check(df.is_active() and df.wave_index() == 0 and df.shade_count() == 2, "r40_restart_after_reenter", df.shade_count())
	rm.enter_room(&"core_bloom_garden")
	await process_frame
	await process_frame
	check(_shade_count_in(cr) == 0, "r40_second_leave_no_orphans")
	rm.enter_room(&"core")
	await process_frame
	await process_frame
	# --- kristal: hazir degil ---
	gs.set_world_flag(&"seal_shard_1", false)
	gs.set_world_flag(&"seal_shard_2", false)
	gs.player_progress_knowledge["ability_soul_slash"] = false
	_unsolve(["core_defense", "core_seal"])
	em.reset_for_smoke()
	await _beat_run(crystal, player)
	await process_frame
	check(em.last_ending == em.Ending.NONE and not df.is_active(), "r40_crystal_not_ready_no_final_no_defense")
	# --- kristal: hazir, savunma yok -> savunma baslar ---
	pm.mark_solved(&"core_seal")
	gs.set_world_flag(&"seal_shard_1", true)
	gs.set_world_flag(&"seal_shard_2", true)
	gs.player_progress_knowledge["ability_soul_slash"] = true
	check(em.can_begin_final(), "r40_ready_precondition")
	await _beat_run(crystal, player)
	await process_frame
	check(df.is_active() and em.last_ending == em.Ending.NONE, "r40_ready_starts_defense_not_final")
	dm.clear()
	# --- varyantlar ---
	var lines: Array = []
	dm.line_shown.connect(func(_sp: String, tx: String) -> void: lines.append(tx))
	var FSc: GDScript = load("res://scripts/story/final_sequence.gd")
	for combo in [[false, false], [true, false], [false, true], [true, true]]:
		gs.player_progress_knowledge["trusted_keeper"] = combo[0]
		gs.player_progress_knowledge["truth_seen"] = combo[1]
		var want: StringName = &"together" if (combo[0] and combo[1]) else &"apart"
		var tag := "%s_%s" % [combo[0], combo[1]]
		check(em.final_variant() == want, "r40_variant_fn_" + tag, em.final_variant())
		gs.story_flags.erase(&"game_completed")
		gs.story_flags.erase(&"final_together")
		em.reset_for_smoke()
		lines.clear()
		await _drive_final(em, dm)
		var lr: Dictionary = FSc.get("last_run")
		check(String(lr.get("variant", "")) == String(want) and bool(lr.get("part_label", false)), "r40_run_variant_" + tag, lr.get("variant"))
		check(gs.has_story_flag(&"final_together") == (want == &"together"), "r40_final_together_flag_" + tag)
		check(lines.has("Bu kez yanında yürüyorum.") == (want == &"together"), "r40_together_line_" + tag)
		check(lines.has("Anlıyorum. Yine de yürü.") == (want == &"apart"), "r40_apart_line_" + tag)
		check(em.last_ending == em.Ending.PART_ONE, "r40_single_ending_" + tag)
	# --- savunma sonrasi kristal finali tetikler (son sinama: dizi arka planda kalir) ---
	gs.story_flags.erase(&"game_completed")
	gs.story_flags.erase(&"final_together")
	em.reset_for_smoke()
	rm.enter_room(&"core")
	await process_frame
	_unsolve(["core_defense"])
	df.start()
	await process_frame
	for i in 3:
		df.debug_clear_wave()
		await process_frame
		await process_frame
	check(pm.is_solved(&"core_defense"), "r40_defense_solved_for_final")
	crystal.on_interact(player)
	await create_timer(0.3).timeout
	check(em.last_ending == em.Ending.PART_ONE, "r40_crystal_after_defense_triggers_final")


## ---------------------------------------------------------------------------------------------
## Softlock senaryoları (T8): v1.17 kayıtları, yeniden giriş, ceset kırpma, ana yol yürüyüşü.
## ---------------------------------------------------------------------------------------------
const _LEGACY_IDS := ["mirrors_reverse", "mirrors_dual", "mirrors_gallery", "mirrors_unbroken", "mirrors_1927"]
const _NEW_LATE_IDS := ["mirrors_labyrinth_crossed", "mirrors_shrine_trial", "mirrors_1927_walk"]


func _softlock() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var player: Node2D = current_scene.get_node("Player")
	var order: Array = Array(rm.ROOM_ORDER)
	var prog_bak: Dictionary = gs.player_progress_knowledge.duplicate(true)
	var life_bak: Dictionary = gs.character_current_life_knowledge.duplicate(true)
	var world_bak: Dictionary = gs.world_memory_state.duplicate(true)
	var src: Dictionary = load("res://scripts/dev/release_audit.gd").get_script_constant_map()["PUZZLE_SOURCE"]
	# --- (a) v1.17 kaydı core_threshold'da: diske yaz, belleği boz, yükle ---
	gs.world_memory_state["puzzles"] = {}
	for id in _LEGACY_IDS:
		(gs.world_memory_state["puzzles"] as Dictionary)[id] = true
	gs.player_progress_knowledge["trusted_keeper"] = true
	gs.player_progress_knowledge["ability_shadow_dash"] = false
	gs.character_current_life_knowledge["room"] = "core_threshold"
	gs.character_current_life_knowledge["checkpoint_room"] = "core_threshold"
	var data: Dictionary = sm._build_data()
	(data["player_progress_knowledge"] as Dictionary).erase("migrated_v118") # v1.17 dosyasında işaret yok
	check(sm._write_atomic(sm.SAVE_PATH, data), "sl_a_write_v117_save")
	sm._delete_resume_files()
	gs.world_memory_state["puzzles"] = {"junk": true}
	gs.player_progress_knowledge = {}
	check(sm.load_game(false), "sl_a_load_game")
	var puz: Dictionary = gs.world_memory_state["puzzles"]
	pm.sync_from_world()
	check(_LEGACY_IDS.all(func(i): return bool(puz.get(i, false))), "sl_a_legacy_ids_kept")
	check(_NEW_LATE_IDS.all(func(i): return bool(puz.get(i, false))), "sl_a_new_ids_migrated")
	check(bool(gs.player_progress_knowledge.get("ability_shadow_dash", false)), "sl_a_shadow_dash_granted")
	check(not bool(gs.player_progress_knowledge.get("trusted_keeper", true)), "sl_a_trusted_keeper_false")
	var fwd_ok := true
	for i in range(27, 34):
		if not _fwd_door_open(StringName(order[i])):
			fwd_ok = false
			check(false, "sl_a_forward_open_%s" % order[i])
	check(fwd_ok, "sl_a_forward_doors_reverse_to_1927_open")
	var back_ok := true
	var back_idx := 34
	while back_idx > 32:
		var prev := String(order[back_idx - 1])
		var found := false
		for d in _doors_of(_room_root(StringName(order[back_idx]))):
			if String(d.target_room_id) == prev:
				found = true
				if d.is_locked():
					back_ok = false
		if not found:
			back_ok = false
		back_idx -= 1
	check(back_ok, "sl_a_walk_back_threshold_to_shrine_open")
	# --- (b) v1.17 kaydı orta yolda (yalnız mirrors_unbroken) ---
	gs.world_memory_state["puzzles"] = {"mirrors_unbroken": true}
	_apply_old("mirrors_unbroken", {"ability_shadow_dash": false, "migrated_v118": false})
	pm.sync_from_world()
	puz = gs.world_memory_state["puzzles"]
	var lab_fwd := _doors_of(_room_root(&"mirrors_labyrinth")).filter(func(d): return String(d.target_room_id) == "mirrors_shrine")
	check(lab_fwd.size() == 1 and lab_fwd[0].is_locked(), "sl_b_labyrinth_forward_locked")
	var lab_req := String(lab_fwd[0].required_puzzle) if lab_fwd.size() == 1 else ""
	var lsrc: Array = src.get(lab_req, ["", "x"])
	check(lab_req != "" and String(lsrc[0]) == "mirrors_labyrinth" and (String(lsrc[1]) == "" or pm.is_solved(StringName(lsrc[1]))), "sl_b_labyrinth_solvable", [lab_req, lsrc])
	check(not _NEW_LATE_IDS.any(func(i): return puz.has(i)) and not puz.has("core_vault_order") and not puz.has("core_bloom_order"), "sl_b_no_auto_solve")
	# --- (c) v1.17 kaydı core'da ---
	gs.world_memory_state["puzzles"] = {}
	_apply_old("core", {"ability_shadow_dash": false, "migrated_v118": false})
	pm.sync_from_world()
	puz = gs.world_memory_state["puzzles"]
	check(bool(puz.get("core_vault_order", false)) and bool(puz.get("core_bloom_order", false)), "sl_c_vault_bloom_solved")
	_unsolve(["core_defense"])
	_clear_corpses()
	rm.enter_room(&"core")
	await process_frame
	await process_frame
	var df: Node = null
	for n in _room_root(&"core").find_children("*", "Node2D", true, false):
		if n.is_in_group("core_defense"):
			df = n
	check(df != null, "sl_c_defense_present")
	if df != null:
		player.global_position = Vector2(480, 288)
		df.start()
		await process_frame
		check(df.is_active() and df.shade_count() == 2, "sl_c_defense_playable_wave0", df.shade_count())
		df.debug_clear_wave()
		await process_frame
		await process_frame
		df.debug_clear_wave()
		await process_frame
		df.debug_clear_wave()
		await process_frame
		check(pm.is_solved(&"core_defense") and not df.is_active(), "sl_c_defense_completes")
	_unsolve(["core_defense"])
	# --- (d) 28-40: çözüm sonrası yeniden giriş ---
	gs.player_progress_knowledge["ability_shadow_dash"] = true
	var dm := root.get_node("DialogueManager")
	for i in range(27, 40):
		var rid := StringName(order[i])
		for id in _ids_of_room(rid, _room_root(rid)):
			pm.mark_solved(StringName(id))
		for id in _legacy_for(rid):
			pm.mark_solved(StringName(id))
		dm.clear()
		player.invert_x = false
		player.global_position = Vector2(60, 288)
		rm.enter_room(rid)
		await process_frame
		await process_frame
		await physics_frame
		await physics_frame
		if i < 39:
			check(_fwd_door_open(rid), "sl_d_reentry_forward_open_%s" % rid)
		check(not bool(player.invert_x), "sl_d_reentry_invert_false_%s" % rid)
		check(not dm.is_open, "sl_d_reentry_no_prompt_%s" % rid)
	# --- (e) 3 ceset anchored + 4. ölüm ---
	_clear_corpses()
	var plates := ["mirrors_gallery_plate_1", "mirrors_dual_weight", "core_bloom_weight"]
	for p in plates:
		pm.mark_solved(StringName(p))
	var cm := root.get_node("CorpseManager")
	var ids: Array = []
	for k in 3:
		ids.append(cm.record_corpse_at(Vector2(200.0 + 60.0 * k, 288.0), &"audit"))
		await create_timer(0.03).timeout # id zaman damgalı: aynı ms'de çakışmasın
	var corpses: Array = gs.world_memory_state["corpses"]
	for k in corpses.size():
		var c: Dictionary = corpses[k]
		c["anchored"] = true
		c["anchor_plate"] = plates[k % 3]
	check(corpses.size() == 3, "sl_e_three_corpses", corpses.size())
	await create_timer(0.03).timeout
	var fourth: String = cm.record_corpse_at(Vector2(420, 288), &"audit")
	corpses = gs.world_memory_state["corpses"]
	var cur_ids: Array = corpses.map(func(c): return String((c as Dictionary).get("id", "")))
	check(corpses.size() == 3, "sl_e_fourth_death_keeps_max", corpses.size())
	check(not cur_ids.has(String(ids[0])) and cur_ids.has(fourth), "sl_e_oldest_trimmed", cur_ids)
	check(plates.all(func(p): return pm.is_solved(StringName(p))), "sl_e_solved_plates_stay_solved")
	check(_fwd_door_open(&"mirrors_gallery") and _fwd_door_open(&"mirrors_dual"), "sl_e_gallery_dual_doors_open")
	var gdoor_ok := false
	for d in _doors_of(_room_root(&"core_bloom_garden")):
		if String(d.target_room_id) == "core":
			gdoor_ok = not d.is_locked()
	check(gdoor_ok, "sl_e_garden_door_open")
	pm.set_live(&"core_bloom_weight", true)
	check(pm.is_live(&"core_bloom_weight"), "sl_e_garden_plate_refillable")
	pm.set_live(&"core_bloom_weight", false)
	_clear_corpses()
	sm.delete_all_save_files() # (a) v1.17 kayıt dosyasını qa/ altında bırakma
	gs.player_progress_knowledge = prog_bak
	gs.character_current_life_knowledge = life_bak
	gs.world_memory_state = world_bak
	pm.sync_from_world()


func _legacy_for(rid: StringName) -> Array:
	var map := {
		"mirrors_reverse": ["mirrors_reverse"], "mirrors_dual": ["mirrors_dual"], "mirrors_gallery": ["mirrors_gallery"],
		"mirrors_unbroken": ["mirrors_unbroken"], "mirrors_1927": ["mirrors_1927"], "core_threshold": ["core_threshold"],
		"core_seal_chamber": ["core_seal"], "core_memory_vault": ["core_vault_order"], "core_bloom_garden": ["core_bloom_order"],
	}
	return map.get(String(rid), [])


func _main_path_walk() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var order: Array = Array(rm.ROOM_ORDER)
	check(order.size() == 40 and order[0] == "awakening" and order[39] == "core", "walk_order_01_to_40")
	var prog_bak: Dictionary = gs.player_progress_knowledge.duplicate(true)
	var world_bak: Dictionary = gs.world_memory_state.duplicate(true)
	for k in ["ability_soul_slash", "ability_shadow_dash", "ability_dash", "ability_double_jump"]:
		gs.player_progress_knowledge[k] = true
	var broken: Array = []
	for i in 39:
		var rid := StringName(order[i])
		for id in _ids_of_room(rid, _room_root(rid)):
			pm.mark_solved(StringName(id))
		for id in _legacy_for(rid):
			pm.mark_solved(StringName(id))
	# ROOM_ORDER 01-27 yan odalar içerir (crypt/catacombs/cistern ...): kapı grafiğinden, kilitsiz kapılarla BFS.
	var seen := {"awakening": true}
	var queue: Array = ["awakening"]
	while not queue.is_empty():
		var cur := String(queue.pop_front())
		for d in _doors_of(_room_root(StringName(cur))):
			var t := String(d.target_room_id)
			if d.is_locked() or seen.has(t) or not rm._rooms.has(StringName(t)):
				continue
			if not (rm._rooms[StringName(t)].spawns as Dictionary).has(StringName(d.target_spawn_id)):
				broken.append("%s->%s:nospawn(%s)" % [cur, t, d.target_spawn_id])
				continue
			seen[t] = true
			queue.append(t)
	for rid in order:
		if not seen.has(String(rid)):
			broken.append("unreached:%s" % rid)
	check(broken.is_empty(), "walk_all_40_rooms_reachable_from_01", broken)
	for i in range(27, 39):
		var fw := false
		for d in _doors_of(_room_root(StringName(order[i]))):
			if String(d.target_room_id) == String(order[i + 1]) and not d.is_locked():
				fw = true
		check(fw, "walk_forward_door_%s" % order[i])
	var door39: Node = null
	for d in _doors_of(_room_root(&"core_bloom_garden")):
		if String(d.target_room_id) == "core":
			door39 = d
	if door39 != null:
		rm.enter_room(&"core", StringName(door39.target_spawn_id))
		await process_frame
		await process_frame
		check(String(rm.get_active_room_id()) == "core", "walk_reaches_core")
		var df: Node = null
		for n in _room_root(&"core").find_children("*", "Node2D", true, false):
			if n.is_in_group("core_defense"):
				df = n
		check(df != null, "walk_core_defense_present")
		if df != null:
			_unsolve(["core_defense"])
			df.start()
			await process_frame
			df.debug_clear_wave()
			await process_frame
			await process_frame
			df.debug_clear_wave()
			await process_frame
			df.debug_clear_wave()
			await process_frame
			check(pm.is_solved(&"core_defense"), "walk_final_triggerable")
			_unsolve(["core_defense"])
	else:
		check(false, "walk_garden_to_core_door")
	gs.player_progress_knowledge = prog_bak
	gs.world_memory_state = world_bak
	pm.sync_from_world()


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


