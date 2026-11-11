class_name CreditsData
extends RefCounted
## Jenerik içeriği tek yerde: başlık ekranı "Jenerik" sayfası ve final sonrası jenerik (Task 9) bunu okur.
## Stüdyo Torimon. Tasarım kredisi Jagwey kalır (README: repo sahibi).
## Sanat/müzik için README'de ayrı bir kişi geçmediğinden o satırlar eklenmedi; icat edilmiş isim yok.

const TITLE := "THE ROOM REMEMBERS"
const TAGLINE := "Sen unutursun. Oda hatırlar."

## Her bölüm: {"head": başlık (boş olabilir), "lines": [satırlar]}.
const SECTIONS: Array = [
	{"head": "", "lines": ["Bir Torimon Studio oyunu"]},
	{"head": "Tasarım ve Kod", "lines": ["Jagwey"]},
	{"head": "Oyun Motoru", "lines": ["Godot Engine 4.7"]},
	{"head": "Teşekkürler", "lines": ["Oynadığın için."]},
	{"head": "", "lines": ["© TORIMON"]},
]


## Düz metin (kaydırmalı sayfada ve testlerde kullanılır).
static func as_text() -> String:
	var out: PackedStringArray = [TITLE, TAGLINE, ""]
	for s in SECTIONS:
		if String(s["head"]) != "":
			out.append(String(s["head"]).to_upper())
		for l in s["lines"]:
			out.append(String(l))
		out.append("")
	return "\n".join(out).strip_edges()
