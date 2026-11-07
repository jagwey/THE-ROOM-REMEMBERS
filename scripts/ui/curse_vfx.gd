extends CanvasLayer
## Erken: gizli. Belirtiler: kırmızı halo, hafif warp, stagger sinyali. Geç: küçük mühür.
## Fısıltı ortam bildirimi — modal diyalogla çakışmaz; eski tween iptal edilir.

signal stagger_pulse

@onready var veil: ColorRect = $Veil
@onready var halo: TextureRect = $Halo
@onready var seal: TextureRect = $SealIndicator
@onready var whisper_label: Label = $Whisper

var _pulse: float = 0.0
var _stagger_cd: float = 0.0
var _whisper_tween: Tween
var _whisper_gen: int = 0
var _whisper_queue: Array[String] = []
var _whisper_showing: bool = false
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _vig_t: float = 0.0
var _vig_smooth: float = 0.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float pulse = 0.0;
uniform float aspect = 1.78;
uniform vec3 vein_color : source_color = vec3(0.45, 0.04, 0.09);
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
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float d = length(c) / (0.5 * sqrt(aspect * aspect + 1.0));
	float n = vnoise(c * 5.0 + vec2(t_anim * 0.05, 0.0)) * 0.6 + vnoise(c * 11.0 - vec2(0.0, t_anim * 0.04)) * 0.4;
	float ridge = 1.0 - abs(vnoise(c * 7.0 + vec2(3.1, 1.7)) * 2.0 - 1.0);
	ridge = pow(ridge, 7.0);
	float f = d + (n - 0.5) * 0.32 - ridge * 0.16 * intensity;
	float th = mix(1.3, 0.38, intensity) - pulse * 0.05 * intensity;
	float creep = smoothstep(th, th + 0.5, f);
	float vein = ridge * smoothstep(th - 0.18, th + 0.25, f);
	float a = (creep * 0.82 + vein * 0.55) * clamp(intensity * 1.25, 0.0, 1.0);
	a *= 1.0 + 0.18 * pulse * intensity;
	vec3 col = mix(vec3(0.03, 0.0, 0.04), vein_color, clamp(vein * 1.5, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
"""


func _ready() -> void:
	add_to_group("curse_vfx")
	# Dünya atmosferi HUD'un altında; okunur UI üstte kalsın.
	layer = 8
	veil.color = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.0)
	halo.texture = load("res://assets/props/halo.png")
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.modulate = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.0)
	whisper_label.add_theme_color_override("font_color", Palette.IVORY)
	whisper_label.add_theme_color_override("font_outline_color", Palette.VOID)
	whisper_label.add_theme_constant_override("outline_size", 3)
	UiTheme.apply_label(whisper_label, UiTheme.BODY, false)
	seal.texture = load("res://assets/hud/diamond_selected.png")
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.visible = false
	whisper_label.text = ""
	whisper_label.visible = false
	# Üst orta — diyalog paneliyle alt bölgede çakışmasın
	whisper_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	whisper_label.offset_left = -180.0
	whisper_label.offset_top = 8.0
	whisper_label.offset_right = 180.0
	whisper_label.offset_bottom = 36.0
	whisper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_vignette()
	CurseManager.curse_changed.connect(_on_curse)
	CurseManager.curse_stage_changed.connect(_on_stage)
	CurseManager.curse_whisper.connect(_on_whisper)
	_on_curse(CurseManager.curse)


func _process(delta: float) -> void:
	if UiGate.pauses_world_threats():
		return
	_pulse += delta
	var c := CurseManager.curse
	var t := c / CurseManager.CURSE_MAX
	_update_vignette(delta, t)
	var wobble := 0.02 * t * sin(_pulse * (2.0 + t * 4.0))
	veil.color.a = clampf(t * 0.28 + wobble, 0.0, 0.45)
	halo.modulate.a = clampf(t * 0.55, 0.0, 0.7)
	halo.rotation = sin(_pulse * 0.7) * 0.08 * t
	halo.scale = Vector2.ONE * (1.0 + 0.15 * t + 0.05 * sin(_pulse * 3.0))
	_stagger_cd = maxf(0.0, _stagger_cd - delta)
	if t >= 0.5 and _stagger_cd <= 0.0 and sin(_pulse * 1.3) > 0.92:
		_stagger_cd = 2.4
		stagger_pulse.emit()
	seal.visible = CurseManager.visible_meter
	if seal.visible:
		seal.modulate = Color(0.9, 0.35, 0.4, 0.35 + t * 0.55)
	# Modal diyalog bitince kuyruk
	if not _whisper_showing and not _whisper_queue.is_empty() and not DialogueManager.is_open:
		_show_whisper(_whisper_queue.pop_front())


func _on_curse(value: float) -> void:
	if value >= 55.0:
		CurseManager.unlock_indicator()


func _on_stage(_stage: int) -> void:
	pass


func _on_whisper(text: String) -> void:
	if DialogueManager.is_open:
		_whisper_queue.append(text)
		return
	_show_whisper(text)


func _show_whisper(text: String) -> void:
	_whisper_gen += 1
	var gen := _whisper_gen
	if _whisper_tween and _whisper_tween.is_valid():
		_whisper_tween.kill()
	_whisper_showing = true
	whisper_label.text = text
	whisper_label.visible = true
	whisper_label.modulate.a = 0.0
	_whisper_tween = create_tween()
	_whisper_tween.tween_property(whisper_label, "modulate:a", 1.0, 0.15)
	var hold := clampf(1.2 + float(text.length()) * 0.02, 1.2, 3.2)
	_whisper_tween.tween_interval(hold)
	_whisper_tween.tween_property(whisper_label, "modulate:a", 0.0, 0.45)
	_whisper_tween.tween_callback(func():
		if gen != _whisper_gen:
			return
		whisper_label.visible = false
		_whisper_showing = false
	)


func _build_vignette() -> void:
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = sh
	_vignette = ColorRect.new()
	_vignette.name = "CurseVignette"
	_vignette.color = Color.WHITE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.material = _vig_mat
	_vignette.visible = false
	add_child(_vignette)
	move_child(_vignette, 0)


func _update_vignette(delta: float, t: float) -> void:
	_vig_t += delta
	var target := pow(clampf(t, 0.0, 1.0), 1.15)
	_vig_smooth = move_toward(_vig_smooth, target, delta * 0.5)
	if _vig_smooth < 0.01:
		_vignette.visible = false
		return
	_vignette.visible = true
	# heartbeat: lub-dub, faster as the curse grows
	var bpm := 56.0 + 64.0 * t
	var p := fmod(_vig_t * bpm / 60.0, 1.0)
	var beat := exp(-p * 9.0)
	if p > 0.3:
		beat += 0.6 * exp(-(p - 0.3) * 10.0)
	var sz := _vignette.size
	_vig_mat.set_shader_parameter("intensity", _vig_smooth)
	_vig_mat.set_shader_parameter("pulse", beat * clampf(t * 1.5, 0.0, 1.0))
	_vig_mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	_vig_mat.set_shader_parameter("t_anim", _vig_t)
