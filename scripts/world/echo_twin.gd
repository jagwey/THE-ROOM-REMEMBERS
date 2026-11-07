extends Node2D
## Yarı saydam Shiren yankısı — kaydedilmiş kareleri tekrar oynatır.
## Katman 64 (echo) gövdesiyle plakalara basar; kayıttaki etkileşim anlarında yakındaki
## "echo_lever" kollarını çeker. Oyuncuyla çarpışmaz.

signal finished

const LAYER_ECHO := 64

var _frames: Array = []
var _events: Array = []
var _t: float = 0.0
var _i: int = 0
var _e: int = 0
var _sprite: AnimatedSprite2D
var _body: AnimatableBody2D
var _done: bool = false


func _ready() -> void:
	add_to_group("echo_twin")
	z_index = 3
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load("res://assets/characters/shiren.tres")
	_sprite.offset = Vector2(0, -44)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	modulate = Color(0.7, 0.6, 1.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.62, 0.25)
	_body = AnimatableBody2D.new()
	_body.add_to_group("echo_twin_body")
	_body.collision_layer = LAYER_ECHO
	_body.collision_mask = 0
	_body.sync_to_physics = false
	_body.set_meta("echo_twin", true)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 40)
	cs.shape = rect
	cs.position = Vector2(0, -20)
	_body.add_child(cs)
	add_child(_body)


func play_recording(frames: Array, events: Array) -> void:
	_frames = frames
	_events = events
	_t = 0.0
	_i = 0
	_e = 0
	if not _frames.is_empty():
		global_position = _frames[0][1]


func get_weight() -> int:
	return 1


func _physics_process(delta: float) -> void:
	if _done or _frames.is_empty():
		return
	if UiGate.pauses_world_threats():
		return
	_t += delta
	while _i < _frames.size() - 1 and float(_frames[_i + 1][0]) <= _t:
		_i += 1
	var f: Array = _frames[_i]
	global_position = f[1]
	_sprite.flip_h = bool(f[2])
	var anim := String(f[3])
	if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)
	while _e < _events.size() and float(_events[_e][0]) <= _t:
		_fire(String(_events[_e][1]))
		_e += 1
	if _t >= float(_frames[_frames.size() - 1][0]) + 0.4:
		_vanish()


func _fire(kind: String) -> void:
	if kind != "interact":
		return
	var best: Node2D = null
	var best_d := 48.0
	for lever in get_tree().get_nodes_in_group("echo_lever"):
		if not (lever is Node2D) or not (lever as Node2D).is_visible_in_tree():
			continue
		var d := global_position.distance_to((lever as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = lever
	if best and best.has_method("pull_by_echo"):
		best.pull_by_echo()


func _vanish() -> void:
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	finished.emit()
	queue_free()
