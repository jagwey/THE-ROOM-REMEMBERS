extends Area2D
## Uyanış — cep saati: durmuş saat, kanıt + günlük, bir kez uzun metin.

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
	var seen: bool = bool(GameState.player_progress_knowledge.get("pocket_watch_seen", false))
	if seen:
		DialogueManager.say("Shiren", "Akrep ve yelkovan hâlâ aynı yerde.")
		await DialogueManager.dialogue_finished
		_busy = false
		return

	DialogueManager.say("Shiren", "Camı çatlak. Akrep durmuş.")
	DialogueManager.say("Shiren", "Saniye yok — ya hep bu an, ya hiç.")
	await DialogueManager.dialogue_finished

	if not bool(GameState.player_progress_knowledge.get("pocket_watch_seen", false)):
		_add_evidence(
			"ev_awakening_watch",
			"Durmuş cep saati",
			"Vitrindeki cam çatlak; mekanizma ilerlemiyor. Zaman burada dile gelmiyor.",
			"evidence",
			"notlar",
		)
		GameState.player_progress_knowledge["pocket_watch_seen"] = true
		GameState.knowledge_changed.emit(&"player")
		SaveManager.save_game()
	_busy = false


func _add_evidence(eid: String, title: String, body: String, kind: String, section: String) -> void:
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	if ev.has(eid):
		return
	ev[eid] = {"id": eid, "discovered": true, "kind": kind, "title": title, "body": body, "section": section}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({
		"evidence_id": eid,
		"section": section,
		"title": title,
		"body": body,
		"kind": kind,
	})
	GameState.player_progress_knowledge["journal_notes"] = notes
	GameState.player_progress_knowledge["journal_unlocked"] = true
	EchoManager.journal_updated.emit()
