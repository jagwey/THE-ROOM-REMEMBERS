extends CanvasLayer
## Kısa TR epilog ekranı — klavye + dokunmatik devam.

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Panel/Title
@onready var body: Label = $Panel/Body
@onready var hint: Label = $Panel/Hint

var _playing: bool = false
var _lines: Array = []
var _index: int = 0
var _touch_armed: bool = true


func _ready() -> void:
	add_to_group("ending_ui")
	visible = false
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	hint.text = "Etkileş / dokun: devam"
	dim.color = Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.82)
	title.add_theme_color_override("font_color", Palette.IVORY)
	body.add_theme_color_override("font_color", Palette.PALE_LILAC)
	hint.add_theme_color_override("font_color", Palette.STONE)
	UiTheme.apply_outlined(title, UiTheme.TITLE, true)
	UiTheme.apply_outlined(body, UiTheme.BODY, false, Palette.PALE_LILAC)
	UiTheme.apply_outlined(hint, UiTheme.HINT, false, Palette.PALE_LILAC)
	dim.gui_input.connect(_on_dim_gui)


func play_epilogue(ep_title: String, lines: Array) -> void:
	_playing = true
	_lines = lines
	_index = 0
	_touch_armed = true
	visible = true
	UiGate.set_ending(true)
	MobileInputManager.clear_held_inputs()
	title.text = ep_title
	_show_line()
	while _playing:
		await get_tree().process_frame
	UiGate.set_ending(false)
	MobileInputManager.clear_held_inputs()


func _show_line() -> void:
	if _index >= _lines.size():
		body.text = "— SON —"
		hint.text = "Etkileş / dokun: kapat"
		return
	body.text = String(_lines[_index])


func _advance() -> void:
	if not _playing:
		return
	_index += 1
	if _index > _lines.size():
		_playing = false
		visible = false
		return
	_show_line()


func _on_dim_gui(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventScreenTouch and event.pressed:
		if _touch_armed:
			_advance()
			_touch_armed = false
		dim.accept_event()
	elif event is InputEventScreenTouch and not event.pressed:
		_touch_armed = true
		dim.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if OS.has_feature("mobile") or event.device == InputEvent.DEVICE_ID_EMULATION or event.is_echo():
			return
		_advance()
		dim.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func force_finish() -> void:
	_playing = false
	visible = false
	UiGate.set_ending(false)


func _process(_delta: float) -> void:
	# Headless/smoke: epilog input beklemesin — her kare ilerlet; kilitlenirse zorla bitir.
	if not _playing:
		return
	if DisplayServer.get_name() == "headless" \
			or OS.get_environment("TORIMON_SMOKE") == "1" \
			or OS.get_environment("TORIMON_AUTO_DIALOGUE") == "1":
		_advance()
		if _playing and _index > _lines.size() + 2:
			force_finish()
