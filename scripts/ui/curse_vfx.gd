extends CanvasLayer
## Erken: gizli. Belirtiler: kırmızı halo, hafif warp, stagger sinyali. Geç: küçük mühür.

signal stagger_pulse

@onready var veil: ColorRect = $Veil
@onready var halo: TextureRect = $Halo
@onready var seal: TextureRect = $SealIndicator
@onready var whisper_label: Label = $Whisper

var _pulse: float = 0.0
var _stagger_cd: float = 0.0


func _ready() -> void:
	add_to_group("curse_vfx")
	layer = 15
	veil.color = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.0)
	halo.texture = load("res://assets/props/halo.png")
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.modulate = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.0)
	whisper_label.add_theme_color_override("font_color", Palette.IVORY)
	whisper_label.add_theme_color_override("font_outline_color", Palette.VOID)
	whisper_label.add_theme_constant_override("outline_size", 2)
	seal.texture = load("res://assets/hud/diamond_selected.png")
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.visible = false
	whisper_label.text = ""
	whisper_label.visible = false
	CurseManager.curse_changed.connect(_on_curse)
	CurseManager.curse_stage_changed.connect(_on_stage)
	CurseManager.curse_whisper.connect(_on_whisper)
	_on_curse(CurseManager.curse)


func _process(delta: float) -> void:
	_pulse += delta
	var c := CurseManager.curse
	var t := c / CurseManager.CURSE_MAX
	# Warp hissi: hafif alfa salınımı
	var wobble := 0.02 * t * sin(_pulse * (2.0 + t * 4.0))
	veil.color.a = clampf(t * 0.28 + wobble, 0.0, 0.45)
	halo.modulate.a = clampf(t * 0.55, 0.0, 0.7)
	halo.rotation = sin(_pulse * 0.7) * 0.08 * t
	halo.scale = Vector2.ONE * (1.0 + 0.15 * t + 0.05 * sin(_pulse * 3.0))
	# Stagger hook
	_stagger_cd = maxf(0.0, _stagger_cd - delta)
	if t >= 0.5 and _stagger_cd <= 0.0 and sin(_pulse * 1.3) > 0.92:
		_stagger_cd = 2.4
		stagger_pulse.emit()
	# Geç mühür göstergesi
	seal.visible = CurseManager.visible_meter
	if seal.visible:
		seal.modulate = Color(0.9, 0.35, 0.4, 0.35 + t * 0.55)


func _on_curse(value: float) -> void:
	if value >= 55.0:
		CurseManager.unlock_indicator()


func _on_stage(_stage: int) -> void:
	pass


func _on_whisper(text: String) -> void:
	whisper_label.text = text
	whisper_label.visible = true
	var tw := create_tween()
	tw.tween_property(whisper_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(whisper_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): whisper_label.visible = false)
