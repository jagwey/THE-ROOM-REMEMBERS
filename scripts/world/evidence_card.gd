extends Area2D
## Basit kanıt kartı — evidence_id ile günlüğe yazar.

@export var evidence_id: StringName = &"ev_card"
@export var title: String = "Kayıt"
@export var body: String = ""
@export var section: String = "notlar"
@export var kind: String = "evidence"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	DialogueManager.say("Sen", title)
	DialogueManager.say("Sen", body if body != "" else "…")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	var eid := String(evidence_id)
	if not ev.has(eid):
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
		EchoManager.journal_updated.emit()
		SaveManager.save_game()
