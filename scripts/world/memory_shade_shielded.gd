extends CharacterBody2D
## Kalkanlı Hafıza Gölgesi (Shielded Memory Shade)
## Ön taraftan gelen kılıç darbelerini sektirir (reflect).
## Kalkan, Ruh Kesimi (SoulSlash) ile kırılabilir veya Gölge Atılması (ShadowDash) ile arkasına geçilerek arkadan vurulabilir.

const SPEED := 35.0
const GRAVITY := 900.0
const AGGRO_RADIUS := 240.0
const TURN_DELAY := 0.7
var _turn_wait := 0.0

@export var max_health: int = 3
var health: int = 3
var _facing: float = -1.0
var _hurt_timer: float = 0.0
var _stun_timer: float = 0.0
var _contact_cd: float = 0.0
var _shield_active: bool = true
var _dead: bool = false
var _hint_given: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var shield_sprite: Sprite2D = $ShieldAura


func _ready() -> void:
	add_to_group("memory_shade")
	add_to_group("enemy")
	collision_layer = 4 ## LAYER_HITBOX
	collision_mask = 1  ## LAYER_WORLD
	health = max_health

	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		var frames := load("res://assets/characters/noroi.tres") as SpriteFrames
		if frames:
			sprite.sprite_frames = frames
		sprite.offset = Vector2(0, -44)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color(0.2, 0.1, 0.3, 0.9)
		add_child(sprite)
	else:
		sprite.modulate = Color(0.2, 0.1, 0.3, 0.9)

	if col_shape == null:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 36)
		col_shape.shape = rect
		col_shape.position = Vector2(0, -18)
		add_child(col_shape)

	if shield_sprite == null:
		shield_sprite = Sprite2D.new()
		shield_sprite.name = "ShieldAura"
		var tex = load("res://assets/props/halo.png")
		if tex == null:
			tex = load("res://assets/props/seal.png")
		shield_sprite.texture = tex
		shield_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shield_sprite.scale = Vector2(0.5, 0.7)
		shield_sprite.position = Vector2(_facing * 12.0, -20.0)
		shield_sprite.modulate = Color(0.85, 0.35, 1.0, 0.75)
		add_child(shield_sprite)

	if shield_sprite:
		var tw := shield_sprite.create_tween().set_loops()
		tw.tween_property(shield_sprite, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(shield_sprite, "modulate:a", 0.85, 0.7).set_trans(Tween.TRANS_SINE)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _dead or UiGate.pauses_world_threats():
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if _contact_cd > 0.0:
		_contact_cd -= delta

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	elif _hurt_timer > 0.0:
		_hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= AGGRO_RADIUS:
				## Ağır kalkan: oyuncu arkasına geçince hemen dönemez (TURN_DELAY) —
				## Ruh Kesimi olmadan da arkadan vurma penceresi kalır.
				var want := signf(player.global_position.x - global_position.x)
				if want != 0.0 and want != _facing:
					_turn_wait += delta
					if _turn_wait >= TURN_DELAY:
						_facing = want
						_turn_wait = 0.0
				else:
					_turn_wait = 0.0
				if sprite:
					sprite.flip_h = _facing < 0.0
					if sprite.sprite_frames and sprite.sprite_frames.has_animation("run") and sprite.animation != "run":
						sprite.play("run")
				if shield_sprite and _shield_active:
					shield_sprite.position.x = _facing * 12.0
				velocity.x = _facing * SPEED

				if dist < 22.0 and _contact_cd <= 0.0:
					_contact_cd = 1.5
					if player.has_method("receive_hazard_hit"):
						player.receive_hazard_hit(global_position.x)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
					sprite.play("idle")
		else:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)

	move_and_slide()


func receive_sword_hit(attacker: Node, dir: float, combo: int) -> void:
	if _dead:
		return

	# Kalkan aktifken önden gelen vuruş kontrolü:
	# Eğer saldıran nesne kalkanın baktığı yöndeyse frontal vuruştur.
	var is_front_attack := true
	if attacker is Node2D:
		var rel_x: float = (attacker as Node2D).global_position.x - global_position.x
		is_front_attack = (rel_x * _facing) > 0.0

	if _shield_active and is_front_attack:
		_reflect_strike(attacker, dir)
		return

	# Arkadan vuruş veya kalkan kırılmış: tam hasar ve savrulma
	health -= 1
	_hurt_timer = 0.25
	velocity.x = signf(dir) * 150.0
	velocity.y = -40.0

	if sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")
		var orig := Color(0.2, 0.1, 0.3, 0.9)
		sprite.modulate = Color(0.9, 0.3, 0.3, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", orig, 0.2)

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"sword_hit")

	if combo == 2 or health <= 0:
		_die()


func _reflect_strike(attacker: Node, dir: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"wall_crack")

	if shield_sprite:
		var orig_color := Color(0.85, 0.35, 1.0, 0.75)
		shield_sprite.modulate = Color(1.8, 1.2, 2.0, 1.0)
		var tw := shield_sprite.create_tween()
		tw.tween_property(shield_sprite, "modulate", orig_color, 0.25)

	_spawn_deflect_sparks()

	# Oyuncuyu hafifçe geri teptir
	if attacker is CharacterBody2D:
		(attacker as CharacterBody2D).velocity.x = -signf(dir) * 120.0

	if not _hint_given:
		_hint_given = true
		if bool(GameState.player_progress_knowledge.get("ability_soul_slash", false)):
			DialogueManager.whisper("Noroi", "Kalkan kılıcı sektiriyor! Arkasına atıl ya da Ruh Kesimi savur.")
		else:
			DialogueManager.whisper("Noroi", "Kalkan kılıcı sektiriyor! Arkasına atıl, sonra arkadan vur.")


func receive_soul_slash(attacker: Node) -> void:
	if _dead:
		return

	if _shield_active:
		# Kalkan parçalanır!
		_shield_active = false
		if shield_sprite:
			var tw := shield_sprite.create_tween()
			tw.tween_property(shield_sprite, "modulate:a", 0.0, 0.25)
			tw.tween_callback(shield_sprite.queue_free)
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"seal_open")
		var cam := get_tree().get_first_node_in_group("follow_camera")
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.2)
		_stun_timer = 1.8
		_spawn_deflect_sparks()

	health -= 2
	_hurt_timer = 0.35
	var dir := 1.0
	if attacker and "direction" in attacker:
		dir = float(attacker.get("direction"))
	velocity.x = dir * 160.0

	if health <= 0:
		_die()


func _spawn_deflect_sparks() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.25
	p.direction = Vector2(-_facing, -0.3)
	p.spread = 50.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.9, 0.5, 1.0, 0.95)
	p.global_position = global_position + Vector2(_facing * 14.0, -20.0)
	if get_parent():
		get_parent().add_child(p)
		p.emitting = true
		get_tree().create_timer(0.4).timeout.connect(p.queue_free)


func _die() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	collision_mask = 0

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"wall_break")

	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 18
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.2
	p.color = Color(0.4, 0.2, 0.5, 0.9)
	p.global_position = global_position + Vector2(0, -18)
	if get_parent():
		get_parent().add_child(p)
		p.emitting = true
		get_tree().create_timer(0.6).timeout.connect(p.queue_free)

	if sprite:
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		queue_free()
