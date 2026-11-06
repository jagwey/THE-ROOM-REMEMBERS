extends Node2D
## Ana sahne — World / Player / Keeper / Camera / UI / Audio.


func _ready() -> void:
	GameState.mark_room_visited(&"awakening")
	GameState.set_checkpoint(Vector2(120, 280), &"awakening")
	DialogueManager.say("???", "Gözlerin açılıyor.")
	DialogueManager.say("???", "Oda seni hatırlıyor.")
	if DisplayServer.get_name() == "headless":
		call_deferred("_headless_faz5_smoke")


func _headless_faz5_smoke() -> void:
	await get_tree().create_timer(1.0).timeout
	if DialogueManager.is_open:
		await DialogueManager.dialogue_closed
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	GameState.character_current_life_knowledge["warned_hazard"] = true
	if int(GameState.player_progress_knowledge["deaths"]) < 1:
		DeathManager.request_death(&"awakening_rift")
		await DeathManager.rebirth_completed
	await get_tree().create_timer(0.3).timeout
	await EchoManager.play_echo(&"awakening_rift_echo")
	CorpseManager.rebuild_world_corpses()
	await get_tree().process_frame
	var corpses := get_tree().get_nodes_in_group("corpse")
	if corpses.size() > 0:
		var c: Node = corpses[0]
		c.global_position = Vector2(520, 300)
		if c.has_method("_persist_position"):
			c._persist_position()
	await get_tree().create_timer(0.3).timeout
	for p in get_tree().get_nodes_in_group("pressure_plate"):
		if p.has_method("_recompute"):
			p._recompute()
	# Bellek mühürü (oyuncu kodu)
	if not PuzzleManager.is_solved(&"awakening_memory_code"):
		var seal := get_tree().get_first_node_in_group("memory_seal")
		if seal and seal.has_method("on_interact"):
			seal.on_interact(null)
			if DialogueManager.is_open:
				await DialogueManager.dialogue_closed
		else:
			PuzzleManager.mark_solved(&"awakening_memory_code")
	SaveManager.save_game()
	var notes: int = (
		EchoManager.get_notes_for_section("izler").size()
		+ EchoManager.get_notes_for_section("notlar").size()
		+ EchoManager.get_notes_for_section("gunluk").size()
	)
	var echoes: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	var msg := "FAZ5_SMOKE ok echo=%s weight=%s code=%s notes=%s door=%s" % [
		str(echoes.has("awakening_rift_echo")),
		str(PuzzleManager.is_solved(&"awakening_weight")),
		str(PuzzleManager.is_solved(&"awakening_memory_code")),
		str(notes),
		str(GameState.get_world_flag(&"awakening_door_opened")),
	]
	print(msg)
	var f := FileAccess.open("user://faz5_smoke.txt", FileAccess.WRITE)
	if f:
		f.store_string(msg)
