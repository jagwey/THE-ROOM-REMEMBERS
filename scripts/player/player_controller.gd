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


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = load("res://assets/characters/shiren.tres")
	sprite.play("idle")
	sprite.offset = Vector2(0, -44)
	attack_area.monitoring = false
	MobileInputManager.attack_pressed.connect(_on_attack)
	MobileInputManager.dash_pressed.connect(_on_dash)
	MobileInputManager.interact_pressed.connect(_on_interact)
	GameState.mark_room_visited(&"awakening")
	GameState.set_checkpoint(global_position, &"awakening")
	GameState.player_progress_knowledge["seen_keeper"] = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	match _state:
		&"dash":
			_dash_timer -= delta
			velocity.x = _dash_dir * DASH_SPEED
			if _dash_timer <= 0.0:
				_state = &"idle"
		&"attack":
			_attack_timer -= delta
			velocity.x = 0.0
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
	if _state == &"dash" or _state == &"attack":
		return
	_state = &"attack"
	_attack_timer = ATTACK_TIME
	attack_area.monitoring = true
	sprite.play("attack")


func _on_dash() -> void:
	if _state == &"dash" or _state == &"attack":
		return
	_state = &"dash"
	_dash_timer = DASH_TIME
	_dash_dir = _facing if absf(MobileInputManager.get_move_axis().x) < 0.1 else signf(MobileInputManager.get_move_axis().x)
	if _dash_dir == 0.0:
		_dash_dir = _facing
	sprite.play("dash")


func _on_interact() -> void:
	if DialogueManager.is_open:
		DialogueManager.advance()
		return
	for body in interact_area.get_overlapping_bodies():
		if body.has_method("on_interact"):
			body.on_interact(self)
			return
	for area in interact_area.get_overlapping_areas():
		if area.has_method("on_interact"):
			area.on_interact(self)
			return
	DialogueManager.say("Sen", "…Burada bir şey var gibi.")


func play_death() -> void:
	_state = &"idle"
	velocity = Vector2.ZERO
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")


func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_state = &"idle"
	modulate = Color.WHITE
	sprite.play("idle")
