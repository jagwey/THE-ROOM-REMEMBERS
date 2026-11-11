extends Area2D
## Bahçe çiçeği — kod ipucu + EchoManager katalog kaydı.

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	EchoManager.register_echo("decay_archive_hint", {
		"evidence_id": "ev_decay_archive_hint",
		"lines": [
			["Yankı", "Bahçe sayıları: yedi, iki, dokuz."],
			["Yankı", "Arşiv mührü bunu ister."],
		],
		"journal": {
			"section": "izler",
			"title": "Bahçe sayıları",
			"body": "Çiçeklerin arasında 7 — 2 — 9. Arşiv kapısı için.",
			"kind": "evidence",
		},
		"memory_code": "729",
	})


func on_interact(_by: Node) -> void:
	if _busy or DialogueManager.is_open:
		return
	_busy = true
	if not GameState.is_shilda_named():
		var keeper := get_tree().get_first_node_in_group("keeper")
		if keeper and keeper.has_method("_run_naming_scene"):
			await keeper._run_naming_scene()
	DialogueManager.say("Noroi", "Kırmızı yapraklar… kurumuş. Yerde bir desen var: 7, 2, 9.")
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		GameState.learn_memory_code("decay_archive", "729")
	_busy = false
