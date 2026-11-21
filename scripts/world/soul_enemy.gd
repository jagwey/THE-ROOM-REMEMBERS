extends CharacterBody2D
## Parçalanmış Ruh (Shattered Soul) — odada ölüp çıkamayanların kırık ruhu.
## Üç tür: crawler (Sürünen), whisper (Fısıltı), warden (Kopuk Bekçi).
## Hepsi saldırır (kısa, adil uyarı süresiyle) ve oyuncudan 1 kalp düşürür (receive_hazard_hit).
## Öldürülünce ruh kıvılcımı düşer (SoulManager.on_enemy_killed); kıvılcım toplanmazsa düşman geri döner.
## AI mantığı `_ai(delta)` içinde — fizik dışı denetimler doğrudan çağırabilir.

const GRAVITY := 900.0
const PROJECTILE_PATH := "res://scripts/world/soul_projectile.gd"

enum S { IDLE, TELEGRAPH, ATTACK, RECOVER }

## Tür başına ayarlar. tele = uyarı süresi, atk = vuruş penceresi, rec = toparlanma, cd = bekleme.
const KINDS := {
	"crawler": {"hp": 2, "speed": 38.0, "aggro": 220.0, "range": 46.0, "tele": 0.55, "atk": 0.25, "rec": 0.7, "cd": 1.2,
		"reach": 24.0, "color": Color(0.42, 0.72, 0.9, 0.82), "scale": 0.9, "leash": 150.0},
	"whisper": {"hp": 1, "speed": 30.0, "aggro": 280.0, "range": 270.0, "tele": 0.8, "atk": 0.05, "rec": 0.6, "cd": 2.2,
		"reach": 0.0, "color": Color(0.7, 0.55, 0.95, 0.7), "scale": 0.85, "leash": 130.0},
	"warden": {"hp": 3, "speed": 28.0, "aggro": 230.0, "range": 50.0, "tele": 0.75, "atk": 0.22, "rec": 1.1, "cd": 1.4,
		"reach": 44.0, "color": Color(0.5, 0.52, 0.66, 0.92), "scale": 1.12, "leash": 120.0},
}
const TURN_DELAY := 0.7
const WHISPER_NEAR := 100.0
const WHISPER_FAR := 190.0

var kind: String = "crawler"
var soul_id: String = ""
var home_x: float = 0.0
var health: int = 2
var cfg: Dictionary = {}
var _facing: float = -1.0
var _state: int = S.IDLE
var _state_t: float = 0.0
var _cd: float = 0.6
var _hurt_timer: float = 0.0
var _turn_wait: float = TURN_DELAY
var _attack_hit: bool = false
var _dead: bool = false
var _base_color: Color = Color.WHITE
var sprite: AnimatedSprite2D
var shield: Sprite2D
var tele_orb: Sprite2D


## Fabrika: tür + kimlik + oda köküne yerleştirme.
static func create(p_kind: String, p_id: String, at: Vector2) -> CharacterBody2D:
	var e := (load("res://scripts/world/soul_enemy.gd") as GDScript).new() as CharacterBody2D
	e.set("kind", p_kind)
	e.set("soul_id", p_id)
	e.position = at
	return e


func _ready() -> void:
	cfg = KINDS.get(kind, KINDS["crawler"])
	add_to_group("soul_enemy")
	add_to_group("enemy")
	collision_layer = 4 ## LAYER_HITBOX
	collision_mask = 1  ## LAYER_WORLD
	health = int(cfg["hp"])
	home_x = position.x
	_base_color = cfg["color"]
	_build_visuals()
	_play("idle")
	if not DeathManager.death_started.is_connected(_on_player_death):
		DeathManager.death_started.connect(_on_player_death)


## Oyuncu ölünce yarım kalan saldırı/telegraph sıfırlanır; yeniden doğuşta anında vurmaz.
func _on_player_death(_reason: StringName) -> void:
	if _dead:
		return
	_state = S.IDLE
	_state_t = 0.0
	_cd = float(cfg["cd"])
	_hurt_timer = 0.0
	velocity = Vector2.ZERO
	_telegraph_fx(0.0)
	if kind == "warden":
		_flash_shield(true)


