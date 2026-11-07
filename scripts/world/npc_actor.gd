extends Area2D
## Konuşan NPC (Arşivci / Yankı yansıması). npc.tres animasyonlarını kullanır.
## Her etkileşimde sıradaki diyalog grubunu oynatır; sonuncusu tekrarlanır.
## dialogue_sets: her eleman "Konuşan|Metin;;Konuşan|Metin" biçiminde bir grup.

@export var npc_id: StringName = &"librarian"
@export var idle_anim: String = "librarian_idle"
@export var walk_anim: String = "librarian_walk"
@export var ghostly: bool = false
@export var wander: float = 0.0 ## >0 ise bu kadar px sağa-sola yürür
@export var dialogue_sets: PackedStringArray = PackedStringArray()

var _sprite: AnimatedSprite2D
var _home_x: float
var _dir: float = 1.0
var _talking: bool = false


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 64)
	cs.shape = rect
	cs.position = Vector2(0, -30)
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load("res://assets/characters/npc.tres")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -44)
	add_child(_sprite)
	if _sprite.sprite_frames.has_animation(idle_anim):
		_sprite.play(idle_anim)
	if ghostly:
		modulate = Color(0.75, 0.7, 1.0, 0.7)
	_home_x = position.x


func _physics_process(delta: float) -> void:
	if wander <= 0.0 or _talking or UiGate.pauses_world_threats():
		if _sprite.animation != idle_anim and _sprite.sprite_frames.has_animation(idle_anim):
			_sprite.play(idle_anim)
		return
	position.x += _dir * 22.0 * delta
	if absf(position.x - _home_x) > wander:
		_dir = -_dir
		position.x = _home_x + signf(position.x - _home_x) * wander
	_sprite.flip_h = _dir < 0.0
	if _sprite.animation != walk_anim and _sprite.sprite_frames.has_animation(walk_anim):
		_sprite.play(walk_anim)


func on_interact(by: Node) -> void:
	if _talking or dialogue_sets.is_empty():
		return
	_talking = true
	if by is Node2D:
		_sprite.flip_h = (by as Node2D).global_position.x < global_position.x
	var key := "npc_talk_%s" % String(npc_id)
	var idx := int(GameState.player_progress_knowledge.get(key, 0))
	var group := dialogue_sets[mini(idx, dialogue_sets.size() - 1)]
	for entry in group.split(";;"):
		var parts := String(entry).split("|", true, 1)
		if parts.size() == 2:
			DialogueManager.say(parts[0], parts[1])
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		GameState.player_progress_knowledge[key] = idx + 1
	_talking = false
