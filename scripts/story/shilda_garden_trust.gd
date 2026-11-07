extends Area2D
## Bahçe — Shilda (Bekçi) koruma döngüsü; güven bayrağı.

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


## Etkileşim etiketi: Shilda adını söyleyene dek "???".
func get_interact_label() -> String:
	return "Shilda" if GameState.is_shilda_named() else "???"


func on_interact(_by: Node) -> void:
	if _busy:
		return
	if bool(GameState.player_progress_knowledge.get("shilda_garden_beat", false)):
		DialogueManager.say("Shilda", "Burada güvendesin.")
		return
	_busy = true
	DialogueManager.say("Shilda", "Bu çürüyen kökler… seni de çeker. Dur yanımda.")
	DialogueManager.say("Noroi", "…Tamam. Senden yana duruyorum.")
	DialogueManager.say("Shilda", "O zaman adını mühürlemeden gitme; hatırla.")
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		GameState.player_progress_knowledge["shilda_garden_beat"] = true
		GameState.player_progress_knowledge["trusted_keeper"] = true
		SaveManager.save_game()
	_busy = false
