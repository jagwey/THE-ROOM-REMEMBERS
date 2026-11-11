extends Area2D
## Oyuncu bölgeye ilk kez girince bulmacayı çözer (yol ödülü). Engel değildir.

@export var puzzle_id: StringName = &"reached"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 80)
		cs.shape = rect
		cs.position = Vector2(0, -28)
		add_child(cs)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	if puzzle_id == &"" or PuzzleManager.is_solved(puzzle_id):
		return
	PuzzleManager.mark_solved(puzzle_id)
