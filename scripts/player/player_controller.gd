extends CharacterBody2D
## Side-view Shiren: yürü, saldır, dash, etkileş.

const SPEED := 110.0
const DASH_SPEED := 260.0
const DASH_TIME := 0.18
const ATTACK_TIME := 0.32
const GRAVITY := 900.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var interact_area: Area2D = $InteractArea

var _state: StringName = &"idle"
var _dash_timer: float = 0.0
var _attack_timer: float = 0.0
var _facing: float = 1.0
var _dash_dir: float = 1.0
var _stagger_timer: float = 0.0
var _input_locked: bool = false
var _hurt_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = load("res://assets/characters/shiren.tres")
	sprite.play("idle")
	sprite.offset = Vector2(0, -44)
	attack_area.monitoring = false
	interact_area.position.y = -18.0
	var interact_shape := interact_area.get_node("CollisionShape2D") as CollisionShape2D
	var reach := RectangleShape2D.new()
	reach.size = Vector2(64, 56)
	interact_shape.shape = reach
	attack_area.collision_mask = 4 | 8
	MobileInputManager.attack_pressed.connect(_on_attack)
	MobileInputManager.dash_pressed.connect(_on_dash)
	MobileInputManager.interact_pressed.connect(_on_interact)
	call_deferred("_apply_initial_checkpoint_if_new_game")
	GameState.player_progress_knowledge["seen_keeper"] = true
	var vfx := get_tree().get_first_node_in_group("curse_vfx")
	if vfx and vfx.has_signal("stagger_pulse"):
		vfx.stagger_pulse.connect(_on_curse_stagger)
	call_deferred("_bind_curse_vfx")
	DeathManager.death_started.connect(_on_death_started)
	DeathManager.rebirth_completed.connect(_on_rebirth_completed)


func _apply_initial_checkpoint_if_new_game() -> void:
	if GameState.session_loaded_from_save:
		return
	GameState.mark_room_visited(&"awakening")
	GameState.set_checkpoint(global_position, &"awakening")


func _bind_curse_vfx() -> void:
	var vfx := get_tree().get_first_node_in_group("curse_vfx")
	if vfx and vfx.has_signal("stagger_pulse") and not vfx.stagger_pulse.is_connected(_on_curse_stagger):
		vfx.stagger_pulse.connect(_on_curse_stagger)


func _on_curse_stagger() -> void:
	if UiGate.pauses_world_threats():
		return
	_stagger_timer = 0.35
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")


func _on_death_started(_reason: StringName) -> void:
	_input_locked = true
	MobileInputManager.clear_held_inputs()
	velocity = Vector2.ZERO
	_state = &"idle"
	attack_area.monitoring = false


func _on_rebirth_completed() -> void:
	_input_locked = false
	MobileInputManager.clear_held_inputs()


func _physics_process(delta: float) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		velocity = Vector2.ZERO
		return
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)

	# Ölüm / modal: hareket yok; animasyon idle'da kalabilir (görsel devam).
	if _input_locked or UiGate.blocks_movement():
		velocity = Vector2.ZERO
		if _state == &"attack" or _state == &"dash":
			_state = &"idle"
			attack_area.monitoring = false
		if not _input_locked:
			_update_anim()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x *= 0.2
		move_and_slide()
		return

	match _state:
		&"dash":
			_dash_timer -= delta
			velocity.x = _dash_dir * DASH_SPEED
			if _dash_timer <= 0.0:
				_state = &"idle"
		&"attack":
			_attack_timer -= delta
			velocity.x = 0.0
			_hit_keeper_if_any()
			if _attack_timer <= 0.0:
				attack_area.monitoring = false
				_state = &"idle"
		&"idle", &"run":
			var axis := MobileInputManager.get_move_axis()
			velocity.x = axis.x * SPEED
			if absf(axis.x) > 0.1:
				_facing = signf(axis.x)
				sprite.flip_h = _facing < 0.0
				_state = &"run"
			else:
				_state = &"idle"
		_:
			_state = &"idle"

	move_and_slide()
	_update_anim()
	attack_area.position.x = 28.0 * _facing
	interact_area.position.x = 20.0 * _facing


