extends Node
## Tanık odası — kısa EchoManager kayıtları (_ready).


func _ready() -> void:
	EchoManager.register_echo("witness_clock", {
		"evidence_id": "ev_witness_clock",
		"lines": [
			["Yankı", "…tik."],
			["Yankı", "Zaman burada durdu."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Saat",
			"body": "Zaman durduğunda kapı kapanmış.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_flower", {
		"evidence_id": "ev_witness_flower",
		"lines": [
			["Yankı", "Solgun kırmızı…"],
			["Yankı", "Yas, deneyden önce başlamış."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Çiçek",
			"body": "Çiçek yasını deneyden önce taşımış.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_seal", {
		"evidence_id": "ev_witness_seal",
		"lines": [
			["Yankı", "Kırmızı mühür kapanıyor."],
			["Yankı", "Koruma sonradan devreye girdi."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Mühür",
			"body": "Koruma mührü olaydan sonra devreye girmiş.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
