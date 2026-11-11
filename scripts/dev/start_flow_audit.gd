extends SceneTree
## Başlık -> Başla/Devam -> ~10 sn oyun: başlık/duraklatma menüsü geri gelmemeli, UiGate NONE'a dönmeli.
## Dokunma + FOCUS_OUT/IN çifti simüle edilir. Yeni oyun ve kayıttan devam iki tur.
## Çalıştır: TORIMON_TEST=1 TORIMON_FORCE_TITLE=1 godot --headless --path . -s res://scripts/dev/start_flow_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	OS.set_environment("TORIMON_FORCE_TITLE", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("STARTFLOW ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func menu_cls_reset() -> void:
	var sc: GDScript = load("res://scripts/ui/session_menu.gd")
	sc.set("_title_shown", false)


func _round(continued: bool) -> void:
	var tag := "continue" if continued else "new"
	var sm := root.get_node("SaveManager")
	var gate := root.get_node("UiGate")
	if continued:
		root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
		sm.save_game()
	else:
		sm.delete_all_save_files()
	root.get_node("RoomManager").reset_registry()
	menu_cls_reset()
	root.get_node("UiGate").set_title(false)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.4).timeout
	var menu := get_first_node_in_group("session_menu")
	check(menu != null and menu.is_title_open(), "[%s] title open at boot" % tag)
	check(gate.current_layer() == gate.Layer.TITLE, "[%s] gate TITLE at boot" % tag)
	var ts = menu._title_screen
	_title_checks(ts, tag, continued)
	ts.start_requested.emit()
	await create_timer(0.6).timeout
	check(not menu.is_title_open(), "[%s] title closed after Başla" % tag)
	var reopened := 0
	var panel_seen := 0
	var title_seen := 0
	var t0 := Time.get_ticks_msec()
	var step := 0
	var maxwait := 10.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < maxwait:
		await process_frame
		step += 1
		if step % 120 == 0:
			var pl := get_first_node_in_group("player") as Node2D
			print("STARTFLOW trace ", tag, " t=", step / 60, " layer=", gate.current_layer(), " dying=", root.get_node("DeathManager").is_dying, " room=", root.get_node("RoomManager").get_active_room_id(), " pos=", pl.global_position if pl else Vector2.ZERO, " dlg=", root.get_node("DialogueManager").is_open)
		## Gerçek oyuncu gibi: diyalog açıksa Etkileş ile ilerlet.
		if step % 20 == 0 and root.get_node("DialogueManager").is_open:
			var ia := InputEventAction.new()
			ia.action = &"interact"
			ia.pressed = true
			Input.parse_input_event(ia)
			await process_frame
			ia = InputEventAction.new()
			ia.action = &"interact"
			ia.pressed = false
			Input.parse_input_event(ia)
		if menu._panel.visible:
			panel_seen += 1
		if menu.is_title_open() or ts.visible:
			title_seen += 1
		if step == 60:
			## Dokunma: oyun alanı (menü düğmesinden uzak) ve joystick bölgesi.
			for pos in [Vector2(300, 200), Vector2(60, 300), Vector2(500, 160)]:
				var e := InputEventScreenTouch.new()
				e.index = 0
				e.position = pos
				e.pressed = true
				Input.parse_input_event(e)
				await process_frame
				e = InputEventScreenTouch.new()
				e.index = 0
				e.position = pos
				e.pressed = false
				Input.parse_input_event(e)
		if step == 150:
			root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			await process_frame
			root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		if step == 200:
			root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
			await process_frame
			root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	check(panel_seen == 0, "[%s] pause/session panel never visible in play (%d frames)" % [tag, panel_seen])
	check(title_seen == 0, "[%s] title never reappeared (%d frames)" % [tag, title_seen])
	check(gate.current_layer() == gate.Layer.NONE, "[%s] UiGate NONE after 10s (is %d)" % [tag, gate.current_layer()])
	check(menu._menu_button.visible, "[%s] Menü button visible after start" % tag)
	var mrect: Rect2 = menu._menu_button.get_global_rect()
	var vp: Vector2 = menu._menu_button.get_viewport_rect().size
	check(mrect.size.x < 140.0 and mrect.size.y < 60.0, "[%s] Menü button small (%s)" % [tag, mrect.size])
	check(not mrect.has_point(vp * 0.5), "[%s] Menü button does not cover screen center" % tag)
	check(mrect.position.x > vp.x * 0.5 and mrect.position.y < vp.y * 0.25, "[%s] Menü button in top-right (%s)" % [tag, mrect.position])
	check(get_first_node_in_group("player") != null, "[%s] player present" % tag)
	if not continued:
		var gsn := root.get_node("GameState")
		var kp := get_first_node_in_group("keeper")
		check(gsn.has_story_flag(&"intro_completed"), "[new] intro_completed set after the eye-open beat")
		check(not gsn.is_shilda_named() and gsn.keeper_speaker_name() == "???", "[new] Shilda name unknown at start (card ???)")
		check(kp == null or not kp.visible, "[new] Shilda is not in the awakening room at start")
		check(gate.current_layer() == gate.Layer.NONE and not root.get_node("DialogueManager").is_open, "[new] player not blocked after the opening")


