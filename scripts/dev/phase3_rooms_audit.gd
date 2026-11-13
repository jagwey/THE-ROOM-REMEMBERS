extends SceneTree
## Faz 3 (oda 14-27) denetimi. Görevler bölümleri ekler: _components, _graph, _rooms_*, _softlock.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/phase3_rooms_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("PHASE3 ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PHASE3 SKIP (run with TORIMON_TEST=1)")
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
	await _rooms_14_17()
	await _rooms_18_20()
	await _rooms_21_24()
	await _rooms_25_27()
	quit(1 if failures > 0 else 0)


func _components() -> void:
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var scene: Node = current_scene
	# --- dial_puzzle ---
	var dial := Node2D.new()
	dial.set_script(load("res://scripts/world/dial_puzzle.gd"))
	dial.puzzle_id = &"p3_dial"
	dial.targets = PackedInt32Array([3, 9, 6])
	dial.also_solve = PackedStringArray(["p3_dial_a", "p3_dial_b"])
	dial.solved_line = ""
	scene.add_child(dial)
	dial.global_position = Vector2(7000, 0)
	await process_frame
	check(dial.values() == PackedInt32Array([12, 12, 12]), "dial_start_all_12")
	for i in 3:
		dial.turn(0)
	check(dial.values()[0] == 3, "dial_turn_wraps_12_to_1_then_3")
	check(not pm.is_solved(&"p3_dial"), "dial_not_solved_partial")
	for i in 9:
		dial.turn(1)
	for i in 6:
		dial.turn(2)
	check(dial.values() == PackedInt32Array([3, 9, 6]), "dial_all_at_target")
	check(pm.is_solved(&"p3_dial"), "dial_solved_when_all_at_target")
	check(pm.is_solved(&"p3_dial_a") and pm.is_solved(&"p3_dial_b"), "dial_also_solve_ids_solved")
	dial.turn(1)
	check(dial.values()[1] == 9, "dial_turn_noop_after_solved")
	dial.queue_free()
	var dial2 := Node2D.new()
	dial2.set_script(load("res://scripts/world/dial_puzzle.gd"))
	dial2.puzzle_id = &"p3_dial2"
	dial2.targets = PackedInt32Array([5, 5])
	scene.add_child(dial2)
	await process_frame
	for i in 12:
		dial2.turn(0)
	check(dial2.values()[0] == 12, "dial_12_turns_return_to_12")
	dial2.turn(0)
	check(dial2.values()[0] == 1, "dial_13th_turn_wraps_to_1")
	dial2.queue_free()
	var dial3 := Node2D.new()
	dial3.set_script(load("res://scripts/world/dial_puzzle.gd"))
	dial3.puzzle_id = &"p3_dial"
	dial3.targets = PackedInt32Array([3, 9, 6])
	scene.add_child(dial3)
	await process_frame
	check(dial3.values() == PackedInt32Array([3, 9, 6]), "dial_solved_room_shows_targets")
	dial3.queue_free()
	var dial4 := Node2D.new()
	dial4.set_script(load("res://scripts/world/dial_puzzle.gd"))
	dial4.puzzle_id = &"p3_dial4"
	dial4.targets = PackedInt32Array([3, 3])
	scene.add_child(dial4)
	await process_frame
	var dchild: Node = dial4.get_node_or_null("Dial0")
	check(dchild != null and dchild.has_method("on_interact"), "dial_child_has_on_interact")
	if dchild:
		dchild.on_interact(scene.get_node("Player"))
		check(dial4.values()[0] == 1, "dial_child_on_interact_turns_value")
	dial4.queue_free()
	_unsolve(["p3_dial", "p3_dial_a", "p3_dial_b"])
	# --- echo_altar live_only ---
	var altar := Area2D.new()
	altar.set_script(load("res://scripts/world/echo_altar.gd"))
	altar.puzzle_id = &"p3_echo"
	altar.live_only = true
	altar.switch_kinds = PackedStringArray(["lever", "lever"])
	altar.switch_positions = PackedVector2Array([Vector2(-80, 0), Vector2(80, 0)])
	altar.lever_hold_seconds = 30.0
	scene.add_child(altar)
	altar.global_position = Vector2(7400, 0)
	await process_frame
	await process_frame
	var sws: Array = altar._switches
	check(sws.size() == 2, "echo_live_two_switches_built")
	if sws.size() == 2:
		sws[0].call("pull_by_echo")
		check(not pm.is_live(&"p3_echo"), "echo_live_off_with_one_switch")
		sws[1].call("pull_by_echo")
		check(pm.is_live(&"p3_echo") and not pm.is_solved(&"p3_echo"), "echo_live_only_live_not_solved")
		sws[0].call("_set_active", false)
		check(not pm.is_live(&"p3_echo"), "echo_live_drops_when_switch_ends")
		check(not pm.is_solved(&"p3_echo"), "echo_live_never_solved")
	if sws.size() == 2:
		sws[0].call("pull_by_echo")
		check(pm.is_live(&"p3_echo"), "echo_live_relit_before_free")
	altar.queue_free()
	await process_frame
	check(not pm.is_live(&"p3_echo"), "echo_live_only_freed_altar_clears_live")
	pm.set_live(&"p3_echo", false)
	# --- code_seal require_live ---
	var hud_nodes: Array = get_nodes_in_group("hud")
	for h in hud_nodes:
		h.remove_from_group("hud")
	var mock := Node.new()
	var gs_src := GDScript.new()
	gs_src.source_code = "extends Node\nfunc prompt_seal_code():\n\treturn \"314\"\n"
	gs_src.reload()
	mock.set_script(gs_src)
	mock.add_to_group("hud")
	scene.add_child(mock)
	var seal := Area2D.new()
	seal.set_script(load("res://scripts/world/code_seal_base.gd"))
	seal.code_key = "p3_test"
	seal.puzzle_id = &"p3_seal"
	seal.story_code = "314"
	seal.require_live = PackedStringArray(["p3_req"])
	seal.require_line = "Önce diğer mekanizma."
	scene.add_child(seal)
	seal.on_interact(null)
	check(not seal._busy, "seal_require_live_blocks_keypad")
	dm.clear()
	pm.set_live(&"p3_req", true)
	seal.on_interact(null)
	check(seal._busy, "seal_require_live_opens_when_live")
	pm.set_live(&"p3_req", false)
	var gd := 0
	while not pm.is_solved(&"p3_seal") and gd < 600:
		gd += 1
		if dm.is_open:
			dm.advance()
		await process_frame
	check(pm.is_solved(&"p3_seal"), "seal_open_keypad_survives_live_dropping")
	dm.clear()
	seal.queue_free()
	mock.queue_free()
	for h in hud_nodes:
		if is_instance_valid(h):
			h.add_to_group("hud")
	_unsolve(["p3_seal", "p3_req"])
	# --- soul_seal requires / blocking ---
	var ss := StaticBody2D.new()
	ss.set_script(load("res://scripts/world/soul_seal.gd"))
	ss.puzzle_id = &"p3_soul"
	ss.requires = &"p3_v1"
	ss.wrong_line = "Henüz değil."
	scene.add_child(ss)
	ss.global_position = Vector2(7800, 0)
	var seen := []
	var on_line := func(_sp: String, t: String): seen.append(t)
	dm.line_shown.connect(on_line)
	ss.receive_soul_slash(null)
	await process_frame
	dm.line_shown.disconnect(on_line)
	check(seen.has("Henüz değil."), "soul_refused_cut_speaks_wrong_line")
	dm.clear()
	check(not pm.is_solved(&"p3_soul"), "soul_requires_unsolved_refuses_cut")
	pm.mark_solved(&"p3_v1")
	ss.receive_soul_slash(null)
	check(pm.is_solved(&"p3_soul"), "soul_requires_solved_allows_cut")
	ss.queue_free()
	var vein := StaticBody2D.new()
	vein.set_script(load("res://scripts/world/soul_seal.gd"))
	vein.puzzle_id = &"p3_vein"
	vein.blocking = false
	scene.add_child(vein)
	var vshape := vein.get_child(0) as CollisionShape2D
	check(vshape != null and vshape.disabled, "soul_nonblocking_has_no_collision")
	vein.global_position = Vector2(8200, 0)
	var wave := Area2D.new()
	wave.set_script(load("res://scripts/player/soul_slash_wave.gd"))
	scene.add_child(wave)
	wave.global_position = Vector2(8200 - 12, -30)
	for i in 10:
		await physics_frame
	check(pm.is_solved(&"p3_vein"), "soul_nonblocking_vein_cut_by_real_wave")
	if is_instance_valid(wave):
		wave.queue_free()
	vein.queue_free()
	dm.clear()
	_unsolve(["p3_soul", "p3_v1", "p3_vein"])
	# --- save migration: soul slash for rooms after library_forbidden_wing ---
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var bak_pk: Dictionary = gs.player_progress_knowledge.duplicate(true)
	var bak_world: Dictionary = gs.world_memory_state.duplicate(true)
	var bak_life: Dictionary = gs.character_current_life_knowledge.duplicate(true)
	var bak_flags: Variant = gs.story_flags.duplicate(true) if gs.story_flags is Dictionary else gs.story_flags
	var bak_seals: Variant = gs.discovered_seals.duplicate()
	var life: Dictionary = gs.character_current_life_knowledge.duplicate(true)
	life["room"] = "experiment_cells"
	life["checkpoint_room"] = "experiment_cells"
	gs.player_progress_knowledge.erase("ability_soul_slash")
	sm._apply_data({"version": 6, "character_current_life_knowledge": life}, false)
	check(bool(gs.player_progress_knowledge.get("ability_soul_slash", false)), "migration_experiment_cells_grants_soul_slash")
	gs.player_progress_knowledge.erase("ability_soul_slash")
	life["room"] = "library_page"
	life["checkpoint_room"] = "library_page"
	sm._apply_data({"version": 6, "character_current_life_knowledge": life}, false)
	check(not bool(gs.player_progress_knowledge.get("ability_soul_slash", false)), "migration_library_page_no_soul_slash")
	gs.player_progress_knowledge = bak_pk
	gs.world_memory_state = bak_world
	gs.character_current_life_knowledge = bak_life
	gs.story_flags = bak_flags
	gs.discovered_seals = bak_seals



