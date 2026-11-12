extends Area2D
## Bahçe çiçeği — kod ipucu + EchoManager katalog kaydı.

var _busy: bool = false


func _ready() -> void:
	PuzzleManager.puzzle_solved.connect(_on_puzzle_solved)
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	EchoManager.register_echo("decay_archive_hint", {
		"evidence_id": "ev_decay_archive_hint",
		"lines": [
			["Yankı", "Taç yapraklar ışıkta sayılıyor."],
			["Yankı", "Çiçekli bedenin ışığında yaprakları say."],
		],
		"journal": {
			"section": "izler",
			"title": "Bahçe yaprakları",
			"body": "Taç yapraklar yalnız çiçekli bedenin ışığında okunur; sırayla aç.",
			"kind": "evidence",
		},
	})


func on_interact(_by: Node) -> void:
	if _busy or DialogueManager.is_open:
		return
	_busy = true
	if not GameState.is_shilda_named():
		var keeper := get_tree().get_first_node_in_group("keeper")
		if keeper and keeper.has_method("_run_naming_scene"):
			await keeper._run_naming_scene()
	DialogueManager.say("Noroi", "Kurumuş kırmızı yapraklar; sayıları ancak ışıkta okunur.")
	await DialogueManager.dialogue_finished
	_busy = false


## Çiçek dizisi çözülünce eski arşiv-anahtarı yan etkileri: anahtar çözülür (kapı bayrağı) ve 729 öğrenilir.
func _on_puzzle_solved(id: StringName) -> void:
	if id != &"decay_garden_bloom":
		return
	GameState.learn_memory_code("decay_archive", "729")
	PuzzleManager.mark_solved(&"decay_archive_key")
