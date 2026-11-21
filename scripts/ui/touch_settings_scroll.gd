extends ScrollContainer

## Telefonda ayar listesi butonların üstünden parmakla kaydırılır (Button dokunuşu
## yuttuğu için ScrollContainer kendi başına kaymıyordu). Sürükleme olduysa
## basılı buton uzak bir sahte bırakmayla iptal edilir → kaydırırken ayar değişmez.
const _DRAG_THRESHOLD := 6.0
var _drag_active: bool = false
var _drag_scrolling: bool = false
var _drag_moved: float = 0.0
var _drag_cancelling: bool = false
var overlay_open: Callable


func _input(event: InputEvent) -> void:
	if _drag_cancelling:
		return
	if not is_visible_in_tree() or (overlay_open.is_valid() and overlay_open.call()):
		_drag_active = false
		return
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	var drag := event is InputEventScreenDrag or (event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	var press := event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not drag and not press:
		return
	if emulated:
		## Dokunuştan türetilen fare olayları: takipte sayma, kaydırma sürerken yut.
		if drag and _drag_scrolling:
			get_viewport().set_input_as_handled()
		return
	var local := make_input_local(event)
	if press:
		if event.is_pressed():
			var scrollbar := get_v_scroll_bar()
			_drag_active = scrollbar.max_value > scrollbar.page and Rect2(Vector2.ZERO, size).has_point(local.get("position"))
			_drag_scrolling = false
			_drag_moved = 0.0
		else:
			_drag_active = false
			_drag_scrolling = false
		return
	if not _drag_active:
		return
	var dy: float = (local.get("relative") as Vector2).y
	_drag_moved += absf(dy)
	if not _drag_scrolling and _drag_moved >= _DRAG_THRESHOLD:
		_drag_scrolling = true
		_cancel_button_press.call_deferred()
	if _drag_scrolling:
		scroll_vertical -= int(round(dy))
		get_viewport().set_input_as_handled()


func _cancel_button_press() -> void:
	## BaseButton "pressing_inside"ı yalnız hareketle günceller: önce dışarı sahte
	## hareket (sol tuş basılı), sonra dışarıda bırakma → `pressed` tetiklenmez.
	var far := Vector2(-10000, -10000)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = far
	move.global_position = far
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = far
	up.global_position = far
	_drag_cancelling = true
	get_viewport().push_input(move)
	get_viewport().push_input(up)
	_drag_cancelling = false
