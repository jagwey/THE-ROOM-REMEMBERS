extends Node2D
## Sera gölgesi: Noroi'nin karanlık silueti. Oyuncuyu beklemez; girişten doğru saksıya (PotB)
## durmadan yürür, yanlış saksıların üstünden geçer, doğru saksının başında diz çöker ve saksı
## parlar. Birkaç saniye sonra söner ve gösteriyi baştan tekrarlar (oyuncu kaçırırsa yeniden görür).
## Savaşsız, hasarsız. `meta kneeling` room_polish toprak izi içindir: yalnız diz çöktüğü saksı işaretlenir.

signal reached(shade_id: StringName)

const START_X := 300.0
const WALK_SPEED := 62.0
const KNEEL_TIME := 3.2
const GAP_TIME := 1.4
const SHADE_TINT := Color(0.05, 0.03, 0.08, 0.86)

@export var target_x: float = 620.0
@export var ground_y: float = 288.0
@export var shade_id: StringName = &"greenhouse_shade_true"

enum State { FADE_IN, WALK, KNEEL, FADE_OUT, GAP }

var state: int = State.FADE_IN
var loops: int = 0 ## audit: tamamlanan gösteri sayısı
var _t: float = 0.0
var _spr: AnimatedSprite2D
var _glow: Sprite2D
var _glow_tw: Tween


func _ready() -> void:
	add_to_group("greenhouse_shade")
	z_index = 3
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = load("res://assets/characters/noroi.tres")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -44)
	_spr.modulate = SHADE_TINT
	add_child(_spr)
	_glow = Sprite2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.6, 1.0, 0.9))
	g.set_color(1, Color(0.85, 0.6, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_glow.texture = gt
	_glow.scale = Vector2(1.4, 0.7)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate.a = 0.0
	_glow.z_index = -1
	_glow.top_level = true
	add_child(_glow)
	_begin_loop()


func _begin_loop() -> void:
	global_position = Vector2(START_X, ground_y)
	_spr.flip_h = false
	_spr.play(&"idle")
	modulate.a = 0.0
	set_meta("kneeling", false)
	state = State.FADE_IN
	_t = 0.0


func _physics_process(delta: float) -> void:
	if UiGate.pauses_world_threats():
		return
	_t += delta
	match state:
		State.FADE_IN:
			modulate.a = minf(1.0, _t / 0.6)
			if _t >= 0.6:
				state = State.WALK
				_spr.play(&"run")
				_spr.speed_scale = 0.6
		State.WALK:
			## Hafif titreme: gölge olduğu belli olsun.
			_spr.modulate.a = SHADE_TINT.a * (0.85 + 0.15 * sin(_t * 9.0))
			var dx := target_x - global_position.x
			var step := WALK_SPEED * delta
			if absf(dx) > step:
				global_position.x += signf(dx) * step
			else:
				global_position.x = target_x
				_kneel()
		State.KNEEL:
			if _t >= KNEEL_TIME:
				state = State.FADE_OUT
				_t = 0.0
		State.FADE_OUT:
			modulate.a = maxf(0.0, 1.0 - _t / 0.9)
			if _t >= 0.9:
				state = State.GAP
				_t = 0.0
				set_meta("kneeling", false)
		State.GAP:
			if _t >= GAP_TIME:
				loops += 1
				_begin_loop()


func _kneel() -> void:
	state = State.KNEEL
	_t = 0.0
	_spr.speed_scale = 1.0
	_spr.play(&"death") ## iki karelik çöküş: diz çöküp saksıya eğilir
	_spr.modulate = SHADE_TINT
	set_meta("kneeling", true)
	_glow.global_position = Vector2(target_x, ground_y - 6.0)
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	_glow_tw = create_tween()
	_glow_tw.tween_property(_glow, "modulate:a", 1.0, 0.5)
	_glow_tw.tween_property(_glow, "modulate:a", 0.45, 0.6)
	_glow_tw.tween_property(_glow, "modulate:a", 0.9, 0.6)
	_glow_tw.tween_interval(1.0)
	_glow_tw.tween_property(_glow, "modulate:a", 0.0, 1.2)
	if loops == 0:
		reached.emit(shade_id)
