extends SceneTree
## Tek final denetimi (v3): enum yalniz NONE/PART_ONE; Shilda olmez; dizi bayrak sirasi
## final_seal_broken -> x_revealed -> game_completed; END OF PART I + kredi gosterilir; final_seen yazilir.
## Calistir: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/final_sequence_audit.gd
var failures := 0
var FS: GDScript


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	FS = load("res://scripts/story/final_sequence.gd")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("FINAL ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("FINAL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var cfg := ConfigFile.new()
	if cfg.load("user://qa/settings.cfg") == OK:
		cfg.set_value("progress", "final_seen", false)
		cfg.save("user://qa/settings.cfg")
	var em := root.get_node("EndingManager")
	var gs := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var rm := root.get_node("RoomManager")
	var dm := root.get_node("DialogueManager")
	check(em.Ending.keys() == ["NONE", "PART_ONE"], "enum only NONE and PART_ONE", em.Ending.keys())
	for m in ["can_attempt_good_seal", "can_attempt_sever"]:
		check(not em.has_method(m), "removed " + m)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.5).timeout
	dm.clear()
	var keeper: Node = current_scene.get_node("Keeper")
	for i in 5:
		keeper.receive_player_strike()
	check(not keeper.is_defeated(), "Shilda not killable by strikes")
	check(not bool(gs.get_world_flag(&"keeper_defeated", false)), "no keeper_defeated flag")
	check(not em.can_begin_final(), "final locked at start")
	root.get_node("PuzzleManager").mark_solved(&"core_seal")
	gs.set_world_flag(&"seal_shard_1", true)
	gs.set_world_flag(&"seal_shard_2", true)
	check(not em.can_begin_final(), "final locked without Soul Slash")
	gs.player_progress_knowledge["ability_soul_slash"] = true
	check(em.can_begin_final(), "final open with all prerequisites")
	rm.enter_room(&"core", &"default", false)
	await process_frame
	await create_timer(0.3).timeout
	check(not FS.call("final_seen"), "final_seen false before first run")
	await em.trigger(em.Ending.PART_ONE, true)
	var r: Dictionary = FS.get("last_run")
	check(r.get("flag_order", []) == ["final_seal_broken", "x_revealed", "game_completed"], "flag order", r.get("flag_order"))
	check(bool(r.get("human", false)), "Shilda human form shown")
	check(bool(r.get("x_seen", false)), "X appeared")
	check(int(r.get("domains", 0)) == 4, "4 domain screens", r.get("domains"))
	check(bool(r.get("end_label", false)), "END OF PART I label")
	check(bool(r.get("part_label", false)), "THE ROOM REMEMBERS label")
	check(bool(r.get("credits", false)), "credits shown")
	check(bool(r.get("title_requested", false)), "title requested at end")
	check(gs.has_story_flag(&"game_completed"), "game_completed flag set")
	check(FS.call("final_seen"), "final_seen persisted")
	check(not gs.has_story_flag(&"final_seen"), "final_seen not a story flag")
	check(em.current == em.Ending.NONE and em.last_ending == em.Ending.PART_ONE, "ending state reset, last kept")
	check(gate.current_layer() != gate.Layer.CUTSCENE and not gate.blocks_movement(), "input released after final")
	print("FINAL DONE failures=", failures)
	quit(1 if failures > 0 else 0)
