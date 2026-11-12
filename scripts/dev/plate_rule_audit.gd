extends SceneTree
## Plaka canlı kuralı + geçiş kilidi denetimi.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/plate_rule_audit.gd
var failures := 0

## accept_player = true olan plakalar yalnız burada olabilir (oda:Düğüm, gerekçe).
const ACCEPT_PLAYER_WHITELIST := {
	"awakening_crypt:BedPlate": "Faz 2: yalnız-ceset plaka (accept_stone=false, accept_player=false); latch_on_press ile anı kalıcı açılır",
}
const CLEARANCE := 48.0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("PLATE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _find(room_root: Node, node_name: String) -> Node:
	return room_root.find_child(node_name, true, false)


func _reset_awakening(pm: Node, state: Node) -> void:
	pm.solved.erase("awakening_weight")
	var pz: Dictionary = state.world_memory_state.get("puzzles", {})
	pz.erase("awakening_weight")
	state.set_world_flag(&"awakening_door_opened", false)
	pm.set_live(&"awakening_weight", false)
	## Faz 2: kapı ayrıca ceset plakasını bekler; bu audit yalnız taş plakasını sınar, ceset plakası çözülmüş sayılır.
	pm.solved["awakening_corpse_plate"] = true


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PLATE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	_static_scene_checks()
	var state := root.get_node("GameState")
	var gate_ui := root.get_node("UiGate")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var cm := root.get_node("CorpseManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate_ui.set_story(false)
	var rm := root.get_node("RoomManager")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	var player: CharacterBody2D = current_scene.get_node("Player")
	var room_root: Node = (rm._rooms[&"awakening"] as Dictionary)["root"]
	var plate := _find(room_root, "PressurePlate") as Node2D
	var door := _find(room_root, "DoorGate") as Node2D
	var stone := _find(room_root, "WeightStone") as Node2D
	if plate == null or door == null or stone == null:
		check(false, "awakening has PressurePlate, DoorGate, WeightStone")
		quit(1)
		return
	var stone_home := stone.global_position
	var on_plate := Vector2(plate.global_position.x, stone_home.y)
	_reset_awakening(pm, state)

	# player alone must not press
	player.global_position = Vector2(plate.global_position.x, plate.global_position.y - 4.0)
	await create_timer(0.4).timeout
	check(not pm.is_live(&"awakening_weight"), "player_alone_no_press")
	player.global_position = Vector2(stone_home.x - 200.0, stone_home.y)
	await create_timer(0.2).timeout

	# live opens gate without solving
	stone.global_position = on_plate
	await create_timer(0.4).timeout
	check(door._is_open() and not pm.is_solved(&"awakening_weight"), "plate_live_opens_gate")

	# removing the stone closes the gate
	stone.global_position = stone_home
	await create_timer(0.4).timeout
	check(not door._is_open() and not pm.is_live(&"awakening_weight"), "plate_removed_closes_gate")

	# passing through latches
	stone.global_position = on_plate
	await create_timer(0.4).timeout
	player.global_position = Vector2(door.global_position.x - 60.0, stone_home.y)
	await create_timer(0.25).timeout
	player.global_position = Vector2(door.global_position.x + 60.0, stone_home.y)
	await create_timer(0.25).timeout
	check(pm.is_solved(&"awakening_weight"), "pass_through_latches: solved after crossing")
	stone.global_position = stone_home
	await create_timer(0.4).timeout
	check(door._is_open(), "pass_through_latches: gate stays open after stone removed")

	# old save: solved stays open with an empty plate
	_reset_awakening(pm, state)
	await create_timer(0.3).timeout
	check(not door._is_open(), "old_save_solved_stays_open: precondition closed")
	state.world_memory_state["puzzles"]["awakening_weight"] = true
	pm.sync_from_world()
	door._apply(door._is_open())
	await create_timer(0.3).timeout
	check(door._is_open() and not pm.is_live(&"awakening_weight"), "old_save_solved_stays_open")

	# reverse-direction crossing latches too (player starts on the far side)
	_reset_awakening(pm, state)
	stone.global_position = stone_home
	player.global_position = Vector2(door.global_position.x + 60.0, stone_home.y)
	await create_timer(0.3).timeout
	stone.global_position = on_plate
	await create_timer(0.4).timeout
	check(pm.is_live(&"awakening_weight") and not pm.is_solved(&"awakening_weight"), "reverse_crossing: live, not yet solved")
	player.global_position = Vector2(door.global_position.x + 30.0, stone_home.y)
	await create_timer(0.2).timeout
	player.global_position = Vector2(door.global_position.x - 30.0, stone_home.y)
	await create_timer(0.25).timeout
	check(pm.is_solved(&"awakening_weight"), "reverse_crossing_latches")

	# spawn/teleport past the open gate must not latch
	_reset_awakening(pm, state)
	stone.global_position = stone_home
	player.global_position = Vector2(door.global_position.x - 300.0, stone_home.y)
	await create_timer(0.3).timeout
	stone.global_position = on_plate
	await create_timer(0.4).timeout
	player.global_position = Vector2(door.global_position.x + 300.0, stone_home.y)
	await create_timer(0.4).timeout
	check(pm.is_live(&"awakening_weight") and not pm.is_solved(&"awakening_weight"), "spawn_past_gate_does_not_latch")
	stone.global_position = stone_home
	await create_timer(0.3).timeout

	# load with stone already on plate: no live feedback without player action
	_reset_awakening(pm, state)
	stone.global_position = on_plate
	player.global_position = Vector2(stone_home.x - 200.0, stone_home.y)
	await create_timer(0.3).timeout
	rm.enter_room(&"awakening", &"default")
	var fb_before: int = door.feedback_count
	await create_timer(0.4).timeout
	check(pm.is_live(&"awakening_weight") and door.feedback_count == fb_before, "load_on_plate_no_feedback (count %d->%d)" % [fb_before, door.feedback_count])
	# after the grace period a live toggle by the player does give feedback
	stone.global_position = stone_home
	await create_timer(0.8).timeout
	stone.global_position = on_plate
	await create_timer(0.4).timeout
	check(door.feedback_count == fb_before + 1, "live_feedback_after_grace (count %d live %s)" % [door.feedback_count, pm.is_live(&"awakening_weight")])
	stone.global_position = stone_home
	await create_timer(0.3).timeout

	# anchored corpse on the plate survives trim
	_reset_awakening(pm, state)
	player.global_position = Vector2(stone_home.x - 200.0, stone_home.y)
	var cid: String = cm.record_corpse_at(on_plate, &"audit")
	await create_timer(0.5).timeout
	for i in 3:
		cm.record_corpse_at(Vector2(200.0 + 40.0 * i, stone_home.y), &"audit")
		await create_timer(0.1).timeout
	var survived := false
	for c in cm.get_corpses():
		if c is Dictionary and String(c.get("id", "")) == cid:
			survived = true
	check(pm.is_live(&"awakening_weight") and survived, "anchored_corpse_survives_trim")

	# decay_weight: crossing the live gate solves + sets decay_weight_latched
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.4).timeout
	var dw_root: Node = (rm._rooms[&"decay_weight"] as Dictionary)["root"]
	var dplate := _find(dw_root, "PressurePlate") as Node2D
	var dgate := _find(dw_root, "PathGate") as Node2D
	var dstone := _find(dw_root, "WeightStone") as Node2D
	if dplate == null or dgate == null or dstone == null:
		check(false, "decay_weight has PressurePlate, PathGate, WeightStone")
	else:
		var d_home := dstone.global_position
		var d_on := Vector2(dplate.global_position.x, d_home.y)
		pm.solved.erase("decay_weight_latch")
		var dpz: Dictionary = state.world_memory_state.get("puzzles", {})
		dpz.erase("decay_weight_latch")
		state.set_world_flag(&"decay_weight_latched", false)
		pm.set_live(&"decay_weight_latch", false)
		pm.set_live(&"decay_weight_corpse", false)
		pm.solved.erase("decay_weight_corpse")
		dpz.erase("decay_weight_corpse")
		var dplayer: CharacterBody2D = current_scene.get_node("Player")
		dplayer.global_position = Vector2(dgate.global_position.x - 60.0, d_home.y)
		await create_timer(0.3).timeout
		dstone.global_position = d_on
		await create_timer(0.4).timeout
		check(pm.is_live(&"decay_weight_latch") and not pm.is_solved(&"decay_weight_latch"), "decay_weight: live before crossing")
		check(dgate.collision_layer == 1, "decay_weight: latch alone does NOT open the gate")
		pm.set_live(&"decay_weight_corpse", true)
		await create_timer(0.2).timeout
		check(dgate.collision_layer == 0, "decay_weight: latch + corpse plate opens the gate")
		dplayer.global_position = Vector2(dgate.global_position.x - 30.0, d_home.y)
		await create_timer(0.2).timeout
		dplayer.global_position = Vector2(dgate.global_position.x + 30.0, d_home.y)
		await create_timer(0.3).timeout
		check(pm.is_solved(&"decay_weight_latch") and bool(state.get_world_flag(&"decay_weight_latched", false)), "decay_weight_crossing_solves_and_flags")
		dstone.global_position = d_home
		pm.set_live(&"decay_weight_corpse", false)
		pm.solved.erase("decay_weight_corpse")
		dpz.erase("decay_weight_corpse")
		await create_timer(0.2).timeout
		check(dgate.collision_layer == 0, "decay_weight: legacy latch solved keeps gate open")

	print("PLATE_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)


## Oda .tscn dosyalarını düz metin olarak tarar: accept_player beyaz listesi + taş kenar boşluğu.
func _static_scene_checks() -> void:
	var dir := DirAccess.open("res://scenes/rooms")
	var files: PackedStringArray = []
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			files.append(f)
	files.sort()
	var accept_bad: PackedStringArray = []
	var clearance_bad: PackedStringArray = []
	var stones := 0
	var door_rx := RegEx.create_from_string("\"x\":\\s*([0-9.]+)")
	var ext_rx := RegEx.create_from_string("\\[ext_resource[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"([^\"]+)\"")
	var name_rx := RegEx.create_from_string("name=\"([^\"]+)\"")
	for f in files:
		var room := f.get_basename()
		var text := FileAccess.get_file_as_string("res://scenes/rooms/" + f)
		var ext: Dictionary = {}
		for m in ext_rx.search_all(text):
			ext[m.get_string(2)] = m.get_string(1)
		var nodes: Array = []
		var cur: Dictionary = {}
		for raw in text.split("\n"):
			var line := raw.strip_edges()
			if line.begins_with("[node "):
				if not cur.is_empty():
					nodes.append(cur)
				var nm := name_rx.search(line)
				cur = {"name": nm.get_string(1) if nm else "", "props": {}, "doors": []}
			elif line.begins_with("[") and not cur.is_empty():
				nodes.append(cur)
				cur = {}
			elif not cur.is_empty() and " = " in line:
				var kv := line.split(" = ", true, 1)
				cur["props"][kv[0]] = kv[1]
				if kv[0] == "doors":
					for dm in door_rx.search_all(kv[1]):
						cur["doors"].append(float(dm.get_string(1)))
		if not cur.is_empty():
			nodes.append(cur)
		var plate_ids: Array = []
		for n in nodes:
			var pr: Dictionary = n["props"]
			if String(pr.get("script", "")).contains("ExtResource"):
				var sid := String(pr["script"]).get_slice("\"", 1)
				n["script_path"] = String(ext.get(sid, ""))
			if String(n.get("script_path", "")).ends_with("pressure_plate.gd"):
				plate_ids.append(String(pr.get("puzzle_id", "&\"awakening_weight\"")))
				var is_accept := String(pr.get("accept_player", "false")) == "true"
				var is_latch := String(pr.get("latch_on_press", "false")) == "true"
				if is_accept or is_latch:
					var key := "%s:%s" % [room, n["name"]]
					if not ACCEPT_PLAYER_WHITELIST.has(key) or not is_latch:
						accept_bad.append(key)
		var barriers: Array = []
		for n in nodes:
			var sp := String(n.get("script_path", ""))
			var pr: Dictionary = n["props"]
			if sp.ends_with("room_transition.gd") or sp.ends_with("gated_room_transition.gd"):
				barriers.append(_x_of(pr))
			elif sp.ends_with("gate_blocker.gd"):
				var listen := String(pr.get("puzzle_listen", "&\"awakening_weight\""))
				if not plate_ids.has(listen):
					barriers.append(_x_of(pr))
			for dx in n["doors"]:
				barriers.append(dx)
		for n in nodes:
			var sp := String(n.get("script_path", ""))
			if not sp.ends_with("weight_stone.gd"):
				continue
			stones += 1
			var pr: Dictionary = n["props"]
			var sx := _x_of(pr)
			var lo := float(pr.get("min_x", "40.0"))
			var hi := float(pr.get("max_x", "900.0"))
			var right := INF
			var left := -INF
			for bx in barriers:
				if bx > sx:
					right = minf(right, bx)
				elif bx < sx:
					left = maxf(left, bx)
			if hi > right - CLEARANCE or lo < left + CLEARANCE:
				clearance_bad.append("%s:%s [%.0f..%.0f] barriers L=%.0f R=%.0f" % [room, n["name"], lo, hi, left, right])
	check(accept_bad.is_empty(), "accept_player_whitelist %s" % [accept_bad])
	check(stones > 0 and clearance_bad.is_empty(), "stone_max_x_clearance (%d stones) %s" % [stones, clearance_bad])


func _x_of(pr: Dictionary) -> float:
	var v := String(pr.get("position", "Vector2(0, 0)"))
	var inner := v.get_slice("(", 1).get_slice(")", 0)
	return float(inner.get_slice(",", 0).strip_edges())
