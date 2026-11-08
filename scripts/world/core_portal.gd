extends Area2D
## Eski çekirdek atlama — artık Kırık Geçit'e yönlendir (erken final yok).


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	## Kapı görsel olarak duruyor; asıl rota PassagePortal / mühür eşiği.
	if PuzzleManager.is_solved(&"awakening_memory_code") and PuzzleManager.is_solved(&"mirrors_unbroken"):
		DialogueManager.say("Noroi", "Çekirdek yolu… açık.")
		var ok: bool = await DialogueManager.dialogue_finished
		if ok:
			RoomManager.enter_room(&"core_threshold", &"from_mirrors")
		return
	DialogueManager.say("Noroi", "Kapı… henüz oraya gitmiyor.")
	DialogueManager.say("", "Önce geçidi ve mühürü dinle.")
	await DialogueManager.dialogue_finished