func _rooms_14_17() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var gs := root.get_node("GameState")
	dm.clear()
	_clear_corpses()
	# ---- 14 hall ----
	_unsolve(["library_hall_shelves", "library_catalog"])
	rm.enter_room(&"library_hall", &"default")
	await create_timer(0.4).timeout
	var hall: Node = _room_root(&"library_hall")
	var hs: Node = hall.find_child("HallShrine", true, false)
	check(hs != null and Array(hs.order) == ["saat", "cicek", "muhur"], "r14_hall_shrine_order")
	if hs != null:
		check(hs.puzzle_id == &"library_hall_shelves", "r14_hall_shrine_id")
		var books := 0
		for c in hs.get_children():
			if "step_id" in c:
				books += 1
		check(books == 3, "r14_hall_three_books")
		hs.press("muhur", null)
		hs.press("saat", null)
		check(not pm.is_solved(&"library_catalog"), "r14_hall_wrong_order_no_catalog")
		hs.press("cicek", null)
		hs.press("muhur", null)
		await create_timer(0.2).timeout
		check(pm.is_solved(&"library_hall_shelves") and pm.is_solved(&"library_catalog"), "r14_hall_shelves_solve_catalog")
		var evd: Dictionary = gs.player_progress_knowledge.get("evidence", {})
		check(evd.has("ev_hall_shelf_digit") and String(evd["ev_hall_shelf_digit"].get("body", "")).contains("iki"), "r14_hall_digit_journaled")
		dm.clear()
		hs.press("saat", null)
		check(dm.is_open, "r14_hall_resolved_shrine_repeats_clue")
		dm.clear()
	var card: Node = hall.find_child("CardLeft", true, false)
	var cb := String(card.body) if card != null else ""
	check(cb.findn("saat") >= 0 and cb.findn("saat") < cb.findn("çiçek") and cb.findn("çiçek") < cb.findn("mühür"), "r14_hall_card_states_order")
	_unsolve(["library_hall_shelves", "library_catalog"])
	var beat: Node = hall.find_child("HallBeat", true, false)
	if beat != null:
		beat.on_interact(null)
		var gdn := 0
		while gdn < 200:
			gdn += 1
			if dm.is_open:
				dm.advance()
			await process_frame
		check(not pm.is_solved(&"library_catalog"), "r14_hall_archivist_alone_not_catalog")
	dm.clear()
	# ---- 15 witness ----
	_unsolve(["library_witnesses", "library_witness_corpse", "library_witness_echo"])
	rm.enter_room(&"library_witness", &"default")
	await create_timer(0.4).timeout
	var wit: Node = _room_root(&"library_witness")
	var seal: Node = wit.find_child("WitnessSeal", true, false)
	var cplate: Node = wit.find_child("CorpsePlate", true, false)
	var altar: Node = wit.find_child("WitnessAltar", true, false)
	check(seal != null and cplate != null and altar != null, "r15_witness_nodes")
	if seal != null and cplate != null and altar != null:
		var rl: Array = Array(seal.require_live)
		check(rl.size() == 2 and "library_witness_corpse" in rl and "library_witness_echo" in rl, "r15_seal_requires_two_live")
		check(seal.story_code == "251" and seal.puzzle_id == &"library_witnesses", "r15_seal_code_251_solves_witnesses")
		check(not bool(cplate.accept_stone), "r15_corpse_plate_no_stone")
		check(bool(altar.live_only) and altar.puzzle_id == &"library_witness_echo", "r15_altar_live_only")
		var tw: Node = wit.find_child("WitnessThorn", true, false)
		check(tw != null and tw.puzzle_hint == &"library_witness_corpse" and absf(float(tw.anchor_x) - cplate.position.x) < 1.0, "r15_thorn_anchored_on_plate")
		var echo_x: float = altar.position.x + Vector2(altar.switch_positions[0]).x
		var spaced: bool = absf(cplate.position.x - echo_x) >= 200.0 and absf(cplate.position.x - seal.position.x) >= 200.0 and absf(echo_x - seal.position.x) >= 200.0
		check(spaced, "r15_plates_and_seal_spaced_200")
		# geometri: dikenin x aralığı plakayı kapsar; altar -> mühür yürüyüşü 8 sn'den kısa
		var tcs: Node = tw.find_child("CollisionShape2D", true, false) if tw != null else null
		var thalf := 20.0
		if tcs != null and tcs.shape is RectangleShape2D:
			thalf = (tcs.shape as RectangleShape2D).size.x * 0.5
		check(tw != null and cplate.position.x >= tw.position.x - thalf and cplate.position.x <= tw.position.x + thalf, "r15_thorn_range_covers_plate")
		var walk := (absf(seal.position.x - altar.position.x) + absf(echo_x - altar.position.x)) / 175.0
		check(walk < 8.0, "r15_altar_to_seal_walk_under_8s")
		var anchors: Array = []
		for nm in ["ClockEcho", "FlowerEcho", "SealEcho", "WitnessAltar"]:
			var an: Node = wit.find_child(nm, true, false)
			if an != null:
				anchors.append(an)
		check(anchors.size() == 4, "r15_witness_anchor_nodes")
		var overlap_bad := false
		for ia in anchors.size():
			for ib in range(ia + 1, anchors.size()):
				if absf(anchors[ia].position.x - anchors[ib].position.x) < 90.0:
					overlap_bad = true
		check(not overlap_bad, "r15_echoes_altar_spaced_90")
		var cp_bad := false
		for ni in wit.find_children("*", "Area2D", true, false):
			if ni.has_method("on_interact") and absf(ni.global_position.x - wit.checkpoint.x) < 40.0:
				cp_bad = true
		check(not cp_bad, "r15_checkpoint_clear_of_interactables")
		var shilda_bad := false
		for ni in wit.find_children("*", "Area2D", true, false):
			if ni.has_method("on_interact") and absf(ni.global_position.x - 702.0) < 120.0:
				shilda_bad = true
		check(not shilda_bad, "r15_shilda_clear_of_interactables")
		var hud_nodes: Array = get_nodes_in_group("hud")
		for h in hud_nodes:
			h.remove_from_group("hud")
		var mock := Node.new()
		var src := GDScript.new()
		src.source_code = "extends Node\nfunc prompt_seal_code():\n\treturn \"251\"\n"
		src.reload()
		mock.set_script(src)
		mock.add_to_group("hud")
		wit.add_child(mock)
		seal.on_interact(null)
		check(not seal._busy, "r15_seal_closed_nothing_live")
		dm.clear()
		pm.set_live(&"library_witness_corpse", true)
		seal.on_interact(null)
		check(not seal._busy, "r15_seal_closed_corpse_only")
		dm.clear()
		pm.set_live(&"library_witness_echo", true)
		seal.on_interact(null)
		check(seal._busy, "r15_seal_opens_corpse_and_echo")
		var g2 := 0
		while not pm.is_solved(&"library_witnesses") and g2 < 600:
			g2 += 1
			if dm.is_open:
				dm.advance()
			await process_frame
		check(pm.is_solved(&"library_witnesses"), "r15_code_251_solves_witnesses")
		dm.clear()
		mock.queue_free()
		for h in hud_nodes:
			if is_instance_valid(h):
				h.add_to_group("hud")
		pm.set_live(&"library_witness_corpse", false)
		pm.set_live(&"library_witness_echo", false)
	var sb := FileAccess.get_file_as_string("res://scripts/story/story_beat.gd")
	var wstart := sb.find("func _library_witness")
	var wend := sb.find("\nfunc ", wstart + 10)
	var wbody := sb.substr(wstart, (wend if wend != -1 else sb.length()) - wstart)
	check(not wbody.contains("251") and not wbody.contains("mark_solved") and not wbody.contains("learn_memory_code"), "r15_story_beat_no_251")
	var ws := FileAccess.get_file_as_string("res://scripts/story/library_witness_room.gd")
	var clk := _echo_block(ws, "witness_clock")
	var flo := _echo_block(ws, "witness_flower")
	var sea := _echo_block(ws, "witness_seal")
	check(clk.contains("üç") and clk.contains("dokuz") and clk.contains("altı"), "r15_clock_echo_hours")
	check(flo.contains("beş") and sea.contains("bir"), "r15_flower_five_seal_one")
	check(not ws.contains("251"), "r15_echo_texts_no_251")
	_unsolve(["library_witnesses", "library_witness_corpse", "library_witness_echo"])
	# ---- 16 clockroom ----
	_unsolve(["library_clock_dials", "library_clockroom"])
	rm.enter_room(&"library_clockroom", &"default")
	await create_timer(0.4).timeout
	var ck: Node = _room_root(&"library_clockroom")
	var dial: Node = ck.find_child("ClockDials", true, false)
	check(dial != null and dial.targets == PackedInt32Array([3, 9, 6]), "r16_dial_targets_396")
	if dial != null:
		check(dial.puzzle_id == &"library_clock_dials" and "library_clockroom" in Array(dial.also_solve), "r16_dial_also_solves_clockroom")
		for i in 3:
			dial.turn(0)
		for i in 9:
			dial.turn(1)
		for i in 6:
			dial.turn(2)
		dm.clear()
		check(pm.is_solved(&"library_clock_dials") and pm.is_solved(&"library_clockroom"), "r16_dials_solve_clockroom")
	for n in ck.find_children("*", "Area2D", true, false):
		if "relic_id" in n:
			check(n.solve_puzzle == &"", "r16_relic_no_solve_" + String(n.relic_id))
	_unsolve(["library_clock_dials", "library_clockroom"])
	# ---- 17 page ----
	rm.enter_room(&"library_page", &"default")
	await create_timer(0.4).timeout
	var pgs: Array = get_nodes_in_group("library_page_puzzle")
	var pg: Node = pgs[0] if pgs.size() > 0 else null
	check(pg != null, "r17_page_puzzle_exists")
	if pg != null:
		_unsolve(["library_witnesses", "library_clockroom", "library_page_order"])
		pg.open_puzzle()
		check(not pg.visible, "r17_page_closed_without_prereq")
		dm.clear()
		pm.mark_solved(&"library_witnesses")
		pg.open_puzzle()
		check(pg.visible, "r17_page_opens_with_legacy_witnesses")
		pg._hide_puzzle()
		_unsolve(["library_witnesses"])
		pm.mark_solved(&"library_clockroom")
		pg.open_puzzle()
		check(pg.visible, "r17_page_opens_with_clockroom")
		pg._hide_puzzle()
		_unsolve(["library_clockroom"])
	dm.clear()


