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
		DialogueManager.say("Noroi", "Akrep ve yelkovan hâlâ aynı yerde.")
		await DialogueManager.dialogue_finished
		_busy = false
		return

	_opening_hook()
	DialogueManager.say("Noroi", "Camı çatlak. Akrep durmuş.")
	DialogueManager.say("Noroi", "Saniye yok — ya hep bu an, ya hiç.")
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


## Açılış kancası: ilk kez, soğuk mavi kısa ekran flaşı + saat tik / kalp atışı.
func _opening_hook() -> void:
	AudioManager.play_sfx(&"clock_tick", -3.0, 1.0)
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	rect.color = Color(0.55, 0.78, 1.0, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.38, 0.06)
	tw.tween_property(rect, "color:a", 0.0, 0.45)
	tw.tween_callback(layer.queue_free)


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
