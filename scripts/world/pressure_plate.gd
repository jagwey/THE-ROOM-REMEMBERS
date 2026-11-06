extends Area2D
## Ceset ağırlığıyla basılan plaka — kapı/yolu açar (mobil: cesedi it).

signal pressed_changed(is_pressed: bool)

@export var puzzle_id: StringName = &"awakening_weight"
@export var required_weight: int = 1
@export var accept_player: bool = false

var _pressed: bool = false


func _ready() -> void:
	add_to_group("pressure_plate")
	collision_layer = 0
	collision_mask = 1 ## corpses on world layer
	if accept_player:
		collision_mask = 1 | 2
	monitoring = true
	body_entered.connect(func(_b): _recompute())
	body_exited.connect(func(_b): _recompute())
	if has_node("Sprite2D"):
		$Sprite2D.texture = load("res://assets/props/pressure_plate.png")
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Dünya bayrağı zaten açıksa basılı göster
	if PuzzleManager.is_solved(puzzle_id) or bool(GameState.get_world_flag(&"awakening_door_opened", false)):
		_set_pressed(true, false)


func _recompute() -> void:
	var total := 0
	for b in get_overlapping_bodies():
		if b.is_in_group("corpse") and b.has_method("get_weight"):
			total += int(b.get_weight())
		elif accept_player and b.is_in_group("player"):
			total += 1
	_set_pressed(total >= required_weight, true)


func _set_pressed(value: bool, emit_solve: bool) -> void:
	if _pressed == value:
		return
	_pressed = value
	modulate = Color(1.2, 0.7, 0.75, 1.0) if _pressed else Color.WHITE
	pressed_changed.emit(_pressed)
	if _pressed and emit_solve:
		PuzzleManager.mark_solved(puzzle_id)
		GameState.set_world_flag(&"awakening_door_opened", true)
		DialogueManager.say("???", "Bir şey… açıldı.")
		SaveManager.save_game()
