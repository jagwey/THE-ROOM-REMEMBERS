extends Node
## Tanık odası — kısa EchoManager kayıtları (_ready).
## Yankılar yalnız ipucu verir: saat saatleri, çiçek ve mühür birer rakam söyler.


func _ready() -> void:
	EchoManager.register_echo("witness_clock", {
		"evidence_id": "ev_witness_clock",
		"lines": [
			["Yankı", "1927'de gece üçte durdum. Sonra dokuzda, en son altıda."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Saat",
			"body": "Saat üç, dokuz ve altıda durmuş. Kadranlar bunu ister.",
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
