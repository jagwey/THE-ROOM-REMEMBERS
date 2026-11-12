extends StaticBody2D
## Sarmaşık geçidi: yakın çiçekli ceset (has_flower) onu yakar; eski kayıt/kol de açar.
## Kılıç artık işe yaramaz: sarmaşık yalnız çiçekle yanar.

## Eski kısayol bulmacası (kol / eski kayıtlar): çözülmüşse geçit açık.
@export var puzzle_id: StringName = &"decay_vine_shortcut"
@export var flag: StringName = &"decay_vine_open"
## Çiçekli cesetle çözülen yeni bulmaca.
@export var burn_puzzle: StringName = &"decay_vines"
## Çiçekli ceset bu yatay mesafe içindeyse sarmaşık yanar.
@export var burn_radius: float = 64.0
@export var room_id: StringName = &"decay_vines"

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var _hint_cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	GameState.world_flag_changed.connect(_on_flag)
	PuzzleManager.puzzle_solved.connect(_on_puzzle)
	CorpseManager.corpses_changed.connect(_on_corpses_changed)
	_apply(_is_open())
	call_deferred("_check_burn")


func _is_open() -> bool:
	return (
		bool(GameState.get_world_flag(flag, false))
		or PuzzleManager.is_solved(puzzle_id)
		or PuzzleManager.is_solved(burn_puzzle)
	)


func _on_flag(f: StringName, value: Variant) -> void:
	if f == flag:
		if bool(value):
			_pulse_open()
		_apply(bool(value) or _is_open())


func _on_puzzle(puzzle: StringName) -> void:
	if puzzle == puzzle_id or puzzle == burn_puzzle:
		_pulse_open()
		_apply(true)


func _on_corpses_changed(_count: int) -> void:
	_check_burn()


## Gate'e ≤ burn_radius yakın, çiçek taşıyan bir ceset var mı?
func _flower_corpse_near() -> bool:
	var corpses: Array = GameState.world_memory_state.get("corpses", [])
	for c in corpses:
		if not (c is Dictionary):
			continue
		if String((c as Dictionary).get("room", "")) != String(room_id):
			continue
		if not bool((c as Dictionary).get("has_flower", false)):
			continue
		var p: Dictionary = (c as Dictionary).get("position", {})
		if absf(float(p.get("x", -9999.0)) - global_position.x) <= burn_radius:
			return true
	return false


func _check_burn() -> void:
	if not is_inside_tree() or PuzzleManager.is_solved(burn_puzzle):
		return
	if _flower_corpse_near():
		PuzzleManager.mark_solved(burn_puzzle)
		GameState.set_world_flag(flag, true)
		GameState.set_world_flag(&"decay_vine_cleared", true)
		SaveManager.save_game()


func _apply(open: bool) -> void:
	if shape:
		shape.set_deferred("disabled", open)
	visible = not open
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0.0) if open else Color(0.55, 0.7, 0.45, 1.0)


func _process(delta: float) -> void:
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)


## Kılıç sarmaşığı kesmez; çiçek yakar.
func receive_sword_hit(_from: Node, _dir: float, _combo: int) -> void:
	if _is_open() or _hint_cooldown > 0.0:
		return
	_hint_cooldown = 4.0
	DialogueManager.say("Noroi", "Kılıç işlemiyor. Bu sarmaşık çiçekten korkar.")


func _pulse_open() -> void:
	if not is_visible_in_tree():
		return
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("focus_pulse"):
		cam.focus_pulse(global_position + Vector2(0, -50))
