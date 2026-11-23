extends SceneTree
## 47 oda grafiği: hedef/spawn, güvenli doğuş, 96 px, ana yol, yan dönüş, Gölge Atılması kilidi, eski kayıt.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/room_graph_audit.gd

var failures := 0

const MAIN_PATH: PackedStringArray = [
	"awakening", "awakening_passage", "awakening_seal", "awakening_vigil",
	"decay_vines", "decay_weight", "decay_greenhouse", "decay_shilda_wall", "decay_garden",
	"library_hall", "library_witness", "library_clockroom", "library_page",
	"library_upper_stacks", "library_forbidden_wing", "library_reading_cell",
	"experiment_cells", "experiment_intake", "experiment_circuit", "experiment_authority",
	"experiment_quarantine", "experiment_core_conduit", "experiment_observation",
	"mirrors_reverse", "mirrors_dual", "mirrors_gallery", "mirrors_unbroken",
	"mirrors_labyrinth", "mirrors_shrine", "mirrors_1927",
	"core_threshold", "core_ascent", "core_seal_chamber",
	"core_memory_vault", "core_bloom_garden", "core",
]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("GRAPH ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("GRAPH SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.45).timeout
	var dm: Node = root.get_node("DialogueManager")
	var rm: Node = root.get_node("RoomManager")
	var pm: Node = root.get_node("PuzzleManager")
	var gate: Node = root.get_node("UiGate")
	dm.clear()
	gate.set_story(false)
	check(rm._rooms.size() == 47, "47 oda kayıtlı", rm._rooms.size())
	check(rm.ROOM_ORDER.size() == 47 and rm.ROOM_TITLES_TR.size() == 47, "ROOM_ORDER ve başlıklar 47")
	## v1.20.4: görünen numara oyun sırasını izler; yan odalar merkezlerinin hemen ardından.
	var po_set := {}
	for r in rm.PROGRESS_ORDER:
		po_set[r] = true
	var same_set: bool = po_set.size() == 47 and rm.PROGRESS_ORDER.size() == 47
	for r in rm.ROOM_ORDER:
		if not po_set.has(r):
			same_set = false
	check(same_set, "PROGRESS_ORDER = ROOM_ORDER kümesi (47, tekrarsız)")
	var side_ok := true
	for side in rm.SIDE_ROOM_HUB.keys():
		var hub := String(rm.SIDE_ROOM_HUB[side])
		var si: int = rm.progress_index(side)
		var hi: int = rm.progress_index(hub)
		if side == "awakening_s_room":
			side_ok = side_ok and si == 46
		elif si < 0 or hi < 0 or si <= hi or si - hi > 2:
			side_ok = false
			print("  side order bad: ", side, " ", si, " hub ", hub, " ", hi)
		if rm.progress_depth(side) != hi:
			side_ok = false
	check(side_ok, "yan odalar merkez odadan hemen sonra numaralı, derinlik = merkez")
	## Ana yol odaları sürekli ODA 01..37, yan odalar merkez kodlu ODA <hub>A.. biçiminde.
	var main_seq_ok := true
	var main_n := 0
	var side_codes_ok := true
	var side_count := 0
	for r in rm.PROGRESS_ORDER:
		var code: String = rm.get_room_code(r)
		if rm.is_side_room(r):
			side_count += 1
			var hub_code: String = rm.get_room_code(String(rm.SIDE_ROOM_HUB[r]))
			if not code.begins_with(hub_code) or code.length() != hub_code.length() + 1:
				side_codes_ok = false
				print("  side code bad: ", r, " code=", code, " hub=", hub_code)
		else:
			main_n += 1
			var expected := "%02d" % main_n
			if code != expected:
				main_seq_ok = false
				print("  main code bad: ", r, " got=", code, " want=", expected)
	check(main_seq_ok and main_n == 37, "ana yol sürekli 01..37 (%d oda)" % main_n)
	check(side_codes_ok and side_count == 10, "10 yan oda merkez kodlu (01A, 02A, ...)")
	check(rm.get_room_number_and_title(&"awakening_s_room").begins_with("ODA 01A ·"), "S.'nin Odası ODA 01A", rm.get_room_number_and_title(&"awakening_s_room"))
	check(rm.get_room_number_and_title(&"awakening_crypt").begins_with("ODA 02A ·"), "İlk Bedenler Mahzeni ODA 02A", rm.get_room_number_and_title(&"awakening_crypt"))
	check(rm.get_room_number_and_title(&"decay_rootworks").begins_with("ODA 10A ·"), "Kök Damarları ODA 10A", rm.get_room_number_and_title(&"decay_rootworks"))
	check(rm.get_room_number_and_title(&"library_hall").begins_with("ODA 11 ·"), "Hafıza Kütüphanesi ODA 11", rm.get_room_number_and_title(&"library_hall"))
	check(rm.get_room_number_and_title(&"core").begins_with("ODA 37 ·"), "Çekirdek ODA 37", rm.get_room_number_and_title(&"core"))
	## Kanonik 6 region_id kontrolü: legacy &"archive" / &"lab" kalmamış olmalı.
	const CANON_REGIONS := ["awakening", "decay", "library", "experiment", "mirrors", "core"]
	var bad_regions: Array = []
	for rid in rm._rooms.keys():
		var room_node: Node = rm._rooms[rid].root
		if "region_id" in room_node:
			var reg := String(room_node.get("region_id"))
			var expected_reg := String(rid).get_slice("_", 0)
			if not CANON_REGIONS.has(reg) or reg != expected_reg:
				bad_regions.append("%s: region_id=%s (want %s)" % [rid, reg, expected_reg])
	check(bad_regions.is_empty(), "tüm odalar 6 kanonik region_id kullanır", bad_regions)
	var bad_doors: Array = []
	var close_pairs: Array = []
	var ability_doors: Array = []
	for rid in rm._rooms.keys():
		var room: Node2D = rm._rooms[rid].root
		var points: Array[Dictionary] = []
		for n in room.find_children("*", "Node", true, false):
			var is_door := n.is_in_group("room_door")
			var is_interact := n.has_method("on_interact")
			if not is_door and not is_interact:
				continue
			if not (n is Node2D):
				continue
			if is_door:
				var target := String(n.get("target_room_id"))
				var spawn := StringName(n.get("target_spawn_id"))
				if not rm.has_room(StringName(target)):
					bad_doors.append("%s → %s oda yok" % [rid, target])
				elif spawn != &"default" and spawn != &"checkpoint" and not (rm._rooms[StringName(target)].spawns as Dictionary).has(spawn):
					bad_doors.append("%s → %s:%s spawn yok" % [rid, target, spawn])
				var ability := String(n.get("required_ability"))
				if ability == "ability_shadow_dash":
					ability_doors.append(n)
			points.append({"at": (n as Node2D).global_position, "name": String(n.name), "door": is_door})
		for i in points.size():
			for j in range(i + 1, points.size()):
				if not points[i].door and not points[j].door:
					continue
				var dist: float = (points[i].at as Vector2).distance_to(points[j].at)
				if dist < 96.0:
					close_pairs.append("%s %s↔%s %.0f" % [rid, points[i].name, points[j].name, dist])
	check(bad_doors.is_empty(), "her kapının hedef odası ve spawn'ı var", bad_doors)
	check(close_pairs.is_empty(), "kapı/etkileşim 96 px'ten yakın değil", close_pairs)
	## Yan odaya (S.'nin Odası) giden yetenek kapısı serbest; ana yol odasına giden yasak.
	var main_ability_doors: Array = ability_doors.filter(func(d): return not rm.SIDE_ROOM_HUB.has(String(d.get("target_room_id"))))
	check(main_ability_doors.is_empty(), "ana yolda Gölge Atılması kapısı yok (oda 14-27)", main_ability_doors.size())
	var player: Node2D = current_scene.get_node("Player")
	for rid in rm._rooms.keys():
		rm.enter_room(rid, &"default")
		await create_timer(0.05).timeout
		dm.clear()
		gate.set_story(false)
		var bounds: Rect2 = rm._rooms[rid].bounds
		var pos: Vector2 = player.global_position
		var inside := pos.x >= bounds.position.x + 8.0 and pos.x <= bounds.position.x + bounds.size.x - 8.0
		check(inside and pos.y < 330.0 and not root.get_node("DeathManager").is_dying, "güvenli spawn %s" % rid, pos)
	_solve_door_puzzles(rm, pm)
	gs.player_progress_knowledge["ability_shadow_dash"] = false
	var locked_count := 0
	for door in ability_doors:
		if door._ability_blocked():
			locked_count += 1
	check(locked_count == ability_doors.size(), "yetenek yokken atılma kapıları kilitli", locked_count)
	gs.player_progress_knowledge["ability_shadow_dash"] = true
	var open_count := 0
	for door in ability_doors:
		if not door._ability_blocked():
			open_count += 1
	check(open_count == ability_doors.size(), "yetenek varken atılma kapıları açık", open_count)
	var walked := true
	var walk_detail := ""
	for i in MAIN_PATH.size() - 1:
		var here := String(MAIN_PATH[i])
		var nxt := String(MAIN_PATH[i + 1])
		if _door_between(rm, here, nxt) == null:
			walked = false
			walk_detail = "%s → %s" % [here, nxt]
			break
	check(walked, "bulmacalar çözülünce ana yol kapı kapı yürür", walk_detail)
	var side_back := true
	var side_detail := ""
	for rid in rm._rooms.keys():
		if MAIN_PATH.has(String(rid)):
			continue
		if not _can_reach_main(rm, String(rid)):
			side_back = false
			side_detail = String(rid)
			break
	check(side_back, "her yan odadan ana yola dönülür", side_detail)
	await _chase_completable(rm, pm, dm, gate)
	await _old_save(sm, gs, rm, dm, gate, player)
	print("GRAPH done failures=", failures)
	quit(1 if failures else 0)


