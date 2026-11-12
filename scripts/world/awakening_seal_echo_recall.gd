extends Area2D
## Mühür odası nişi — geçitteki yankı kodunu hatırlatır (yedek, mühür UI'sına girmeden).

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if PuzzleManager.is_solved(&"awakening_memory_code"):
		DialogueManager.say("Noroi", "Mühür zaten açık.")
		return
	## Aynı hayatta duyulan yankı ile önceki hayattan kalan sezgi ayrılır (code_seal_base ile aynı kural).
	match GameState.memory_code_reaction("awakening"):
		&"same_life":
			DialogueManager.say("Noroi", "Yarıktaki yankı üç, bir, dört dedi; mührü bununla açacağım.")
			return
		&"past_life":
			DialogueManager.say("Noroi", "Oyuğa bakınca aklımda üç hane beliriyor: 3 — 1 — 4.")
			DialogueManager.say("Noroi", "Bunu hiç duymadım, ama ellerim biliyor.")
			return
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	if seen.has("awakening_rift_echo"):
		GameState.learn_memory_code("awakening", "314")
		SaveManager.save_game()
		DialogueManager.say("Noroi", "Yankıyı yeniden duydum: 3 — 1 — 4, mühre bunu yazacağım.")
		return
	DialogueManager.say("Noroi", "Önce geçitteki taşın yankısını dinlemeliyim.")
