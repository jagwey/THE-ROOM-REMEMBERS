extends "res://scripts/world/sequence_shrine.gd"
## S.'nin Odası son rafı: beş Kırık Anı sayfası yıl sırasıyla çevrilir.
## Çözüm: epilog kaydı (günlük) + Shilda/Noroi "Ortak amaç" konuşması (bir kez) + kalıcı bayrak.

const FLAG := "s_room_epilogue"

const EXCHANGE := [
	["Shilda", "Bu oda benim insan zamanımdı. Burada defter tutardım."],
	["Noroi", "Duvardaki her sayfa senin elinden geçmiş."],
	["Shilda", "Lanet bu defterin yarım kaldığı yerde başladı, Noroi."],
	["Noroi", "O zaman yarımı tamamlarız. Ben kaydı sürdürürüm."],
	["Shilda", "Ortak bir işimiz var: bu odayı unutuluştan çıkarmak."],
	["Noroi", "Birlikte. Bölüm bitmedi; kapılar hâlâ bizi bekliyor."],
]


static func done() -> bool:
	return bool(GameState.player_progress_knowledge.get(FLAG, false))


func _add_evidence() -> void:
	super._add_evidence()
	if done():
		return
	GameState.player_progress_knowledge[FLAG] = true
	for e in EXCHANGE:
		var who: String = String(e[0])
		if who == "Shilda":
			who = GameState.keeper_speaker_name()
		DialogueManager.say(who, String(e[1]))
	SaveManager.save_game()