func _rooms_18_20() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var gs := root.get_node("GameState")
	dm.clear()
	# ---- 18 upper_stacks ----
	rm.enter_room(&"library_upper_stacks", &"default")
	await create_timer(0.4).timeout
	var st: Node = _room_root(&"library_upper_stacks")
	var fwd: Node = null
	for d in _doors_of(st):
		if d.target_room_id == &"library_forbidden_wing":
			fwd = d
	check(fwd != null and fwd.required_puzzle == &"library_shelf_order", "r18_forward_door_needs_shelf_order")
	var lib_txt := ""
	var lib: Node = st.find_child("Librarian", true, false)
	if lib != null:
		lib_txt = " ".join(Array(lib.dialogue_sets)).to_lower()
	check(lib != null and not (lib_txt.find("ses") != -1 and lib_txt.find("mühür") != -1 and lib_txt.find("çiçek") != -1), "r18_librarian_states_no_answer")
	check(lib != null and lib_txt.find("sırası") != -1, "r18_librarian_hints_at_order")
	# ---- 19 forbidden_wing ----
	rm.enter_room(&"library_forbidden_wing", &"default")
	await create_timer(0.4).timeout
	var fw: Node = _room_root(&"library_forbidden_wing")
	var seals: Array = []
	for n in fw.find_children("*", "StaticBody2D", true, false):
		if n.is_in_group("soul_seal"):
			seals.append(n)
	seals.sort_custom(func(a, b): return a.position.x < b.position.x)
	check(seals.size() == 2, "r19_two_soul_seals", seals.size())
	if seals.size() == 2:
		check(seals[0].puzzle_id == &"soul_seal_forbidden" and seals[1].puzzle_id == &"soul_seal_forbidden_2", "r19_seal_ids")
		check(seals[1].requires == &"soul_seal_forbidden", "r19_second_seal_requires_first")
		var pick: Node = fw.find_child("SoulSlash", true, false)
		check(pick != null and pick.position.x < seals[0].position.x, "r19_slash_before_first_seal")
		var fwd2: Node = null
		for d in _doors_of(fw):
			if d.target_room_id == &"library_reading_cell":
				fwd2 = d
		check(fwd2 != null and fwd2.required_puzzle == &"soul_seal_forbidden_2", "r19_forward_door_needs_second_seal")
		if fwd2 != null:
			for s in seals:
				check(absf(s.position.x - fwd2.position.x) >= 96.0, "r19_door_clear_of_seal_%s" % String(s.puzzle_id))
		_unsolve(["soul_seal_forbidden", "soul_seal_forbidden_2"])
		pm.solved.erase("soul_seal_forbidden")
		seals[1].receive_soul_slash(null)
		check(not pm.is_solved(&"soul_seal_forbidden_2"), "r19_second_seal_refuses_out_of_order")
		dm.clear()
		# eski kayit: yalniz ilk muhur cozulmus -> ikincisi hala kesilebilir
		pm.mark_solved(&"soul_seal_forbidden")
		seals[1].receive_soul_slash(null)
		check(pm.is_solved(&"soul_seal_forbidden_2"), "r19_legacy_first_solved_second_cuttable")
		dm.clear()
	for hid in [&"soul_seal_forbidden", &"soul_seal_forbidden_2", &"library_reading_cabin", &"library_reading_cell"]:
		var hh: Dictionary = pm.HINTS.get(hid, {})
		check(hh.size() == 3, "r19_hint_exists_" + String(hid))
		for tier in hh.values():
			check(String(tier).length() <= 70, "r19_hint_len_" + String(hid))
	_unsolve(["soul_seal_forbidden", "soul_seal_forbidden_2"])
	# ---- 20 reading_cell ----
	_unsolve(["library_reading_cell", "library_reading_cabin"])
	(gs.player_progress_knowledge.get("relics", {}) as Dictionary).erase("reading_notches")
	rm.enter_room(&"library_reading_cell", &"default")
	await create_timer(0.4).timeout
	var rc: Node = _room_root(&"library_reading_cell")
	var cabin: Node = null
	for n in rc.find_children("*", "StaticBody2D", true, false):
		if n.is_in_group("soul_seal") and n.puzzle_id == &"library_reading_cabin":
			cabin = n
	var notches: Node = rc.find_child("Notches", true, false)
	check(cabin != null, "r20_cabin_soul_seal")
	check(cabin != null and notches != null and notches.position.x > cabin.position.x, "r20_notches_inside_cabin")
	var js := FileAccess.get_file_as_string("res://data/dialogue/library_reading_cell.json")
	for bad in ["Kitap okurdum", "Adımı unutmuşsun", "sesimi kaybettim"]:
		check(js.find(bad) == -1, "r20_json_no_" + bad)
	check(js.find("@shilda") == -1, "r20_json_no_shilda")
	var kc := FileAccess.get_file_as_string("res://scripts/keeper/keeper_controller.gd")
	var ki := kc.find('"library_reading_cell"')
	var kb := kc.substr(ki, 60) if ki != -1 else ""
	check(ki != -1 and kb.find('"hidden"') != -1 and kb.find('"present"') == -1, "r20_shilda_hidden")
	if notches != null:
		notches.on_interact(null)
		var gn := 0
		while gn < 300 and not pm.is_solved(&"library_reading_cell"):
			gn += 1
			if dm.is_open:
				dm.advance()
			await process_frame
		dm.clear()
		check(pm.is_solved(&"library_reading_cell"), "r20_notches_solve_reading_cell")
		await create_timer(0.2).timeout
		var shades := 0
		for n in rc.find_children("*", "Node2D", true, false):
			if "shade_id" in n and not bool(n.fake):
				shades += 1
		check(shades == 1, "r20_trace_shade_spawned", shades)
	var fwd3: Node = null
	for d in _doors_of(rc):
		if cabin != null:
			check(absf(d.position.x - cabin.position.x) >= 96.0, "r20_door_clear_of_cabin_%s" % String(d.target_room_id))
		if d.target_room_id == &"experiment_cells":
			fwd3 = d
	check(fwd3 != null and fwd3.required_puzzle == &"library_reading_cell", "r20_forward_door_gate")
	dm.clear()
	_migration_shelf_order()


