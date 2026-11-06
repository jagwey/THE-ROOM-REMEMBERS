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
	if UiGate.blocks_movement():
		return Vector2.ZERO
	var axis := move_vector
	if axis.length() < 0.05:
		axis = Vector2(Input.get_axis("ui_left", "ui_right"), 0.0)
	else:
		axis.y = 0.0
	return axis


func clear_held_inputs() -> void:
	move_vector = Vector2.ZERO
	attack_held = false
	dash_held = false
	interact_held = false


func press_attack() -> void:
	if UiGate.blocks_combat():
		return
	attack_held = true
	attack_pressed.emit()


func release_attack() -> void:
	attack_held = false


func press_dash() -> void:
	if UiGate.blocks_combat():
		return
	dash_held = true
	dash_pressed.emit()


func release_dash() -> void:
	dash_held = false


func press_interact() -> void:
	if UiGate.blocks_dialogue_advance():
		return
	interact_held = true
	interact_pressed.emit()


func release_interact() -> void:
	interact_held = false


func _notification(what: int) -> void:
	# Odak kaybı / arka plan — tutulan girişleri bırak
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_held_inputs()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android geri: üst modalı kapat
		var journal := get_tree().get_first_node_in_group("journal_ui")
		if journal and journal.visible and journal.has_method("close_journal"):
			journal.close_journal()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		press_attack()
	elif event.is_action_released("attack"):
		release_attack()
	if event.is_action_pressed("dash") and not event.is_echo():
		press_dash()
	elif event.is_action_released("dash"):
		release_dash()
	if event.is_action_pressed("interact") and not event.is_echo():
		press_interact()
	elif event.is_action_released("interact"):
		release_interact()
