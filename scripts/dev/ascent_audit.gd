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
	check(plat_count >= 3, "ascent_has_platforms (%d platform; traversal, not a jump challenge)" % plat_count)
	check(gaps.is_empty(), "ascent_no_fake_gap")

	## 2) Üç sınav: mühür (Ruh Kesimi), >= 96 px boşluk + lanet perdesi (Atılma), plaka + yankı sunağı.
	var seals := room.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.is_in_group("soul_seal"))
	var barriers := room.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.is_in_group("curse_barrier"))
	var plates := room.find_children("*", "Area2D", true, false).filter(func(n): return n.is_in_group("pressure_plate"))
	var altars := room.find_children("*", "Area2D", true, false).filter(func(n): return n.is_in_group("echo_altar"))
	check(seals.size() >= 1, "ascent_seal_present")
	var player: CharacterBody2D = current_scene.get_node("Player")
	var pc: Script = load("res://scripts/player/player_controller.gd")
	var jump_peak: float = pow(float(pc.JUMP_VELOCITY), 2.0) / (2.0 * float(pc.GRAVITY))
	var barrier_ok := barriers.size() >= 1
	for b in barriers:
		if float(b.get("height")) <= jump_peak * 1.5 or (int(b.collision_layer) & int(player.collision_mask)) == 0:
			barrier_ok = false
	check(barrier_ok, "ascent_dash_barrier (peak %.0f px, layer in player mask)" % jump_peak)
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

	var last: Node = room.find_child("LastStep", true, false)
	var sl := String(last.get("soul_refusal_line"))
	var dl := String(last.get("dash_refusal_line"))
	check(sl.contains(forbidden) and dl.contains(shrine) and sl.length() <= 90 and dl.length() <= 90, "ascent_laststep_refusals_name_rooms")

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
		check(clear, "ascent_no_softlock (spawn %.0f, back door %.0f)" % [spawn_x, dx])
	await _functional(rm, room, player, plates, altars)
	print("ASCENT DONE failures=", failures)
	quit(1 if failures > 0 else 0)


func _reset(ids: Array) -> void:
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	for id in ids:
		pm.solved.erase(String(id))
		var pz: Variant = gs.world_memory_state.get("puzzles", {})
		if pz is Dictionary:
			(pz as Dictionary).erase(String(id))
	pm.set_live(&"core_ascent_echo", false)


func _functional(rm: Node, room: Node, player: CharacterBody2D, plates: Array, altars: Array) -> void:
	var pm := root.get_node("PuzzleManager")
	var gs := root.get_node("GameState")
	var gate: StaticBody2D = room.find_child("EchoGate", true, false)
	var all_ids := [&"core_ascent", &"core_ascent_seal", &"core_ascent_gap", &"core_ascent_echo"]
	gs.player_progress_knowledge["ability_soul_slash"] = true
	gs.player_progress_knowledge["ability_shadow_dash"] = true
	## (a) canlı plaka kapıyı açar, geçiş kalıcı çözer.
	_reset(all_ids)
	rm.enter_room(&"core_ascent", &"default")
	await create_timer(0.8).timeout
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(gate.global_position.x - 70.0, 288.0)
	await physics_frame
	await physics_frame
	pm.set_live(&"core_ascent_echo", true)
	await physics_frame
	await physics_frame
	check(gate.collision_layer == 0, "ascent_live_opens_gate")
	player.global_position = Vector2(gate.global_position.x + 70.0, 288.0)
	await physics_frame
	await physics_frame
	check(pm.is_solved(&"core_ascent_echo"), "ascent_pass_through_latches")
	## (b) canlı biter, hiçbir şey çözülmemiş: kapı kapalı.
	_reset(all_ids)
	await physics_frame
	await physics_frame
	check(gate.collision_layer == 1 and not pm.is_solved(&"core_ascent_echo"), "ascent_gate_closed_when_not_live")
	## (c) ortadan yükleme: spawn -> sunak -> plaka -> kapı sırası, arada boşluk yok.
	var altar_x: float = (altars[0] as Node2D).position.x
	var plate_x: float = (plates[0] as Node2D).position.x
	var spawn_x: float = (room.get("default_spawn") as Vector2).x
	check(spawn_x < altar_x and altar_x < plate_x and plate_x < gate.position.x and (room.get("floor_gaps") as PackedVector2Array).is_empty(), "ascent_altar_plate_reachable_from_spawn")
	## (d) eski kayıt: yalnız core_ascent çözülü, sağdan giriş.
	_reset(all_ids)
	pm.mark_solved(&"core_ascent")
	rm.enter_room(&"core_seal_chamber", &"default")
	await create_timer(0.3).timeout
	rm.enter_room(&"core_ascent", &"from_core_seal_chamber")
	await create_timer(0.8).timeout
	check(player.global_position.x > gate.global_position.x, "ascent_legacy_spawns_east_of_gate (x %.0f)" % player.global_position.x)
	check(pm.is_solved(&"core_ascent_seal") and pm.is_solved(&"core_ascent_gap") and pm.is_solved(&"core_ascent_echo"), "ascent_legacy_sub_puzzles_migrated")
	var seal: Node = room.find_child("SoulSeal", true, false)
	var seal_shape: CollisionShape2D = seal.find_child("CollisionShape2D", true, false) if seal.find_child("CollisionShape2D", true, false) != null else seal.get_child(0)
	check(gate.collision_layer == 0 and seal_shape.disabled, "ascent_legacy_gate_and_seal_open")
	var back: Node = null
	for n in room.find_children("*", "Node", true, false):
		if n.is_in_group("room_door") and String(n.get("target_room_id")) == "core_threshold":
			back = n
	check(back != null and not back.is_locked(), "ascent_legacy_back_door_reachable")
	_reset(all_ids)
