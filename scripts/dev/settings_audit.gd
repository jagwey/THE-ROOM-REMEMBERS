extends SceneTree
## Oyuncu ayarları: varsayılanlar, kalıcılık, metin hızı, sarsıntı, yazı boyutu, ipucu seviyesi, menü düğmeleri.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/settings_audit.gd
var failures := 0
const TMP := "user://settings_audit_tmp.cfg"


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("ST ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("ST SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var gs := GameSettings
	## Test ortamında kalmış ayar dosyasını sil (yalnız qa kopyası user://).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	gs.load_settings()
	## --- varsayılanlar eski davranışla aynı ---
	gs.reset_defaults()
	check(gs.music_volume == 1.0 and gs.sfx_volume == 1.0, "default music/sfx volume 100")
	check(is_equal_approx(gs.text_cps(), 48.0), "default text speed = 48 cps (old TYPE_CPS)")
	check(gs.shake_enabled(), "default screen shake on")
	check(is_equal_approx(gs.font_scale(), 1.0), "default font scale 1.0")
	check(gs.max_hint_tier() == 3, "default hint level = all tiers")

	## --- kalıcılık: kaydet, sıfırla, yükle ---
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	var pre := ConfigFile.new()
	pre.set_value("audio", "volume", 0.5)
	pre.set_value("input", "haptics", false)
	pre.save(TMP)
	gs.music_volume = 0.3
	gs.sfx_volume = 0.6
	gs.text_speed = 2
	gs.screen_shake = false
	gs.font_large = true
	gs.hint_level = 0
	gs.save_settings(TMP)
	gs.reset_defaults()
	check(gs.text_speed == 1 and gs.screen_shake, "reset_defaults really resets")
	gs.load_settings(TMP)
	check(is_equal_approx(gs.music_volume, 0.3) and is_equal_approx(gs.sfx_volume, 0.6), "volumes persist")
	check(gs.text_speed == 2 and not gs.screen_shake and gs.font_large and gs.hint_level == 0, "text/shake/font/hint persist")
	var chk := ConfigFile.new()
	chk.load(TMP)
	check(is_equal_approx(float(chk.get_value("audio", "volume", 0.0)), 0.5) and chk.get_value("input", "haptics", true) == false, "save keeps existing keys (master volume, haptics)")
	gs.reset_defaults()
	gs.load_settings("user://does_not_exist_settings.cfg")
	check(gs.text_speed == 1 and gs.hint_level == 2 and gs.shake_enabled(), "missing file -> defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

	## --- ipucu seviyesi kademeleri ---
	var pm := root.get_node("PuzzleManager")
	var pid: StringName = &"awakening_balcony_crossed"
	var h: Dictionary = pm.get_hints(pid)
	gs.hint_level = 0
	check(pm.get_current_hint(pid, 3) == String(h["goal"]) and pm.get_current_hint(pid, 2) == String(h["goal"]), "hint Yok: only goal tier")
	gs.hint_level = 1
	check(pm.get_current_hint(pid, 3) == String(h["orientation"]) and pm.get_current_hint(pid, 1) == String(h["goal"]), "hint Yon: up to orientation")
	gs.hint_level = 2
	check(pm.get_current_hint(pid, 3) == String(h["explicit"]) and pm.get_current_hint(pid, 2) == String(h["orientation"]), "hint Acik: all tiers")
	gs.reset_defaults()

	## --- diyalog metin hızı ---
	var dm := root.get_node("DialogueManager")
	var line := "Bu oda seni hatırlıyor."
	gs.text_speed = 1
	dm.say("Noroi", line)
	check(dm.is_open and dm.is_typing() and dm.visible_page_text().length() < line.length(), "Normal: typewriter starts partial")
	dm.clear()
	gs.text_speed = 2
	dm.say("Noroi", line)
	check(dm.is_open and not dm.is_typing() and dm.visible_page_text() == line, "Aninda: full text at once, not typing")
	dm.clear()
	gs.text_speed = 0
	check(is_equal_approx(gs.text_cps(), 24.0), "Yavas: 24 cps")
	gs.reset_defaults()

	## --- ana sahne: menü düğmeleri, kamera sarsıntısı, yazı boyutu ---
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	root.get_node("UiGate").set_story(false)
	var menu: Node = get_first_node_in_group("session_menu")
	check(menu != null, "session menu exists")
	if menu != null:
		menu._cycle_text_speed()
		check(gs.text_speed == 2 and menu._text_speed_button.text == "Metin hızı: Anında", "button cycles text speed -> Anında (label ok)")
		menu._cycle_text_speed()
		menu._cycle_text_speed()
		check(gs.text_speed == 1 and menu._text_speed_button.text == "Metin hızı: Normal", "text speed cycle wraps to Normal")
		menu._toggle_shake()
		check(not gs.screen_shake and menu._shake_button.text == "Ekran sarsıntısı: Kapalı", "shake toggle off")
		menu._cycle_hint_level()
		check(gs.hint_level == 0 and menu._hint_button.text == "İpucu: Yok", "hint cycle -> Yok")
		menu._step_music_volume(-1)
		menu._step_sfx_volume(-1)
		check(is_equal_approx(gs.music_volume, 0.9) and is_equal_approx(gs.sfx_volume, 0.9), "stepper: -10 percent each")
		menu._step_sfx_volume(-1)
		menu._step_sfx_volume(-1)
		check(is_equal_approx(gs.sfx_volume, 0.7), "sfx stepper reaches 70")
		for i in 12:
			menu._step_music_volume(-1)
		check(is_equal_approx(gs.music_volume, 0.0), "music stepper clamps at 0")
		for i in 12:
			menu._step_music_volume(1)
		check(is_equal_approx(gs.music_volume, 1.0), "music stepper clamps at 100")
		check(menu._music_vol_label.text == "Müzik sesi: %100" and menu._sfx_vol_label.text == "Efekt sesi: %70", "stepper labels")
		var am := root.get_node("AudioManager")
		check(is_equal_approx(am.get_music_volume(), 1.0) and is_equal_approx(am.get_sfx_volume(), 0.7), "AudioManager holds music/sfx volume")
		## menüde kaydedilen değerler diskten geri okunur
		gs.reset_defaults()
		gs.load_settings()
		check(gs.text_speed == 1 and not gs.screen_shake and gs.hint_level == 0 and is_equal_approx(gs.sfx_volume, 0.7), "menu changes persisted to user://settings.cfg")
		menu.open_menu()
		menu._show_pause_page(true)
		await process_frame
		var vp := root.get_visible_rect().size
		var fr: Rect2 = menu._panel.frame.get_global_rect()
		check(fr.size.y <= vp.y and fr.position.y >= -0.5, "settings panel fits viewport height (%s in %s)" % [fr.size, vp])
		check(menu._settings_scroll.is_visible_in_tree() and menu._vol_button.is_visible_in_tree(), "settings scroll + existing buttons visible")
		menu.close_menu()

	var cam := root.get_viewport().get_camera_2d()
	check(cam != null and cam.has_method("add_trauma"), "follow camera found")
	if cam != null:
		cam._trauma = 0.0
		gs.screen_shake = false
		cam.add_trauma(1.0)
		check(cam.get_trauma() == 0.0, "shake off: add_trauma ignored")
		gs.screen_shake = true
		cam.add_trauma(0.5)
		check(is_equal_approx(cam.get_trauma(), 0.5), "shake on: add_trauma applied")

	var hud: Node = get_first_node_in_group("hud")
	check(hud != null and hud.has_method("apply_text_size_setting"), "HUD found")
	if hud != null:
		var base: int = hud.dialogue_text.get_theme_font_size("font_size")
		gs.font_large = true
		hud.apply_text_size_setting()
		var big: int = hud.dialogue_text.get_theme_font_size("font_size")
		check(big == int(round(base * 1.25)) and big > base, "Buyuk: dialogue font %d -> %d" % [base, big])
		check(dm.page_font_size == big, "pagination metrics follow font size")
		gs.font_large = false
		hud.apply_text_size_setting()
		check(hud.dialogue_text.get_theme_font_size("font_size") == base, "Normal restores base font")

	## test ortamında ayarları temizle
	gs.reset_defaults()
	gs.save_settings()
	print("ST DONE failures=", failures)
	quit(1 if failures > 0 else 0)
