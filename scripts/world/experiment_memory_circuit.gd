extends CanvasLayer
## Hafiza devresi — kayitli echo rotasi (script) + oyuncu anahtari. UiGate modalda zaman durur.

const ECHO_SECONDS := 2.2
const PLAYER_WINDOW := 3.5

var _running: bool = false
var _echo_phase: bool = false
var _player_open: bool = false
var _elapsed: float = 0.0
var _status: Label
var _b_start: Button
var _b_stop: Button
var _b_reset: Button
var _b_player: Button
var _silhouette: ColorRect


func _ready() -> void:
	layer = 24
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 4.0
	panel.offset_bottom = 112.0
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_status = Label.new()
	_status.text = "Kayitli rota: baslat"
	v.add_child(_status)
	var row := HBoxContainer.new()
	v.add_child(row)
	_b_start = Button.new()
	_b_start.text = "Baslat"
	_b_start.pressed.connect(_on_start)
	row.add_child(_b_start)
	_b_stop = Button.new()
	_b_stop.text = "Dur"
	_b_stop.pressed.connect(_on_stop)
	row.add_child(_b_stop)
	_b_reset = Button.new()
	_b_reset.text = "Sifirla"
	_b_reset.pressed.connect(_on_reset)
	row.add_child(_b_reset)
	_b_player = Button.new()
	_b_player.text = "Oyuncu devresi"
	_b_player.disabled = true
	_b_player.pressed.connect(_on_player_circuit)
	row.add_child(_b_player)
	_silhouette = ColorRect.new()
	_silhouette.color = Color(0.25, 0.22, 0.35, 0.35)
	_silhouette.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_silhouette.offset_top = -64.0
	add_child(_silhouette)
	_silhouette.visible = false


func _process(delta: float) -> void:
	if PuzzleManager.is_solved(&"experiment_circuit"):
		return
	if not _running:
		return
	if UiGate.pauses_world_threats():
		return
	_elapsed += delta
	if _echo_phase:
		var p := clampf(_elapsed / ECHO_SECONDS, 0.0, 1.0)
		_silhouette.visible = true
		_silhouette.modulate = Color(1, 1, 1, 0.35 + 0.35 * p)
		if _elapsed >= ECHO_SECONDS:
			_echo_phase = false
			_player_open = true
			_elapsed = 0.0
			_status.text = "Simdi oyuncu devresini ac"
			_b_player.disabled = false
	else:
		if _player_open and _elapsed >= PLAYER_WINDOW:
			_status.text = "Zaman asimi — sifirla"
			_on_stop()


func _on_start() -> void:
	if PuzzleManager.is_solved(&"experiment_circuit"):
		return
	_running = true
	_echo_phase = true
	_player_open = false
	_elapsed = 0.0
	_b_player.disabled = true
	_status.text = "Kayitli rota oynatiliyor..."
	_silhouette.visible = true


func _on_stop() -> void:
	_running = false
	_echo_phase = false
	_player_open = false
	_b_player.disabled = true
	_silhouette.visible = false
	_status.text = "Durdu"


func _on_reset() -> void:
	_on_stop()
	_status.text = "Sifirlandi"


func _on_player_circuit() -> void:
	if not _running or not _player_open:
		return
	if UiGate.pauses_world_threats():
		return
	PuzzleManager.mark_solved(&"experiment_circuit")
	_running = false
	_status.text = "Devre tamam"
	_b_player.disabled = true
	_silhouette.visible = false
	SaveManager.save_game()

