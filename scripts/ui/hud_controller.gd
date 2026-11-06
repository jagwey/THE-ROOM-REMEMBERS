extends CanvasLayer
## Kalpler (sol üst) + mobil joystick/düğmeler (TR etiketler).

@onready var hearts_row: HBoxContainer = $SafeArea/Hearts
@onready var joystick_base: TextureRect = $SafeArea/Joystick/Base
@onready var joystick_thumb: TextureRect = $SafeArea/Joystick/Thumb
@onready var btn_attack: TextureButton = $SafeArea/Buttons/Attack
@onready var btn_dash: TextureButton = $SafeArea/Buttons/Dash
@onready var btn_interact: TextureButton = $SafeArea/Buttons/Interact
@onready var dialogue_panel: NinePatchRect = $SafeArea/Dialogue
@onready var dialogue_speaker: Label = $SafeArea/Dialogue/Speaker
@onready var dialogue_text: Label = $SafeArea/Dialogue/Text
@onready var hint_label: Label = $SafeArea/Hint

var _joy_active: bool = false
var _joy_touch_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
const JOY_RADIUS := 36.0


func _ready() -> void:
	_setup_textures()
	_refresh_hearts(GameState.hearts, GameState.max_hearts)
	GameState.hearts_changed.connect(_refresh_hearts)
	DialogueManager.line_shown.connect(_on_dialogue_line)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	dialogue_panel.visible = false
	hint_label.text = "Yürü · Saldır · Dash · Etkileş"
	btn_attack.button_down.connect(MobileInputManager.press_attack)
	btn_attack.button_up.connect(MobileInputManager.release_attack)
	btn_dash.button_down.connect(MobileInputManager.press_dash)
	btn_dash.button_up.connect(MobileInputManager.release_dash)
	btn_interact.button_down.connect(MobileInputManager.press_interact)
	btn_interact.button_up.connect(MobileInputManager.release_interact)
	_joy_center = joystick_base.position + joystick_base.size * 0.5


func _setup_textures() -> void:
	joystick_base.texture = load("res://assets/hud/joystick_base.png")
	joystick_thumb.texture = load("res://assets/hud/joystick_thumb.png")
	btn_attack.texture_normal = load("res://assets/hud/attack.png")
	btn_dash.texture_normal = load("res://assets/hud/dash.png")
	btn_interact.texture_normal = load("res://assets/hud/interact.png")


func _refresh_hearts(current: int, maximum: int) -> void:
	for c in hearts_row.get_children():
		c.queue_free()
	var full_tex: Texture2D = load("res://assets/hud/heart_full.png")
	var empty_tex: Texture2D = load("res://assets/hud/heart_empty.png")
	for i in range(maximum):
		var tr := TextureRect.new()
		tr.texture = full_tex if i < current else empty_tex
		tr.custom_minimum_size = Vector2(24, 24)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_row.add_child(tr)


func _on_dialogue_line(speaker: String, text: String) -> void:
	dialogue_panel.visible = true
	dialogue_speaker.text = speaker
	dialogue_text.text = text
	hint_label.text = "Etkileş: devam"


func _on_dialogue_closed() -> void:
	dialogue_panel.visible = false
	hint_label.text = "Yürü · Saldır · Dash · Etkileş"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Editör testi: fareyle joystick.
		var mb := event as InputEventMouseButton
		var fake := InputEventScreenTouch.new()
		fake.pressed = mb.pressed
		fake.position = mb.position
		fake.index = 0
		_handle_touch(fake)
	elif event is InputEventMouseMotion and _joy_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag := InputEventScreenDrag.new()
		drag.position = (event as InputEventMouseMotion).position
		drag.index = 0
		_handle_drag(drag)


func _touch_to_joystick_local(screen_pos: Vector2) -> Vector2:
	var xform: Transform2D = joystick_base.get_parent().get_global_transform_with_canvas()
	return xform.affine_inverse() * screen_pos


func _handle_touch(event: InputEventScreenTouch) -> void:
	var local: Vector2 = _touch_to_joystick_local(event.position)
	var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
	if event.pressed:
		if local.distance_to(center) <= JOY_RADIUS * 2.2 and not _joy_active:
			_joy_active = true
			_joy_touch_index = event.index
			_update_joy(local, center)
	else:
		if event.index == _joy_touch_index:
			_joy_active = false
			_joy_touch_index = -1
			MobileInputManager.set_move_vector(Vector2.ZERO)
			joystick_thumb.position = center - joystick_thumb.size * 0.5


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _joy_active or event.index != _joy_touch_index:
		return
	var local: Vector2 = _touch_to_joystick_local(event.position)
	var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
	_update_joy(local, center)


func _update_joy(local: Vector2, center: Vector2) -> void:
	var offset := (local - center).limit_length(JOY_RADIUS)
	joystick_thumb.position = center + offset - joystick_thumb.size * 0.5
	MobileInputManager.set_move_vector(offset / JOY_RADIUS)