func _build_visuals() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	var frames := load("res://assets/characters/noroi.tres") as SpriteFrames
	if frames:
		sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -44)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = _base_color
	sprite.scale = Vector2.ONE * float(cfg["scale"])
	add_child(sprite)
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 36)
	cs.shape = rect
	cs.position = Vector2(0, -18)
	add_child(cs)
	var halo_tex: Texture2D = load("res://assets/props/halo.png")
	if halo_tex:
		tele_orb = Sprite2D.new()
		tele_orb.texture = halo_tex
		tele_orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tele_orb.modulate = Color(1.0, 0.5, 0.55, 0.0)
		tele_orb.position = Vector2(0, -24)
		tele_orb.scale = Vector2(0.1, 0.1)
		add_child(tele_orb)
		if kind == "warden":
			shield = Sprite2D.new()
			shield.texture = halo_tex
			shield.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shield.modulate = Color(0.75, 0.85, 1.0, 0.65)
			shield.scale = Vector2(0.14, 0.42)
			shield.position = Vector2(_facing * 14.0, -22)
			add_child(shield)


func _play(anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p if p != null and is_instance_valid(p) else null


func is_shield_up() -> bool:
	return kind == "warden" and _state != S.RECOVER and not _dead


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if UiGate.pauses_world_threats() or DeathManager.is_dying:
		velocity.x = 0.0
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	_ai(delta)
	move_and_slide()
	## Tasma/zıplama kaçışı: kayıtlı gezinme bölgesinden (boşluk/bulmaca) çıkmaz.
	var lo := home_x - float(cfg["leash"])
	var hi := home_x + float(cfg["leash"])
	if global_position.x < lo or global_position.x > hi:
		global_position.x = clampf(global_position.x, lo, hi)
		velocity.x = 0.0
	if global_position.y > 900.0:
		global_position = Vector2(home_x, 280.0)
		velocity = Vector2.ZERO


## Karar mantığı. Yatay hızı ve durum makinesini yönetir (yerçekimi/hareket _physics_process'te).
func _ai(delta: float) -> void:
	if _dead:
		return
	if _cd > 0.0:
		_cd -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
		return
	var p := _player()
	match _state:
		S.IDLE:
			_ai_idle(delta, p)
		S.TELEGRAPH:
			velocity.x = 0.0
			_state_t -= delta
			_telegraph_fx(1.0 - clampf(_state_t / float(cfg["tele"]), 0.0, 1.0))
			if _state_t <= 0.0:
				_begin_attack(p)
		S.ATTACK:
			_state_t -= delta
			_attack_tick(p)
			if _state_t <= 0.0:
				_state = S.RECOVER
				_state_t = float(cfg["rec"])
				velocity.x = 0.0
				_telegraph_fx(0.0)
				if kind == "warden":
					_flash_shield(false)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_state = S.IDLE
				_cd = float(cfg["cd"])
				if kind == "warden":
					_flash_shield(true)


func _ai_idle(delta: float, p: Node2D) -> void:
	if p == null:
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_play("idle")
		return
	var dx := p.global_position.x - global_position.x
	var dy := p.global_position.y - global_position.y
	var dist := absf(dx)
	var aggro: float = cfg["aggro"]
	if dist > aggro or absf(dy) > 140.0:
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_play("idle")
		return
	_face_toward(dx, delta)
	var speed: float = cfg["speed"]
	match kind:
		"whisper":
			if dist < WHISPER_NEAR:
				velocity.x = -signf(dx) * speed * 1.3
			elif dist > WHISPER_FAR:
				velocity.x = signf(dx) * speed * 0.8
			else:
				velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_:
			velocity.x = _facing * speed if dist > 14.0 else 0.0
	_play("run" if absf(velocity.x) > 5.0 else "idle")
	if _cd > 0.0:
		return
	if kind == "whisper":
		if dist <= float(cfg["range"]) and absf(dy) < 70.0 and signf(dx) == _facing:
			_begin_telegraph()
	elif dist <= float(cfg["range"]) and absf(dy) < 40.0 and signf(dx) == _facing:
		_begin_telegraph()


func _face_toward(dx: float, delta: float) -> void:
	var want := signf(dx)
	if want == 0.0:
		return
	if kind == "warden":
		## Bekçi geç döner: arkasına dash ile geçmek için pencere.
		if want == _facing:
			_turn_wait = TURN_DELAY
			return
		_turn_wait -= delta
		if _turn_wait > 0.0:
			return
		_turn_wait = TURN_DELAY
	_facing = want
	if sprite:
		sprite.flip_h = _facing < 0.0
	if shield:
		shield.position.x = _facing * 14.0


func _begin_telegraph() -> void:
	_state = S.TELEGRAPH
	_state_t = float(cfg["tele"])
	_attack_hit = false
	velocity.x = 0.0
	_play("idle")


func _begin_attack(p: Node2D) -> void:
	_state = S.ATTACK
	_state_t = float(cfg["atk"])
	_attack_hit = false
	match kind:
		"crawler":
			velocity.x = _facing * 170.0
		"whisper":
			_fire()
		"warden":
			velocity.x = _facing * 60.0
			if shield:
				shield.modulate = Color(1.0, 0.7, 0.6, 0.8)


func _attack_tick(p: Node2D) -> void:
	if kind == "whisper" or _attack_hit or p == null:
		return
	var dx := p.global_position.x - global_position.x
	var forward := dx * _facing
	if forward >= -8.0 and absf(dx) <= float(cfg["reach"]) and absf(p.global_position.y - global_position.y) <= 30.0:
		_attack_hit = true
		if p.has_method("receive_hazard_hit"):
			p.receive_hazard_hit(global_position.x)


func _fire() -> void:
	var par := get_parent()
	if par == null:
		return
	var pr := (load(PROJECTILE_PATH) as GDScript).new() as Node2D
	pr.set("dir", _facing)
	pr.global_position = global_position + Vector2(_facing * 12.0, -18.0)
	par.add_child(pr)
	pr.global_position = global_position + Vector2(_facing * 12.0, -18.0)


func _telegraph_fx(t: float) -> void:
	if sprite:
		sprite.modulate = _base_color.lerp(Color(1.0, 0.45, 0.4, 1.0), t)
	if tele_orb:
		tele_orb.modulate.a = 0.75 * t
		tele_orb.scale = Vector2.ONE * (0.1 + 0.25 * t)
		tele_orb.position.x = _facing * (14.0 if kind == "whisper" else 0.0)


func _flash_shield(up: bool) -> void:
	if shield:
		shield.modulate = Color(0.75, 0.85, 1.0, 0.65) if up else Color(0.75, 0.85, 1.0, 0.12)


## `dir`: kılıç yönü (oyuncunun baktığı yön). Bekçi önden gelen darbeyi, kalkan açıkken sektirir.
func receive_sword_hit(attacker: Node, dir: float, combo: int) -> void:
	if _dead:
		return
	if is_shield_up() and _from_front(attacker, dir):
		_block_fx()
		return
	_take_damage(2 if combo >= 2 else 1, dir)


func receive_soul_slash(attacker: Node) -> void:
	if _dead:
		return
	var dir := 1.0
	if attacker and "direction" in attacker:
		dir = float(attacker.get("direction"))
	_take_damage(2, dir)


func _from_front(attacker: Node, dir: float) -> bool:
	if attacker is Node2D:
		return signf((attacker as Node2D).global_position.x - global_position.x) == _facing
	return signf(-dir) == _facing


func _block_fx() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"sword_hit")
	if shield:
		var tw := create_tween()
		shield.modulate = Color(1, 1, 1, 1)
		tw.tween_property(shield, "modulate", Color(0.75, 0.85, 1.0, 0.65), 0.2)


