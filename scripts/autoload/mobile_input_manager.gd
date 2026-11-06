extends Node
## Mobil sanal joystick + düğme durumu. Klavye/gamepad yedekleri de buradan okunur.

signal attack_pressed
signal dash_pressed
signal interact_pressed

var move_vector: Vector2 = Vector2.ZERO
var attack_held: bool = false
var dash_held: bool = false
var interact_held: bool = false


func set_move_vector(v: Vector2) -> void:
	move_vector = v.limit_length(1.0)


func get_move_axis() -> Vector2:
	var axis := move_vector
	if axis.length() < 0.05:
		axis = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		# Yatay side-view: dikey girdiyi yok say (zıplama FAZ dışı).
		axis.y = 0.0
	else:
		axis.y = 0.0
	return axis


func press_attack() -> void:
	attack_held = true
	attack_pressed.emit()


func release_attack() -> void:
	attack_held = false


func press_dash() -> void:
	dash_held = true
	dash_pressed.emit()


func release_dash() -> void:
	dash_held = false


func press_interact() -> void:
	interact_held = true
	interact_pressed.emit()


func release_interact() -> void:
	interact_held = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		press_attack()
	elif event.is_action_released("attack"):
		release_attack()
	if event.is_action_pressed("dash"):
		press_dash()
	elif event.is_action_released("dash"):
		release_dash()
	if event.is_action_pressed("interact"):
		press_interact()
	elif event.is_action_released("interact"):
		release_interact()
