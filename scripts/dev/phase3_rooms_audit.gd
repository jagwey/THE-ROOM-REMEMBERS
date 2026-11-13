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
	check(spawn_bad.is_empty(), "GRAPH every door target spawn exists", spawn_bad)
	check(back_bad.is_empty(), "GRAPH every back door targets previous room", back_bad)
	check(dash_bad.is_empty(), "GRAPH no shadow dash door in 14-27", dash_bad)
