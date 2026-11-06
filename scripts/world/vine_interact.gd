extends Area2D
## Sarmaşık kesimi — kalıcı kısa yol.

@export var puzzle_id: StringName = &"decay_vine_shortcut"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if PuzzleManager.is_solved(puzzle_id):
		visible = false


func on_interact(_by: Node) -> void:
	if PuzzleManager.is_solved(puzzle_id):
		DialogueManager.say("Sen", "Geçit açık.")
		return
	DialogueManager.say("Sen", "Sarmaşık… burayı tıkıyor.")
	DialogueManager.say("Sen", "Kesersem yol kalır.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(puzzle_id)
	GameState.set_world_flag(&"decay_vine_cleared", true)
	visible = false
	SaveManager.save_game()
	DialogueManager.say("Sen", "Kısa yol açıldı.")
