extends SceneTree
## Shilda yerleşimi + isim sahnesi: siluet beat'i oda değişiminde iptal olur ve yerleşimi engellemez,
## isim sahnesi satırları "???" -> "Shilda" sırasıyla, geç odada otomatik sahne bir kez, son çare sessiz isim.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/keeper_naming_audit.gd
var failures := 0
var shown: Array = []  ## {"sp","t","named"}


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("KEEPNAME ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("KEEPNAME SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var gs := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	gs.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(1.0).timeout
	var keeper := get_first_node_in_group("keeper")
	check(keeper != null, "keeper node found")
	if keeper == null:
		quit(1)
		return
	dm.line_shown.connect(func(sp: String, t: String): shown.append({"sp": sp, "t": t, "named": gs.is_shilda_named()}))
	dm.clear()
	gs.set_shilda_named(false)
	gs.clear_story_flags()

	## 1) Siluet beat'i çalışırken odadan çık: beat iptal, sonraki oda doğru yerleşim.
	rm.enter_room(&"awakening_passage", &"default")
	await create_timer(0.5).timeout
	check(keeper._shadow_beat_running, "shadow beat waiting in passage (player far)")
	var gen_before: int = keeper._beat_gen
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.4).timeout
	check(not keeper._shadow_beat_running and keeper._beat_gen > gen_before, "leaving the passage cancels the shadow beat")
	check(keeper.presence == "hidden" and not keeper.visible and keeper.collision_layer == 0, "awakening before first death: keeper hidden, no leftover silhouette")
	check(not gs.has_story_flag(&"first_shadow_seen"), "cancelled beat did not mark first_shadow_seen")
	rm.enter_room(&"awakening_passage", &"default")
	await create_timer(0.5).timeout
	check(keeper._shadow_beat_running, "beat re-armed on re-entering the passage")
	rm.enter_room(&"decay_garden", &"default")
	await create_timer(0.4).timeout
	check(keeper.presence == "present" and keeper.visible and keeper.collision_layer != 0, "decay_garden: keeper placed present (naming reachable)")
	check(keeper.global_position.is_equal_approx(keeper.home_position), "decay_garden: keeper at its room position")
	check(not keeper._shadow_beat_running and not dm.is_open, "no beat state or dialogue left in decay_garden")

	## 2) Isim sahnesi satırları: ??? -> Shilda, ad "Ben Noroi." satırında açılır.
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	gs.set_shilda_named(false)
	shown.clear()
	keeper._queue_naming_lines()
	await create_timer(0.1).timeout
	for _i in range(45):
		dm.advance()
		await create_timer(0.04).timeout
	var texts: Array = shown.map(func(e): return String(e["t"]))
	var i_name := texts.find("Shilda.")
	var i_noroi := texts.find("Ben Noroi.")
	var i_know := texts.find("Biliyorum.")
	check(texts.size() == 12 and i_name >= 0 and i_noroi == i_name + 1 and i_know == i_name + 2, "naming scene shows 12 lines in order %s" % str(texts))
	check(i_name >= 0 and shown[i_name]["sp"] == "???" and not shown[i_name]["named"], "line 'Shilda.' is spoken by ??? while unnamed")
	check(i_noroi >= 0 and shown[i_noroi]["sp"] == "Noroi" and shown[i_noroi]["named"], "name flips on the 'Ben Noroi.' line")
	check(i_know >= 0 and shown[i_know]["sp"] == "Shilda" and shown[i_know]["named"], "line 'Biliyorum.' is spoken by Shilda")
	var all_q := true
	for e in shown:
		if e["t"] in ["Buraya geldiğinden beri.", "Daha önce de birilerinin geldiğini gördüm.", "Hiçbiri çıkamadı.", "Shilda."] and e["sp"] != "???":
			all_q = false
	check(all_q, "every pre-name Shilda line uses the ??? card")
	check(gs.is_shilda_named() and gs.has_story_flag(&"shilda_name_known"), "shilda_name_known flag set after the scene")
	## Tam sahne (başsız ortamda diyalog kısaltılır): bayraklar + bilgi anahtarları.
	dm.clear()
	gs.set_shilda_named(false)
	gs.player_progress_knowledge.erase("shilda_talk_done")
	await keeper._run_naming_scene()
	check(gs.is_shilda_named() and bool(gs.player_progress_knowledge.get("shilda_talk_done", false)) and not keeper._busy, "full scene: flag + shilda_talk_done set, keeper not stuck busy")

	## 3) Geç odada otomatik sahne: bir kez; silüet odada isimlendirme yok; core_final son çare.
	dm.clear()
	gs.set_shilda_named(false)
	shown.clear()
	rm.enter_room(&"experiment_authority", &"default")
	await create_timer(1.5).timeout
	check(not gs.is_shilda_named() and not dm.is_open, "late silhouette room: no silent naming, no scene")
	rm.enter_room(&"mirrors_unbroken", &"default")
	await create_timer(1.5).timeout
	var starts := 0
	for e in shown:
		if e["t"] == "Beni ne zamandır izliyorsun?":
			starts += 1
	check(starts == 1, "present late room: naming scene auto-runs exactly once (%d)" % starts)
	await create_timer(1.0).timeout
	check(gs.is_shilda_named(), "after the auto scene she is named")
	gs.set_shilda_named(false)
	dm.clear()
	shown.clear()
	keeper.place_for_room(&"core_final")
	await create_timer(0.3).timeout
	check(gs.is_shilda_named() and shown.is_empty(), "core_final (keeper hidden): silent last-resort naming, no dialogue")
	gs.set_shilda_named(false)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
