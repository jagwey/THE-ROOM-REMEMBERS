extends CharacterBody2D
## Side-view Shiren: yürü, zıpla, saldır (kombo), dash (afterimage), ruh kesimi, etkileş.

const SPEED := 175.0
const ACCELERATION := 1150.0
const FRICTION := 1350.0
const DASH_SPEED := 340.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.45
const ATTACK_TIME := 0.26
const COMBO_WINDOW := 0.38
const GRAVITY := 900.0
const JUMP_VELOCITY := -322.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.1
const MAX_FALL := 520.0
const HITSTOP := 0.05
const SKILL_COOLDOWN := 0.8
## Fizik katmanları: 1 dünya · 2 oyuncu · 4 tehlike · 8 etkileşim · 16 lanet bariyeri · 32 kırılabilir
const LAYER_CURSE_BARRIER := 16
const LAYER_BREAKABLE := 32

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
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _dash_cd: float = 0.0
var _skill_cd: float = 0.0
var _combo: int = 0
var _combo_timer: float = 0.0
var _hit_this_swing: Array = []
var _trail_timer: float = 0.0
var _curse_jitter: float = 0.0
## Prosedürel squash/stretch — az kareli sprite'a canlılık katar.
var _squash: Vector2 = Vector2.ONE


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
	attack_area.collision_mask = 4 | 8 | LAYER_BREAKABLE
	collision_mask = 1 | LAYER_CURSE_BARRIER
	MobileInputManager.jump_pressed.connect(_on_jump)
	MobileInputManager.jump_released.connect(_on_jump_released)
	MobileInputManager.skill_pressed.connect(_on_skill)
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

	_dash_cd = maxf(0.0, _dash_cd - delta)
	_skill_cd = maxf(0.0, _skill_cd - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_combo = 0
	_push_hud_cooldowns()

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		if _state != &"dash":
			velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x *= 0.2
		move_and_slide()
		return

	# Tamponlanmış zıplama: yere değdiği / coyote süresi içinde tetikle.
	if _jump_buffer > 0.0 and _coyote > 0.0 and _state != &"attack":
		_do_jump()

	match _state:
		&"dash":
			_dash_timer -= delta
			velocity.x = _dash_dir * DASH_SPEED
			velocity.y = 0.0
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.035
				_spawn_afterimage()
			if _dash_timer <= 0.0:
				_end_dash()
		&"attack":
			_attack_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			_process_sword_hits()
			if _attack_timer <= 0.0:
				attack_area.monitoring = false
				_state = &"idle"
		&"idle", &"run":
			var axis := MobileInputManager.get_move_axis()
			axis.x = _apply_curse_drift(axis.x, delta)
			var target := axis.x * SPEED
			var rate := ACCELERATION if absf(axis.x) > 0.1 else FRICTION
			if not on_floor:
				rate *= 0.7
			velocity.x = move_toward(velocity.x, target, rate * delta)
			if absf(axis.x) > 0.1:
				_facing = signf(axis.x)
				sprite.flip_h = _facing < 0.0
				_state = &"run"
			else:
				_state = &"idle"
		_:
			_state = &"idle"

	var was_air := not on_floor
	var fall_speed := velocity.y
	move_and_slide()
	if was_air and is_on_floor() and fall_speed > 90.0:
		var k := clampf(fall_speed / 520.0, 0.0, 1.0)
		_squash = Vector2(1.0 + 0.22 * k, 1.0 - 0.2 * k)
		if fall_speed > 240.0:
			_camera_trauma(0.18)
			_play_sfx(&"land")
	_update_anim()
	attack_area.position.x = 28.0 * _facing
	interact_area.position.x = 20.0 * _facing


# --- Zıplama -----------------------------------------------------------------

func _on_jump() -> void:
	if _input_locked or UiGate.blocks_movement():
		return
	_jump_buffer = JUMP_BUFFER


func _on_jump_released() -> void:
	if velocity.y < 0.0 and _state != &"dash":
		velocity.y *= JUMP_CUT


func _do_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	velocity.y = JUMP_VELOCITY
	_squash = Vector2(0.84, 1.18)
	if _state == &"attack":
		return
	_play_sfx(&"jump")


func is_airborne() -> bool:
	return not is_on_floor()


# --- Dash / Gölge Atılması -----------------------------------------------------

func has_shadow_dash() -> bool:
	return bool(GameState.player_progress_knowledge.get("ability_shadow_dash", false))


func _end_dash() -> void:
	_state = &"idle"
	_dash_cd = DASH_COOLDOWN
	collision_mask = 1 | LAYER_CURSE_BARRIER
	velocity.x = _dash_dir * SPEED * 0.6


func is_shadow_dashing() -> bool:
	return _state == &"dash" and has_shadow_dash()


func _spawn_afterimage() -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var tex := frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = sprite.flip_h
	ghost.offset = sprite.offset
	ghost.global_position = global_position
	ghost.z_index = z_index - 1
	ghost.modulate = Color(0.78, 0.55, 1.0, 0.55) if has_shadow_dash() else Color(0.95, 0.9, 1.0, 0.45)
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ghost.queue_free)


