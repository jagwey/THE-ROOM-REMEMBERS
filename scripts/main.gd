extends Node2D
## Ana sahne — World / Player / Keeper / Camera / UI / Audio.


func _ready() -> void:
	GameState.mark_room_visited(&"awakening")
	GameState.set_checkpoint(Vector2(120, 280), &"awakening")
	DialogueManager.say("???", "Gözlerin açılıyor.")
	DialogueManager.say("???", "Oda seni hatırlıyor.")
	if DisplayServer.get_name() == "headless":
		call_deferred("_headless_faz4_smoke")


func _headless_faz4_smoke() -> void:
	## Gizem sonrası tek öğretici ölüm yolunu doğrula (Bekçi öldürmez).
	await get_tree().create_timer(1.2).timeout
	if DialogueManager.is_open:
		await DialogueManager.dialogue_closed
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	GameState.character_current_life_knowledge["warned_hazard"] = true
	await get_tree().create_timer(0.3).timeout
	if not DeathManager.is_dying:
		DeathManager.request_death(&"awakening_rift")
	await DeathManager.rebirth_completed
	# Dünya bayrağı + ceset kalıcılığı
	GameState.set_world_flag(&"awakening_trap_sprung", true)
	SaveManager.save_game()
	var msg := "FAZ4_SMOKE ok deaths=%s corpses=%s flowers=%s trap=%s" % [
		str(GameState.player_progress_knowledge["deaths"]),
		str(CorpseManager.get_corpses().size()),
		str(GameState.world_memory_state["flowers_left"]),
		str(GameState.get_world_flag(&"awakening_trap_sprung")),
	]
	print(msg)
	var f := FileAccess.open("user://faz4_smoke.txt", FileAccess.WRITE)
	if f:
		f.store_string(msg)
