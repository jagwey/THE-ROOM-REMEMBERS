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
	whisper_label.add_theme_constant_override("outline_size", 2)
	UiTheme.apply_label(whisper_label, 11, false)
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
