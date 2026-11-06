extends Camera2D
## Oyuncuyu takip; dead zone + yumuşak ileri bakış; tek smoothing (motor kapalı).

@export var room_rect: Rect2 = Rect2(0, 0, 640, 360)
@export var follow_lambda: float = 8.0
## İçeride kamera hedefi oyuncuya kilitlenir; dışına çıkınca yumuşak takip.
@export var dead_zone_half_extents: Vector2 = Vector2(56, 32)
@export var look_ahead_pixels: float = 60.0
@export var look_smooth_lambda: float = 6.0

var _target: Node2D
var _look_offset: float = 0.0
var _prev_target_x: float = 0.0


func _ready() -> void:
	add_to_group("follow_camera")
	position_smoothing_enabled = false
	make_current()
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if _target:
		_prev_target_x = _target.global_position.x
	_apply_limits()


func set_room_bounds(rect: Rect2) -> void:
	room_rect = rect
	_apply_limits()


func snap_to_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if _target == null:
		return
	_prev_target_x = _target.global_position.x
	var sp := _target.global_position
	var half := _viewport_half_extents()
	var cx := clampf(sp.x, room_rect.position.x + half.x, maxf(room_rect.position.x + half.x, room_rect.end.x - half.x))
	var cy := clampf(sp.y, room_rect.position.y + half.y, maxf(room_rect.position.y + half.y, room_rect.end.y - half.y))
	global_position = Vector2(cx, cy)
	_look_offset = 0.0


func _physics_process(delta: float) -> void:
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node2D
		if _target == null:
			return
		_prev_target_x = _target.global_position.x

	var sp := _target.global_position
	var dx := sp.x - _prev_target_x
	if absf(dx) > 0.01:
		var dir := signf(dx)
		_look_offset = lerpf(_look_offset, dir * look_ahead_pixels, 1.0 - exp(-look_smooth_lambda * delta))
	_prev_target_x = sp.x

	var half := _viewport_half_extents()
	var dead := dead_zone_half_extents
	var cam := global_position
	var inner_left := cam.x - dead.x
	var inner_right := cam.x + dead.x
	var inner_top := cam.y - dead.y
	var inner_bottom := cam.y + dead.y

	var want := cam
	if sp.x < inner_left:
		want.x = sp.x + dead.x
	elif sp.x > inner_right:
		want.x = sp.x - dead.x
	if sp.y < inner_top:
		want.y = sp.y + dead.y
	elif sp.y > inner_bottom:
		want.y = sp.y - dead.y

	want.x += _look_offset

	var min_x := room_rect.position.x + half.x
	var max_x := room_rect.end.x - half.x
	var min_y := room_rect.position.y + half.y
	var max_y := room_rect.end.y - half.y
	if min_x <= max_x:
		want.x = clampf(want.x, min_x, max_x)
	else:
		want.x = (room_rect.position.x + room_rect.end.x) * 0.5
	if min_y <= max_y:
		want.y = clampf(want.y, min_y, max_y)
	else:
		want.y = (room_rect.position.y + room_rect.end.y) * 0.5

	var alpha := 1.0 - exp(-follow_lambda * delta)
	global_position = global_position.lerp(want, alpha)


func _apply_limits() -> void:
	limit_left = int(room_rect.position.x)
	limit_top = int(room_rect.position.y)
	limit_right = int(room_rect.end.x)
	limit_bottom = int(room_rect.end.y)


func _viewport_half_extents() -> Vector2:
	return get_viewport_rect().size * 0.5 / zoom
