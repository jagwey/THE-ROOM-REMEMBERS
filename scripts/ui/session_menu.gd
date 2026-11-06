extends CanvasLayer
## Accessible desktop/mobile pause menu. Pauses logic through UiGate, not animation.

var _panel: PanelContainer
var _menu_button: Button
var _confirm: bool = false
var _new_button: Button

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("session_menu")
	_menu_button = Button.new()
	_menu_button.text = "Menü"
	_menu_button.position = Vector2(482, 6)
	_menu_button.custom_minimum_size = Vector2(60, 30)
	_menu_button.pressed.connect(toggle_menu)
	add_child(_menu_button)
	_panel = PanelContainer.new()
	_panel.position = Vector2(138, 54)
	_panel.size = Vector2(364, 245)
	add_child(_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "THE ROOM REMEMBERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_label(title, 16, true)
	column.add_child(title)
	var help := Label.new()
	help.text = "A/D: yürü · E: etkileş / konuşmayı ilerlet\nX: atıl · Z: saldır · I: günlük · Esc: menü"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_label(help, 10, false)
	column.add_child(help)
	var resume := Button.new()
	resume.text = "Devam et"
	resume.pressed.connect(close_menu)
	column.add_child(resume)
	_new_button = Button.new()
	_new_button.text = "Yeni oyun"
	_new_button.pressed.connect(_new_game)
	column.add_child(_new_button)
	var exit_button := Button.new()
	exit_button.text = "Kaydet ve çık"
	exit_button.pressed.connect(func(): SaveManager.save_game(); get_tree().quit())
	column.add_child(exit_button)
	_panel.hide()
	EndingManager.epilogue_finished.connect(open_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _panel.visible:
			close_menu()
		elif UiGate.current_layer() == UiGate.Layer.NONE:
			open_menu()
		else:
			return
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if _panel.visible:
		close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()

func open_menu() -> void:
	if DeathManager.is_dying:
		return
	_panel.show()
	UiGate.set_journal(true)
	MobileInputManager.clear_held_inputs()
	_confirm = false
	_new_button.text = "Yeni oyun"

func close_menu() -> void:
	_panel.hide()
	UiGate.set_journal(false)
	MobileInputManager.clear_held_inputs()

func _new_game() -> void:
	if not _confirm:
		_confirm = true
		_new_button.text = "Sıfırdan başlamak için tekrar bas"
		return
	close_menu()
	SaveManager.start_new_game()