func _fn_body(src: String, fname: String) -> String:
	var a := src.find("func " + fname)
	if a == -1:
		return ""
	var b := src.find("\nfunc ", a + 10)
	return src.substr(a, (b if b != -1 else src.length()) - a)


func _drive_busy(n: Node, dm: Node) -> void:
	var g := 0
	await process_frame
	while g < 600 and bool(n.get("_busy")):
		g += 1
		if dm.is_open:
			dm.advance()
		await process_frame


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


func _thorns_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "Area2D", true, false):
		if "anchor_x" in n and "puzzle_hint" in n:
			out.append(n)
	return out


func _rooms_21_24() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var gs := root.get_node("GameState")
	var sb := FileAccess.get_file_as_string("res://scripts/story/story_beat.gd")
	dm.clear()
	_clear_corpses()
	# ---- 21 cells ----
	_unsolve(["experiment_cells_seen", "experiment_cell_a", "experiment_cell_b", "experiment_cell_c"])
	var evd: Dictionary = gs.player_progress_knowledge.get("evidence", {})
	evd.erase("ev_cell_a")
	evd.erase("ev_cell_b")
	rm.enter_room(&"experiment_cells", &"default")
	await create_timer(0.4).timeout
	var cells: Node = _room_root(&"experiment_cells")
	var cgates: Array = _gates_of(cells)
	cgates.sort_custom(func(a, b): return a.position.x < b.position.x)
	check(cgates.size() == 3, "r21_three_cell_gates", cgates.size())
	var cplates: Array = _plates_of(cells)
	check(cplates.size() == 3, "r21_three_cell_plates", cplates.size())
	var cthorns: Array = _thorns_of(cells)
	var cids := ["experiment_cell_a", "experiment_cell_b", "experiment_cell_c"]
	for i in mini(3, mini(cgates.size(), cplates.size())):
		check(not bool(cplates[i].accept_stone) and String(cplates[i].puzzle_id) == cids[i], "r21_plate_%d_corpse_only" % i)
		check(Array(cgates[i].puzzle_listen_all) == [cids[i]], "r21_gate_%d_listens_plate" % i)
		check(cgates[i].legacy_puzzle == &"experiment_cells_seen", "r21_gate_%d_legacy_cells_seen" % i)
		check(cplates[i].position.x < cgates[i].position.x and cgates[i].position.x - cplates[i].position.x <= 100.0, "r21_plate_%d_in_front_of_gate" % i)
		var tok := false
		for t in cthorns:
			if t.puzzle_hint == StringName(cids[i]) and absf(float(t.anchor_x) - cplates[i].position.x) < 1.0:
				tok = true
		check(tok, "r21_thorn_above_plate_%d" % i)
	var cdoors: Array = []
	for d in _doors_of(cells):
		cdoors.append(d.position.x)
	check(_min_dx(cdoors, cgates + cplates + cthorns) >= 96.0, "r21_door_clearance_96")
	for c in cplates:
		check(absf(c.position.x - cells.checkpoint.x) >= 40.0, "r21_plate_clear_of_checkpoint")
	# kayitlar: A+B okununca cells_seen
	var recs: Dictionary = {}
	for n in cells.find_children("*", "Area2D", true, false):
		if "beat_id" in n:
			recs[String(n.beat_id)] = n
	check(recs.has("experiment_cell_a") and recs.has("experiment_cell_b") and recs.has("experiment_cell_c"), "r21_three_records")
	var seen_lines: Array = []
	var on_line := func(sp: String, t: String): seen_lines.append(t)
	dm.line_shown.connect(on_line)
	if recs.has("experiment_cell_a") and recs.has("experiment_cell_b"):
		recs["experiment_cell_a"].on_interact(null)
		await _drive_busy(recs["experiment_cell_a"], dm)
		check(not pm.is_solved(&"experiment_cells_seen"), "r21_only_a_does_not_solve_seen")
		check(" ".join(seen_lines).find("dört") != -1, "r21_a_says_dort")
		seen_lines.clear()
		recs["experiment_cell_a"].on_interact(null)
		await _drive_busy(recs["experiment_cell_a"], dm)
		check(" ".join(seen_lines).find("dört") != -1, "r21_a_reread_repeats_digit")
		recs["experiment_cell_b"].on_interact(null)
		await _drive_busy(recs["experiment_cell_b"], dm)
		check(pm.is_solved(&"experiment_cells_seen"), "r21_a_and_b_solve_seen")
		evd = gs.player_progress_knowledge.get("evidence", {})
		check(evd.has("ev_cell_a") and String(evd["ev_cell_a"].get("body", "")).find("dört") != -1, "r21_evidence_a_keeps_digit")
		check(evd.has("ev_cell_b") and String(evd["ev_cell_b"].get("body", "")).find("bir") != -1, "r21_evidence_b_keeps_digit")
	dm.line_shown.disconnect(on_line)
	dm.clear()
	for g in cgates:
		check(bool(g._is_open()), "r21_legacy_seen_opens_gate")
	var cells_txt := FileAccess.get_file_as_string("res://scenes/rooms/experiment_cells.tscn")
	for body in [_fn_body(sb, "_cell_record"), cells_txt]:
		var lo := String(body).to_lower()
		check(String(body) != "" and lo.find("sağdaki") == -1 and lo.find("hatıra") == -1 and lo.find("bellek") == -1, "r21_cells_text_clean")
	check(sb.find("İleride bir devre yankını bekliyor.") != -1, "r21_cells_forward_hint_line")
	# ---- 22 intake ----
	_unsolve(["experiment_intake", "experiment_intake_corpse", "experiment_intake_stone"])
	rm.enter_room(&"experiment_intake", &"default")
	await create_timer(0.4).timeout
	var intake: Node = _room_root(&"experiment_intake")
	var igates: Array = _gates_of(intake)
	check(igates.size() == 1, "r22_one_gate", igates.size())
	var ig: Node = igates[0] if igates.size() > 0 else null
	if ig != null:
		check(Array(ig.puzzle_listen_all) == ["experiment_intake_corpse", "experiment_intake_stone"], "r22_gate_listens_two_ids")
		check(ig.legacy_puzzle == &"experiment_intake" and "experiment_intake" in Array(ig.also_solve), "r22_gate_legacy_and_also_solve")
		check(not bool(ig._is_open()), "r22_gate_closed_fresh")
		pm.set_live(&"experiment_intake_corpse", true)
		check(not bool(ig._is_open()), "r22_corpse_alone_keeps_closed")
		pm.set_live(&"experiment_intake_stone", true)
		check(bool(ig._is_open()), "r22_both_live_opens")
		pm.set_live(&"experiment_intake_corpse", false)
		pm.set_live(&"experiment_intake_stone", false)
		pm.mark_solved(&"experiment_intake")
		check(bool(ig._is_open()), "r22_legacy_solved_gate_open")
		_unsolve(["experiment_intake"])
	var iplates: Array = _plates_of(intake)
	var cp: Node = null
	var sp: Node = null
	for p in iplates:
		if p.puzzle_id == &"experiment_intake_corpse":
			cp = p
		if p.puzzle_id == &"experiment_intake_stone":
			sp = p
	check(cp != null and not bool(cp.accept_stone), "r22_left_pan_corpse_only")
	check(sp != null and bool(sp.accept_stone), "r22_right_pan_takes_stone")
	var fdoor: Node = null
	for d in _doors_of(intake):
		if d.target_room_id == &"experiment_circuit":
			fdoor = d
	var stone: Node = intake.find_child("ScaleStone", true, false)
	check(stone != null and fdoor != null and float(stone.max_x) <= fdoor.position.x - 48.0, "r22_stone_max_x_below_door")
	check(stone != null and sp != null and float(stone.max_x) >= sp.position.x, "r22_stone_can_reach_plate")
	var ithorns: Array = _thorns_of(intake)
	var tok2 := false
	for t in ithorns:
		if cp != null and t.puzzle_hint == &"experiment_intake_corpse" and absf(float(t.anchor_x) - cp.position.x) < 1.0:
			tok2 = true
	check(tok2, "r22_thorn_over_left_pan")
	var iprops: Array = igates + iplates + ithorns
	if stone != null:
		iprops.append(stone)
	var idoors: Array = []
	for d in _doors_of(intake):
		idoors.append(d.position.x)
	check(_min_dx(idoors, iprops) >= 96.0, "r22_door_clearance_96")
	var coat: Node = intake.find_child("Coat", true, false)
	check(coat != null and coat.solve_puzzle == &"", "r22_coat_no_longer_solves")
	var ijs := FileAccess.get_file_as_string("res://data/dialogue/experiment_intake.json")
	check(ijs.find("sekiz") != -1 and ijs.to_lower().find("sağdaki") == -1 and ijs.find("O çiçek benimdi.") != -1, "r22_json_sekiz_no_sagdaki_flower_kept")
	var adm: Node = intake.find_child("Admission", true, false)
	check(adm != null and String(adm.evidence_body).find("sekiz") != -1, "r22_admission_evidence_keeps_digit")
	var seen2: Array = []
	var on2 := func(sp2: String, t: String): seen2.append(t)
	dm.line_shown.connect(on2)
	if adm != null:
		adm.on_interact(null)
		await _drive_busy(adm, dm)
		check(" ".join(seen2).find("sekiz") != -1, "r22_admission_says_sekiz")
		seen2.clear()
		adm.on_interact(null)
		await _drive_busy(adm, dm)
		check(" ".join(seen2).find("sekiz") != -1, "r22_admission_reread_repeats_digit")
	dm.line_shown.disconnect(on2)
	dm.clear()
	# ---- 23 circuit ----
	rm.enter_room(&"experiment_circuit", &"default")
	await create_timer(0.4).timeout
	var circ: Node = _room_root(&"experiment_circuit")
	var cb: Node = circ.find_child("CircuitBeat", true, false)
	check(cb != null and absf(float(cb.record_seconds) - 8.0) < 0.01, "r23_record_seconds_8")
	var ctxt := FileAccess.get_file_as_string("res://scenes/rooms/experiment_circuit.tscn") + _fn_body(sb, "_experiment_circuit")
	check(ctxt.find("altı" + " saniye") == -1 and ctxt.find("6 sn") == -1 and ctxt.to_lower().find("sekiz saniye") != -1, "r23_text_eight_seconds")
	check(cb != null and String(cb.solved_text).to_lower().find("sağdaki") == -1, "r23_solved_text_no_direction_word")
	# ---- 24 authority ----
	_unsolve(["experiment_authority"])
	gs.story_flags.erase(&"shilda_past_discovered")
	gs.set_world_flag(&"mirrors_unlocked", false)
	rm.enter_room(&"experiment_authority", &"default")
	await create_timer(0.4).timeout
	var auth: Node = _room_root(&"experiment_authority")
	var aseal: Node = auth.find_child("AuthoritySeal", true, false)
	check(aseal != null and aseal.story_code == "418" and aseal.puzzle_id == &"experiment_authority", "r24_seal_code_418")
	var abody := _fn_body(sb, "_experiment_authority")
	check(abody != "" and abody.find("418") == -1 and abody.find("4-1-8") == -1, "r24_authbeat_hides_code")
	check(sb.find("4-1-8") == -1, "r24_story_beat_no_4_1_8")
	if aseal != null:
		var hud_nodes: Array = get_nodes_in_group("hud")
		for h in hud_nodes:
			h.remove_from_group("hud")
		var mock := Node.new()
		var src := GDScript.new()
		src.source_code = "extends Node\nvar code := \"000\"\nfunc prompt_seal_code():\n\treturn code\n"
		src.reload()
		mock.set_script(src)
		mock.add_to_group("hud")
		current_scene.add_child(mock)
		var lp: GDScript = load("res://scripts/world/lore_point.gd")
		var pk: Dictionary = gs.player_progress_knowledge
		if pk.has("evidence"):
			for k in ["ev_cell_a", "ev_cell_b", "ev_intake_file", "ev_authority_desk"]:
				pk["evidence"].erase(k)
		if pk.has("memory_codes"):
			pk["memory_codes"].erase("experiment_authority")
		pk.erase("foreign_memory_used")
		# AuthBeat okunmadan mühür kodu istemez
		mock.code = "418"
		aseal.on_interact(null)
		await _drive_busy(aseal, dm)
		check(not pm.is_solved(&"experiment_authority"), "r24_seal_needs_authbeat_first")
		lp.record_evidence("ev_authority_desk", "Yetki masası kaydı", "test", "gunluk")
		# iki rakam kaydı: kod öğrenilmez
		lp.record_evidence("ev_cell_a", "Hücre A kaydı", "İlk hane: dört.", "izler")
		lp.record_evidence("ev_cell_b", "Hücre B kaydı", "İkinci hane: bir.", "izler")
		check(gs.memory_code_reaction("experiment_authority") == &"unknown", "r24_two_records_do_not_teach_code")
		# üçüncü kayıt: kod öğrenilir
		lp.record_evidence("ev_intake_file", "Kabul Kaydı 1995", "Son hane: sekiz.", "izler")
		check(gs.memory_code_reaction("experiment_authority") != &"unknown", "r24_three_records_teach_code")
		lp.learn_authority_code_if_ready()
		check(String(pk["memory_codes"].get("experiment_authority", "")) == "418", "r24_learn_code_idempotent")
		mock.code = "000"
		aseal.on_interact(null)
		await _drive_busy(aseal, dm)
		check(not pm.is_solved(&"experiment_authority"), "r24_wrong_code_does_not_solve")
		mock.code = "418"
		aseal.on_interact(null)
		await _drive_busy(aseal, dm)
		check(pm.is_solved(&"experiment_authority"), "r24_code_418_solves_authority")
		check(not bool(pk.get("foreign_memory_used", false)), "r24_known_code_no_foreign_memory")
		check(bool(gs.get_world_flag(&"mirrors_unlocked", false)), "r24_mirrors_unlocked")
		check(abody.find("shilda_past_discovered") != -1 and not gs.has_story_flag(&"shilda_past_discovered"), "r24_shilda_flag_only_in_authbeat")
		mock.queue_free()
		for h in hud_nodes:
			if is_instance_valid(h):
				h.add_to_group("hud")
		dm.clear()
	var afwd: Node = null
	for d in _doors_of(auth):
		if d.target_room_id == &"experiment_quarantine":
			afwd = d
	check(afwd != null and afwd.required_puzzle == &"experiment_authority", "r24_forward_door_needs_authority")
	if afwd != null and aseal != null:
		check(absf(afwd.position.x - aseal.position.x) >= 96.0, "r24_door_clear_of_seal")
	dm.clear()


