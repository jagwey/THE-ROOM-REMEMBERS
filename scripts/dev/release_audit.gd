extends SceneTree
## Run with TORIMON_TEST=1. Tests never write to the player's save.
var checks: Array = []
var main: Node

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("run")

func check_it(label: String, value: bool, detail: Variant = "") -> void:
	checks.append({"name": label, "pass": value, "detail": str(detail)})
	print("PASS " if value else "FAIL ", label, " ", detail)

## Bulmacanın çözüldüğü oda + (varsa) önkoşul bulmacası/yeteneği. Kapı grafiği softlock analizi için.
const PUZZLE_SOURCE := {
	"awakening_passage_rings": ["awakening_passage", ""],
	"awakening_memory_code": ["awakening_seal", ""],
	"awakening_vigil": ["awakening_vigil", ""],
	"decay_greenhouse": ["decay_greenhouse", ""],
	"library_clockroom": ["library_clockroom", ""],
	"experiment_intake": ["experiment_intake", ""],
	"core_ascent": ["core_ascent", ""],
	"awakening_seal_weight": ["awakening_seal", ""],
	"core_seal": ["core_seal_chamber", ""],
	"core_threshold": ["core_threshold", ""],
	"experiment_authority": ["experiment_authority", ""],
	"experiment_cells_seen": ["experiment_cells", ""],
	"experiment_circuit": ["experiment_circuit", ""],
	"library_catalog": ["library_hall", ""],
	"library_page_order": ["library_page", ""],
	"library_witnesses": ["library_witness", ""],
	"mirrors_dual": ["mirrors_dual", ""],
	"mirrors_reverse": ["mirrors_reverse", ""],
	"mirrors_unbroken": ["mirrors_unbroken", ""],
	"mirrors_gallery": ["mirrors_gallery", ""],
	"mirrors_reverse_crossed": ["mirrors_reverse", ""],
	"mirrors_dual_echo": ["mirrors_dual", ""],
	"mirrors_dual_weight": ["mirrors_dual", ""],
	"mirrors_gallery_plate_1": ["mirrors_gallery", ""],
	"mirrors_gallery_plate_2": ["mirrors_gallery", ""],
	"mirrors_gallery_plate_3": ["mirrors_gallery", ""],
	"mirrors_unbroken_mimic": ["mirrors_unbroken", ""],
	"decay_shilda_wall_broken": ["decay_shilda_wall", ""],
	"ability_soul_slash": ["library_forbidden_wing", ""],
	"awakening_balcony_crossed": ["awakening_balcony", ""],
	## Faz 3 (v1.17.0) dogrusal yol kilitleri
	"library_shelf_order": ["library_upper_stacks", ""],
	"soul_seal_forbidden_2": ["library_forbidden_wing", ""],
	"library_reading_cell": ["library_reading_cell", ""],
	"experiment_quarantine_done": ["experiment_quarantine", ""],
	"experiment_conduit": ["experiment_core_conduit", ""],
	"experiment_observation": ["experiment_observation", ""],
	"seal_shard_1": ["library_forbidden_wing", ""],
	"seal_shard_2": ["mirrors_shrine", ""],
	## Faz 4 (v1.18.0) dogrusal yol kilitleri (oda 28-40)
	"mirrors_labyrinth_crossed": ["mirrors_labyrinth", ""],
	"mirrors_shrine_trial": ["mirrors_shrine", ""],
	"mirrors_1927": ["mirrors_1927", ""],
	"core_vault_order": ["core_memory_vault", ""],
	"core_bloom_order": ["core_bloom_garden", ""],
}


## Ruh mührü odayı ikiye böler: mührün her yanındaki giriş noktasının o yanda
## (mühür gerektirmeyen) bir çıkışı olmalı ya da mühür o yandan açılmalı.
func _seal_trap_checks(rm: Node) -> void:
	var traps: Array = []
	for rid in rm._rooms.keys():
		var room: Node2D = rm._rooms[rid].root
		var seals := room.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.is_in_group("soul_seal"))
		for s in seals:
			var sx: float = room.to_local(s.global_position).x
			var pid := StringName(s.get("puzzle_id"))
			var exits := {-1: false, 1: false}
			for n in room.find_children("*", "Area2D", true, false):
				if n.is_in_group("room_door") and StringName(n.get("required_puzzle")) != pid:
					exits[int(signf(room.to_local(n.global_position).x - sx))] = true
			for sname in (rm._rooms[rid].spawns as Dictionary).keys():
				var side := int(signf((rm._rooms[rid].spawns[sname] as Vector2).x - sx))
				if side != 0 and not exits[side] and int(s.get("back_side")) != side:
					traps.append("%s:%s side %d" % [rid, sname, side])
	check_it("No soul-seal traps (every spawn side has an exit)", traps.is_empty(), traps)


