extends SceneTree
## Telefon (yatay) görüntülü ekran görüntüleri — headless DEĞİL. Çıktı repo dışı: C:/tb/mobile_shots/
## godot --path PROJECT -s res://scripts/dev/mobile_capture.gd
const OUT := "C:/tb/mobile_shots"
const SHOTS: Array = [
	[Vector2i(2400, 1080), false], [Vector2i(1600, 720), false], [Vector2i(2048, 1536), false], [Vector2i(1600, 720), true],
]
const LONG_LINE := "Uzun bir konuşma satırı: duvarlar ağır ağır nefes alıyor, taşın altındaki isimleri tek tek okumaya çalışıyorsun ama harfler kayıyor; sonunda yalnız kendi sesinin yankısı kalıyor ve kapı hâlâ kapalı."
var _dm: Node
var _gs: Node
var _sm: Node
var _n := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_TOUCH_UI", "1")
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	_dm = root.get_node("DialogueManager")
	_gs = root.get_node("GameState")
	_gs.player_progress_knowledge["ability_soul_slash"] = true
	_gs.player_progress_knowledge["journal_unlocked"] = true
	_dm.call("clear")
	GameSettings.text_speed = 2
	_sm = root.find_child("SessionMenu", true, false)
	var hud := root.find_child("HUD", true, false)
	var journal := root.find_child("Journal", true, false)
	for spec in SHOTS:
		var sz: Vector2i = spec[0]
		GameSettings.font_large = spec[1]
		var tag := "%dx%d%s" % [sz.x, sz.y, "_large" if spec[1] else ""]
		root.size = sz
		DisplayServer.window_set_size(sz)
		await create_timer(0.5).timeout
		if hud:
			hud.call("apply_text_size_setting", true)
			hud.call("refresh_touch_controls")
		await create_timer(0.3).timeout
		await _shot(tag + "_1_play")
		_dm.call("ask", "Shilda", LONG_LINE, PackedStringArray(["Evet, hatırlıyorum.", "Hayır, hiçbir şey hatırlamıyorum.", "Sana güvenmiyorum."]))
		var g := 0
		while not bool(_dm.get("_choices_live")) and g < 10:
			_dm.call("advance")
			await create_timer(0.2).timeout
			g += 1
		await create_timer(0.4).timeout
		await _shot(tag + "_2_dialogue_choices")
		_dm.call("clear")
		_dm.call("say", "Araştırma Yardımcısı S.", LONG_LINE + " " + LONG_LINE)
		await create_timer(0.6).timeout
		await _shot(tag + "_3_dialogue_long")
		_dm.call("clear")
		await create_timer(0.3).timeout
		if journal:
			journal.call("open_journal")
			await create_timer(0.4).timeout
			journal.call("_show_section", "harita")
			await create_timer(0.5).timeout
			await _shot(tag + "_4_journal_map")
			journal.call("close_journal")
			await create_timer(0.3).timeout
		if _sm:
			_sm.call("open_menu")
			await create_timer(0.4).timeout
			await _shot(tag + "_5_pause")
			_sm.call("_show_pause_page", true)
			await create_timer(0.3).timeout
			await _shot(tag + "_6_settings")
			_sm.call("_show_pause_page", false)
			_sm.call("close_menu")
			await create_timer(0.3).timeout
			_sm.call("_open_title")
			await create_timer(1.0).timeout
			await _shot(tag + "_7_title")
			var ts: Node = _sm.get("_title_screen")
			if ts and ts.has_method("_show_page"):
				ts.call("_show_page", &"settings")
				await create_timer(0.4).timeout
				await _shot(tag + "_8_title_settings")
				ts.call("_show_page", &"main")
			ts.call("close", func(): _sm.call("close_menu"))
			await create_timer(1.0).timeout
	print("MOBILE_CAPTURE shots=", _n, " dir=", OUT)
	quit(0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("MOBILE_CAPTURE fail ", name)
		return
	var err := img.save_png(OUT.path_join(name + ".png"))
	_n += 1
	print("MOBILE_CAPTURE ", name, " err=", err, " ", img.get_width(), "x", img.get_height())
