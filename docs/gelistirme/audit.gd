extends SceneTree

var scene: Node
var gs: Node
var dm: Node
var mobile: Node
var results: Array = []
var case_name: String

func _initialize() -> void:
	call_deferred("run")

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func check(id: String, passed: bool, evidence: Dictionary) -> void:
	results.append({"id": id, "passed": passed, "evidence": evidence})
	print("AUDIT_CHECK ", JSON.stringify(results.back()))

func run() -> void:
	case_name = OS.get_environment("TORIMON_AUDIT_CASE")
	create_timer(35.0).timeout.connect(func(): print("AUDIT_TIMEOUT ", case_name); quit(90))
	gs = root.get_node("GameState")
	dm = root.get_node("DialogueManager")
	mobile = root.get_node("MobileInputManager")
	scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await wait(3.5)
	var player: Node = get_first_node_in_group("player")
	var keeper: Node = get_first_node_in_group("keeper")
	var cm: Node = root.get_node("CorpseManager")
	var sm: Node = root.get_node("SaveManager")
	var pm: Node = root.get_node("PuzzleManager")
	var em: Node = root.get_node("EndingManager")
	match case_name:
		"baseline":
			check("boot_two_rooms", scene.get_node("World").get_child_count() == 2, {"rooms": scene.get_node("World").get_child_count(), "user_data": OS.get_user_data_dir()})
			var start_x: float = player.position.x
			mobile.set_move_vector(Vector2.RIGHT)
			await wait(0.4)
			mobile.set_move_vector(Vector2.ZERO)
			var distance: float = player.position.x - start_x
			check("horizontal_movement", distance > 35 and distance < 55, {"distance_px": distance, "seconds": 0.4})
			var has_a := false
			for event in InputMap.action_get_events("ui_left"):
				if event is InputEventKey and (event.physical_keycode == KEY_A or event.keycode == KEY_A): has_a = true
			check("documented_wasd_binding", has_a, {"A_bound_to_left": has_a})
		"save_write":
			gs.player_progress_knowledge["audit_marker"] = "persist_20261106"
			gs.set_world_flag(&"awakening_door_opened", true)
			sm.save_game()
			check("save_written", FileAccess.file_exists("user://torimon_save.json"), {"path": ProjectSettings.globalize_path("user://torimon_save.json")})
		"save_read":
			check("startup_restores_save", gs.player_progress_knowledge.get("audit_marker", "") == "persist_20261106", {"save_exists": FileAccess.file_exists("user://torimon_save.json"), "marker_after_fresh_boot": gs.player_progress_knowledge.get("audit_marker", "MISSING"), "door_open": gs.get_world_flag(&"awakening_door_opened")})
			var loaded: bool = sm.load_game()
			check("explicit_load_reads_save", loaded and gs.player_progress_knowledge.get("audit_marker", "") == "persist_20261106", {"loaded": loaded, "marker": gs.player_progress_knowledge.get("audit_marker", "MISSING")})
			check("load_resyncs_puzzle", pm.is_solved(&"awakening_weight"), {"world_door_open": gs.get_world_flag(&"awakening_door_opened"), "puzzle_solved": pm.is_solved(&"awakening_weight")})
		"death":
			root.get_node("DeathManager").request_death(&"audit")
			var start_x: float = player.position.x
			mobile.set_move_vector(Vector2.RIGHT)
			await wait(0.2)
			mobile.set_move_vector(Vector2.ZERO)
			check("death_locks_movement", absf(player.position.x - start_x) < 1.0, {"is_dying": root.get_node("DeathManager").is_dying, "movement_px": player.position.x - start_x, "animation": String(player.sprite.animation)})
			await wait(2.0)
			check("death_respawns_and_retains_corpse", not root.get_node("DeathManager").is_dying and cm.get_corpses().size() == 1, {"is_dying": root.get_node("DeathManager").is_dying, "corpses": cm.get_corpses().size(), "deaths": gs.player_progress_knowledge["deaths"]})
		"seal":
			gs.player_progress_knowledge["memory_codes"] = {"awakening": "999"}
			await get_first_node_in_group("memory_seal").on_interact(player)
			check("wrong_code_rejected", not pm.is_solved(&"awakening_memory_code"), {"fixture_code": "999", "expected_story_code": "314", "solved": pm.is_solved(&"awakening_memory_code")})
		"core_corpse":
			scene.enter_core()
			cm.record_corpse_at(Vector2(200, 288))
			await wait(0.15)
			var corpse: Node = get_first_node_in_group("corpse")
			check("core_corpse_in_active_room", corpse != null and corpse.is_visible_in_tree() and String(corpse.get_parent().get_path()).contains("/Core/"), {"parent": String(corpse.get_parent().get_path()), "visible": corpse.is_visible_in_tree(), "can_process": corpse.can_process(), "room": String(gs.character_current_life_knowledge["room"])})
		"trim":
			for i in 4:
				gs.player_progress_knowledge["deaths"] = i + 1
				cm.record_corpse_at(Vector2(200 + i * 40, 288))
				await process_frame
			check("three_corpses_plus_trace", cm.get_corpses().size() == 3 and cm.get_traces().size() == 1, {"corpses": cm.get_corpses().size(), "traces": cm.get_traces().size()})
			gs.set_world_flag(&"audit_persistent", true)
			gs.character_current_life_knowledge["interacted"] = ["audit"]
			gs.reset_character_life()
			check("memory_layers_survive_life_reset", gs.get_world_flag(&"audit_persistent") and gs.character_current_life_knowledge["interacted"].is_empty(), {"world_flag": gs.get_world_flag(&"audit_persistent"), "life_interacted": gs.character_current_life_knowledge["interacted"]})
		"ending_touch":
			var ui: Node = get_first_node_in_group("ending_ui")
			ui.set_process(false) # disable headless-only automatic epilogue advance
			ui.play_epilogue("Audit", ["One", "Two"])
			var touch := InputEventScreenTouch.new()
			touch.position = Vector2(320, 180)
			touch.pressed = true
			Input.parse_input_event(touch)
			await process_frame
			touch = InputEventScreenTouch.new()
			touch.position = Vector2(320, 180)
			touch.pressed = false
			Input.parse_input_event(touch)
			mobile.press_interact()
			mobile.release_interact()
			await process_frame
			check("touch_or_mobile_interact_advances_epilogue", ui._index > 0, {"index_after_touch_and_mobile_signal": ui._index, "headless_auto_advance": false})
			var key := InputEventAction.new()
			key.action = &"interact"
			key.pressed = true
			ui._unhandled_input(key)
			check("keyboard_advances_epilogue", ui._index == 1, {"index_after_keyboard_handler": ui._index})
			ui._playing = false
		"bad_attacks":
			# Position fixture isolates attack collision from traversal/hazard.
			player.global_position = Vector2(440, 280)
			keeper.global_position = Vector2(480, 280)
			player.set_physics_process(false)
			# Keep player on floor, outside rift fixture; attack geometry checked by physics.
			scene.get_node("World/Awakening/Hazards/MemoryRift").set_deferred("monitoring", false)
			player.set_physics_process(true)
			for i in 3:
				mobile.press_attack()
				mobile.release_attack()
				await wait(0.55)
			check("three_attacks_reach_bad_ending", em.current == 1, {"attack_presses": 3, "keeper_strikes": keeper._strikes, "ending": em.current, "rooms_visited": gs.player_progress_knowledge["rooms_visited"], "fixture": "position + hazard monitoring disabled"})
		"plate_chain":
			# Actual corpse body at ground-level player feet; no solved flags injected.
			gs.player_progress_knowledge["first_death_seen"] = true
			cm.record_corpse_at(Vector2(448, player.position.y))
			await wait(0.1)
			var corpse: Node = get_first_node_in_group("corpse")
			await corpse.on_interact(player)
			await wait(0.3)
			corpse.on_interact(player)
			await wait(0.3)
			corpse.on_interact(player)
			await wait(0.4)
			var plate: Node = get_first_node_in_group("pressure_plate")
			check("ground_corpse_activates_plate", pm.is_solved(&"awakening_weight"), {"corpse_position": str(corpse.position), "player_feet_y": player.position.y, "plate_position": str(plate.position), "overlap_count": plate.get_overlapping_bodies().size(), "door_open": gs.get_world_flag(&"awakening_door_opened")})
			corpse.position.y += 4.0 # Diagnostic adjustment in test copy ONLY.
			await wait(0.3)
			check("plate_diagnostic_four_px_down", pm.is_solved(&"awakening_weight"), {"adjustment_px": 4, "door_open": gs.get_world_flag(&"awakening_door_opened")})
			await wait(0.3)
			await get_first_node_in_group("memory_seal").on_interact(player)
			await keeper.on_interact(player)
			scene.enter_core()
			await wait(0.3)
			await get_first_node_in_group("core_crystal").on_interact(player)
			check("fixture_assisted_good_chain", em.current == 2, {"ending": em.current, "prep": em.prep_status(), "fixture": "corpse spawn, direct interactions, corpse +4px diagnostic, room transition"})
	var record := {"case": case_name, "engine": Engine.get_version_info()["string"], "results": results, "headless": true}
	var f := FileAccess.open("res://audit_" + case_name + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(record, "\t"))
	f.close()
	quit(0)