func _graph_checks(rm: Node) -> void:
	_seal_trap_checks(rm)
	var edges: Dictionary = {} ## room -> [[target, spawn, req]]
	var bad_targets: Array = []
	for rid in rm._rooms.keys():
		var room: Node = rm._rooms[rid].root
		var croots := room.find_children("*", "Node", true, false).filter(func(n): return n.is_in_group("corpses_root"))
		check_it("corpses_root present " + str(rid), not croots.is_empty())
		edges[String(rid)] = []
		for n in room.find_children("*", "Area2D", true, false):
			if not n.is_in_group("room_door"):
				continue
			var target := String(n.get("target_room_id"))
			var spawn := StringName(n.get("target_spawn_id"))
			edges[String(rid)].append([target, String(n.get("required_puzzle"))])
			if not rm.has_room(StringName(target)):
				bad_targets.append("%s -> %s (room)" % [rid, target])
			elif spawn != &"default" and spawn != &"checkpoint" and not (rm._rooms[StringName(target)].spawns as Dictionary).has(spawn):
				bad_targets.append("%s -> %s:%s (spawn)" % [rid, target, spawn])
	check_it("Every door targets a real room and spawn", bad_targets.is_empty(), bad_targets)
	## Softlock analizi: kilitleri, kaynağı erişilebilir olan bulmacalar çözüldükçe aç.
	var reach := {"awakening": true}
	var solved := {}
	var changed := true
	var unknown_locks: Array = []
	while changed:
		changed = false
		for pid in PUZZLE_SOURCE.keys():
			var src: Array = PUZZLE_SOURCE[pid]
			if not solved.has(pid) and reach.has(String(src[0])) and (String(src[1]) == "" or solved.has(String(src[1]))):
				solved[pid] = true
				changed = true
		for r in reach.keys():
			for e in edges.get(r, []):
				var req := String(e[1])
				if req != "" and not PUZZLE_SOURCE.has(req) and not unknown_locks.has(req):
					unknown_locks.append(req)
				if not reach.has(String(e[0])) and (req == "" or solved.has(req)):
					reach[String(e[0])] = true
					changed = true
	var missing: Array = []
	for rid in rm._rooms.keys():
		if not reach.has(String(rid)):
			missing.append(String(rid))
	check_it("No unknown door locks", unknown_locks.is_empty(), unknown_locks)
	check_it("All rooms reachable without softlock", missing.is_empty(), missing)
	check_it("Both seal shards obtainable", solved.has("seal_shard_1") and solved.has("seal_shard_2"))


