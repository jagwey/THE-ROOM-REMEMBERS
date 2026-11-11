extends Node2D
## Sıralı etkileşim. Çocuk sequence_step düğümleri step_id ile basınır.
## Yanlış adım zinciri sıfırlar; ilk doğru adım hemen yeniden sayılır.
## bridge.z > 1 ise çözümde oda koordinatında tek yönlü tahta iner.

@export var puzzle_id: StringName = &"sequence"
@export var order: PackedStringArray = PackedStringArray()
@export var fail_line: String = ""
@export var success_line: String = ""
## x, y_top, width. width <= 1 ise tahta yok.
@export var bridge: Vector3 = Vector3.ZERO

var _progress: int = 0


func _ready() -> void:
	add_to_group("sequence_shrine")
	if PuzzleManager.is_solved(puzzle_id):
		_progress = order.size()
		_set_all_lit(true)
		_spawn_bridge()


func get_progress() -> int:
	return _progress


func press(step_id: String, source: Node = null) -> void:
	if order.is_empty():
		return
	if PuzzleManager.is_solved(puzzle_id):
		return
	var want := String(order[_progress])
	if step_id == want:
		_progress += 1
		if source and source.has_method("set_lit"):
			source.set_lit(true)
		_tick(source)
		if _progress >= order.size():
			PuzzleManager.mark_solved(puzzle_id)
			_burst(source)
			_spawn_bridge()
			if success_line != "":
				DialogueManager.say("Noroi", success_line)
		return
	_progress = 0
	_set_all_lit(false)
	_trauma(0.18)
	if step_id == String(order[0]):
		_progress = 1
		if source and source.has_method("set_lit"):
			source.set_lit(true)
		_tick(source)
	elif fail_line != "":
		DialogueManager.say("Noroi", fail_line)


func _set_all_lit(on: bool) -> void:
	for c in get_children():
		if c.has_method("set_lit"):
			c.set_lit(on)


func _tick(source: Node) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(&"seal_key", -10.0, 0.9)
	_trauma(0.08)
	if source is Node2D:
		var n := source as Node2D
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector2(1.08, 0.92), 0.06).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(n, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _trauma(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera") if is_inside_tree() else null
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


func _burst(source: Node) -> void:
	_trauma(0.32)
	var at := global_position
	if source is Node2D:
		at = (source as Node2D).global_position
	var cam := get_tree().get_first_node_in_group("follow_camera") if is_inside_tree() else null
	if cam and cam.has_method("focus_pulse"):
		cam.focus_pulse(at, 0.45)
	var p := CPUParticles2D.new()
	p.name = "SolveBurst"
	p.z_index = 6
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 18
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 50.0
	p.initial_velocity_min = 24.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 80)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(0.95, 0.55, 0.62, 1.0)
	p.texture = _dot()
	add_child(p)
	p.global_position = at + Vector2(0, -16)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _dot() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 6:
			var d := Vector2(x - 2.5, y - 2.5).length() / 3.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _spawn_bridge() -> void:
	if bridge.z <= 1.0 or get_node_or_null("ShelfBridge") != null:
		return
	var body := StaticBody2D.new()
	body.name = "ShelfBridge"
	body.collision_layer = 1
	body.position = Vector2(bridge.x + bridge.z * 0.5, bridge.y + 6.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(bridge.z, 12)
	cs.shape = rect
	cs.one_way_collision = true
	body.add_child(cs)
	var tile: Texture2D = load("res://assets/tiles/tile_00.png")
	var strip := Sprite2D.new()
	strip.texture = tile
	strip.centered = false
	strip.position = Vector2(-bridge.z * 0.5, -6)
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	strip.region_enabled = true
	strip.region_rect = Rect2(0, 0, bridge.z, 14)
	strip.modulate = Color(0.72, 0.58, 0.38)
	strip.z_index = 2
	body.add_child(strip)
	add_child(body)