## Başlık ana sayfa: düğme sırası, Devam Et durumu, Yeni Oyun onayı, Jenerik sayfası.
func _title_checks(ts: Control, tag: String, has_save: bool) -> void:
	var texts := []
	for b in (ts._pages[&"main"] as Control).get_children():
		if b is Button and (b as Button).visible:
			texts.append((b as Button).text)
	check(texts == ["Yeni Oyun", "Devam Et", "Ayarlar", "Jenerik", "Oyundan Çık"], "[%s] title buttons in order %s" % [tag, str(texts)])
	check(ts._start_button.disabled == (not has_save), "[%s] Devam Et disabled iff no save (disabled=%s)" % [tag, ts._start_button.disabled])
	check(ts._new_button.visible, "[%s] Yeni Oyun always visible" % tag)
	if has_save:
		ts._new_button.pressed.emit()
		var ct := ""
		var ctexts := []
		for c in (ts._pages[&"confirm"] as Control).get_children():
			if c is Label and (c as Label).text.begins_with("Kayıtlı"):
				ct = (c as Label).text
			elif c is Button:
				ctexts.append((c as Button).text)
		check(ts._page == &"confirm", "[%s] Yeni Oyun with save opens confirmation" % tag)
		check(ct == "Kayıtlı ilerlemen silinecek. Yeni oyuna başlamak istiyor musun?", "[%s] new game confirm text (%s)" % [tag, ct])
		check(ctexts == ["Evet", "Vazgeç"], "[%s] new game confirm buttons %s" % [tag, str(ctexts)])
		ts._show_page(&"main")
	ts._open_credits()
	check(ts._credits_panel.visible, "[%s] Jenerik opens credits panel" % tag)
	check(CreditsData.as_text().contains("Bir Torimon Studio oyunu") and CreditsData.as_text().contains("THE ROOM REMEMBERS") and CreditsData.as_text().contains("Jagwey"), "[%s] credits content present" % tag)
	check(ts.back() and not ts._credits_panel.visible, "[%s] back closes credits" % tag)


## Yeni Oyun: kayıt commit edilir ama sahne "Devam" değil taze girişle açılmalı.
func _new_game_round() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["deaths"] = 3
	sm.save_game()
	sm.start_new_game()
	await process_frame
	await create_timer(0.5).timeout
	check(not gs.session_loaded_from_save, "[newgame] session_loaded_from_save false (fresh path)")
	check(current_scene != null and not bool(current_scene._continued), "[newgame] main took fresh path, not continue")
	check(not sm.fresh_start_pending, "[newgame] fresh flag consumed")
	check(FileAccess.file_exists(sm.SAVE_PATH) and not FileAccess.file_exists(sm.resume_path()), "[newgame] committed exists, no stale resume")
	check(int(gs.player_progress_knowledge.get("deaths", -1)) == 0, "[newgame] progress reset")
	sm.delete_all_save_files()


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("STARTFLOW SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	await _round(false)
	await _round(true)
	await _new_game_round()
	print("STARTFLOW done failures=", failures)
	quit(1 if failures > 0 else 0)
