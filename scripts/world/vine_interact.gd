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
		DialogueManager.say("Noroi", "Geçit açık.")
		return
	DialogueManager.say("Noroi", "Sarmaşık… burayı tıkıyor.")
	DialogueManager.say("Noroi", "Kesersem yol kalır. Kol da aynı düğümü çözer.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_open_vines()


func receive_sword_hit(_from: Node, _dir: float, _combo: int) -> void:
	if PuzzleManager.is_solved(puzzle_id):
		return
	_open_vines()


func _open_vines() -> void:
	if PuzzleManager.is_solved(puzzle_id):
		return
	PuzzleManager.mark_solved(puzzle_id)
	GameState.set_world_flag(&"decay_vine_cleared", true)
	GameState.set_world_flag(&"decay_vine_open", true)
	visible = false
	SaveManager.save_game()
	DialogueManager.say("Noroi", "Kısa yol açıldı.")
