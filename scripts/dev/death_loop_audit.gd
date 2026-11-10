extends SceneTree
## Tekrarlı ölüm testi: Shilda karşılaşması sırasında ölüm → yas → yeniden doğuş döngüsü
## hiçbir dokunuş olmadan tamamlanmalı (kilitlenme yok), Shilda savaşı bırakmalı,
## oyuncu kontrolü geri gelmeli. Pencereli çalıştırınca gerçek süreler sınanır.
## Çalıştır: TORIMON_TEST=1 godot --path . -s res://scripts/dev/death_loop_audit.gd [--headless]
var failures := 0
const LOOPS := 6


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("DEATH ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _committed_serial(sm: Node) -> int:
	var f := FileAccess.open(sm.SAVE_PATH, FileAccess.READ)
	if f == null:
		return -1
	var d: Variant = JSON.parse_string(f.get_as_text())
	return int((d as Dictionary).get("save_serial", -1)) if d is Dictionary else -1


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("DEATH SKIP (run with TORIMON_TEST=1 so the player save is never touched)")
		quit(0)
		return
	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	var dm := root.get_node("DialogueManager")
	var death := root.get_node("DeathManager")
	var rm := root.get_node("RoomManager")
	var gate := root.get_node("UiGate")
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")
	var keeper := current_scene.get_node("Keeper")
	var deaths_before := int(state.player_progress_knowledge.get("deaths", 0))
	var phases: Array = []
	death.phase_changed.connect(func(p: int) -> void: phases.append(p))
	## Diriliş HUD'a haber vermeli (yoksa dokunmatik düğmeler gizli kalır).
	var gate_layers: Array = []
	gate.gate_changed.connect(func(l: int) -> void: gate_layers.append(l))
	var cam := get_first_node_in_group("follow_camera")
	var sm := root.get_node("SaveManager")
	for i in LOOPS:
		rm.enter_room(&"decay_shilda_wall", &"default")
		await create_timer(0.15).timeout
		dm.clear()
		player.global_position = Vector2(300, 288)
		player.velocity = Vector2.ZERO
		keeper.start_encounter(&"shilda_wall")
		await create_timer(0.6).timeout
		check(keeper.mode == keeper.Mode.COMBAT, "loop %d: keeper in combat" % i)
		phases.clear()
		gate_layers.clear()
		state.damage(99)
		check(death.is_dying, "loop %d: death started" % i)
		check(keeper.mode != keeper.Mode.COMBAT and keeper.collision_mask == 0, "loop %d: combat aborted on death" % i)
		## İkinci ölüm isteği yok sayılmalı (tek ölüm kilidi).
		var corpses_mid: int = (state.world_memory_state["corpses"] as Array).size()
		death.request_death(&"double")
		state.damage(1)
		await process_frame
		check((state.world_memory_state["corpses"] as Array).size() == corpses_mid, "loop %d: single corpse per death" % i)
		## Dokunuş yok: akış kendiliğinden bitmeli.
		var t0 := Time.get_ticks_msec()
		var t := 0.0
		while death.is_dying and t < 25.0:
			await process_frame
			t = (Time.get_ticks_msec() - t0) / 1000.0
			## Ruh/ölüm sırasında Shilda saldırmamalı.
			if keeper.mode == keeper.Mode.COMBAT:
				check(false, "loop %d: keeper re-entered combat during death" % i)
				break
		check(not death.is_dying, "loop %d: rebirth completes without input (%.1fs)" % [i, t])
		check(not gate_layers.is_empty() and int(gate_layers.back()) == 0, "loop %d: gate_changed(NONE) emitted on rebirth %s" % [i, str(gate_layers.slice(-3))])
		dm.clear()
		await create_timer(0.1).timeout
		check(not gate.blocks_movement(), "loop %d: controls free after rebirth" % i)
		check(state.hearts == state.max_hearts, "loop %d: hearts restored" % i)
		check(is_instance_valid(keeper._player) or keeper._player == null, "loop %d: keeper player ref valid" % i)
		check(not player.attack_area.monitoring, "loop %d: attack hitbox closed" % i)
		check(phases == [1, 2, 3, 4, 0], "loop %d: phases DYING>SOUL_RELEASE>SOUL_TRANSITION>RESPAWNING>ALIVE %s" % [i, str(phases)])
		check(not is_instance_valid(death._soul), "loop %d: soul freed" % i)
		check(cam == null or cam._focus == null, "loop %d: camera back on player" % i)
		check(player.visible, "loop %d: player visible after wake" % i)
		## Sonraki ölümlerin possession'a kaymaması için laneti Bant 1'de tut.
		var cm_loop := root.get_node("CurseManager")
		if cm_loop.possessing:
			var tw := Time.get_ticks_msec()
			while cm_loop.possessing and Time.get_ticks_msec() - tw < 20000:
				await process_frame
		cm_loop.set_curse(50.0)
		dm.clear()
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_before + LOOPS, "death counter == loops")
	var corpses: Array = state.world_memory_state["corpses"]
	print("DEATH info corpses=", corpses.size())
	## Yankı tekrarı: son cesette iz var, etkileşimde hayalet tekrar oynar.
	var last: Dictionary = corpses[corpses.size() - 1] if corpses.size() > 0 else {}
	var trail: Array = last.get("trail", [])
	print("DEATH info trail_samples=", trail.size())
	check(trail.size() >= 4, "corpse stores echo trail")
	rm.enter_room(&"decay_shilda_wall", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	var cnode: Node = null
	for n in get_nodes_in_group("corpse"):
		if is_instance_valid(n) and String(n.corpse_id) == String(last.get("id", "")):
			cnode = n
	check(cnode != null and is_instance_valid(cnode), "last corpse node exists")
	if cnode and is_instance_valid(cnode):
		cnode._data = last
		check(cnode._replay_trail(trail), "echo replay starts")
		check(is_instance_valid(cnode) and cnode.get_node_or_null("EchoReplay") != null, "echo replay ghost spawned")
		await create_timer(trail.size() * 0.1 + 1.5).timeout
		check(not is_instance_valid(cnode) or cnode.get_node_or_null("EchoReplay") == null, "echo replay ghost freed")
	## Shilda öldürülemez (v3): vuruş öldürmez, is_defeated daima false.
	for i in 4:
		keeper.receive_player_strike()
	check(not keeper.is_defeated(), "keeper cannot be defeated by strikes")
	check(not bool(state.get_world_flag(&"keeper_defeated", false)), "no keeper_defeated flag after strikes")
	## Normal ölüm (v1.7): uzak odada ölüm -> aynı odada doğuş; +%25 lanet (en az %50); ceset uzak odada; dünya kalır; committed kayıt dokunulmaz.
	var puz := root.get_node("PuzzleManager")
	puz.mark_solved(&"decay_vine_shortcut")
	state.set_world_flag(&"audit_door_open", true)
	state.set_checkpoint(Vector2(777, 288), &"decay_garden") ## eski oda checkpoint'i artık karar vermemeli
	state.set_story_flag(&"first_death_completed", false) ## aşağıdaki kontrol gerçekten sınasın
	sm.commit_save(&"audit")
	var serial_before := _committed_serial(sm)
	var saves_before := FileAccess.get_modified_time(sm.SAVE_PATH)
	rm.enter_room(&"decay_garden", &"default", false)
	await create_timer(0.2).timeout
	dm.clear()
	player.global_position = Vector2(420, 288)
	var far_pos: Vector2 = player.global_position
	var curse_pre_far: float = root.get_node("CurseManager").curse
	state.damage(99)
	var t2 := Time.get_ticks_msec()
	while death.is_dying and Time.get_ticks_msec() - t2 < 25000:
		await process_frame
	await create_timer(0.2).timeout
	dm.clear()
	check(not death.is_dying and rm.get_active_room_id() == &"decay_garden", "far death respawns in same room", str(rm.get_active_room_id()))
	var garden_cp := Vector2(130, 288)
	check(absf(player.global_position.x - garden_cp.x) < 8.0 and absf(player.global_position.y - garden_cp.y) < 14.0, "respawn at room checkpoint not rebirth bed", str(player.global_position))
	var curse_after_far: float = root.get_node("CurseManager").curse
	check(curse_after_far >= 50.0, "far death curse at least 50", curse_after_far)
	check(curse_after_far >= curse_pre_far + 24.0 or curse_pre_far + 25.0 > 99.0, "far death adds ~25 curse", [curse_pre_far, curse_after_far])
	var corpses_far: Array = state.world_memory_state["corpses"]
	check(corpses_far.size() > 0 and String((corpses_far[corpses_far.size() - 1] as Dictionary).get("room", "")) == "decay_garden", "new corpse recorded in far room (list is capped)")
	var far_corpse: Dictionary = corpses_far[corpses_far.size() - 1] if corpses_far.size() > 0 else {}
	check(String(far_corpse.get("room", "")) == "decay_garden", "corpse stays in far room", str(far_corpse.get("room", "?")))
	rm.enter_room(&"decay_garden", &"default", false)
	await create_timer(0.2).timeout
	dm.clear()
	var found := false
	for n in get_nodes_in_group("corpse"):
		if String(n.corpse_id) == String(far_corpse.get("id", "?")):
			found = true
	check(found, "corpse node exists in far room")
	check(puz.is_solved(&"decay_vine_shortcut") and state.world_memory_state["flags"].get("audit_door_open", false), "puzzles and doors persist")
	check(_committed_serial(sm) == serial_before and FileAccess.get_modified_time(sm.SAVE_PATH) == saves_before, "committed save untouched by normal death", "%d" % serial_before)
	check(state.has_story_flag(&"first_death_completed"), "first_death_completed set after the far death respawn (was cleared before)")
	rm.enter_room(&"awakening", &"rebirth_bed", false)
	await create_timer(0.2).timeout
	var seal := current_scene.find_child("MemorySeal", true, false)
	check(seal != null and absf(seal.global_position.x - death.REBIRTH_BED.x) < 500.0 and absf(seal.global_position.x - death.REBIRTH_BED.x) > 40.0, "awakening seal near bed")
	var blocked := false
	var space: PhysicsDirectSpaceState2D = current_scene.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(death.REBIRTH_BED + Vector2(0, -20), Vector2(seal.global_position.x, death.REBIRTH_BED.y - 20), 1)
	blocked = not space.intersect_ray(q).is_empty()
	check(not blocked, "no wall between bed and awakening seal")
	## Lanet ele geçirmesi (v3): ölüm yolundan geçmez; ceset/ruh/yatak yok, final değil, committed kayda döner.
	var curse := root.get_node("CurseManager")
	var c_before: int = (state.world_memory_state["corpses"] as Array).size()
	var tr_before: int = (state.world_memory_state["traces"] as Array).size()
	var deaths_pre: int = int(state.player_progress_knowledge.get("deaths", 0))
	state.set_story_flag(&"first_death_completed", false)
	var fdc_pre: bool = state.has_story_flag(&"first_death_completed")
	check(not fdc_pre, "first_death_completed cleared before possession (assert meaningful)")
	sm.commit_save(&"audit")
	phases.clear()
	curse.add_curse(500.0)
	check(curse.possessing and not death.is_dying, "possession starts without the death path")
	var t1 := Time.get_ticks_msec()
	while curse.possessing and Time.get_ticks_msec() - t1 < 20000:
		await process_frame
	check(not curse.possessing and not death.is_dying, "possession completes")
	check((state.world_memory_state["corpses"] as Array).size() == c_before and (state.world_memory_state["traces"] as Array).size() == tr_before, "possession leaves no corpse")
	check(phases.is_empty(), "possession never enters a death phase (no soul/bed)")
	check(int(state.player_progress_knowledge.get("deaths", 0)) == deaths_pre, "possession does not count as a death")
	check(state.has_story_flag(&"first_death_completed") == fdc_pre, "possession does not fire first_death_completed")
	check(absf(curse.curse - curse.POSSESSION_SAFE_CURSE) < 1.0 and root.get_node("EndingManager").current == root.get_node("EndingManager").Ending.NONE, "curse at possession safe band and no ending", curse.curse)
	check(puz.is_solved(&"decay_vine_shortcut") and state.world_memory_state["flags"].get("audit_door_open", false), "possession keeps world memory and puzzles")
	sm.delete_all_save_files()
	dm.clear()
	print("DEATH_AUDIT failures=", failures)
	quit(1 if failures else 0)
