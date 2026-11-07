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


func check(ok: bool, label: String) -> void:
	print("DEATH ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


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
	var cam := get_first_node_in_group("follow_camera")
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
		if String(n.corpse_id) == String(last.get("id", "")):
			cnode = n
	check(cnode != null, "last corpse node exists")
	if cnode:
		cnode._data = last
		check(cnode._replay_trail(trail), "echo replay starts")
		check(cnode.get_node_or_null("EchoReplay") != null, "echo replay ghost spawned")
		await create_timer(trail.size() * 0.1 + 1.5).timeout
		check(cnode.get_node_or_null("EchoReplay") == null, "echo replay ghost freed")
	## Shilda yenilgisi: kalıcı işaret, iyi son kapalı, yas yok.
	state.set_world_flag(&"keeper_defeated", true)
	keeper.place_for_room(rm.get_active_room_id())
	check(not keeper.visible and keeper.collision_layer == 0, "defeated keeper hidden")
	check(not root.get_node("EndingManager").can_attempt_good_seal(), "good ending closed after keeper defeat")
	keeper.start_encounter(&"shilda_wall")
	check(keeper.mode != keeper.Mode.COMBAT, "defeated keeper never restarts combat")
	state.set_world_flag(&"keeper_defeated", false)
	## Lanet ele geçirmesi: ceset yok, ruh yok, yine de doğuş.
	var c_before: int = (state.world_memory_state["corpses"] as Array).size()
	var tr_before: int = (state.world_memory_state["traces"] as Array).size()
	phases.clear()
	death.request_death(&"curse")
	var t1 := Time.get_ticks_msec()
	while death.is_dying and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	check(not death.is_dying, "possession rebirth completes")
	check((state.world_memory_state["corpses"] as Array).size() == c_before and (state.world_memory_state["traces"] as Array).size() == tr_before, "possession leaves no corpse")
	check(not phases.has(2), "possession has no soul release")
	dm.clear()
	print("DEATH_AUDIT failures=", failures)
	quit(1 if failures else 0)
