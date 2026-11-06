extends Node
## Sonlar — kötü: Bekçi'ye saldırmak; iyi: güven + hazırlık + Çekirdek mühür.

signal ending_reached(ending_id: StringName)
signal epilogue_finished

enum Ending { NONE, BAD_KILL_KEEPER, GOOD_TRUST_SEAL }

var current: Ending = Ending.NONE
var _locked: bool = false

const EPILOGUES := {
	"bad_kill_keeper": {
		"title": "Kötü Son",
		"lines": [
			"Bekçi yere düştü. Çiçekler soldu.",
			"Oda seni hâlâ hatırlıyor.",
			"Döngü… yeniden başlıyor.",
			"Sen unutacaksın. O unutmayacak.",
		],
	},
	"good_trust_seal": {
		"title": "İyi Son",
		"lines": [
			"Çekirdek mühürlendi. Kırmızı ışık söndü.",
			"Bekçi… artık yalnız değil.",
			"Sen hâlâ bazı şeyleri unutuyorsun.",
			"Ama bu kez, oda da biraz unutuyor.",
		],
	},
}


func can_attempt_good_seal() -> bool:
	## Hazırlık şart — sadece konuşmak yetmez.
	var weight := PuzzleManager.is_solved(&"awakening_weight")
	var code := PuzzleManager.is_solved(&"awakening_memory_code")
	var echo := bool(GameState.player_progress_knowledge.get("echoes_seen", []).size() > 0)
	var trusted := bool(GameState.player_progress_knowledge.get("trusted_keeper", false))
	return weight and code and echo and trusted


func prep_status() -> Dictionary:
	return {
		"weight": PuzzleManager.is_solved(&"awakening_weight"),
		"code": PuzzleManager.is_solved(&"awakening_memory_code"),
		"echo": bool(GameState.player_progress_knowledge.get("echoes_seen", []).size() > 0),
		"trusted": bool(GameState.player_progress_knowledge.get("trusted_keeper", false)),
	}


func reset_for_smoke() -> void:
	## Headless: iki yolu ardışık doğrulamak için.
	_locked = false
	current = Ending.NONE


func trigger(ending: Ending) -> void:
	if _locked or ending == Ending.NONE:
		return
	_locked = true
	current = ending
	var id: StringName
	match ending:
		Ending.BAD_KILL_KEEPER:
			id = &"bad_kill_keeper"
		Ending.GOOD_TRUST_SEAL:
			id = &"good_trust_seal"
		_:
			id = &"unknown"
	var seen: Array = GameState.player_progress_knowledge["endings_seen"]
	if not seen.has(String(id)):
		seen.append(String(id))
	GameState.set_world_flag(StringName("ending_%s" % String(id)), true)
	SaveManager.save_game()
	ending_reached.emit(id)
	await _show_epilogue(String(id))
	epilogue_finished.emit()


func _show_epilogue(id: String) -> void:
	var ui := get_tree().get_first_node_in_group("ending_ui")
	var data: Dictionary = EPILOGUES.get(id, {"title": "Son", "lines": ["…"]})
	if ui and ui.has_method("play_epilogue"):
		await ui.play_epilogue(String(data.get("title", "Son")), data.get("lines", []))
	else:
		DialogueManager.clear()
		DialogueManager.say(String(data.get("title", "Son")), "…")
		for line in data.get("lines", []):
			DialogueManager.say("…", String(line))
		await DialogueManager.dialogue_closed