# --- Kılıç: kombo, hitstop, kıvılcım -----------------------------------------------

func _process_sword_hits() -> void:
	if not attack_area.monitoring:
		return
	var targets: Array = []
	for body in attack_area.get_overlapping_bodies():
		targets.append(body)
	for area in attack_area.get_overlapping_areas():
		targets.append(area)
		if area.get_parent():
			targets.append(area.get_parent())
	for t in targets:
		if t == self or _hit_this_swing.has(t):
			continue
		if t.is_in_group("keeper") and t.has_method("receive_player_strike"):
			_hit_this_swing.append(t)
			t.receive_player_strike()
			_on_hit_confirm(t, 0.35)
			attack_area.monitoring = false
			return
		if t.has_method("receive_sword_hit"):
			_hit_this_swing.append(t)
			t.receive_sword_hit(self, _facing, _combo)
			_on_hit_confirm(t, 0.22 + 0.08 * float(_combo))


func _hit_keeper_if_any() -> void:
	_process_sword_hits()


func _on_hit_confirm(target: Node, trauma: float) -> void:
	_camera_trauma(trauma)
	_play_sfx(&"sword_hit")
	var at := global_position + Vector2(26.0 * _facing, -22.0)
	if target is Node2D:
		at = ((target as Node2D).global_position + at) * 0.5
	_spawn_sparks(at)
	_hitstop(HITSTOP if _combo < 2 else HITSTOP * 1.8)


