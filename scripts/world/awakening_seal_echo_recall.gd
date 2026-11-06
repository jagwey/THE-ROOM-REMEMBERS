extends Area2D
## Mühür odası nişi — geçitteki yankı kodunu hatırlatır (yedek, mühür UI'sına girmeden).

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if PuzzleManager.is_solved(&"awakening_memory_code"):
		DialogueManager.say("Shiren", "Mühür zaten çözüldü.")
		return
	var codes: Dictionary = GameState.player_progress_knowledge.get("memory_codes", {})
	var known := String(codes.get("awakening", ""))
	if known != "":
		DialogueManager.say("Shiren", "Yarıktaki yankı: üç, bir, dört. Mührü bununla açmalıyım.")
		return
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	if seen.has("awakening_rift_echo"):
		codes["awakening"] = "314"
		GameState.player_progress_knowledge["memory_codes"] = codes
		SaveManager.save_game()
		DialogueManager.say("Shiren", "Yankıyı yeniden duyuyorum: 3 — 1 — 4. Bunu mühre yazmalıyım.")
		return
	DialogueManager.say("Shiren", "Önce geçitteki taş yankısını dinlemeliyim.")
