extends Area2D
## Sarmaşık kısayolu — tek seferlik çözüm.

@export var puzzle_id: StringName = &"decay_vine_shortcut"

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_node_or_null("Sprite2D") == null:
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		spr.texture = load("res://assets/props/seal.png")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(0.45, 0.45)
		spr.modulate = Color(0.55, 0.78, 0.48, 0.9)
		add_child(spr)


func on_interact(_by: Node) -> void:
	if _busy:
		return
	if PuzzleManager.is_solved(puzzle_id):
		DialogueManager.say("Noroi", "Sarmaşık zaten çekilmiş.")
		return
	_busy = true
	DialogueManager.say("Noroi", "Düğümü çözüyorum.")
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		PuzzleManager.mark_solved(puzzle_id)
		GameState.set_world_flag(&"decay_vine_open", true)
		GameState.set_world_flag(&"decay_vine_cleared", true)
		SaveManager.save_game()
		DialogueManager.say("Noroi", "Sarmaşık çekildi.")
	_busy = false
