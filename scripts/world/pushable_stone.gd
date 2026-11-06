extends CharacterBody2D
## Oyuncunun itebildiği taş ağırlık — ceset sınırına bağımlı değil.

@export var weight_value: int = 1
@export var push_speed: float = 70.0

var _home: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("corpse") ## pressure_plate weight_of corpse path
	add_to_group("pushable_stone")
	_home = global_position
	collision_layer = 1
	collision_mask = 1
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		if s.texture == null:
			s.texture = load("res://assets/layers/rubble.png")
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func get_weight() -> int:
	return weight_value


func reset_to_home() -> void:
	global_position = _home
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if UiGate.pauses_world_threats():
		velocity = Vector2.ZERO
		return
	velocity.y += 900.0 * delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and absf(player.global_position.y - global_position.y) < 40.0:
		var dx := global_position.x - player.global_position.x
		if absf(dx) < 36.0 and absf(dx) > 8.0:
			var pvel := 0.0
			if "velocity" in player:
				pvel = float(player.velocity.x)
			if absf(pvel) > 20.0 and signf(pvel) == signf(dx):
				velocity.x = signf(dx) * push_speed
			else:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
