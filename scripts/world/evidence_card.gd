extends Area2D
## Katalog karti — GameState.player_progress_knowledge["evidence"] içine evidence_id yazar.

@export var evidence_id: StringName = &"ev_catalog_sample"
@export var title: String = "Kayit"
@export var body: String = "..."
@export var kind: String = "evidence"
@export var section: String = "notlar"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	var key := String(evidence_id)
	if ev.has(key):
		DialogueManager.say("Sen", "Bu karti zaten okudum.")
		return
	ev[key] = {
		"id": key,
		"discovered": true,
		"kind": kind,
		"title": title,
		"body": body,
		"section": section,
	}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({
		"evidence_id": key,
		"section": section,
		"title": title,
		"body": body,
		"kind": kind,
	})
	GameState.player_progress_knowledge["journal_notes"] = notes
	EchoManager.journal_updated.emit()
	DialogueManager.say("Kayit", title + " — " + body)
	SaveManager.save_game()
