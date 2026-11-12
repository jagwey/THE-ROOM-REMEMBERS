extends SceneTree
## Faz 0 softlock denetimi: katakomb çiçek kaynağı, çiçek->ceset aktarımı, Sarnıç yetenek şartı.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/softlock_phase0_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("PHASE0 ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PHASE0 SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	_static_checks()
	var state := root.get_node("GameState")
	var cm := root.get_node("CorpseManager")
	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	root.get_node("UiGate").set_story(false)
	rm.enter_room(&"decay_catacombs", &"default")
	await create_timer(0.4).timeout
	var room_root: Node = (rm._rooms[&"decay_catacombs"] as Dictionary)["root"]
	var src := room_root.find_child("FlowerSource", true, false)
	var player: Node = current_scene.get_node("Player")
	if src == null:
		check(false, "flower_transfers_to_corpse (no source)")
		check(false, "flower_source_reusable (no source)")
		quit(1)
		return
	src.on_interact(player)
	await process_frame
	check(bool(state.character_current_life_knowledge.get("flower_in_hand", false)), "flower_picked_up")
	dm.clear()
	var id: String = cm.record_corpse_at(Vector2(300, 288), &"thorn")
	state.reset_character_life()
	var has_flower := false
	for c in state.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == id:
			has_flower = bool(c.get("has_flower", false))
	check(has_flower and not bool(state.character_current_life_knowledge.get("flower_in_hand", false)), "flower_transfers_to_corpse")
	# çiçeksiz ölüm + kaynak yeniden kullanılabilir
	var id2: String = cm.record_corpse_at(Vector2(330, 288), &"thorn")
	state.reset_character_life()
	var plain := true
	for c in state.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == id2:
			plain = not bool(c.get("has_flower", false))
	src.on_interact(player)
	await process_frame
	check(plain and bool(state.character_current_life_knowledge.get("flower_in_hand", false)), "flower_source_reusable")
	quit(1 if failures > 0 else 0)


func _static_checks() -> void:
	var packed := load("res://scenes/rooms/decay_catacombs.tscn") as PackedScene
	var inst := packed.instantiate()
	var src := inst.find_child("FlowerSource", true, false) as Node2D
	check(src != null and src.position.x < 380.0 and src.has_method("on_interact"), "catacomb_flower_source_exists")
	inst.free()
	var pm := root.get_node("PuzzleManager")
	var hint: Variant = pm.HINTS.get(&"decay_catacombs", null)
	check(hint is Dictionary and str((hint as Dictionary).get("orientation", "")) != "", "catacomb_hint_exists")
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var line := ""
	for l in main_src.split("\n"):
		if l.contains("\"to\": \"decay_cistern\""):
			line = l
	var cistern_txt := FileAccess.get_file_as_string("res://scenes/rooms/decay_cistern.tscn")
	check(line != "" and not line.contains("\"ability\"") and not cistern_txt.contains("need_dash") and not cistern_txt.contains("need_soul"), "cistern_no_ability")
