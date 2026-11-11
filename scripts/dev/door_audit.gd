extends SceneTree
## Gotik kapı sistemi testi: boyut/katmanlar, açık kapı geçişi, çift dokunuş koruması,
## kilitli kapı mesajları + mühür, çözülünce geçiş, ölümden sonra kilit geri gelmez.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/door_audit.gd
var failures := 0
var _changes := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("DOOR ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _door_in(rm: Node, room_id: StringName, target: StringName) -> Area2D:
	var root: Node = (rm._rooms[room_id] as Dictionary)["root"]
	for n in root.find_children("*", "Area2D", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("room_transition.gd") \
				and n.target_room_id == target:
			return n
	return null


func _wait_transition(door_script) -> float:
	var t := 0.0
	while door_script.is_transitioning() and t < 5.0:
		await create_timer(0.05).timeout
		t += 0.05
	return t


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("DOOR SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	rm.room_changed.connect(func(_a, _b): _changes += 1)
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	var player: CharacterBody2D = current_scene.get_node("Player")
	var player_h := 74.0
	var ps := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if ps and ps.sprite_frames:
		var tex := ps.sprite_frames.get_frame_texture(&"idle", 0)
		if tex:
			## Hücre değil, karakterin görünen piksel boyu.
			player_h = float(tex.get_image().get_used_rect().size.y) * absf(ps.scale.y)

	## 1) Görsel: katmanlar + boy oranı.
	var door := _door_in(rm, &"awakening", &"awakening_passage")
	check(door != null, "awakening → passage door found")
	if door == null:
		quit(1)
		return
	var frame := door.get_node_or_null("DoorFrame") as Sprite2D
	check(door.get_node_or_null("DoorBack") != null and frame != null and door.get_node_or_null("DoorInnerLight") != null, "door layers back/light/frame exist")
	var ratio := float(frame.texture.get_height()) / player_h if frame else 0.0
	check(ratio >= 1.5 and ratio <= 2.5, "door height %.2fx player (%.0f px)" % [ratio, player_h])
	check(door.get_node("DoorBack").z_index >= 1 and door.get_node("DoorFrame").z_index >= 1, "door drawn above parallax (z_index >= 1)")
	check(not door.is_locked() and not (door.get_node("DoorSeal") as Sprite2D).visible, "open door has no seal")
	check(door.get_glow_kind() == &"normal", "open door glow = normal")
	var legacy_visible := 0
	for c in door.get_parent().get_children():
		if c is Sprite2D and (c as Sprite2D).visible and (c as Sprite2D).texture \
				and String((c as Sprite2D).texture.resource_path).ends_with("door_closed.png") \
				and absf((c as Sprite2D).position.x - door.position.x) < 48.0:
			legacy_visible += 1
	check(legacy_visible == 0, "legacy small door sprite hidden")

	## 2) Açık kapı geçişi + çift dokunuş.
	player.global_position = door.global_position + Vector2(-30, 0)
	await create_timer(0.1).timeout
	_changes = 0
	door.on_interact(player)
	door.on_interact(player) ## ikinci dokunuş yok sayılmalı
	check(door.is_transitioning(), "transition started")
	check(gate.blocks_movement(), "input blocked during transition")
	await create_timer(0.12).timeout
	check(player.scripted_walk and ps.animation == &"run", "walk-in plays run anim (no foot sliding) [%s]" % ps.animation)
	var waited := await _wait_transition(door)
	check(not door.is_transitioning(), "transition finished (%.2fs)" % waited)
	check(rm.get_active_room_id() == &"awakening_passage", "arrived in target room (%s)" % rm.get_active_room_id())
	check(_changes == 1, "double interact → single room change (%d)" % _changes)
	check(not gate.blocks_movement(), "control returned")
	check(not player.scripted_walk and player.modulate == Color.WHITE, "player state restored")
	check(current_scene.get_tree().root.get_node_or_null("DoorFade") == null, "fade layer freed")

	## 3) Kilitli kapı (mühür eşiği → çürüme).
	rm.enter_room(&"awakening_seal", &"default")
	await create_timer(0.3).timeout
	var ldoor := _door_in(rm, &"awakening_seal", &"awakening_vigil")
	check(ldoor != null, "seal room locked door found")
	if ldoor:
		var was_solved: bool = pm.is_solved(&"awakening_memory_code")
		check(not was_solved and ldoor.is_locked(), "door locked before puzzle")
		await create_timer(0.05).timeout
		check((ldoor.get_node("DoorSeal") as Sprite2D).visible, "seal visible while locked")
		check(ldoor.get_glow_kind() == &"cursed" and ldoor.get_interact_label() == "Mühürlü Kapı", "locked glow=cursed, label=Mühürlü Kapı")
		var msgs := []
		for i in 3:
			dm.clear()
			ldoor._last_locked_ms = -10000
			ldoor.on_interact(player)
			msgs.append(ldoor._locked_tries)
			await create_timer(0.05).timeout
		check(rm.get_active_room_id() == &"awakening_seal", "locked door does not travel")
		dm.clear()
		check(not ldoor.is_transitioning() and not gate.blocks_movement(), "locked door leaves control (after message)")
		var before: int = ldoor._locked_tries
		ldoor.on_interact(player) ## debounce: hemen tekrar → sayılmaz
		check(ldoor._locked_tries == before, "locked spam debounced")
		var variants := {}
		for i in 4:
			variants[ldoor.locked_message if i == 0 else String(ldoor.LOCKED_VARIANTS[i - 1])] = true
		check(variants.size() == 4, "4 distinct locked messages")
		dm.clear()
		## Çöz → mühür kalkar → geçer.
		pm.mark_solved(&"awakening_memory_code")
		await create_timer(0.05).timeout
		check(not ldoor.is_locked() and not (ldoor.get_node("DoorSeal") as Sprite2D).visible, "solved → seal hidden")
		## Ölüm → kilit geri gelmez.
		state.damage(99)
		var death := root.get_node("DeathManager")
		var t := 0.0
		while death.is_dying and t < 20.0:
			await create_timer(0.25).timeout
			t += 0.25
			dm.clear()
		check(not death.is_dying, "death finished")
		check(pm.is_solved(&"awakening_memory_code") and not ldoor.is_locked(), "lock stays open after death")
		rm.enter_room(&"awakening_seal", &"default")
		await create_timer(0.3).timeout
		dm.clear()
		gate.set_story(false)
		player.global_position = ldoor.global_position + Vector2(-30, 0)
		_changes = 0
		ldoor.on_interact(player)
		await _wait_transition(ldoor)
		check(rm.get_active_room_id() == &"awakening_vigil", "unlocked door travels (%s)" % rm.get_active_room_id())
	## 4) Gözlem Balkonu: mahzen tarafından girilince ruh mührü oyuncuyu hapsetmemeli.
	gate.set_story(false)
	check(not pm.is_solved(&"soul_seal_balcony"), "balcony soul seal starts closed")
	rm.enter_room(&"awakening_balcony", &"from_awakening_crypt")
	await create_timer(0.4).timeout
	dm.clear()
	gate.set_story(false)
	var start_x := player.global_position.x
	for i in 3:
		await process_frame
		await process_frame
		Input.action_press(&"ui_left")
		await create_timer(0.7).timeout
		Input.action_release(&"ui_left")
		dm.clear()
		gate.set_story(false)
	check(pm.is_solved(&"soul_seal_balcony"), "seal opens when approached from crypt side")
	await process_frame
	await process_frame
	Input.action_press(&"ui_left")
	await create_timer(1.5).timeout
	Input.action_release(&"ui_left")
	dm.clear()
	check(player.global_position.x < 780.0, "player walks past the seal from crypt side (%.0f → %.0f)" % [start_x, player.global_position.x])
	print("DOOR_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
