extends StaticBody2D
## Basınç plakası / bayrak ile açılan engel.

@export var flag: StringName = &"awakening_door_opened"
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	GameState.world_flag_changed.connect(_on_flag)
	PuzzleManager.puzzle_solved.connect(_on_puzzle)
	_apply(bool(GameState.get_world_flag(flag, false)))


func _on_flag(f: StringName, value: Variant) -> void:
	if f == flag:
		_apply(bool(value))


func _on_puzzle(puzzle_id: StringName) -> void:
	if puzzle_id == &"awakening_weight":
		_apply(true)


func _apply(open: bool) -> void:
	if shape:
		shape.set_deferred("disabled", open)
	visible = not open
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0.0) if open else Color(1, 1, 1, 1)
