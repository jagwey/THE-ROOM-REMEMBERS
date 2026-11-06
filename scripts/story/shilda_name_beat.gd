extends Area2D
## Uyanış — Shilda isim beat'i (bir kez uzun; tekrar kısa).

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if _busy:
		return
	_busy = true
	var done_partial: bool = bool(GameState.player_progress_knowledge.get("shilda_named_partial", false))
	if not done_partial:
		DialogueManager.say("Shilda", "Shiren… yine mi?")
		DialogueManager.say("Shiren", "Beni… nasıl ismimle çağırdın?")
		DialogueManager.say("Shilda", "Bu oda seni tanıyor. Ben sadece hatırlatıyorum.")
		await DialogueManager.dialogue_finished
		GameState.player_progress_knowledge["awakening_mystery_seen"] = true
		GameState.player_progress_knowledge["shilda_named_partial"] = true
		GameState.player_progress_knowledge["seen_keeper"] = true
		GameState.knowledge_changed.emit(&"player")
		SaveManager.save_game()
	else:
		DialogueManager.say("Shilda", "İlk uyandığını sanıyorsun. Devam et.")
		await DialogueManager.dialogue_finished
	_busy = false
