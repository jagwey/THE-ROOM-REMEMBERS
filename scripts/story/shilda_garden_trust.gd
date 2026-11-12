extends Area2D
## Bahçe — Shilda (Bekçi) koruma döngüsü; güven bayrağı.

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_interact_label() -> String:
	return GameState.keeper_speaker_name()


func on_interact(_by: Node) -> void:
	if _busy:
		return
	_busy = true
	var keeper_name := GameState.keeper_speaker_name()
	var trusted: bool = GameState.is_shilda_trusted()

	if bool(GameState.player_progress_knowledge.get("shilda_garden_beat", false)):
		if trusted:
			DialogueManager.say(keeper_name, "Burada güvendesin. Çiçekler fısıldıyor.")
		else:
			DialogueManager.say(keeper_name, "Adımlarına dikkat et. Kökler hâlâ huzursuz.")
		await DialogueManager.dialogue_finished
		_busy = false
		return

	# İlk derin diyalog — oyuncunun eylemlerini tartar
	DialogueManager.say(keeper_name, "Kökler seni de çeker. Yanımda dur.")
	if trusted:
		DialogueManager.say("Noroi", "Seni dinliyorum, çiçeklere zarar vermedim.")
		DialogueManager.say(keeper_name, "Fark ettim, aceleci değilsin. Sana inanmak istiyorum.")
		GameState.player_progress_knowledge["trusted_keeper"] = true
	else:
		DialogueManager.say("Noroi", "Buradan nasıl çıkarım?")
		DialogueManager.say(keeper_name, "Acele ediyorsun. Burada güven adım adım kazanılır.")

	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		GameState.player_progress_knowledge["shilda_garden_beat"] = true
		SaveManager.save_game()
	_busy = false
