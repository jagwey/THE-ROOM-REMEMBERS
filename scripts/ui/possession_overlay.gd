extends CanvasLayer
## Lanet ele geçirilme sekansı: damarlar yayılır, görüntü bozulur, karanlığa düşülür, metin kartı.
## CurseManager sürer: `await play(repeat)` karanlık + metin tamam olunca döner; yükleme sonrası `await finish(repeat)`.
## İlk sekans ~4.5 sn; tekrarlar ~2 sn ve (kısa bir tutma süresinden sonra) herhangi bir girdiyle atlanır.

const TitleCardStyle := preload("res://scripts/ui/title_card_style.gd")
const FIRST_DURATION := 4.5
const REPEAT_DURATION := 2.0
const SKIP_GRACE := 0.25
const CARD_W := 560.0
const CARD_H := 84.0

const TITLE_TEXT := "LANET SENİ ELE GEÇİRDİ"
const SUB_TEXT := "Bilincin karanlığın içinde kayboldu.\nSon kayıt noktasından yeniden başlayacaksın."

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float veins = 0.0;
uniform float warp = 0.0;
uniform float fade = 0.0;
uniform float aspect = 1.78;
uniform float t_anim = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float wob = warp * 0.018;
	uv += vec2(sin(uv.y * 28.0 + t_anim * 5.0), cos(uv.x * 22.0 - t_anim * 4.0)) * wob;
	vec3 col = texture(screen_tex, uv).rgb;
	float g = dot(col, vec3(0.3, 0.5, 0.2));
	col = mix(col, vec3(g * 1.2, g * 0.35, g * 0.4), clamp(veins * 0.6 + warp * 0.2, 0.0, 0.8));
	float d = length(c) / (0.5 * sqrt(aspect * aspect + 1.0));
	float n = vnoise(c * 5.0 + vec2(t_anim * 0.4, 0.0)) * 0.6 + vnoise(c * 11.0 - vec2(0.0, t_anim * 0.3)) * 0.4;
	float ridge = pow(1.0 - abs(vnoise(c * 7.0 + vec2(3.1, 1.7)) * 2.0 - 1.0), 6.0);
	float f = d + (n - 0.5) * 0.35 - ridge * 0.18 * veins;
	float th = mix(1.4, 0.05, veins);
	float creep = smoothstep(th, th + 0.45, f);
	float vein = ridge * smoothstep(th - 0.2, th + 0.3, f);
	vec3 red = vec3(0.55, 0.04, 0.1);
	col = mix(col, vec3(0.04, 0.0, 0.05), creep * 0.85 * veins);
	col = mix(col, red, clamp(vein * 1.4, 0.0, 1.0) * veins);
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
"""

var _t: float = 0.0
var _duration: float = FIRST_DURATION
var _repeat: bool = false
var _skip: bool = false
var _playing: bool = false
var _rect: ColorRect
var _mat: ShaderMaterial
var _card: Control

signal reached_end


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.name = "PossessionFx"
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	add_child(_rect)
	_build_card()


func _build_card() -> void:
	_card = Control.new()
	_card.name = "PossessionCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -CARD_W * 0.5
	_card.offset_right = CARD_W * 0.5
	_card.offset_top = -CARD_H * 0.5
	_card.offset_bottom = CARD_H * 0.5
	_card.modulate.a = 0.0
	add_child(_card)
	var parts := TitleCardStyle.build(_card, CARD_W, CARD_H, Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.85))
	(parts["title"] as Label).text = TITLE_TEXT
	(parts["sub"] as Label).text = SUB_TEXT


## Sekansı oynat; karanlık ve metin yerine oturunca döner.
func play(repeat: bool) -> void:
	_repeat = repeat
	_duration = REPEAT_DURATION if repeat else FIRST_DURATION
	_t = 0.0
	_skip = false
	_playing = true
	await reached_end


## Yükleme tamamlandı: karanlık ve metin kalkar, overlay kendini siler.
func finish(repeat: bool) -> void:
	var dur := 0.3 if repeat else 0.7
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("fade", v), 1.0, 0.0, dur)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("veins", v), 1.0, 0.0, dur)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("warp", v), 1.0, 0.0, dur)
	tw.tween_property(_card, "modulate:a", 0.0, dur * 0.6)
	await tw.finished
	queue_free()


func elapsed() -> float:
	return _t


func _input(event: InputEvent) -> void:
	if not _playing or not _repeat or _t < SKIP_GRACE:
		return
	if event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		_skip = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	var d := _duration
	if _skip:
		_t = d
		_skip = false
	# Çizelge, süreye oranlı: damarlar %0–35, bozulma %20–65, kararma %55–75, metin %65–.
	var k := _t / d
	_mat.set_shader_parameter("veins", clampf(k / 0.35, 0.0, 1.0))
	_mat.set_shader_parameter("warp", clampf((k - 0.2) / 0.45, 0.0, 1.0))
	_mat.set_shader_parameter("fade", clampf((k - 0.55) / 0.2, 0.0, 1.0))
	_mat.set_shader_parameter("t_anim", _t)
	var vp := _rect.size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_card.modulate.a = clampf((k - 0.65) / 0.12, 0.0, 1.0)
	if _t >= d:
		_playing = false
		reached_end.emit()
