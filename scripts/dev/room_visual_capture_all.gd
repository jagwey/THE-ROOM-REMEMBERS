extends SceneTree
## 47 odanın tamamı: ekran görüntüsü — görüntülü (headless DEĞİL). TORIMON_TEST=1 ile çalıştır (qa kaydı).
## TORIMON_TEST=1 godot --path . -s res://scripts/dev/room_visual_capture_all.gd -- <çıktı_klasörü> [oda1,oda2]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_abs: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://room_visual")
	var only: PackedStringArray = String(args[1]).split(",", false) if args.size() > 1 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out_abs)
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.8).timeout
	var dm := root.get_node("DialogueManager")
	var gate := root.get_node("UiGate")
	var rooms: Node = root.get_node("RoomManager")
	var idx := 0
	for id in rooms.ROOM_ORDER:
		idx += 1
		if not only.is_empty() and not only.has(String(id)):
			continue
		rooms.call("enter_room", id, &"default")
		await create_timer(0.7).timeout
		dm.clear()
		gate.set_story(false)
		await process_frame
		await process_frame
		var img: Image = get_root().get_viewport().get_texture().get_image()
		var path := out_abs.path_join("%02d_%s.png" % [idx, String(id)])
		img.save_png(path)
		print("SHOT ", path, " ", img.get_size())
	quit()
