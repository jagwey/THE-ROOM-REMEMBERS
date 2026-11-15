extends SceneTree
## Defter haritasından hızlı seyahat: engeller, ışınlanma, kilit/sinematik geri açılır.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/fast_travel_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("FT ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("FT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	var door_script = load("res://scripts/world/room_transition.gd")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout

	check(rm.fast_travel_block_reason(&"awakening") == "Zaten buradasın.", "current room blocked")
	check(rm.fast_travel_block_reason(&"no_such_room") == "Bu odaya yol yok.", "unknown room blocked")
	var target: StringName = &"awakening_passage"
	var visited: Array = state.player_progress_knowledge.get("rooms_visited", [])
	visited.erase(String(target))
	state.player_progress_knowledge["rooms_visited"] = visited
	check(rm.fast_travel_block_reason(target) == "Bu odayı henüz görmedin.", "unvisited room blocked")
	visited.append(String(target))
	state.player_progress_knowledge["rooms_visited"] = visited
	check(rm.fast_travel_block_reason(target) == "", "visited room allowed")

	var started: bool = await rm.fast_travel(target)
	check(started, "fast_travel returned true")
	check(rm.get_active_room_id() == target, "now in %s (got %s)" % [target, rm.get_active_room_id()])
	check(not door_script.is_transitioning(), "transition lock released")
	check(gate.current_layer() == gate.Layer.NONE, "UiGate back to NONE (got %d)" % gate.current_layer())
	check(root.get_node_or_null("FastTravelFade") == null or root.get_node("FastTravelFade").is_queued_for_deletion(), "fade layer freed")
	var player := current_scene.get_node("Player") as CharacterBody2D
	check(player != null and player.modulate.a > 0.99, "player visible")

	## Geri dönüş de çalışır.
	var back: bool = await rm.fast_travel(&"awakening")
	check(back and rm.get_active_room_id() == &"awakening", "travel back to awakening")

	## Günlük haritası: sinyal bağlı ve harita sekmesi çiziliyor.
	var journal = get_first_node_in_group("journal_ui")
	check(journal != null, "journal_ui present")
	if journal:
		journal.open_journal()
		journal._show_section("harita")
		await process_frame
		await process_frame
		check(journal.map_view.travel_requested.is_connected(journal._on_travel_requested), "map travel signal connected")
		check(journal.map_view._hits.size() >= 1, "map has tappable rooms (%d)" % journal.map_view._hits.size())
		journal.close_journal()

	print("FT DONE failures=", failures)
	quit(1 if failures > 0 else 0)
