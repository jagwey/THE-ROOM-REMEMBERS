extends Area2D
## Bahçe → Kütüphane. Güven + çiçek kanıtı gerekir.

@export var puzzle_id: StringName = &"decay_archive_key"
@export var target_room_id: StringName = &"library_hall"
@export var target_spawn_id: StringName = &"from_garden"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	_refresh_visual()
	PuzzleManager.puzzle_solved.connect(func(_p): _refresh_visual())


func _refresh_visual() -> void:
	if has_node("Sprite2D"):
		var open := PuzzleManager.is_solved(puzzle_id)
		$Sprite2D.texture = load("res://assets/props/door_open.png" if open else "res://assets/props/door_closed.png")
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func on_interact(_by: Node) -> void:
	if PuzzleManager.is_solved(puzzle_id):
		RoomManager.enter_room(target_room_id, target_spawn_id)
		return
	var trusted := bool(GameState.player_progress_knowledge.get("trusted_keeper", false))
	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})
	var has_flower := ev.has("ev_garden_shilda")
	if trusted and has_flower:
		DialogueManager.say("Bekçi", "Arşiv… seni bekliyor.")
		DialogueManager.say("Sen", "Kapı… açılıyor.")
		var ok: bool = await DialogueManager.dialogue_finished
		if not ok:
			return
		PuzzleManager.mark_solved(puzzle_id)
		GameState.set_world_flag(&"archive_unlocked", true)
		SaveManager.save_game()
		_refresh_visual()
		RoomManager.enter_room(target_room_id, target_spawn_id)
	elif not has_flower:
		DialogueManager.say("Sen", "Kilitte bir çiçek izi var.")
		DialogueManager.say("???", "Önce bahçeyi dinle.")
	else:
		DialogueManager.say("Bekçi", "Henüz değil. Bana… bir kez daha bak.")
