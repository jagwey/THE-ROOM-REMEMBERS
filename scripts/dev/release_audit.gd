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
	check_it("18 rooms registered", rm._rooms.size() == 18, rm._rooms.size())
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
	# Restart must clear registries and stale puzzle progress, not leave old room nodes.
	saves.start_new_game()
	await create_timer(0.3).timeout
	check_it("New game reloads all rooms", rm._rooms.size() == 18 and rm.get_active_room_id() == &"awakening")
	check_it("New game clears prior progress", not gs.player_progress_knowledge.has("qa_roundtrip") and root.get_node("PuzzleManager").solved.is_empty())
	var failed := checks.filter(func(c): return not c.pass).size()
	var report := {"checks": checks, "total": checks.size(), "failed": failed, "passed": checks.size() - failed}
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	var out := FileAccess.open("res://build/qa/release-audit.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t"))
	out.close()
	print("RELEASE_AUDIT ", JSON.stringify({"total": checks.size(), "failed": failed}))
	quit(1 if failed else 0)