func _hit_keeper_if_any() -> void:
	if not attack_area.monitoring:
		return
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("keeper") and body.has_method("receive_player_strike"):
			body.receive_player_strike()
			attack_area.monitoring = false
			return
	for area in attack_area.get_overlapping_areas():
		var p: Node = area.get_parent()
		if p and p.is_in_group("keeper") and p.has_method("receive_player_strike"):
			p.receive_player_strike()
			attack_area.monitoring = false
			return


func _update_anim() -> void:
	var want: StringName = _state
	if want == &"run":
		want = &"run"
	elif want == &"dash":
		want = &"dash"
	elif want == &"attack":
		want = &"attack"
	else:
		want = &"idle"
	if sprite.animation != String(want) or not sprite.is_playing():
		sprite.play(String(want))


func _on_attack() -> void:
	if _input_locked or UiGate.blocks_combat():
		return
	if _state == &"dash" or _state == &"attack":
		return
	_state = &"attack"
	_attack_timer = ATTACK_TIME
	attack_area.monitoring = true
	sprite.play("attack")


func _on_dash() -> void:
	if _input_locked or UiGate.blocks_combat():
		return
	if _state == &"dash" or _state == &"attack":
		return
	_state = &"dash"
	_dash_timer = DASH_TIME
	_dash_dir = _facing if absf(MobileInputManager.get_move_axis().x) < 0.1 else signf(MobileInputManager.get_move_axis().x)
	if _dash_dir == 0.0:
		_dash_dir = _facing
	sprite.play("dash")


func _on_interact() -> void:
	if _input_locked:
		return
	if UiGate.current_layer() == UiGate.Layer.JOURNAL:
		return
	if UiGate.current_layer() == UiGate.Layer.ENDING:
		return
	if DialogueManager.is_open:
		DialogueManager.advance()
		return
	var journal := get_tree().get_first_node_in_group("journal_ui")
	if journal and journal.visible:
		return
	var target := get_interaction_target()
	if target:
		if target.has_method("on_interact"):
			target.on_interact(self)
		elif target.has_method("apply_push"):
			target.apply_push(_facing)


func get_interaction_target() -> Node2D:
	# Disabled rooms retain Area2D overlaps for a physics frame. Never interact with them.
	var candidates: Array[Node2D] = []
	var overlaps: Array = interact_area.get_overlapping_bodies()
	overlaps.append_array(interact_area.get_overlapping_areas())
	for collider in overlaps:
		var target: Node = collider
		if not target.has_method("on_interact") and not target.has_method("apply_push"):
			target = target.get_parent()
		if not (target is Node2D) or not target.can_process():
			continue
		if not target.is_visible_in_tree():
			continue
		if not target.has_method("on_interact") and not target.has_method("apply_push"):
			continue
		if not candidates.has(target):
			candidates.append(target)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Node2D, b: Node2D): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return candidates[0]


func is_dashing() -> bool:
	return _state == &"dash"


func receive_hazard_hit(from_x: float) -> bool:
	if _hurt_cooldown > 0.0 or is_dashing() or _input_locked or UiGate.pauses_world_threats():
		return false
	_hurt_cooldown = 2.0
	# A mistake costs a heart and clearly pushes away; one contact cannot consume all hearts.
	velocity.x = -90.0 if global_position.x < from_x else 90.0
	_stagger_timer = 0.25
	GameState.damage(1)
	if not DeathManager.is_dying:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 0.35, 0.1)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.15)
	return true


func get_facing() -> float:
	return _facing


func play_death() -> void:
	_state = &"idle"
	velocity = Vector2.ZERO
	_input_locked = true
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")


func respawn_at(pos: Vector2) -> void:
	_hurt_cooldown = 3.0
	sprite.modulate = Color.WHITE
	global_position = pos
	velocity = Vector2.ZERO
	_state = &"idle"
	modulate = Color.WHITE
	sprite.play("idle")
	# Kilit rebirth_completed ile kalkar; erken açılma olmasın.
