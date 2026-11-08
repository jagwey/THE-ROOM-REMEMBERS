extends StaticBody2D
## Basınç plakası / bayrak ile açılan engel.

@export var open_flag: StringName = &"awakening_door_opened"
## Hangi bulmaca çözülünce açılır (boşsa sadece bayrak).
@export var puzzle_listen: StringName = &"awakening_weight"
## true ise yalnızca puzzle ile açılır (bayrak/legacy tek başına yetmez).
@export var ignore_world_flag: bool = false
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	GameState.world_flag_changed.connect(_on_flag)
	PuzzleManager.puzzle_solved.connect(_on_puzzle)
	_apply(_is_open())


func _is_open() -> bool:
	if puzzle_listen != &"" and PuzzleManager.is_solved(puzzle_listen):
		return true
	if ignore_world_flag:
		return false
	if open_flag != &"" and bool(GameState.get_world_flag(open_flag, false)):
		return true
	return false


func _on_flag(f: StringName, value: Variant) -> void:
	if f == open_flag:
		if bool(value):
			_pulse_open()
		_apply(bool(value))


func _on_puzzle(puzzle_id: StringName) -> void:
	if puzzle_id == puzzle_listen:
		_pulse_open()
		_apply(true)


func _apply(open: bool) -> void:
	collision_layer = 0 if open else 1
	if has_meta("room_saved_layer"):
		set_meta("room_saved_layer", 0 if open else 1)
	if shape:
		shape.set_deferred("disabled", open)
	visible = not open
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0.0) if open else Color(1, 1, 1, 1)


func _pulse_open() -> void:
	if not is_visible_in_tree():
		return
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("focus_pulse"):
		cam.focus_pulse(global_position + Vector2(0, -50))
