extends SceneTree
## Tek final denetimi (v3): enum yalniz NONE/PART_ONE; Shilda olmez; dizi bayrak sirasi
## final_seal_broken -> x_revealed -> game_completed; END OF PART I + kredi gosterilir; final_seen yazilir.
## Calistir: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/final_sequence_audit.gd
var failures := 0
var FS: GDScript
const UNKNOWN := "X?" ## DialogueManager.UNKNOWN_VOICE
var shown: Array = [] ## DialogueManager.line_shown kayitlari: [konusmaci, sayfa]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	FS = load("res://scripts/story/final_sequence.gd")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("FINAL ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


## Gercekten gosterilen diyalog satirlari (sira korunarak) beklenen final satirlariyla eslesir.
func _check_lines_in_order() -> void:
	var expected: Array = [
		["Shilda", "Ellerim..."], ["Noroi", "Shilda?"],
		["Shilda", "Sanırım... sonunda bitti."], ["Noroi", "Gidelim."],
		[UNKNOWN, "Demek sonunda başardınız."], ["Shilda", "Bu ses..."],
		["Shilda", "Kurucu...?"], ["X", "Merhaba, Shilda."], ["X", "Biliyorum."],
		["X", "Her şeyi kaydettim."], ["Noroi", "Bizi burada bıraktın."],
		["X", "Bu bir deneydi."],
		["X", "Şimdiye kadarki en başarılı deneklerim sizsiniz."],
		["X", "İlk boyuttan çıkmanız beklediğimden uzun sürdü."],
		["Shilda", "Noroi!"], ["X", "İhtiyacım olan şeyi aldım."],
		["X", "Çünkü henüz işiniz bitmemişti."],
		["Shilda", "Noroi... beni duyuyor musun?"]]
	var at := 0
	var missing: Array = []
	var shilda_tag := "Shilda" if root.get_node("GameState").is_shilda_named() else "???"
	## X'in gizli sesi: Shilda adı bilinse de "Shilda" olmaz; kartta "???" görünür.
	var dm_node: Node = root.get_node("DialogueManager")
	var hidden_voice := false
	var hidden_as_shilda := false
	for s in shown:
		if String(s[1]) == "Demek sonunda başardınız.":
			hidden_voice = dm_node.display_speaker(String(s[0])) == "???"
			hidden_as_shilda = String(s[0]) == "Shilda"
	check(hidden_voice and not hidden_as_shilda, "X hidden line displays ??? (not Shilda), shilda_named=%s" % str(root.get_node("GameState").is_shilda_named()))
	var portraits: GDScript = load("res://scripts/ui/dialogue_portraits.gd")
	## X? / ??? ayrı siluet asset kullanır (Shilda portresi değil).
	check(portraits.key_for(dm_node.UNKNOWN_VOICE) == &"x_unknown", "X hidden voice uses x_unknown portrait")
	check(portraits.key_for("???") == &"shilda_unknown", "??? speaker uses unknown silhouette")
	check(portraits.key_for("X") == &"x_unknown", "X speaker uses x portrait")
	for e in expected:
		var found := false
		while at < shown.size():
			var s: Array = shown[at]
			at += 1
			var sp := shilda_tag if String(e[0]) == "Shilda" else String(e[0])
			## Portreli satırlar sayfalanabilir: ilk sayfa beklenen metnin öneki olur.
			var shown_tx := String(s[1]).replace("\n", " ")
			var want_tx := String(e[1]).replace("\n", " ")
			var text_ok := shown_tx == want_tx or shown_tx.begins_with(want_tx) or want_tx.begins_with(shown_tx) \
				or shown_tx.find(want_tx.substr(0, mini(18, want_tx.length()))) >= 0
			if text_ok and String(s[0]) == sp:
				found = true
				break
		if not found:
			missing.append(e)
	check(missing.is_empty(), "displayed final lines match script in order", missing)
	check(shown.size() >= expected.size(), "line count", shown.size())


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("FINAL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var cfg := ConfigFile.new()
	if cfg.load("user://qa/settings.cfg") == OK:
		cfg.set_value("progress", "final_seen", false)
		cfg.save("user://qa/settings.cfg")
	var em := root.get_node("EndingManager")
	var gs := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var rm := root.get_node("RoomManager")
	var dm := root.get_node("DialogueManager")
	check(em.Ending.keys() == ["NONE", "PART_ONE"], "enum only NONE and PART_ONE", em.Ending.keys())
	for m in ["can_attempt_good_seal", "can_attempt_sever"]:
		check(not em.has_method(m), "removed " + m)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.5).timeout
	dm.clear()
	var keeper: Node = current_scene.get_node("Keeper")
	for i in 5:
		keeper.receive_player_strike()
	check(not keeper.is_defeated(), "Shilda not killable by strikes")
	check(not bool(gs.get_world_flag(&"keeper_defeated", false)), "no keeper_defeated flag")
	check(not em.can_begin_final(), "final locked at start")
	root.get_node("PuzzleManager").mark_solved(&"core_seal")
	gs.set_world_flag(&"seal_shard_1", true)
	gs.set_world_flag(&"seal_shard_2", true)
	check(not em.can_begin_final(), "final locked without Soul Slash")
	gs.player_progress_knowledge["ability_soul_slash"] = true
	## Gerçek oyunda çekirdeğe gelindiğinde Shilda adlıdır: son bu durumda sınanır.
	gs.set_shilda_named(true)
	check(gs.is_shilda_named(), "Shilda named for final run")
	check(dm.resolve_whisper_speaker("???", false, true) == "Shilda" and dm.resolve_whisper_speaker("Shilda", false, true) == "Shilda",
		"resolver still names Shilda's own lines")
	check(dm.resolve_whisper_speaker(UNKNOWN, false, true) == UNKNOWN, "resolver passes X hidden voice through")
	check(em.can_begin_final(), "final open with all prerequisites")
	rm.enter_room(&"core", &"default", false)
	await process_frame
	await create_timer(0.3).timeout
	check(not FS.call("final_seen"), "final_seen false before first run")
	dm.line_shown.connect(func(sp: String, tx: String) -> void: shown.append([sp, tx]))
	await em.trigger(em.Ending.PART_ONE, true)
	var r: Dictionary = FS.get("last_run")
	check(r.get("flag_order", []) == ["final_seal_broken", "x_revealed", "game_completed"], "flag order", r.get("flag_order"))
	_check_lines_in_order()
	check(bool(r.get("human", false)), "Shilda human form shown")
	check(bool(r.get("x_seen", false)), "X appeared")
	check(int(r.get("domains", 0)) == 4, "4 domain screens", r.get("domains"))
	check(bool(r.get("end_label", false)), "END OF PART I label")
	check(bool(r.get("part_label", false)), "THE ROOM REMEMBERS label")
	check(bool(r.get("part_two_teaser", false)), "Bölüm II teaser shown")
	check(bool(r.get("credits", false)), "credits shown")
	check(bool(r.get("title_requested", false)), "title requested at end")
	check(gs.has_story_flag(&"game_completed"), "game_completed flag set")
	check(FS.call("final_seen"), "final_seen persisted")
	check(not gs.has_story_flag(&"final_seen"), "final_seen not a story flag")
	check(em.current == em.Ending.NONE and em.last_ending == em.Ending.PART_ONE, "ending state reset, last kept")
	check(gate.current_layer() != gate.Layer.CUTSCENE and not gate.blocks_movement(), "input released after final")
	# Tamamlanmis kayitta kristal sessiz: final tekrar oynamaz
	rm.enter_room(&"core", &"default", false)
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	var crystal: Node = get_first_node_in_group("core_crystal")
	var seen_before: int = (gs.player_progress_knowledge["endings_seen"] as Array).size()
	var n_before := shown.size()
	crystal.on_interact(null)
	await create_timer(0.3).timeout
	check(em.current == em.Ending.NONE, "crystal inert after game_completed (no ending)")
	check(shown.size() > n_before and String(shown[n_before][1]).begins_with("Kristal sustu"),
		"crystal shows short inert line", shown.slice(n_before))
	check((gs.player_progress_knowledge["endings_seen"] as Array).size() == seen_before,
		"no replay: endings_seen unchanged")
	print("FINAL DONE failures=", failures)
	quit(1 if failures > 0 else 0)
