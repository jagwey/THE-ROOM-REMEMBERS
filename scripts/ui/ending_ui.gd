extends CanvasLayer
## Kısa TR epilog ekranı.

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Panel/Title
@onready var body: Label = $Panel/Body
@onready var hint: Label = $Panel/Hint

var _playing: bool = false
var _lines: Array = []
var _index: int = 0


func _ready() -> void:
	add_to_group("ending_ui")
	visible = false
	layer = 30
	hint.text = "Etkileş: devam"


func play_epilogue(ep_title: String, lines: Array) -> void:
	_playing = true
	_lines = lines
	_index = 0
	visible = true
	title.text = ep_title
	_show_line()
	while _playing:
		await get_tree().process_frame


func _show_line() -> void:
	if _index >= _lines.size():
		body.text = "— SON —"
		hint.text = "Etkileş: kapat"
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


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
	# Headless auto
	if DisplayServer.get_name() == "headless" and event is InputEvent:
		pass


func _process(_delta: float) -> void:
	if _playing and DisplayServer.get_name() == "headless":
		_advance()