func run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await create_timer(0.3).timeout
	main = current_scene
	var dm: Node = root.get_node("DialogueManager")
	var rm: Node = root.get_node("RoomManager")
	var gs: Node = root.get_node("GameState")
	var gate: Node = root.get_node("UiGate")
	var saves: Node = root.get_node("SaveManager")
	var player: Node2D = main.get_node("Player")
	check_it("40 rooms registered", rm._rooms.size() == 40, rm._rooms.size())
	check_it("Intro waits for player", dm.is_open)
	check_it("Story freezes threats", gate.pauses_world_threats())
	var before := player.position
	root.get_node("MobileInputManager").set_move_vector(Vector2.RIGHT)
	await create_timer(0.3).timeout
	check_it("Story freezes all movement", player.position.distance_to(before) < 0.01, player.position)
	check_it("Story animation still runs", player.sprite.is_playing() and player.sprite.can_process())
	dm.clear()
	await physics_frame
	main.get_node("Journal").open_journal()
	check_it("Journal freezes threats without tree pause", gate.pauses_world_threats() and not paused and player.sprite.can_process())
	main.get_node("Journal").close_journal()
	var visited := []
	for room_id in rm._rooms.keys():
		rm.enter_room(room_id, &"default")
		await create_timer(0.08).timeout
		dm.clear()
		var active_colliders := 0
		var leaked_colliders := []
		for rid in rm._rooms.keys():
			var room: Node = rm._rooms[rid].root
			for n in room.find_children("*", "CollisionObject2D", true, false):
				if n.collision_layer != 0:
					if rid == room_id:
						active_colliders += 1
					else:
						leaked_colliders.append(str(n.get_path()))
		check_it("Room collision isolation " + str(room_id), leaked_colliders.is_empty() and active_colliders > 0, leaked_colliders)
		var pos := player.position
		await create_timer(0.12).timeout
		check_it("Safe spawn " + str(room_id), player.position.y < 330 and not root.get_node("DeathManager").is_dying, player.position)
		visited.append(str(room_id))
	_graph_checks(rm)
	rm.enter_room(&"awakening", &"default")
	dm.clear()
	var start_x: float = player.position.x
	var start_camera: float = main.get_node("Camera2D").get_screen_center_position().x
	for frame in 220:
		root.get_node("MobileInputManager").set_move_vector(Vector2.RIGHT)
		await physics_frame
		if dm.is_open:
			dm.advance()
	root.get_node("MobileInputManager").clear_held_inputs()
	check_it("Walk across actual first room", player.position.x > start_x + 220, player.position)
	check_it("Rendered camera follows actual walking", main.get_node("Camera2D").get_screen_center_position().x > start_camera + 30, main.get_node("Camera2D").get_screen_center_position())
	dm.clear()
	var menu: Node = main.get_node("SessionMenu")
	menu.open_menu()
	check_it("Menu freezes threats", gate.pauses_world_threats() and not paused)
	menu.close_menu()
	saves.save_game()
	var expected_room: Variant = gs.character_current_life_knowledge.room
	gs.player_progress_knowledge["qa_roundtrip"] = true
	saves.save_game()
	gs.player_progress_knowledge.erase("qa_roundtrip")
	check_it("Save roundtrip", saves.load_game(false) and gs.player_progress_knowledge.get("qa_roundtrip", false) and gs.character_current_life_knowledge.room == expected_room)
	check_it("Test save isolated", "qa/" in saves.SAVE_PATH, saves.SAVE_PATH)

	# v1.3.0 Feature 29 Audits:
	# 1) WeightStone collision layer bit 3 / layer 8 (interactable)
	var stone_res := load("res://scripts/world/weight_stone.gd")
	if stone_res:
		var stone_node: CharacterBody2D = stone_res.new()
		check_it("WeightStone collision layer has layer 8", (stone_node.collision_layer & 8) != 0, stone_node.collision_layer)
		stone_node.free()
	else:
		check_it("WeightStone collision layer has layer 8", false, "weight_stone.gd not found")

	# 2) core.tscn contains exit door leading back to core_bloom_garden
	var core_room: Node = rm._rooms[&"core"].root
	var core_exit: Node = null
	for n in core_room.find_children("*", "Area2D", true, false):
		if n.is_in_group("room_door") and String(n.get("target_room_id")) == "core_bloom_garden":
			core_exit = n
			break
	check_it("Core room contains exit door to core_bloom_garden", core_exit != null, core_exit != null)

	# 3) Consecutive Windows saves succeed without ERR_ALREADY_EXISTS
	var s1: bool = bool(saves.save_game())
	var s2: bool = bool(saves.save_game())
	var s3: bool = bool(saves.save_game())
	check_it("Consecutive Windows saves without ERR_ALREADY_EXISTS", s1 and s2 and s3, "3 saves in succession")

	# Restart must clear registries and stale puzzle progress, not leave old room nodes.
	saves.start_new_game()
	await create_timer(0.3).timeout
	check_it("New game reloads all rooms", rm._rooms.size() == 40 and rm.get_active_room_id() == &"awakening")
	check_it("New game clears prior progress", not gs.player_progress_knowledge.has("qa_roundtrip") and root.get_node("PuzzleManager").solved.is_empty())
	var failed := checks.filter(func(c): return not c.pass).size()
	var report := {"checks": checks, "total": checks.size(), "failed": failed, "passed": checks.size() - failed}
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	var out := FileAccess.open("res://build/qa/release-audit.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t"))
	out.close()
	print("RELEASE_AUDIT ", JSON.stringify({"total": checks.size(), "failed": failed}))
	quit(1 if failed else 0)
