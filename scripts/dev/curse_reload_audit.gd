extends SceneTree
## Lanet bantları + ele geçirilme denetimi: bant eşikleri, 100'de sekans -> committed kayıt (A durumu),
## ceset/ruh/yatak/final yok, ilk sekans uzun / tekrar kısa / girdi atlatır, sayaç yeniden yüklemeden sağ çıkar.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/curse_reload_audit.gd
var failures := 0
var curse: Node
var sm: Node
var gs: Node
var rm: Node
var dm: Node
var gate: Node
var death: Node
var player: CharacterBody2D
var puz: Node
var phases: Array = []


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("CURSE ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _on_hazard(pos: Vector2) -> bool:
	## Oyuncu kutusu (48x60, ayak noktası pos) lanet bulutu / diken / çukur ile örtüşüyor mu.
	var box := Rect2(pos + Vector2(-16, -60), Vector2(32, 60))
	var rt: Node = rm._rooms[rm.get_active_room_id()].root
	for n in rt.find_children("*", "Node2D", true, false):
		var hz: bool = n.is_in_group("curse_cloud") or n.is_in_group("blood_thorn") or String(n.name).begins_with("Pit")
		if not hz:
			var par := n.get_parent()
			hz = par != null and String(par.name) == "Hazards"
		if not hz:
			continue
		for cs in n.find_children("*", "CollisionShape2D", true, false):
			var r := (cs as CollisionShape2D).shape as RectangleShape2D
			if r != null and Rect2((cs as Node2D).global_position - r.size * 0.5, r.size).intersects(box):
				return true
	return false


## Sekansı bitene kadar bekle, gerçek süreyi (sn) döndür.
func _run_possession(skip_after: float = -1.0) -> float:
	var t0 := Time.get_ticks_msec()
	curse.set_curse(100.0)
	var skipped := false
	while curse.possessing and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if skip_after >= 0.0 and not skipped and float(Time.get_ticks_msec() - t0) / 1000.0 >= skip_after:
			skipped = true
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.pressed = true
			Input.parse_input_event(ev)
	return float(Time.get_ticks_msec() - t0) / 1000.0


func _run() -> void:
	sm = root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("CURSE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()
	gs = root.get_node("GameState")
	gs.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await _wait(0.3)
	curse = root.get_node("CurseManager")
	rm = root.get_node("RoomManager")
	dm = root.get_node("DialogueManager")
	gate = root.get_node("UiGate")
	death = root.get_node("DeathManager")
	player = current_scene.get_node("Player")
	dm.clear()
	death.phase_changed.connect(func(p: int) -> void: phases.append(p))

	## 1) Bant eşikleri.
	var cases := [[0.0, 0], [49.0, 0], [49.9, 0], [50.0, 1], [69.0, 1], [69.9, 1], [70.0, 2], [89.0, 2], [89.9, 2], [90.0, 3], [99.0, 3]]
	for c in cases:
		curse.set_curse(float(c[0]))
		check(curse.get_band() == int(c[1]) and curse.band_for(float(c[0])) == int(c[1]), "band(%s) == %d" % [str(c[0]), int(c[1])], curse.get_band())
	var seen: Array = []
	curse.band_changed.connect(func(b: int) -> void: seen.append(b))
	curse.set_curse(0.0)
	curse.set_curse(55.0)
	curse.set_curse(75.0)
	curse.set_curse(95.0)
	check(seen == [0, 1, 2, 3], "band_changed fires per band crossing", seen)
	check(curse.visible_meter, "meter visible from 50")
	curse.set_curse(10.0)

	## 2) Hafif takılma: havada yok.
	rm.enter_room(&"library_hall", &"default")
	await _wait(0.2)
	dm.clear()
	player.global_position = Vector2(player.global_position.x, 60.0)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	player._stagger_timer = 0.0
	player._on_curse_stagger()
	check(not player.is_on_floor() and player._stagger_timer == 0.0, "no stumble while airborne")
	await _wait(1.2)
	player._stagger_timer = 0.0
	player._on_curse_stagger()
	check(player.is_on_floor() and player._stagger_timer > 0.0 and player._stagger_timer <= 0.2, "brief stumble on floor", player._stagger_timer)
	player._stagger_timer = 0.0

	## 3) A: library_hall mührü konumunda commit; B: başka oda + bayrak/dünya değişikliği.
	var seal_pos: Vector2 = rm._rooms[&"library_hall"].spawns[&"seal_library_hall"]
	player.global_position = seal_pos
	gs.set_story_flag(&"first_warning_heard")
	gs.set_story_flag(&"first_death_completed", false) ## ele geçirme bunu ASLA açmamalı: assert gerçekten sınasın
	gs.set_world_flag(&"audit_marker_b", false)
	gs.set_world_flag(&"audit_possession_world_persist", true)
	puz = root.get_node("PuzzleManager")
	puz.mark_solved(&"audit_possession_persist")
	curse.set_curse(20.0)
	check(sm.commit_save(&"audit_a", seal_pos, &"library_hall"), "commit A")
	var corpses_a: int = (gs.world_memory_state["corpses"] as Array).size()
	var deaths_a: int = int(gs.player_progress_knowledge.get("deaths", 0))
	var fdc_a: bool = gs.has_story_flag(&"first_death_completed")
	check(not fdc_a, "first_death_completed unset before possessions (assert below is meaningful)")

	var dirty_b := func() -> void:
		rm.enter_room(&"decay_garden", &"default")
		gs.set_story_flag(&"core_access_granted")
		gs.set_world_flag(&"audit_marker_b", true)
		gs.player_progress_knowledge["deaths"] = deaths_a  # ölüm sayısı sabit
		sm.save_game()

	await dirty_b.call()
	await _wait(0.2)
	dm.clear()
	check(rm.get_active_room_id() == &"decay_garden" and gs.has_story_flag(&"core_access_granted"), "state B set")
	phases.clear()
	var dur1: float = await _run_possession()
	check(dur1 >= 4.0 and dur1 <= 4.8, "first possession ~4.5s", "%.2fs" % dur1)
	await _wait(0.2)
	_assert_a(seal_pos, corpses_a, deaths_a, fdc_a, "possession 1")
	check(gs.possession_count == 1, "possession_count == 1", gs.possession_count)
	var resume: Variant = sm._read_save(sm.resume_path())
	check(resume is Dictionary and int((resume as Dictionary).get("possession_count", -1)) == 1, "possession_count persisted to resume file")

	## 4) Tekrar: kısa.
	await dirty_b.call()
	await _wait(0.2)
	dm.clear()
	var dur2: float = await _run_possession()
	check(dur2 < dur1 - 1.5 and dur2 <= 2.5 and dur2 >= 1.5, "second possession shorter (~2s)", "%.2fs vs first %.2fs" % [dur2, dur1])
	await _wait(0.2)
	_assert_a(seal_pos, corpses_a, deaths_a, fdc_a, "possession 2")
	check(gs.possession_count == 2, "possession_count == 2 (survives load_committed)", gs.possession_count)

	## 5) Tekrar + girdi: atlar.
	await dirty_b.call()
	await _wait(0.2)
	dm.clear()
	var dur3: float = await _run_possession(0.5)
	check(dur3 < dur2 - 0.4 and dur3 < 1.5, "input skips repeat possession", "%.2fs" % dur3)
	await _wait(0.2)
	_assert_a(seal_pos, corpses_a, deaths_a, fdc_a, "possession 3 (skipped)")
	check(gs.possession_count == 3, "possession_count == 3", gs.possession_count)

	## 5b) Ele geçirme sırasında ölüm/hasar (çukur yarışı) yok sayılır: ceset, yatak, ölüm sayacı yok.
	await dirty_b.call()
	await _wait(0.2)
	dm.clear()
	var hearts_before: int = gs.hearts
	curse.set_curse(100.0)
	var tw := Time.get_ticks_msec()
	while not curse.possessing and Time.get_ticks_msec() - tw < 3000:
		await process_frame
	check(curse.possessing, "5b: possession started")
	death.request_death(&"hazard")
	gs.damage(gs.hearts + 5)
	check(not death.is_dying and phases.is_empty(), "5b: request_death ignored during possession", phases)
	check(gs.hearts == hearts_before, "5b: damage ignored during possession", gs.hearts)
	var t5 := Time.get_ticks_msec()
	while curse.possessing and Time.get_ticks_msec() - t5 < 20000:
		await process_frame
	await _wait(0.2)
	_assert_a(seal_pos, corpses_a, deaths_a, fdc_a, "possession 5b (death+damage during)")
	check(gs.possession_count == 4, "5b: possession_count == 4", gs.possession_count)

	## 6) Yeniden başlatma benzetimi: sayaç kayıt dosyasından geri gelir.
	gs.possession_count = 0
	check(sm.load_game(false), "load_game after restart-like reset")
	check(gs.possession_count == 4, "possession_count restored from save after restart", gs.possession_count)

	## 7) 100 kayda yazılmış olsa bile yükleme ele geçirme tetiklemez.
	curse.restore_curse(100.0)
	check(curse.curse <= 99.0 and not curse.possessing, "restore_curse never triggers possession", curse.curse)

	sm.delete_all_save_files()
	print("CURSE RESULT failures=", failures)
	quit(1 if failures > 0 else 0)


func _assert_a(seal_pos: Vector2, corpses_a: int, deaths_a: int, fdc_a: bool, tag: String) -> void:
	check(rm.get_active_room_id() == &"library_hall", "%s: room == A" % tag, rm.get_active_room_id())
	check(player.global_position.distance_to(seal_pos) < 12.0, "%s: spawn at committed safe position" % tag, player.global_position)
	## v1.7: possession odası/konumu A'ya döner ama dünya ilerlemesi (story/world/puzzle) silinmez.
	check(gs.has_story_flag(&"first_warning_heard") and gs.has_story_flag(&"core_access_granted"), "%s: story flags persist across possession" % tag)
	check(gs.get_world_flag(&"audit_marker_b", false), "%s: world state B persists" % tag)
	check((gs.world_memory_state["corpses"] as Array).size() == corpses_a, "%s: corpse count unchanged" % tag)
	check(int(gs.player_progress_knowledge.get("deaths", 0)) == deaths_a, "%s: death count unchanged" % tag)
	check(gs.has_story_flag(&"first_death_completed") == fdc_a, "%s: first_death_completed untouched" % tag)
	check(phases.is_empty() and not death.is_dying, "%s: no death/soul/bed phases" % tag, phases)
	check(root.get_node("EndingManager").current == root.get_node("EndingManager").Ending.NONE, "%s: EndingManager.current == NONE" % tag)
	check(absf(curse.curse - curse.POSSESSION_SAFE_CURSE) < 1.0 and curse.get_band() == curse.Band.FIRST_SIGNS, "%s: curse at possession safe 50" % tag, curse.curse)
	check(gs.get_world_flag(&"audit_possession_world_persist", false), "%s: world flag persisted" % tag)
	check(puz.is_solved(&"audit_possession_persist"), "%s: puzzle state persisted" % tag)
	check(not _on_hazard(player.global_position), "%s: player not on a hazard" % tag)
	check(not curse.possessing and gate.current_layer() == gate.Layer.NONE, "%s: control returned" % tag, gate.current_layer())
	check(player.visible and player.modulate.is_equal_approx(Color.WHITE), "%s: player visible, tint reset" % tag)
