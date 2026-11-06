extends SceneTree
## Genişleme kanıt ekranları — görüntülü (headless değil).

const OUT_REL := "docs/gelistirme/sonraki-asama/screens"


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	print("EXPAND_CAPTURE display=", DisplayServer.get_name())
	var out_abs := ProjectSettings.globalize_path("res://").path_join(OUT_REL)
	DirAccess.make_dir_recursive_absolute(out_abs)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var main := current_scene
	var dm := root.get_node("DialogueManager")
	var player := main.get_node("Player")
	var journal := main.get_node("Journal")
	var cam := main.get_node("Camera2D")
	# Intro temizle
	if dm.is_open:
		dm.clear()
	await process_frame
	await _shot(out_abs, "20_awakening_start")

	var rooms: Node = root.get_node("RoomManager")
	# Geniş oda + kamera
	if rooms.call("has_room", &"awakening_passage"):
		rooms.call("enter_room", &"awakening_passage", &"default")
		await create_timer(0.35).timeout
		await _shot(out_abs, "21_passage_wide_left")
		player.global_position = Vector2(1100, 288)
		await create_timer(0.45).timeout
		await _shot(out_abs, "22_passage_camera_follow")
		print("EXPAND cam=", cam.global_position, " bounds=", cam.room_rect)

	# Uzun konuşmacı + günlük
	dm.say("BekçiAvcısıUzunKonuşmacıAdıTestiXXXX", "Oda hatırlıyor. Sen unutuyorsun. Bu cümle sayfalama ve taşma için bilerek uzun tutuldu; Türkçe ığüşöç.")
	await create_timer(0.4).timeout
	await _shot(out_abs, "23_dialogue_long_speaker")
	dm.clear()
	journal.open_journal()
	await create_timer(0.35).timeout
	await _shot(out_abs, "24_journal_twocol")
	journal.close_journal()

	# Çürüme / kütüphane varlık
	if rooms.call("has_room", &"decay_garden"):
		rooms.call("enter_room", &"decay_garden", &"default")
		await create_timer(0.3).timeout
		await _shot(out_abs, "25_decay_garden")
	if rooms.call("has_room", &"library_hall"):
		rooms.call("enter_room", &"library_hall", &"default")
		await create_timer(0.3).timeout
		await _shot(out_abs, "26_library_hall")
	if rooms.call("has_room", &"core"):
		rooms.call("enter_room", &"core", &"default")
		await create_timer(0.3).timeout
		await _shot(out_abs, "27_core_chamber")

	print("EXPAND_CAPTURE done")
	quit(0)


func _shot(out_abs: String, name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var path := out_abs.path_join("%s.png" % name)
	img.save_png(path)
	print("SHOT ", path)
