extends StaticBody2D
## Çatlak Duvar — kılıç yetmez; Shilda'nın atılma saldırısı çarparsa çatlar, ikinci çarpmada yıkılır.
## Hasar world_memory_state["walls"] içinde ölümler arası kalıcıdır. Yıkılınca gizli geçit açılır.

signal broken(wall_id: StringName)

@export var wall_id: StringName = &"decay_shilda_wall"
@export var max_hits: int = 2
@export var shortcut_flag: StringName = &"shortcut_decay_crypt"

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _sword_hint_done: bool = false


func _ready() -> void:
	add_to_group("cracked_wall")
	collision_layer = 1 | 32
	collision_mask = 0
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 140)
		_shape.shape = rect
		_shape.position = Vector2(0, -70)
		add_child(_shape)
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = load("res://assets/layers/column.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -70)
	_apply_state(false)


func hits() -> int:
	var walls: Dictionary = GameState.world_memory_state.get("walls", {})
	return int(walls.get(String(wall_id), 0))


func is_broken() -> bool:
	return hits() >= max_hits


func receive_keeper_charge(_keeper: Node) -> void:
	if is_broken():
		return
	var walls: Dictionary = GameState.world_memory_state.get("walls", {})
	walls[String(wall_id)] = hits() + 1
	GameState.world_memory_state["walls"] = walls
	_debris(18 if is_broken() else 9)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"wall_break" if is_broken() else &"wall_crack")
	_apply_state(true)
	if is_broken():
		GameState.set_world_flag(shortcut_flag, true)
		broken.emit(wall_id)
		DialogueManager.say("Shiren", "Duvar yıkıldı… arkasında bir geçit var.")
	else:
		DialogueManager.whisper("Shiren", "Duvar çatladı! Bir kez daha…")
	SaveManager.save_game()


func receive_sword_hit(_from: Node, _dir: float, _combo: int) -> void:
	if is_broken():
		return
	if not _sword_hint_done:
		_sword_hint_done = true
		DialogueManager.whisper("Shiren", "Kılıcım taşı çizmiyor bile. Bunu yıkabilecek tek güç… Shilda'nın atılması.")


func _apply_state(animate: bool) -> void:
	var h := hits()
	if h >= max_hits:
		if _shape:
			_shape.set_deferred("disabled", true)
		if animate:
			var tw := create_tween()
			tw.tween_property(_sprite, "modulate:a", 0.0, 0.5)
			tw.parallel().tween_property(_sprite, "position:y", -40.0, 0.5)
		else:
			_sprite.visible = false
		return
	_sprite.modulate = Color(0.85, 0.78, 0.82, 1.0).lerp(Color(0.55, 0.42, 0.45, 1.0), float(h) / float(max_hits))
	if h > 0:
		_sprite.rotation = 0.03
	if animate:
		var tw2 := create_tween()
		tw2.tween_property(_sprite, "position:x", 4.0, 0.05)
		tw2.tween_property(_sprite, "position:x", -4.0, 0.05)
		tw2.tween_property(_sprite, "position:x", 0.0, 0.05)


func _debris(n: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.5, 0.45, 0.48, 1.0)
	p.position = Vector2(0, -60)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
