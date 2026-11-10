extends Area2D
## Mühür odası nişi — geçitteki yankı kodunu hatırlatır (yedek, mühür UI'sına girmeden).

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if PuzzleManager.is_solved(&"awakening_memory_code"):
		DialogueManager.say("Noroi", "Mühür zaten çözüldü.")
		return
	## Aynı hayatta duyulan yankı ile önceki hayattan kalan sezgi ayrılır (code_seal_base ile aynı kural).
	match GameState.memory_code_reaction("awakening"):
		&"same_life":
			DialogueManager.say("Noroi", "Yarıktaki yankı: üç, bir, dört. Mührü bununla açmalıyım.")
			return
		&"past_life":
			DialogueManager.say("Noroi", "Oyuğa bakınca zihnimde üç hane beliriyor: 3 — 1 — 4.")
			DialogueManager.say("Noroi", "Bunu nereden biliyorum? Hiç duymadım… ama ellerim biliyor.")
			return
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	if seen.has("awakening_rift_echo"):
		GameState.learn_memory_code("awakening", "314")
		SaveManager.save_game()
		DialogueManager.say("Noroi", "Yankıyı yeniden duyuyorum: 3 — 1 — 4. Bunu mühre yazmalıyım.")
		return
	DialogueManager.say("Noroi", "Önce geçitteki taş yankısını dinlemeliyim.")
