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
## Mobil haptik titreşim tercihi (ayar menüsünden değiştirilebilir).
var haptics_enabled: bool = true
## Kontrol yeniden verilince (diyalog/ölüm/menü sonrası) basılı kalan yön girişi
## karakteri kendi kendine koşturmasın: önce nötre dönülmeli (taze basış şartı).
var _need_neutral: bool = true


## Dokunmatik veya Android haptik titreşimi.
func vibrate(duration_ms: int = 20) -> void:
	if not haptics_enabled:
		return
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.get_environment("TORIMON_TEST_HAPTICS") == "1":
		Input.vibrate_handheld(duration_ms)


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
		_need_neutral = true
		return Vector2.ZERO
	var axis := move_vector
	if axis.length() < 0.05:
		axis = Vector2(Input.get_axis("ui_left", "ui_right"), 0.0)
	else:
		axis.y = 0.0
	if _need_neutral:
		if absf(axis.x) < 0.2:
			_need_neutral = false
		return Vector2.ZERO
	return axis


func clear_held_inputs() -> void:
	move_vector = Vector2.ZERO
	_need_neutral = true
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
	# v1.4.1: FOCUS_OUT Android'de geçici overlay'lerde de gelir (bildirim perdesi, jest çubuğu,
	# kenar kaydırma). Menüyü yalnız gerçek arka plana geçişte (PAUSED) aç; odak kaybında sadece kaydet.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_autosave_and_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_autosave_only()
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
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("cancel_seal_code") and hud.has_method("is_seal_code_open") and hud.is_seal_code_open():
		hud.cancel_seal_code()
		return
	var page_puzzle := get_tree().get_first_node_in_group("page_puzzle")
	if page_puzzle and page_puzzle.visible and page_puzzle.has_method("close_puzzle"):
		page_puzzle.close_puzzle()
		return
	var journal := get_tree().get_first_node_in_group("journal_ui")
	if journal and journal.visible and journal.has_method("close_journal"):
		journal.close_journal()
		return
	var menu := get_tree().get_first_node_in_group("session_menu")
	if menu == null or not menu.has_method("handle_back"):
		return
	# v1.4.1: oyun sırasında Android kenar-kaydırma "geri" jesti (sol joystick ekran kenarında)
	# menüyü sürekli açıyordu. Oynanışta menü için 1.5 sn içinde ikinci geri gerekir.
	if _is_gameplay_back(menu):
		var now := Time.get_ticks_msec()
		if now - _first_back_ms > BACK_CONFIRM_MS:
			_first_back_ms = now
			_show_back_hint()
			return
		_first_back_ms = -100000
	menu.handle_back()


const BACK_CONFIRM_MS := 1500
var _first_back_ms: int = -100000
var _back_hint: Label = null


func _is_gameplay_back(menu: Node) -> bool:
	if UiGate.current_layer() != UiGate.Layer.NONE:
		return false
	if menu.has_method("is_title_open") and menu.is_title_open():
		return false
	if menu.has_method("is_confirm_open") and menu.is_confirm_open():
		return false
	if menu.has_method("is_menu_open") and menu.is_menu_open():
		return false
	return true


func _show_back_hint() -> void:
	if _back_hint == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_back_hint = Label.new()
		_back_hint.text = "Menü için tekrar geri"
		_back_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_back_hint.position.y -= 48
		_back_hint.add_theme_color_override("font_color", Color("#E1D3D1"))
		_back_hint.add_theme_color_override("font_outline_color", Color("#221B27"))
		_back_hint.add_theme_constant_override("outline_size", 4)
		_back_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_back_hint)
	_back_hint.modulate.a = 1.0
	_back_hint.visible = true
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_back_hint, "modulate:a", 0.0, 0.4)


## Odak kaybı: menü açmadan ilerlemeyi kaydet.
func _autosave_only() -> void:
	if not OS.has_feature("mobile") or get_tree() == null or get_tree().current_scene == null:
		return
	var menu := get_tree().get_first_node_in_group("session_menu")
	if menu and menu.has_method("is_title_open") and menu.is_title_open():
		return
	if DeathManager.is_dying or UiGate.current_layer() == UiGate.Layer.ENDING:
		return
	if _unsafe_to_autosave():
		return
	SaveManager.save_resume_point()


var _last_autosave_frame: int = -100

const _ROOM_TRANSITION := preload("res://scripts/world/room_transition.gd")

## Possession veya kapı geçişi sırasında konum/oda uyuşmayabilir; kayıt atlanır.
func _unsafe_to_autosave() -> bool:
	return CurseManager.possessing or _ROOM_TRANSITION.is_transitioning()

## Uygulama arka plana geçince ilerlemeyi yaz ve oyunu duraklat (telefon araması, ana ekran).
func _autosave_and_pause() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_autosave_frame:
		return
	_last_autosave_frame = frame
	if not OS.has_feature("mobile") or get_tree() == null or get_tree().current_scene == null:
		return
	var menu := get_tree().get_first_node_in_group("session_menu")
	if menu and menu.has_method("is_title_open") and menu.is_title_open():
		return
	if DeathManager.is_dying or UiGate.current_layer() == UiGate.Layer.ENDING:
		return
	if _unsafe_to_autosave():
		return
	SaveManager.save_resume_point()
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
