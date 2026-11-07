extends Node
## Ölüm / yeniden doğuş — karakter sıfırlanır; dünya kalır; checkpoint'e dönüş.

signal death_started(reason: StringName)
signal rebirth_completed

var is_dying: bool = false


func request_death(reason: StringName = &"unknown", full_reset: bool = false) -> void:
	if is_dying or EndingManager.current != EndingManager.Ending.NONE:
		return
	is_dying = true
	death_started.emit(reason)

	var death_pos := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player:
		death_pos = player.global_position
		if player.has_method("play_death"):
			player.play_death()

	GameState.player_progress_knowledge["deaths"] = int(GameState.player_progress_knowledge["deaths"]) + 1
	if not bool(GameState.player_progress_knowledge.get("first_death_seen", false)):
		GameState.player_progress_knowledge["first_death_seen"] = true

	# Ceset dünya hafızasına — karakter bilgisi henüz sıfırlanmadan konum alınır.
	var corpse_id: String = CorpseManager.record_corpse_at(death_pos, reason)

	GameState.reset_character_life()
	CurseManager.reset_for_new_life()
	# Karakter bu hayatı unutur; dünya bayrakları durur.
	knowledge_note_after_death(reason)

	if full_reset:
		# Yalnız özel sonlar — FAZ 4'te kullanılmaz.
		pass

	SaveManager.save_game()
	await get_tree().create_timer(0.55).timeout

	# Bekçi yas: çiçek bırakabilir (öldürmez).
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper and keeper.has_method("mourn_corpse"):
		await keeper.mourn_corpse(death_pos, corpse_id)

	await _respawn()


func knowledge_note_after_death(reason: StringName) -> void:
	# Meta katmanda ölüm nedeni izi (karakter bilmez).
	var touched: Array = GameState.world_memory_state["forbidden_touched"]
	var key := "death:%s" % String(reason)
	if not touched.has(key):
		touched.append(key)


func _respawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cp: Vector2 = GameState.get_checkpoint()
	var cp_room: StringName = GameState.character_current_life_knowledge.get("checkpoint_room", &"awakening")
	if RoomManager.has_room(cp_room):
		RoomManager.enter_room(cp_room, &"checkpoint", false)
	if player and player.has_method("respawn_at"):
		player.respawn_at(cp)
	# Karakter unutkanlığı — kısa TR satır.
	DialogueManager.clear()
	DialogueManager.say("Shiren", "…Neredeyim?")
	DialogueManager.say("Shiren", "Bir şey… unuttum.")
	if OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.05).timeout
		if DialogueManager.is_open:
			DialogueManager.clear()
	CorpseManager.rebuild_world_corpses()
	SaveManager.save_game()
	is_dying = false
	rebirth_completed.emit()