func _hitstop(duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _spawn_sparks(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.28
	p.explosiveness = 1.0
	p.spread = 70.0
	p.direction = Vector2(_facing, -0.3)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1.0, 0.82, 0.78, 1.0)
	p.global_position = at
	p.z_index = 6
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


# --- Ruh Kesimi (Soul Slash) ---------------------------------------------------------

func has_soul_slash() -> bool:
	return bool(GameState.player_progress_knowledge.get("ability_soul_slash", false))


func _on_skill() -> void:
	if _input_locked or UiGate.blocks_combat() or _skill_cd > 0.0:
		return
	if not has_soul_slash():
		DialogueManager.whisper("Shiren", "…İçimde bir şey kıpırdıyor. Henüz uyanmadı.")
		return
	_skill_cd = SKILL_COOLDOWN
	_play_sfx(&"soul_slash")
	_camera_trauma(0.15)
	var wave := Area2D.new()
	wave.set_script(load("res://scripts/player/soul_slash_wave.gd"))
	wave.global_position = global_position + Vector2(24.0 * _facing, -24.0)
	wave.set("direction", _facing)
	get_parent().add_child(wave)


# --- Lanet %80+: kontrol teklemesi ve Çekirdek'e çekilme ---------------------------------

func _apply_curse_drift(axis_x: float, delta: float) -> float:
	var c := CurseManager.curse
	if c < 80.0:
		return axis_x
	var strength := clampf((c - 80.0) / 20.0, 0.0, 1.0)
	_curse_jitter -= delta
	if _curse_jitter <= 0.0:
		_curse_jitter = randf_range(0.25, 0.8)
		if randf() < 0.35 * strength:
			_stagger_timer = 0.12
	## Çekirdek hep "sağda": odanın sağ ucuna doğru zayıf çekim.
	return clampf(axis_x + 0.35 * strength, -1.0, 1.0)


# --- Yardımcılar -----------------------------------------------------------------

func _camera_trauma(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


func _play_sfx(id: StringName) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(id)


func _push_hud_cooldowns() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_button_cooldown"):
		hud.set_button_cooldown(&"dash", _dash_cd / DASH_COOLDOWN)
		hud.set_button_cooldown(&"skill", _skill_cd / SKILL_COOLDOWN)


func _update_anim() -> void:
	var want: StringName = &"idle"
	match _state:
		&"run", &"dash", &"attack":
			want = _state
	if want == &"idle" and not is_on_floor() and absf(velocity.y) > 1.0 and sprite.sprite_frames and sprite.sprite_frames.has_animation("dash"):
		## Havadayken dash karesini tut (ayrı zıplama animasyonu yok). Donmuşken (hikâye) idle kalsın.
		want = &"dash"
	if sprite.animation != String(want) or not sprite.is_playing():
		sprite.play(String(want))
	if _state == &"run":
		sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.5, 1.2)
	elif _state == &"attack":
		sprite.speed_scale = 1.0 + 0.2 * float(_combo)
	else:
		sprite.speed_scale = 1.0
	_apply_squash()


func _apply_squash() -> void:
	var dt := get_physics_process_delta_time()
	_squash = _squash.lerp(Vector2.ONE, clampf(dt * 11.0, 0.0, 1.0))
	var s := _squash
	if not is_on_floor() and _state != &"dash":
		## Havada dikey hıza göre hafif uzama; tepe noktasında yuvarlak.
		var st := clampf(absf(velocity.y) / 520.0, 0.0, 1.0) * 0.08
		s *= Vector2(1.0 - st, 1.0 + st)
	elif _state == &"run":
		## Koşu sekmesi: adım ritminde küçük dikey nefes.
		var t := float(Time.get_ticks_msec()) * 0.001
		s *= Vector2(1.0, 1.0 + 0.035 * sin(t * 22.0))
	sprite.scale = s


func _on_attack() -> void:
	if _input_locked or UiGate.blocks_combat():
		return
	if _state == &"dash":
		return
	if _state == &"attack" and _attack_timer > ATTACK_TIME * 0.45:
		return ## kombo penceresi: vuruşun ikinci yarısında zincirle
	_combo = (_combo + 1) % 3 if _combo_timer > 0.0 else 0
	_combo_timer = COMBO_WINDOW + ATTACK_TIME
	_state = &"attack"
	_attack_timer = ATTACK_TIME * (1.25 if _combo == 2 else 1.0)
	_hit_this_swing.clear()
	attack_area.monitoring = true
	velocity.x = _facing * (40.0 + 25.0 * float(_combo))
	sprite.play("attack")
	sprite.frame = 0
	_play_sfx(&"sword_swing")


func _on_dash() -> void:
	if _input_locked or UiGate.blocks_combat():
		return
	if _state == &"dash" or _state == &"attack" or _dash_cd > 0.0:
		return
	_state = &"dash"
	_dash_timer = DASH_TIME
	_trail_timer = 0.0
	if has_shadow_dash():
		collision_mask = 1 ## lanet bariyerlerinin içinden geç
	_play_sfx(&"dash")
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
	_camera_trauma(0.4)
	_play_sfx(&"hurt")
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