func _veins_of(room: Node) -> Array:
	var out: Array = []
	for n in room.find_children("*", "StaticBody2D", true, false):
		if n.is_in_group("soul_seal"):
			out.append(n)
	out.sort_custom(func(a, b): return a.position.x < b.position.x)
	return out


func _live_shades(room: Node) -> int:
	var n := 0
	for x in room.find_children("*", "Node2D", true, false):
		if "shade_id" in x and not bool(x.fake) and not x.is_queued_for_deletion():
			n += 1
	return n


func _rooms_25_27() -> void:
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	dm.clear()
	_clear_corpses()
	# ---- 25 quarantine ----
	rm.enter_room(&"experiment_quarantine", &"default")
	await create_timer(0.4).timeout
	var qr: Node = _room_root(&"experiment_quarantine")
	var qfwd: Node = null
	for d in _doors_of(qr):
		if d.target_room_id == &"experiment_core_conduit":
			qfwd = d
	check(qfwd != null and qfwd.required_puzzle == &"experiment_quarantine_done", "r25_forward_door_needs_quarantine_done")
	var cloud := false
	for n in qr.find_children("*", "Area2D", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("curse_cloud.gd"):
			cloud = true
	check(cloud, "r25_curse_cloud_present")
	check(String(rm.ROOM_TITLES_TR.get("experiment_quarantine", "")) == "Karantina Mahzeni", "r25_title")
	var qtxt := FileAccess.get_file_as_string("res://scenes/rooms/experiment_quarantine.tscn")
	check(qtxt.find("ölü beden onu emer") == -1 and qtxt.find("Ölünü sisin") == -1, "r25_sign_gives_no_answer")
	# ---- 26 core_conduit ----
	_unsolve(["experiment_conduit", "experiment_vein_1", "experiment_vein_2", "experiment_vein_3"])
	rm.enter_room(&"experiment_core_conduit", &"default")
	await create_timer(0.4).timeout
	var cr: Node = _room_root(&"experiment_core_conduit")
	var veins: Array = _veins_of(cr)
	check(veins.size() == 3, "r26_three_soul_seals", veins.size())
	var altar_left := false
	for n in cr.find_children("*", "Area2D", true, false):
		if n.is_in_group("echo_altar"):
			altar_left = true
	check(not altar_left, "r26_no_echo_altar")
	if veins.size() == 3:
		var by_id: Dictionary = {}
		for v in veins:
			by_id[String(v.puzzle_id)] = v
		check(by_id.has("experiment_vein_1") and by_id.has("experiment_vein_2") and by_id.has("experiment_vein_3"), "r26_vein_ids")
		var v1: Node = by_id.get("experiment_vein_1")
		var v2: Node = by_id.get("experiment_vein_2")
		var v3: Node = by_id.get("experiment_vein_3")
		for v in veins:
			check(not bool(v.blocking), "r26_vein_non_blocking_%s" % String(v.puzzle_id))
		check(v1.requires == &"" and v2.requires == &"experiment_vein_1" and v3.requires == &"experiment_vein_2", "r26_requires_chain")
		check(absf(v1.position.x - 640.0) <= 40.0 and absf(v2.position.x - 300.0) <= 40.0 and absf(v3.position.x - 980.0) <= 40.0, "r26_vein_positions")
		check(v1.wrong_line == "Damar direniyor. Önce kalbe yakın olanı kes.", "r26_wrong_line")
		v2.receive_soul_slash(null)
		check(not pm.is_solved(&"experiment_vein_2"), "r26_vein2_refused_before_vein1")
		v3.receive_soul_slash(null)
		check(not pm.is_solved(&"experiment_vein_3") and not pm.is_solved(&"experiment_conduit"), "r26_vein3_refused_before_vein2")
		dm.clear()
		v1.receive_soul_slash(null)
		check(pm.is_solved(&"experiment_vein_1") and not pm.is_solved(&"experiment_conduit"), "r26_vein1_solves_alone")
		dm.clear()
		v2.receive_soul_slash(null)
		check(pm.is_solved(&"experiment_vein_2") and not pm.is_solved(&"experiment_conduit"), "r26_vein2_after_vein1")
		dm.clear()
		v3.receive_soul_slash(null)
		check(pm.is_solved(&"experiment_vein_3") and pm.is_solved(&"experiment_conduit"), "r26_vein3_solves_conduit")
		dm.clear()
		var cfwd: Node = null
		var log_n: Node = cr.find_child("ConduitLog", true, false)
		var door_xs: Array = []
		for d in _doors_of(cr):
			door_xs.append(d.position.x)
			if d.target_room_id == &"experiment_observation":
				cfwd = d
		check(cfwd != null and cfwd.required_puzzle == &"experiment_conduit", "r26_forward_door_needs_conduit")
		check(_min_dx(door_xs, veins) >= 96.0, "r26_door_clearance_96")
		var lt := " ".join(Array(log_n.lines)) if log_n != null else ""
		check(lt.find("Kalpten başla, sola dön, en son uca.") != -1, "r26_log_states_order")
	# eski kayit: kanal cozulmus -> damarlar gorsel olarak da acik
	_unsolve(["experiment_vein_1", "experiment_vein_2", "experiment_vein_3"])
	pm.mark_solved(&"experiment_conduit")
	var legacy_room: Node = (load("res://scenes/rooms/experiment_core_conduit.tscn") as PackedScene).instantiate()
	current_scene.add_child(legacy_room)
	await create_timer(0.3).timeout
	var legacy_ok := true
	var legacy_n := 0
	for v in _veins_of(legacy_room):
		legacy_n += 1
		if not pm.is_solved(v.puzzle_id) or bool(v._vis.visible):
			legacy_ok = false
	check(legacy_ok and legacy_n == 3, "r26_legacy_conduit_veins_visually_open", legacy_n)
	legacy_room.queue_free()
	_unsolve(["experiment_conduit", "experiment_vein_1", "experiment_vein_2", "experiment_vein_3"])
	var csrc := FileAccess.get_file_as_string("res://scripts/world/experiment_core_conduit.gd")
	check(csrc.find("LEVER_HOLD_SECONDS") == -1, "r26_no_lever_hold_constant")
	_unsolve(["experiment_conduit", "experiment_vein_1", "experiment_vein_2", "experiment_vein_3"])
	# ---- 27 observation ----
	_unsolve(["experiment_observation"])
	_clear_corpses()
	rm.enter_room(&"experiment_observation", &"default")
	await create_timer(0.4).timeout
	var ob: Node = _room_root(&"experiment_observation")
	var oplates: Array = _plates_of(ob)
	check(oplates.size() == 1 and String(oplates[0].puzzle_id) == "experiment_observation_projector" and not bool(oplates[0].accept_stone), "r27_corpse_only_projector_plate")
	var othorns: Array = _thorns_of(ob)
	var thorn_ok := false
	for t in othorns:
		if oplates.size() == 1 and t.puzzle_hint == &"experiment_observation_projector" and absf(float(t.anchor_x) - oplates[0].position.x) < 1.0:
			thorn_ok = true
	check(thorn_ok, "r27_thorn_above_plate")
	var ofwd: Node = null
	var odoors: Array = []
	for d in _doors_of(ob):
		odoors.append(d.position.x)
		if d.target_room_id == &"mirrors_reverse":
			ofwd = d
	check(ofwd != null and ofwd.required_puzzle == &"experiment_observation" and String(ofwd.required_ability) == "", "r27_forward_door_no_ability")
	check(_min_dx(odoors, oplates + othorns) >= 96.0, "r27_door_clearance_96")
	var opath := FileAccess.get_file_as_string("res://scenes/rooms/experiment_observation.tscn")
	check(opath.find("ability_shadow_dash") == -1 and opath.find("need_dash") == -1, "r27_no_shadow_dash")
	await create_timer(0.5).timeout
	check(_live_shades(ob) == 0, "r27_no_echo_when_plate_empty")
	var plate: Node = oplates[0] if oplates.size() == 1 else null
	if plate != null:
		_corpse_at(plate.position.x, plate.position.y - 8.0)
		await create_timer(0.6).timeout
		check(pm.is_live(&"experiment_observation_projector"), "r27_corpse_lights_plate")
		check(_live_shades(ob) == 1, "r27_echo_walks_when_plate_full", _live_shades(ob))
		_clear_corpses()
		await create_timer(0.6).timeout
		check(not pm.is_live(&"experiment_observation_projector") and _live_shades(ob) == 0, "r27_echo_stops_when_corpse_removed")
		check(not pm.is_solved(&"experiment_observation"), "r27_not_solved_while_stopped")
		_corpse_at(plate.position.x, plate.position.y - 8.0)
		await create_timer(0.6).timeout
		check(_live_shades(ob) == 1, "r27_echo_restarts_when_plate_refilled")
		var player: Node2D = current_scene.get_node("Player")
		var seen_lines: Array = []
		var on_line := func(sp: String, t: String): seen_lines.append(t)
		dm.line_shown.connect(on_line)
		var g := 0
		while g < 900 and not pm.is_solved(&"experiment_observation"):
			g += 1
			for x in ob.find_children("*", "Node2D", true, false):
				if "shade_id" in x and not bool(x.fake) and not x.is_queued_for_deletion():
					player.global_position = Vector2(x.global_position.x, 288.0)
			if dm.is_open:
				dm.advance()
			await process_frame
		check(pm.is_solved(&"experiment_observation"), "r27_echo_end_solves_observation")
		var joined := " ".join(seen_lines).replace("\n", " ")
		check(joined.find("camın ardında çalışırdım") != -1, "r27_notes_played_with_shilda_line", joined.substr(0, 200))
		dm.clear()
	var holders: Array = []
	for dir_path in ["res://data/dialogue/", "res://scenes/rooms/", "res://scripts/story/", "res://scripts/world/"]:
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".json") or f.ends_with(".tscn") or f.ends_with(".gd"):
				if FileAccess.get_file_as_string(dir_path + f).find("Ben de insandım") != -1:
					holders.append(f)
	check(holders == ["experiment_observation.json"], "r27_ben_de_insandim_only_in_observation_json", holders)
	for hid in [&"experiment_conduit", &"experiment_observation", &"experiment_quarantine_done"]:
		var hh: Dictionary = pm.HINTS.get(hid, {})
		check(hh.size() == 3, "r25_27_hint_exists_" + String(hid))
		for tier in hh.values():
			check(String(tier).length() <= 70, "r25_27_hint_len_" + String(hid))
	dm.clear()


