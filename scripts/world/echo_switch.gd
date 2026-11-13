extends Area2D
## Yankı bulmacası anahtarı. "plate": oyuncu / yankı ikizi / ceset üstündeyken aktif.
## "lever": oyuncu veya yankı çekince hold_seconds boyunca aktif.

signal state_changed(active: bool)

@export var kind: String = "plate"
@export var hold_seconds: float = 1.6
## "plate": üstünden inildikten sonra bu kadar süre aktif kalır (0 = anında söner).
@export var release_delay: float = 0.0

var active: bool = false
var _locked: bool = false
var _lever_timer: float = 0.0
var _release_timer: float = 0.0
var _sprite: Sprite2D


func _ready() -> void:
	monitorable = true
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if kind == "plate":
		collision_layer = 0
		collision_mask = 1 | 2 | 64
		monitoring = true
		rect.size = Vector2(48, 24)
		_sprite.texture = load("res://assets/props/pressure_plate.png")
	else:
		add_to_group("echo_lever")
		collision_layer = 8
		collision_mask = 0
		monitoring = false
		rect.size = Vector2(36, 56)
		_sprite.texture = load("res://assets/props/crystal.png")
		_sprite.scale = Vector2(0.6, 0.6)
		_sprite.position = Vector2(0, -16)
	cs.shape = rect
	add_child(cs)
	_apply_visual()


func _physics_process(delta: float) -> void:
	if _locked:
		return
	if UiGate.pauses_world_threats():
		return
	if kind == "plate":
		var on := false
		for b in get_overlapping_bodies():
			if b.is_in_group("player") or b.is_in_group("echo_twin_body") or b.is_in_group("corpse") or b.is_in_group("weight_stone"):
				on = true
				break
		if on:
			_release_timer = release_delay
			_set_active(true)
		elif active and _release_timer > 0.0:
			_release_timer -= delta
			if _release_timer <= 0.0:
				_set_active(false)
		else:
			_set_active(false)
	elif _lever_timer > 0.0:
		_lever_timer -= delta
		if _lever_timer <= 0.0:
			_set_active(false)


func on_interact(_by: Node) -> void:
	if kind != "lever" or _locked:
		return
	_pull()


func pull_by_echo() -> void:
	if kind == "lever" and not _locked:
		_pull()


func _pull() -> void:
	_lever_timer = hold_seconds
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"plate_press")
	_set_active(true)
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation", 0.35, 0.08)
	tw.tween_property(_sprite, "rotation", 0.0, 0.2)


func _set_active(v: bool) -> void:
	if active == v:
		return
	active = v
	if v and kind == "plate":
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"plate_press")
	_apply_visual()
	state_changed.emit(active)


func set_locked_on() -> void:
	_locked = true
	active = true
	_apply_visual()


func _apply_visual() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.3, 0.75, 1.15, 1.0) if active else Color(0.75, 0.72, 0.82, 1.0)
