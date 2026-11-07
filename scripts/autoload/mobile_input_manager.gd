extends Node
## Mobil sanal joystick + düğme durumu. Klavye/gamepad yedekleri de buradan okunur.

signal attack_pressed
signal dash_pressed
signal interact_pressed
signal jump_pressed
signal jump_released
signal skill_pressed

var move_vector: Vector2 = Vector2.ZERO
var attack_held: bool = false
var dash_held: bool = false
var interact_held: bool = false
var jump_held: bool = false
## HUD dinamik joystick tercihi (ayar menüsünden değiştirilebilir).
var floating_joystick: bool = true


## Dokunmatik arayüz mü (Android/iOS)? Metinler klavye tuşu yerine HUD buton adı söyler.
func is_touch_ui() -> bool:
	return OS.has_feature("mobile") or OS.get_environment("TORIMON_TOUCH_UI") == "1"


## Eylemin oyuncuya gösterilecek adı: masaüstünde tuş, mobilde HUD butonu.
func control_name(action: StringName) -> String:
	var touch := is_touch_ui()
	match action:
		&"interact":
			return "El" if touch else "E"
		&"attack":
			return "Kılıç" if touch else "Z"
		&"dash":
			return "Atılma" if touch else "X"
		&"jump":
			return "Zıpla" if touch else "W/Space"
		&"skill":
			return "Yetenek" if touch else "Q"
		&"journal":
			return "Günlük" if touch else "I"
	return String(action)


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
	jump_held = false


func press_jump() -> void:
	if UiGate.blocks_movement():
		return
	jump_held = true
	jump_pressed.emit()


func release_jump() -> void:
	if jump_held:
		jump_held = false
		jump_released.emit()


func press_skill() -> void:
	if UiGate.blocks_combat():
		return
	skill_pressed.emit()


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
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_autosave_and_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_go_back()


var _last_back_frame: int = -100


func _ready() -> void:
	## Android geri: bildirim, kök pencere sinyali ve KEY_BACK — hangisi gelirse; aynı karede bir kez işlenir.
	get_tree().root.go_back_requested.connect(_on_go_back)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_BACK:
		_on_go_back()
		get_viewport().set_input_as_handled()


func _on_go_back() -> void:
	var frame := Engine.get_process_frames()
	if frame - _last_back_frame < 3:
		return
	_last_back_frame = frame
	print("[TRR] go_back")
	# Önce günlüğü kapat, yoksa duraklatma menüsünü aç/kapat.
	var journal := get_tree().get_first_node_in_group("journal_ui")
	if journal and journal.visible and journal.has_method("close_journal"):
		journal.close_journal()
		return
	var menu := get_tree().get_first_node_in_group("session_menu")
	if menu and menu.has_method("handle_back"):
		menu.handle_back()


## Uygulama arka plana geçince ilerlemeyi yaz ve oyunu duraklat (telefon araması, ana ekran).
func _autosave_and_pause() -> void:
	if not OS.has_feature("mobile") or get_tree() == null or get_tree().current_scene == null:
		return
	if DeathManager.is_dying or UiGate.current_layer() == UiGate.Layer.ENDING:
		return
	SaveManager.save_game()
	var menu := get_tree().get_first_node_in_group("session_menu")
	if menu and menu.has_method("open_menu") and UiGate.current_layer() == UiGate.Layer.NONE:
		menu.open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		press_attack()
	elif event.is_action_released("attack"):
		release_attack()
	if event.is_action_pressed("dash") and not event.is_echo():
		press_dash()
	elif event.is_action_released("dash"):
		release_dash()
	if event.is_action_pressed("jump") and not event.is_echo():
		press_jump()
	elif event.is_action_released("jump"):
		release_jump()
	if event.is_action_pressed("skill") and not event.is_echo():
		press_skill()
	if event.is_action_pressed("interact") and not event.is_echo():
		press_interact()
	elif event.is_action_released("interact"):
		release_interact()