func _migration_shelf_order() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var life: Dictionary = gs.character_current_life_knowledge
	var puzzles: Dictionary = gs.world_memory_state["puzzles"]
	var old_room: Variant = life.get("room", "")
	var old_shelf: Variant = puzzles.get("library_shelf_order", null)
	puzzles.erase("library_shelf_order")
	life["room"] = "library_forbidden_wing"
	sm._migrate_shelf_order_for_late_rooms()
	check(bool(puzzles.get("library_shelf_order", false)), "mig_old_save_past_stacks_gets_shelf_order")
	var snap := puzzles.duplicate(true)
	sm._migrate_shelf_order_for_late_rooms()
	check(puzzles == snap, "mig_idempotent")
	puzzles.erase("library_shelf_order")
	life["room"] = "library_upper_stacks"
	sm._migrate_shelf_order_for_late_rooms()
	check(not puzzles.has("library_shelf_order"), "mig_in_stacks_untouched")
	life["room"] = old_room
	if old_shelf == null:
		puzzles.erase("library_shelf_order")
	else:
		puzzles["library_shelf_order"] = old_shelf


func _echo_block(src: String, id: String) -> String:
	var a := src.find('register_echo("%s"' % id)
	if a == -1:
		return ""
	var b := src.find("register_echo(", a + 10)
	return src.substr(a, (b if b != -1 else src.length()) - a)


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

