extends SceneTree
## Kaydet ve Çık: onay → commit_save → ANA MENÜ (uygulama kapanmaz) → Devam Et committed durumu yükler.
## Ana Menüye Dön: kayıt yazmaz, resume silinir, Devam Et committed kaydı yükler. Düğme sırası/metinler kontrol edilir.
## Kayıt hatası → "Tekrar Dene". Ölüm yatak noktasına döner (resume silinir).
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
	var order := []
	for b in menu._main_box.get_children():
		order.append((b as Button).text)
	check(order == ["Devam Et", "Ayarlar", "Kaydet ve Çık", "Ana Menüye Dön"], "pause buttons in order %s" % str(order))
	var yeni := 0
	for b in menu._panel.find_children("*", "Button", true, false):
		if "Yeni" in (b as Button).text:
			yeni += 1
	check(yeni == 0, "no 'Yeni oyun' button in pause menu")
	## Ayarlar: var olan ayar düğmeleri alt sayfada, Geri ana sayfaya döner.
	menu._settings_button.pressed.emit()
	check(menu._settings_box.visible and not menu._main_box.visible, "Ayarlar opens settings sub-page")
	check(menu._vol_button.is_visible_in_tree() and menu._music_button.is_visible_in_tree(), "settings page shows volume + music")
	check(menu._settings_help.is_visible_in_tree() and "NASIL OYNANIR" in menu._settings_help.text and "Ölmek son değil" in menu._settings_help.text, "settings page shows Nasıl Oynanır + death line")
	menu._show_pause_page(false)
	check(menu._main_box.visible and not menu._settings_box.visible, "Geri returns to main pause page")
	## 1) Onay → Vazgeç: hiçbir şey olmaz.
	menu._quit_button.pressed.emit()
	check(menu.is_confirm_open(), "confirm dialog opens")
	check(menu._confirm_text.text == "İlerlemen kaydedilecek ve ana menüye döneceksin. Emin misin?", "confirm text (%s)" % menu._confirm_text.text)
	check(menu._confirm_ok.text == "Kaydet ve Çık", "confirm ok button")
	check(menu._confirm_panel.title_label.text == "Kaydet ve Çık", "save&quit confirm title (%s)" % menu._confirm_panel.title_label.text)
	check(player.is_on_floor(), "player grounded before Save & Quit (safe case)")
	var cancel_texts := []
	for b in menu._confirm_ok.get_parent().get_children():
		cancel_texts.append((b as Button).text)
	check(cancel_texts == ["Vazgeç", "Kaydet ve Çık"], "confirm buttons %s" % str(cancel_texts))
	menu._close_confirm()
	check(not menu.is_confirm_open() and menu._panel.visible, "Vazgeç keeps game + menu")
	## Ana Menüye Dön onay metni.
	menu._main_menu_button.pressed.emit()
	check(menu.is_confirm_open() and menu._confirm_text.text == "Kaydedilmemiş ilerleme kaybolacak. Ana menüye dönmek istiyor musun?", "main menu confirm text (%s)" % menu._confirm_text.text)
	check(menu._confirm_ok.text == "Ana Menüye Dön", "main menu confirm ok button")
	check(menu._confirm_panel.title_label.text == "Ana Menü", "main menu confirm title")
	menu._close_confirm()
	check(not menu.is_confirm_open() and current_scene.get_node_or_null("Player") == player, "main menu Vazgeç changes nothing")
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
	var saved: Variant = sm._read_save(sm.SAVE_PATH)
	check(saved != null and (saved as Dictionary).get("commit_reason", "") == "save_and_quit", "committed save written with reason save_and_quit")
	var committed_serial := int((saved as Dictionary).get("save_serial", 0))
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	check(current_scene != null and current_scene != old_scene, "scene rebuilt (returned to title, app still running)")
	menu = _menu()
	check(menu.is_title_open(), "title screen open after Save & Quit")
	check(menu._title_screen._start_button.text == "Devam Et" and not menu._title_screen._start_button.disabled, "title Devam Et enabled")
	player = current_scene.get_node("Player")
	check(rm.get_active_room_id() == &"awakening", "continue room = committed room")
	check(player.global_position.distance_to(saved_pos) < 12.0, "Devam Et restores same position after safe Save & Quit (%s vs %s)" % [player.global_position, saved_pos])
	check(int(sm._serial_of(sm._read_save(sm.SAVE_PATH))) >= committed_serial, "committed serial intact")
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
	## 4b) Ana Menüye Dön: kaydedilmemiş ilerleme gider, Devam Et committed kaydı yükler.
	var committed_deaths := int(state.player_progress_knowledge.get("deaths", 0))
	state.player_progress_knowledge["deaths"] = committed_deaths + 7
	sm.save_resume_point() ## daha yeni serial'lı resume
	check(FileAccess.file_exists(sm.resume_path()), "resume file exists before Ana Menüye Dön")
	root.get_node("DialogueManager").clear()
	menu.open_menu()
	menu._main_menu_button.pressed.emit()
	menu._confirm_ok.pressed.emit()
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	menu = _menu()
	check(menu.is_title_open(), "title open after Ana Menüye Dön")
	check(not FileAccess.file_exists(sm.resume_path()), "resume invalidated by Ana Menüye Dön")
	check(int(state.player_progress_knowledge.get("deaths", -1)) == committed_deaths, "Devam Et state = committed (deaths %d)" % int(state.player_progress_knowledge.get("deaths", -1)))
	ts = menu._title_screen
	ts.start_requested.emit()
	await create_timer(0.6).timeout
	player = current_scene.get_node("Player")
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
	check(absf(player.global_position.x - death.REBIRTH_BED.x) < 40.0, "respawn at rebirth bed (not the quit position)")
	## 6) Güvensiz Kaydet ve Çık (yakında düşman): oyuncu konumu değil son checkpoint kaydedilir.
	var cp_before: Vector2 = state.get_checkpoint()
	player.global_position = cp_before + Vector2(220, 0)
	## Geniş boşluk: pit merkezi 400px uzakta olsa da kenara 96px içindeyse tehlikeli (gerçek genişlik).
	var pit := Area2D.new()
	pit.add_to_group("pit")
	var pcs := CollisionShape2D.new()
	var prect := RectangleShape2D.new()
	prect.size = Vector2(700, 24)
	pcs.shape = prect
	pit.add_child(pcs)
	current_scene.add_child(pit)
	pit.global_position = Vector2(player.global_position.x + 400.0, 352.0)
	check(player._near_pit(pit) and player._near_hazard(), "wide pit: near its edge (center 400px away) counts as near hazard")
	pit.global_position = Vector2(player.global_position.x + 700.0, 352.0)
	check(not player._near_pit(pit), "wide pit: >96px from edge is not near hazard")
	pit.queue_free()
	var foe := Node2D.new()
	foe.add_to_group("enemy")
	current_scene.add_child(foe)
	foe.global_position = player.global_position + Vector2(40, 0)
	menu = _menu()
	check(menu._safe_quit_spot().is_empty(), "unsafe spot (enemy within 120px) -> _safe_quit_spot empty")
	root.get_node("DialogueManager").clear()
	var unsafe_pos := player.global_position
	menu._save_and_exit()
	var usaved: Variant = sm._read_save(sm.SAVE_PATH)
	check(usaved != null and (usaved as Dictionary).get("commit_reason", "") == "save_and_quit", "unsafe Save & Quit still commits (reason save_and_quit)")
	var ulife: Dictionary = (usaved as Dictionary).get("character_current_life_knowledge", {})
	var ucp: Dictionary = ulife.get("checkpoint", {})
	check(absf(float(ucp.get("x", -1.0)) - cp_before.x) < 1.0 and absf(float(ucp.get("x", -1.0)) - unsafe_pos.x) > 100.0, "unsafe Save & Quit stores last checkpoint, not player position (cp %s)" % str(ucp))
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	check(_menu().is_title_open(), "unsafe Save & Quit returns to title")
	print("SAVEQUIT_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