func _solve_door_puzzles(rm: Node, pm: Node) -> void:
	for rid in rm._rooms.keys():
		var room: Node = rm._rooms[rid].root
		for n in room.find_children("*", "Area2D", true, false):
			if n.is_in_group("room_door"):
				var req := StringName(n.get("required_puzzle"))
				if req != &"":
					pm.mark_solved(req)


func _door_between(rm: Node, here: String, nxt: String) -> Node:
	var room: Node = rm._rooms[StringName(here)].root
	for n in room.find_children("*", "Area2D", true, false):
		if n.is_in_group("room_door") and String(n.get("target_room_id")) == nxt and not n.is_locked():
			return n
	return null


func _can_reach_main(rm: Node, start: String) -> bool:
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if MAIN_PATH.has(here):
			return true
		var room: Node = rm._rooms[StringName(here)].root
		for n in room.find_children("*", "Area2D", true, false):
			if not n.is_in_group("room_door") or n.is_locked():
				continue
			var nxt := String(n.get("target_room_id"))
			if not seen.has(nxt) and rm.has_room(StringName(nxt)):
				seen[nxt] = true
				queue.append(nxt)
	return false


func _chase_completable(rm: Node, pm: Node, dm: Node, gate: Node) -> void:
	pm.solved.erase("decay_shilda_wall_broken")
	var pz: Dictionary = root.get_node("GameState").world_memory_state.get("puzzles", {})
	pz.erase("decay_shilda_wall_broken")
	var garden_door := _door_between_any(rm, "decay_shilda_wall", "decay_garden")
	check(garden_door != null and garden_door.is_locked(), "bahçe kapısı kovalamaca bitmeden kilitli")
	rm.enter_room(&"decay_shilda_wall", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	gate.set_story(false)
	var wall: Node = null
	for n in rm._rooms[&"decay_shilda_wall"].root.find_children("*", "StaticBody2D", true, false):
		if n.is_in_group("cracked_wall"):
			wall = n
			break
	var keeper: Node = current_scene.get_node("Keeper")
	check(wall != null and keeper != null, "çatlak duvar ve gölge sahnede")
	if wall and keeper and keeper.has_method("start_encounter"):
		keeper.start_encounter(&"shilda_wall")
		await create_timer(0.4).timeout
		dm.clear()
		gate.set_story(false)
		wall.receive_keeper_charge(keeper)
		wall.receive_keeper_charge(keeper)
		dm.clear()
		check(wall.is_broken() and pm.is_solved(&"decay_shilda_wall_broken") and not garden_door.is_locked(), "kovalamaca iki çarpmada biter, bahçe açılır")
	else:
		check(false, "kovalamaca iki çarpmada biter, bahçe açılır")


func _door_between_any(rm: Node, here: String, nxt: String) -> Node:
	var room: Node = rm._rooms[StringName(here)].root
	for n in room.find_children("*", "Area2D", true, false):
		if n.is_in_group("room_door") and String(n.get("target_room_id")) == nxt:
			return n
	return null


func _old_save(sm: Node, gs: Node, rm: Node, dm: Node, gate: Node, player: Node2D) -> void:
	gs.character_current_life_knowledge["room"] = &"decay_vines"
	gs.character_current_life_knowledge["spawn_id"] = &"default"
	gs.character_current_life_knowledge["checkpoint_room"] = &"decay_vines"
	gs.character_current_life_knowledge["checkpoint"] = Vector2(120, 288)
	sm.delete_all_save_files()
	check(sm.save_game(), "v1.9.0 biçiminde kayıt yazıldı")
	gs.character_current_life_knowledge["room"] = &"awakening"
	check(sm.load_game(false), "v1.9.0 kaydı yüklenir")
	check(String(gs.character_current_life_knowledge.get("room", "")) == "decay_vines", "eski oda kimliği durur")
	check(rm.has_room(&"decay_vines"), "eski oda hâlâ kayıtlı")
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.15).timeout
	dm.clear()
	gate.set_story(false)
	var pos: Vector2 = player.global_position
	check(pos.y < 330.0 and not root.get_node("DeathManager").is_dying, "eski kayıttan güvenli doğuş", pos)
