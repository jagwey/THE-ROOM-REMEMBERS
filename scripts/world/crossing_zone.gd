extends Area2D
## Oyuncu ilk kez girince puzzle_id çözülür (ör. boşluğu aşma). Kaydedilir; öldürmez.

@export var puzzle_id: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## player
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if puzzle_id == &"" or not body.is_in_group("player"):
		return
	if PuzzleManager.is_solved(puzzle_id):
		return
	PuzzleManager.mark_solved(puzzle_id)
