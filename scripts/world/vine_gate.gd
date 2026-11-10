extends StaticBody2D
## Bulmaca / bayrak ile açılan engel (sarmaşık geçidi).

@export var puzzle_id: StringName = &"decay_vine_shortcut"
@export var flag: StringName = &"decay_vine_open"

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	GameState.world_flag_changed.connect(_on_flag)
	PuzzleManager.puzzle_solved.connect(_on_puzzle)
	_apply(_is_open())


func _is_open() -> bool:
	return bool(GameState.get_world_flag(flag, false)) or PuzzleManager.is_solved(puzzle_id)


func _on_flag(f: StringName, value: Variant) -> void:
	if f == flag:
		if bool(value):
			_pulse_open()
		_apply(bool(value))


func _on_puzzle(puzzle: StringName) -> void:
	if puzzle == puzzle_id:
		_pulse_open()
		_apply(true)


func _apply(open: bool) -> void:
	if shape:
		shape.set_deferred("disabled", open)
	visible = not open
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0.0) if open else Color(0.55, 0.7, 0.45, 1.0)


func receive_sword_hit(_from: Node, _dir: float, _combo: int) -> void:
	if _is_open():
		return
	PuzzleManager.mark_solved(puzzle_id)
	GameState.set_world_flag(flag, true)
	GameState.set_world_flag(&"decay_vine_cleared", true)
	SaveManager.save_game()


func _pulse_open() -> void:
	if not is_visible_in_tree():
		return
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("focus_pulse"):
		cam.focus_pulse(global_position + Vector2(0, -50))
