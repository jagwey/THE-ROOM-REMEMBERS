extends SceneTree
## Her bölgeden temsilî odaların ekran görüntüsü — görüntülü (headless DEĞİL).
## godot --path . -s res://scripts/dev/room_visual_capture.gd -- <çıktı_klasörü>
## Çıktı klasörü verilmezse user://room_visual/ kullanılır.

const ROOMS := [
	&"awakening", &"awakening_crypt", &"core", &"core_bloom_garden",
	&"decay_garden", &"decay_shilda_wall", &"experiment_cells", &"experiment_observation",
	&"library_hall", &"library_clockroom", &"mirrors_gallery", &"mirrors_1927",
]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	var args := OS.get_cmdline_user_args()
	var out_abs: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://room_visual")
	DirAccess.make_dir_recursive_absolute(out_abs)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var dm := root.get_node("DialogueManager")
	if dm.is_open:
		dm.clear()
	var rooms: Node = root.get_node("RoomManager")
	for id in ROOMS:
		if not rooms.call("has_room", id):
			print("SKIP ", id)
			continue
		rooms.call("enter_room", id, &"default")
		await create_timer(0.6).timeout
		if dm.is_open:
			dm.clear()
		await process_frame
		await process_frame
		var img: Image = get_root().get_viewport().get_texture().get_image()
		var path := out_abs.path_join("%s.png" % String(id))
		img.save_png(path)
		print("SHOT ", path)
	quit()