func _take_damage(amount: int, dir: float) -> void:
	health -= amount
	_hurt_timer = 0.25
	velocity.x = signf(dir) * 150.0
	velocity.y = -45.0
	## Darbe hazırlığı bozar; ama kısa bir soluk alma payı kalır.
	if _state != S.RECOVER:
		_state = S.IDLE
		_cd = maxf(_cd, 0.8)
		_telegraph_fx(0.0)
	if sprite:
		sprite.modulate = Color(1.0, 0.95, 0.95, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", _base_color, 0.2)
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
	SoulManager.on_enemy_killed(self)
	if sprite:
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func _spawn_particles() -> void:
	var par := get_parent()
	if par == null:
		return
	var pt := CPUParticles2D.new()
	pt.one_shot = true
	pt.explosiveness = 0.9
	pt.amount = 18
	pt.lifetime = 0.5
	pt.direction = Vector2(0, -1)
	pt.spread = 70.0
	pt.initial_velocity_min = 30.0
	pt.initial_velocity_max = 80.0
	pt.scale_amount_min = 1.5
	pt.scale_amount_max = 3.0
	pt.color = Color(0.6, 0.85, 1.0, 0.85)
	pt.global_position = global_position + Vector2(0, -18)
	par.add_child(pt)
	pt.emitting = true
	get_tree().create_timer(0.7).timeout.connect(pt.queue_free)
