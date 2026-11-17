extends SceneTree
## Günlük görsel kanıtı (headless DEĞİL): en kötü durumla dört sekmeyi PNG'ye yazar.
## godot --path . -s res://scripts/dev/journal_capture.gd  (çıktı: C:/tb/journal_shots)
const OUT := "C:/tb/journal_shots"
var journal: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	journal = root.find_child("Journal", true, false)
	if journal == null:
		print("JC no journal")
		quit(1)
		return
	var dm := root.get_node_or_null("/root/DialogueManager")
	for i in 6:
		if dm:
			dm.call("clear")
		await create_timer(0.1).timeout
	journal.call("open_journal")
	await process_frame
	journal.visible = true
	print("JC journal visible=", journal.visible)
	await process_frame
	journal._show_section("harita")
	await process_frame
	_fill_worst_case(journal.map_view)
	for large in [false, true]:
		var GS: GDScript = load("res://scripts/autoload/game_settings.gd")
		GS.font_large = large
		for sec in ["gunluk", "notlar", "izler", "harita"]:
			journal._show_section(sec)
			journal.map_view.queue_redraw()
			await create_timer(0.3).timeout
			var img := root.get_viewport().get_texture().get_image()
			var path := "%s/%s%s_%dx%d.png" % [OUT, sec, "_large" if large else "", img.get_width(), img.get_height()]
			img.save_png(path)
			print("JC shot ", path)
	quit(0)


func _fill_worst_case(map: Control) -> void:
	var gs := root.get_node("GameState")
	var pk: Dictionary = gs.player_progress_knowledge
	var visited: Array = []
	var corpses: Array = []
	for reg in map._rooms_by_region:
		for rid in map._rooms_by_region[reg]:
			visited.append(String(rid))
			corpses.append({"room": String(rid)})
	pk["rooms_visited"] = visited
	pk["journal_unlocked"] = true
	var ev := {}
	for i in 123:
		ev["ev%d" % i] = {"discovered": true}
	pk["evidence"] = ev
	var nooks := {}
	for i in 8:
		nooks["n%d" % i] = true
	pk["nooks"] = nooks
	var trials := {}
	for i in 6:
		trials["t%d" % i] = true
	pk["trials"] = trials
	var mems := {}
	for i in 5:
		mems["m%d" % i] = true
	pk["memories"] = mems
	for i in 9:
		corpses.append({"room": String(visited[0])}) # iki haneli ceset sayısı
	var flags: Dictionary = gs.world_memory_state.get("flags", {})
	flags["seal_shard_1"] = true
	flags["seal_shard_2"] = true
	flags["shortcut_decay_crypt"] = true
	flags["decay_vine_shortcut"] = true
	gs.world_memory_state["flags"] = flags
	gs.world_memory_state["corpses"] = corpses
	var pm := root.get_node("PuzzleManager")
	for r in map.REGIONS:
		pm.solved[String(r["seal"])] = true


