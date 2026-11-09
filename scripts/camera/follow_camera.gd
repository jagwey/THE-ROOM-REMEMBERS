extends Camera2D
## Sinematik takip kamerası: dead zone, hız tabanlı ileri bakış, odak zoom'u,
## trauma tabanlı sarsıntı ve geniş/uzun ekranlarda boşluk göstermeyen fit-zoom.

@export var room_rect: Rect2 = Rect2(0, 0, 640, 360)
@export var follow_lambda: float = 8.0
@export var dead_zone_half_extents: Vector2 = Vector2(56, 32)
@export var look_ahead_pixels: float = 75.0
@export var look_smooth_lambda: float = 5.0
@export var zoom_lambda: float = 4.0
@export var max_shake_offset: Vector2 = Vector2(10, 7)
@export var trauma_decay: float = 1.6

const ZOOM_NORMAL := 1.0
const ZOOM_FOCUS := 1.22
const ZOOM_WIDE := 0.9
## Mimari ihtişam: geniş salonlarda varsayılan zoom-out.
const ROOM_BASE_ZOOM := {
	"library_hall": ZOOM_WIDE,
	"library_upper_stacks": ZOOM_WIDE,
	"core": ZOOM_WIDE,
	"core_seal_chamber": 0.95,
	"mirrors_labyrinth": 0.95,
}
var _base_zoom: float = ZOOM_NORMAL

var _target: Node2D
## Geçici odak (ruh vb.). Silinirse oyuncuya döner.
var _focus: Node2D = null
var _look_offset: float = 0.0
var _prev_target_x: float = 0.0
var _zoom_goal: float = ZOOM_NORMAL
var _zoom_now: float = ZOOM_NORMAL
var _zoom_hold: float = 0.0
var _trauma: float = 0.0
var _shake_t: float = 0.0


func _ready() -> void:
	add_to_group("follow_camera")
	position_smoothing_enabled = false
	make_current()
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if _target:
		_prev_target_x = _target.global_position.x
	get_viewport().size_changed.connect(_on_viewport_resized)
	EchoManager.echo_started.connect(func(_id): zoom_to(ZOOM_FOCUS))
	EchoManager.echo_finished.connect(func(_id): reset_zoom())
	CurseManager.band_changed.connect(func(b: int): if b > 0: add_trauma(0.15 + 0.1 * float(b)))
	_apply_limits()


func set_room_bounds(rect: Rect2) -> void:
	room_rect = rect
	_base_zoom = float(ROOM_BASE_ZOOM.get(String(RoomManager.get_active_room_id()), ZOOM_NORMAL))
	_zoom_goal = _base_zoom
	_zoom_hold = 0.0
	_apply_limits()
	_apply_zoom(true)


## Hedef zoom: 1.0 normal, 1.22 odak, 0.9 geniş salon. hold>0 ise süre sonunda normale döner.
func zoom_to(amount: float, hold: float = 0.0) -> void:
	_zoom_goal = clampf(amount, 0.75, 1.6)
	_zoom_hold = hold


func reset_zoom() -> void:
	_zoom_goal = _base_zoom
	_zoom_hold = 0.0


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_trauma() -> float:
	return _trauma


func set_focus(node: Node2D) -> void:
	_focus = node


func clear_focus() -> void:
	_focus = null


