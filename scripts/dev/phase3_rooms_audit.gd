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
	check(lib != null and lib_txt.find("ses, mühür, çiçek") == -1, "r18_librarian_states_no_answer")
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
	check(pm.HINTS.has(&"soul_seal_forbidden_2") or pm.HINTS.has(&"soul_seal_forbidden"), "r19_hint_exists")
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
	var kb := kc.substr(kc.find('"library_reading_cell"'), 80)
	check(kb.find('"present"') == -1, "r20_shilda_not_present")
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
		if d.target_room_id == &"experiment_cells":
			fwd3 = d
	check(fwd3 != null and fwd3.required_puzzle == &"library_reading_cell", "r20_forward_door_gate")
	dm.clear()


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
