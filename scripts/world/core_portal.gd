extends Area2D
## Açılan kapı → Çekirdek odası (Main üzerinden sahne içi geçiş).


func _ready() -> void:
	add_to_group("core_portal")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if not bool(GameState.get_world_flag(&"awakening_door_opened", false)):
		DialogueManager.say("Sen", "Kapı kapalı.")
		return
	DialogueManager.say("Sen", "İçeri… giriyorum.")
	await DialogueManager.dialogue_closed
	var main := get_tree().current_scene
	if main and main.has_method("enter_core"):
		main.enter_core()
	else:
		GameState.mark_room_visited(&"core")
		get_tree().change_scene_to_file("res://scenes/rooms/core.tscn")