const MAIN_PATH_P3: PackedStringArray = [
	"library_hall", "library_witness", "library_clockroom", "library_page", "library_upper_stacks",
	"library_forbidden_wing", "library_reading_cell", "experiment_cells", "experiment_intake",
	"experiment_circuit", "experiment_authority", "experiment_quarantine", "experiment_core_conduit",
	"experiment_observation", "mirrors_reverse",
]


func _graph() -> void:
	var rm: Node = root.get_node("RoomManager")
	var main_scene: Node = current_scene
	var side: Dictionary = main_scene.SIDE_DOORS
	for rid in MAIN_PATH_P3:
		if rid == "mirrors_reverse":
			continue
		check(not side.has(rid), "GRAPH SIDE_DOORS has no %s" % rid)
	var fwd_ok := true
	var visited: Array = []
	var here := "library_hall"
	var guard := 0
	while guard < 30:
		guard += 1
		visited.append(here)
		if here == "mirrors_reverse":
			break
		var idx := MAIN_PATH_P3.find(here)
		var want: String = String(MAIN_PATH_P3[idx + 1]) if idx >= 0 and idx + 1 < MAIN_PATH_P3.size() else ""
		var nxt := ""
		for d in _doors_of(rm._rooms[StringName(here)].root):
			if String(d.target_room_id) == want and float(d.global_position.x) > 400.0:
				nxt = want
		if nxt == "":
			fwd_ok = false
			break
		here = nxt
	check(fwd_ok and visited == Array(MAIN_PATH_P3), "GRAPH forward walk from hall equals linear path", visited)
	var spawn_bad: Array = []
	var back_bad: Array = []
	var dash_bad: Array = []
	for i in MAIN_PATH_P3.size():
		var rid := StringName(MAIN_PATH_P3[i])
		for d in _doors_of(rm._rooms[rid].root):
			var tgt := StringName(d.target_room_id)
			var sp := StringName(d.target_spawn_id)
			if not rm.has_room(tgt) or not (rm._rooms[tgt].spawns as Dictionary).has(sp):
				spawn_bad.append("%s->%s:%s" % [rid, tgt, sp])
			if String(d.required_ability) == "ability_shadow_dash":
				dash_bad.append(String(rid))
		if i > 0 and rid != &"library_witness" and rid != &"library_hall":
			var prev := String(MAIN_PATH_P3[i - 1])
			var has_back := false
			for d in _doors_of(rm._rooms[rid].root):
				if String(d.target_room_id) == prev and float(d.global_position.x) < 400.0:
					has_back = true
			if not has_back:
				back_bad.append(String(rid))
	var gap_bad: Array = []
	for rid in MAIN_PATH_P3:
		var rroot: Node = rm._rooms[StringName(rid)].root
		var gaps = rroot.get("floor_gaps")
		var plats = rroot.get("platforms")
		for sname in (rm._rooms[StringName(rid)].spawns as Dictionary).keys():
			var sx: float = (rm._rooms[StringName(rid)].spawns[sname] as Vector2).x
			if gaps != null:
				for g in (gaps as PackedVector2Array):
					if sx > g.x - 16.0 and sx < g.y + 16.0:
						gap_bad.append("%s:%s gap" % [rid, sname])
			if plats != null:
				for p in (plats as PackedVector3Array):
					if sx > p.x - 16.0 and sx < p.x + p.z + 16.0 and p.y > 200.0:
						gap_bad.append("%s:%s under platform" % [rid, sname])
	check(gap_bad.is_empty(), "GRAPH arrival spawns not over gap or under low platform", gap_bad)
	check(spawn_bad.is_empty(), "GRAPH every door target spawn exists", spawn_bad)
	check(back_bad.is_empty(), "GRAPH every back door targets previous room", back_bad)
	check(dash_bad.is_empty(), "GRAPH no shadow dash door in 14-27", dash_bad)
