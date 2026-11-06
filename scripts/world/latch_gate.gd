extends StaticBody2D
## Kalıcı açılan geçit — puzzle_id çözülünce collider kapanır.

@export var puzzle_id: StringName = &"decay_vine_shortcut"
@export var open_flag: StringName = &""


func _ready() -> void:
	add_to_group("latch_gate")
	collision_layer = 1
	collision_mask = 0
	PuzzleManager.puzzle_solved.connect(_on_solved)
	_refresh()


func _on_solved(pid: StringName) -> void:
	if pid == puzzle_id:
		_refresh()


func _refresh() -> void:
	var open := PuzzleManager.is_solved(puzzle_id)
	if open_flag != &"" and bool(GameState.get_world_flag(open_flag, false)):
		open = true
	visible = not open
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.disabled = open