## Kapı/mühür/kısayol açılınca kısa (0.5 sn) kamera odağı + parlak halka.
func focus_pulse(world_pos: Vector2, duration: float = 0.5) -> void:
	if _focus != null or get_parent() == null:
		return
	var m := Marker2D.new()
	get_parent().add_child(m)
	m.global_position = world_pos
	_focus = m
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.95, 0.8, 0.85), Color(1, 0.95, 0.8, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96
	var glow := Sprite2D.new()
	glow.texture = tex
	glow.z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate.a = 0.0
	m.add_child(glow)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(glow, "modulate:a", 1.0, duration * 0.3)
	tw.tween_property(glow, "scale", Vector2(1.8, 1.8), duration)
	tw.chain().tween_property(glow, "modulate:a", 0.0, duration * 0.4)
	tw.chain().tween_callback(func() -> void:
		if _focus == m:
			_focus = null
		m.queue_free())


func snap_to_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if _target == null:
		return
	_prev_target_x = _target.global_position.x
	_apply_zoom(true)
	global_position = _clamp_to_room(_target.global_position)
	_look_offset = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
		if not is_instance_valid(_target):
			return
		_prev_target_x = _target.global_position.x
	if _focus != null and not is_instance_valid(_focus):
		_focus = null

	if _zoom_hold > 0.0:
		_zoom_hold -= delta
		if _zoom_hold <= 0.0:
			_zoom_goal = _base_zoom
	_zoom_now = lerpf(_zoom_now, _zoom_goal, 1.0 - exp(-zoom_lambda * delta))
	_apply_zoom(false)

	var follow: Node2D = _focus if _focus != null else _target
	var sp := follow.global_position
	var vx := 0.0
	if "velocity" in follow:
		vx = (follow.get("velocity") as Vector2).x
	else:
		vx = (sp.x - _prev_target_x) / maxf(delta, 0.0001)
	_prev_target_x = sp.x
	var speed_ratio := clampf(absf(vx) / 175.0, 0.0, 1.6)
	var want_look := signf(vx) * look_ahead_pixels * speed_ratio if absf(vx) > 4.0 else _look_offset
	_look_offset = lerpf(_look_offset, want_look, 1.0 - exp(-look_smooth_lambda * delta))

	var dead := dead_zone_half_extents
	var cam := global_position - offset
	var want := cam
	if sp.x < cam.x - dead.x:
		want.x = sp.x + dead.x
	elif sp.x > cam.x + dead.x:
		want.x = sp.x - dead.x
	if sp.y < cam.y - dead.y:
		want.y = sp.y + dead.y
	elif sp.y > cam.y + dead.y:
		want.y = sp.y - dead.y
	want.x += _look_offset

	var alpha := 1.0 - exp(-follow_lambda * delta)
	global_position = global_position.lerp(_clamp_to_room(want), alpha)
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_t += delta * 38.0
	var power := _trauma * _trauma
	offset = Vector2(
		max_shake_offset.x * power * sin(_shake_t * 1.7 + cos(_shake_t * 0.6)),
		max_shake_offset.y * power * sin(_shake_t * 2.3 + 1.3)
	)
	_trauma = maxf(0.0, _trauma - trauma_decay * delta)


func _clamp_to_room(p: Vector2) -> Vector2:
	var half := _viewport_half_extents()
	var out := p
	var min_x := room_rect.position.x + half.x
	var max_x := room_rect.end.x - half.x
	var min_y := room_rect.position.y + half.y
	var max_y := room_rect.end.y - half.y
	out.x = clampf(out.x, min_x, max_x) if min_x <= max_x else room_rect.get_center().x
	out.y = clampf(out.y, min_y, max_y) if min_y <= max_y else room_rect.get_center().y
	return out


## Görünür alan odadan büyükse zoom'u yükselt: hiçbir ekranda oda dışı boşluk görünmez.
func _fit_zoom() -> float:
	var vp := get_viewport_rect().size
	if room_rect.size.x <= 0.0 or room_rect.size.y <= 0.0:
		return 1.0
	return maxf(vp.x / room_rect.size.x, vp.y / room_rect.size.y)


func _apply_zoom(instant: bool) -> void:
	if instant:
		_zoom_now = _zoom_goal
	var z := maxf(_zoom_now, _fit_zoom())
	zoom = Vector2(z, z)


func _on_viewport_resized() -> void:
	_apply_zoom(false)
	RoomManager.call_deferred("refit_parallax")


func _apply_limits() -> void:
	limit_left = int(room_rect.position.x)
	limit_top = int(room_rect.position.y)
	limit_right = int(room_rect.end.x)
	limit_bottom = int(room_rect.end.y)


func _viewport_half_extents() -> Vector2:
	return get_viewport_rect().size * 0.5 / zoom
