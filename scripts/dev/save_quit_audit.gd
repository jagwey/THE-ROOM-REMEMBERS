extends SceneTree
## Kaydet ve Çık: onay → kayıt doğrulanır → ANA MENÜ (uygulama kapanmaz) → Devam Et kaydedilen
## konumdan başlar. Kayıt hatası → "Tekrar Dene". Ölüm ise yine yatak noktasına döner (resume silinir).
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/save_quit_audit.gd
var failures := 0
var _quit_called := false


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("SAVEQUIT ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _menu() -> Node:
	return current_scene.get_node("SessionMenu")


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("SAVEQUIT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	root.get_node("DialogueManager").clear()
	var rm := root.get_node("RoomManager")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.2).timeout
	var player: CharacterBody2D = current_scene.get_node("Player")
	player.global_position = Vector2(300, 288)
	player.velocity = Vector2.ZERO
	await create_timer(0.3).timeout
	var saved_pos := player.global_position
	var menu := _menu()
	gate.set_story(false)
	menu.open_menu()
	check(menu._panel.visible, "pause menu opens")
	check(menu._quit_button.text == "Kaydet ve Çık", "pause button text 'Kaydet ve Çık' (%s)" % menu._quit_button.text)
	## Menüde "Ana Menüye Dön" kopyası olmamalı.
	var dup := 0
	for b in menu._panel.find_children("*", "Button", true, false):
		if "Ana Men" in (b as Button).text:
			dup += 1
	check(dup == 0, "no duplicate 'Ana Menüye Dön' button")
	## 1) Onay → Vazgeç: hiçbir şey olmaz.
	menu._quit_button.pressed.emit()
	check(menu.is_confirm_open(), "confirm dialog opens")
	check(menu._confirm_panel.title_label.text == "Emin misin?", "confirm title")
	check(menu._confirm_text.text == "İlerlemen kaydedilecek ve ana menüye dönülecek.", "confirm text")
	check(menu._confirm_ok.text == "Kaydet ve Çık", "confirm ok button")
	menu._close_confirm()
	check(not menu.is_confirm_open() and menu._panel.visible, "Vazgeç keeps game + menu")
	## 2) Kayıt hatası → Tekrar Dene diyaloğu.
	sm.force_fail_for_test = true
	menu._quit_button.pressed.emit()
	menu._confirm_ok.pressed.emit()
	check(menu.is_confirm_open() and menu._confirm_text.text == "Kayıt başarısız. Tekrar denemek ister misin?", "save failure shows retry dialog")
	check(menu._confirm_ok.text == "Tekrar Dene", "retry button text")
	check(current_scene.get_node_or_null("Player") == player, "no scene change on failed save")
	## 3) Tekrar Dene başarılı → ana menü (sahne yeniden kurulur, uygulama açık).
	sm.force_fail_for_test = false
	OS.set_environment("TORIMON_FRESH", "") ## yeniden yüklemede kayıttan devam
	var old_scene := current_scene
	menu._confirm_ok.pressed.emit()
	var saved: Variant = sm._read_save(sm.resume_path())
	check(saved != null and (saved["character_current_life_knowledge"] as Dictionary).has("resume"), "save verified with resume point")
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	check(current_scene != null and current_scene != old_scene, "scene rebuilt (returned to title, app still running)")
	menu = _menu()
	check(menu.is_title_open(), "title screen open after Save & Quit")
	check(menu._title_screen._start_button.text == "Devam Et", "title shows 'Devam Et'")
	player = current_scene.get_node("Player")
	check(rm.get_active_room_id() == &"awakening", "continue room = saved room")
	check(player.global_position.distance_to(saved_pos) < 6.0, "continue at saved position (%s vs %s)" % [player.global_position, saved_pos])
	check(not (state.character_current_life_knowledge as Dictionary).has("resume"), "resume point consumed once")
	## Başlıktaki çıkış onaylı sayfa.
	var ts: Control = menu._title_screen
	ts._show_page(&"quit_confirm")
	var qtexts := []
	for b in (ts._pages[&"quit_confirm"] as Control).find_children("*", "Button", true, false):
		qtexts.append((b as Button).text)
	check(qtexts == ["Vazgeç", "Çıkış Yap"], "title quit confirm buttons %s" % str(qtexts))
	ts._show_page(&"main")
	## 4) Devam Et → oyun.
	ts.start_requested.emit()
	await create_timer(0.6).timeout
	check(not menu.is_title_open(), "Devam Et closes title")
	## 5) Ölüm: resume değil yatak/checkpoint.
	sm.save_resume_point()
	check((state.character_current_life_knowledge as Dictionary).has("resume"), "resume written again")
	root.get_node("DialogueManager").clear()
	state.damage(99)
	var death := root.get_node("DeathManager")
	var t := 0.0
	while death.is_dying and t < 20.0:
		await create_timer(0.25).timeout
		t += 0.25
		root.get_node("DialogueManager").clear()
	check(not death.is_dying, "death loop finished (%.1fs)" % t)
	check(not (state.character_current_life_knowledge as Dictionary).has("resume"), "death clears resume (respawn at bed)")
	check(player.global_position.distance_to(state.get_checkpoint()) < 40.0, "respawn near checkpoint")
	print("SAVEQUIT_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
