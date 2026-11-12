extends Node
## Tanık odası — kısa EchoManager kayıtları (_ready).


func _ready() -> void:
	EchoManager.register_echo("witness_clock", {
		"evidence_id": "ev_witness_clock",
		"lines": [
			["Yankı", "…tik. 1927. Boyut kuruldu."],
			["Yankı", "Zaman burada durdu. Kapı o an hâlâ açıktı."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Saat",
			"body": "1927 damgası. Zaman durduğunda kapı henüz kapanmamıştı.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_flower", {
		"evidence_id": "ev_witness_flower",
		"lines": [
			["Yankı", "Solgun kırmızı bir çiçek. Yas deneyden önce gelmiş."],
			["Yankı", "Biri 1995'e kadar çiçek bırakıp bekledi."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Çiçek",
			"body": "Çiçek yasını deneyden önce taşımış; 1995'e kadar beklenmiş.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
	EchoManager.register_echo("witness_seal", {
		"evidence_id": "ev_witness_seal",
		"lines": [
			["Yankı", "Kırmızı mühür kapanıyor. İki, beş, bir."],
			["Yankı", "Koruma sonra devreye girdi, felaketi içeride tuttu."],
		],
		"journal": {
			"section": "izler",
			"title": "Tanık: Mühür",
			"body": "Koruma mührü olaydan sonra devreye girmiş. Kod: 251. Kronoloji: 1927 kuruluş → deney → 1995 giriş.",
			"kind": "evidence",
		},
		"memory_code": "",
	})
