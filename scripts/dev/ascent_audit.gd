extends SceneTree
## Son Merdiven (core_ascent) üç sınav düzeni denetimi.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/ascent_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("ASCENT ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("ASCENT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	var rm := root.get_node("RoomManager")
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	rm.enter_room(&"core_ascent", &"default")
	await create_timer(0.3).timeout
	var room: Node = (rm._rooms[&"core_ascent"] as Dictionary)["root"]

	## 1) Platform / boşluk sayısı.
	var plat_count: int = (room.get("platforms") as PackedVector3Array).size()
	var gaps: PackedVector2Array = room.get("floor_gaps")
	check(plat_count + gaps.size() >= 3, "ascent_has_platforms (%d platform, %d gap)" % [plat_count, gaps.size()])

	## 2) Üç sınav: mühür (Ruh Kesimi), >= 96 px boşluk + lanet perdesi (Atılma), plaka + yankı sunağı.
	var seals := room.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.is_in_group("soul_seal"))
	var barriers := room.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.is_in_group("curse_barrier"))
	var wide_gap := false
	var barrier_in_gap := false
	for g in gaps:
		if g.y - g.x >= 96.0:
			wide_gap = true
			for b in barriers:
				var bx: float = (b as Node2D).position.x
				if bx > g.x and bx < g.y:
					barrier_in_gap = true
	var plates := room.find_children("*", "Area2D", true, false).filter(func(n): return n.is_in_group("pressure_plate"))
	var altars := room.find_children("*", "Area2D", true, false).filter(func(n): return n.is_in_group("echo_altar"))
	check(seals.size() >= 1, "ascent_seal_present")
	check(wide_gap and barrier_in_gap, "ascent_dash_gap_with_barrier")
	check(plates.size() >= 1 and altars.size() >= 1, "ascent_echo_plate_and_altar")
	var plate_ok := true
	for p in plates:
		if bool(p.get("accept_player")) or bool(p.get("latch_on_press")):
			plate_ok = false
	check(plate_ok, "ascent_plate_echo_only")
	## record_seconds sahnede geçersiz kılınmamalı (varsayılan her yerde aynı kalır).
	var scene_text := FileAccess.get_file_as_string("res://scenes/rooms/core_ascent.tscn")
	var altar_ok := not altars.is_empty() and not scene_text.contains("record_seconds")
	check(altar_ok, "ascent_altar_default_record")
	var plate_listen_ok := false
	for gb in room.find_children("*", "StaticBody2D", true, false):
		var l: Variant = gb.get("puzzle_listen")
		if l != null and not plates.is_empty() and StringName(l) == StringName(plates[0].get("puzzle_id")):
			plate_listen_ok = true
	check(plate_listen_ok, "ascent_gate_listens_to_plate")

	## 3) Ret repliği: yeteneğin alındığı odanın gerçek başlığı geçmeli.
	var titles: Dictionary = rm.ROOM_TITLES_TR
	var forbidden: String = String(titles.get(&"library_forbidden_wing", titles.get("library_forbidden_wing", "")))
	var shrine: String = String(titles.get(&"mirrors_shrine", titles.get("mirrors_shrine", "")))
	check(forbidden != "" and shrine != "", "ascent_titles_known (%s / %s)" % [forbidden, shrine])
	var seal_line := String(seals[0].get("refusal_line")) if not seals.is_empty() else ""
	var bar_line := String(barriers[0].get("refusal_line")) if not barriers.is_empty() else ""
	check(forbidden != "" and seal_line.contains(forbidden), "ascent_refusal_names_room seal: %s" % seal_line)
	check(shrine != "" and bar_line.contains(shrine), "ascent_refusal_names_room dash: %s" % bar_line)
	check(seal_line.length() <= 90 and bar_line.length() <= 90, "ascent_refusal_len_le_90")
	check(not seal_line.contains("...") and not bar_line.contains("..."), "ascent_refusal_ellipsis_char")

	## 4) Yumuşak kilit yok: spawn ile geri kapı arasında engel/boşluk yok, kapı kilitsiz.
	var spawn_x: float = (room.get("default_spawn") as Vector2).x
	var back_door: Node = null
	for n in room.find_children("*", "Node", true, false):
		if n.is_in_group("room_door") and String(n.get("target_room_id")) == "core_threshold":
			back_door = n
	check(back_door != null, "ascent_back_door_exists")
	if back_door != null:
		var dx: float = (back_door as Node2D).position.x
		check(not back_door.is_locked(), "ascent_back_door_unlocked")
		var clear := true
		for n in seals + barriers:
			var nx: float = (n as Node2D).position.x
			if nx > minf(dx, spawn_x) - 1.0 and nx < maxf(dx, spawn_x) + 1.0:
				clear = false
		for g in gaps:
			if g.y > minf(dx, spawn_x) and g.x < maxf(dx, spawn_x):
				clear = false
		check(clear, "ascent_no_softlock (spawn %.0f, back door %.0f)" % [spawn_x, dx])
	print("ASCENT DONE failures=", failures)
	quit(1 if failures > 0 else 0)
