extends Node
## Tanık odası — kısa EchoManager kayıtları (_ready).
## Yankılar yalnız ipucu verir: saat, çiçek ve mühür birer rakam söyler (2, 5, 1).


func _ready() -> void:
	if not EchoManager.echo_finished.is_connected(_on_echo_finished):
		EchoManager.echo_finished.connect(_on_echo_finished)
	EchoManager.register_echo("witness_clock", {
		"evidence_id": "ev_witness_clock",
		"lines": [
			["Yankı", "Gece iki kez vurup durdum."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Saat",
			"body": "Saatin sözü: iki.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_flower", {
		"evidence_id": "ev_witness_flower",
		"lines": [
			["Yankı", "Solgun çiçeğin beş yaprağı kaldı."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Çiçek",
			"body": "Çiçeğin sözü: beş.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_seal", {
		"evidence_id": "ev_witness_seal",
		"lines": [
			["Yankı", "Kırmızı mühür kapanırken bir kez vurdu."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Mühür",
			"body": "Mührün sözü: bir.",
			"kind": "evidence",
		},
		"memory_code": "",
	})


## Üç tanık da dinlenince kod "öğrenilmiş" sayılır; doğru giriş yabancı anı tepkisi vermez.
func _on_echo_finished(_echo_id: StringName) -> void:
	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})
	if ev.has("ev_witness_clock") and ev.has("ev_witness_flower") and ev.has("ev_witness_seal"):
		GameState.learn_memory_code("library_witness", "2" + "5" + "1")
