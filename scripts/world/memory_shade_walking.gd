extends CharacterBody2D
## Yürüyen Hafıza Gölgesi (Walking Memory Shade)
## Oyuncuya doğru yavaşça ilerler, kılıç darbelerinde geri savrulur (knockback).
## 3 vuruşluk kombo bitiricisinde (combo == 2) veya canı bitince ölür ve berraklık kıvılcımı (clarity spark) düşürür.

const SPEED := 45.0
const GRAVITY := 900.0
const AGGRO_RADIUS := 260.0

@export var max_health: int = 3
var health: int = 3
var _facing: float = -1.0
var _hurt_timer: float = 0.0
var _contact_cd: float = 0.0
var _dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("memory_shade")
	add_to_group("enemy")
	collision_layer = 4 ## LAYER_HITBOX
	collision_mask = 1  ## LAYER_WORLD
	health = max_health

	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		var frames := load("res://assets/characters/shiren.tres") as SpriteFrames
		if frames:
			sprite.sprite_frames = frames
		sprite.offset = Vector2(0, -44)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color(0.28, 0.12, 0.22, 0.85)
		add_child(sprite)
	else:
		sprite.modulate = Color(0.28, 0.12, 0.22, 0.85)

	if col_shape == null:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 36)
		col_shape.shape = rect
		col_shape.position = Vector2(0, -18)
		add_child(col_shape)

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

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist <= AGGRO_RADIUS:
				_facing = signf(player.global_position.x - global_position.x)
				if _facing == 0.0:
					_facing = 1.0
				if sprite:
					sprite.flip_h = _facing < 0.0
					if sprite.sprite_frames and sprite.sprite_frames.has_animation("run") and sprite.animation != "run":
						sprite.play("run")
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
	health -= 1
	_hurt_timer = 0.25
	velocity.x = signf(dir) * 160.0
	velocity.y = -50.0

	if sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")
		var orig := Color(0.28, 0.12, 0.22, 0.85)
		sprite.modulate = Color(0.9, 0.3, 0.3, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", orig, 0.2)

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"sword_hit")

	if combo == 2 or health <= 0:
		_die()


func receive_soul_slash(attacker: Node) -> void:
	if _dead:
		return
	health -= 2
	_hurt_timer = 0.35
	var dir := 1.0
	if attacker and "direction" in attacker:
		dir = float(attacker.get("direction"))
	velocity.x = dir * 180.0
	velocity.y = -40.0

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"sword_hit")

	if health <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	collision_mask = 0

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"wall_break")

	_spawn_particles()
	_spawn_clarity_spark()

	if sprite:
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func _spawn_particles() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 16
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.35, 0.15, 0.28, 0.85)
	p.global_position = global_position + Vector2(0, -18)
	if get_parent():
		get_parent().add_child(p)
		p.emitting = true
		get_tree().create_timer(0.6).timeout.connect(p.queue_free)


func _spawn_clarity_spark() -> void:
	var spark := Area2D.new()
	spark.name = "ClaritySpark"
	spark.collision_layer = 0
	spark.collision_mask = 2 ## LAYER_PLAYER (mask bit 1 = 2)
	spark.monitoring = true
	spark.monitorable = false
	spark.global_position = global_position + Vector2(0, -16)

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	cs.shape = circle
	spark.add_child(cs)

	var mote := Sprite2D.new()
	mote.texture = load("res://assets/props/memory_mote.png")
	mote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mote.modulate = Color(0.6, 0.9, 1.0, 0.95)
	spark.add_child(mote)

	var halo := Sprite2D.new()
	var halo_tex = load("res://assets/props/halo.png")
	if halo_tex:
		halo.texture = halo_tex
		halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		halo.scale = Vector2(0.35, 0.35)
		halo.modulate = Color(0.4, 0.8, 1.0, 0.5)
		spark.add_child(halo)

	spark.body_entered.connect(func(body: Node):
		if body.is_in_group("player"):
			CurseManager.clear_curse(10.0)
			var am_spark := get_node_or_null("/root/AudioManager")
			if am_spark:
				am_spark.play_sfx(&"seal_open")
			DialogueManager.whisper("Shiren", "+%10 Berraklık")
			spark.queue_free()
	)

	var tw := spark.create_tween().set_loops()
	tw.tween_property(mote, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_SINE)

	if get_parent():
		get_parent().add_child(spark)
