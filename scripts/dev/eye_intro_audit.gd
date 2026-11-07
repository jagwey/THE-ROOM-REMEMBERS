extends SceneTree
## Göz açma girişi testi: süre boyunca CUTSCENE kapısı, HUD gizli, hareket yok, beyaz kare yok;
## bitince kapı serbest ve düğüm silinmiş. Pencereli çalıştırınca kare görüntüleri kaydeder.
## Çalıştır: TORIMON_TEST=1 godot --path . -s res://scripts/dev/eye_intro_audit.gd
var EyeOpenIntro: GDScript
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")
	EyeOpenIntro = load("res://scripts/ui/eye_open_intro.gd")


func check(ok: bool, label: String) -> void:
	print("EYE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("EYE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.4).timeout
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	dm.clear()
	check(not gate.is_cutscene(), "fast intro already finished in test mode")
	var player: CharacterBody2D = current_scene.get_node("Player")
	var hud := current_scene.get_node_or_null("UI")
	var eyes: CanvasLayer = EyeOpenIntro.new()
	current_scene.add_child(eyes)
	var done := [false]
	eyes.finished.connect(func() -> void: done[0] = true)
	eyes.play(2.2, true)
	await process_frame
	check(gate.current_layer() == gate.Layer.CUTSCENE, "cutscene gate during intro")
	check(gate.blocks_movement(), "movement blocked during intro")
	if hud:
		check(not hud.safe_area.visible, "HUD hidden during intro")
	var menu := get_first_node_in_group("session_menu")
	if menu:
		check(not menu._menu_button.visible, "menu button hidden during intro")
	var x0 := player.global_position.x
	Input.action_press("ui_right")
	var shots := [0.05, 0.6, 1.1, 1.6, 2.4]
	var t0 := Time.get_ticks_msec()
	var windowed := DisplayServer.get_name() != "headless"
	var max_lum := 0.0
	for st in shots:
		while (Time.get_ticks_msec() - t0) / 1000.0 < st:
			await process_frame
		if windowed:
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.save_png("user://qa/eye_%04d.png" % int(st * 1000))
			## Ortalama parlaklık: beyaz flaş olmamalı.
			var small := img.duplicate() as Image
			small.resize(32, 18)
			var sum := 0.0
			for y in 18:
				for x in 32:
					sum += small.get_pixel(x, y).get_luminance()
			max_lum = maxf(max_lum, sum / (32.0 * 18.0))
	Input.action_release("ui_right")
	check(absf(player.global_position.x - x0) < 2.0, "player did not move during intro")
	check(done[0], "intro finished")
	check(not is_instance_valid(eyes), "intro node freed")
	check(not gate.is_cutscene() and not gate.blocks_movement(), "gate released after intro")
	if hud:
		check(hud.safe_area.visible, "HUD back after intro")
	if menu:
		check(menu._menu_button.visible, "menu button back after intro")
	if windowed:
		print("EYE info max_avg_luminance=%.3f shots=%s" % [max_lum, ProjectSettings.globalize_path("user://qa/")])
		check(max_lum < 0.6, "no white flash")
	print("EYE_AUDIT failures=", failures)
	quit(1 if failures else 0)
