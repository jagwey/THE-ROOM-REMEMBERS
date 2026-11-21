extends CanvasLayer
## Kalpler + mobil kontroller + hikâye diyaloğu (atlas çerçeve) + mühür girişi.

const InteractGlowLib := preload("res://scripts/world/interact_glow.gd")
@onready var hearts_row: HBoxContainer = $SafeArea/Hearts
@onready var joystick_base: TextureRect = $SafeArea/Joystick/Base
@onready var joystick_thumb: TextureRect = $SafeArea/Joystick/Thumb
@onready var btn_attack: HudTouchButton = $SafeArea/Buttons/Attack
@onready var btn_dash: HudTouchButton = $SafeArea/Buttons/Dash
@onready var btn_interact: HudTouchButton = $SafeArea/Buttons/Interact
@onready var btn_jump: HudTouchButton = $SafeArea/Buttons/Jump
@onready var btn_skill: HudTouchButton = $SafeArea/Buttons/Skill
@onready var dialogue_panel: NinePatchRect = $SafeArea/Dialogue
@onready var dialogue_speaker: Label = $SafeArea/Dialogue/Margin/VBox/Speaker
@onready var dialogue_text: Label = $SafeArea/Dialogue/Margin/VBox/Text
@onready var dialogue_continue: TextureRect = $SafeArea/Dialogue/Continue
@onready var hint_label: Label = $SafeArea/Hint
@onready var btn_journal: TextureButton = $SafeArea/JournalBtn
@onready var safe_area: Control = $SafeArea
@onready var joystick_root: Control = $SafeArea/Joystick
@onready var buttons_root: Control = $SafeArea/Buttons
@onready var seal_root: Control = $SafeArea/SealCode
@onready var seal_digits: Label = $SafeArea/SealCode/Box/Digits
@onready var seal_row: HBoxContainer = $SafeArea/SealCode/Box/Row

var _joy_active: bool = false
var _joy_touch_index: int = -1
## Görsel yarıçap 50 (eski 40'ın %25 fazlası); sabit modda kabul alanı biraz daha geniş.
const JOY_RADIUS := 50.0
const JOY_ACCEPT := 65.0
const JOY_BASE_SIZE := 100.0
## Joystick ev konumu: güvenli alana göre sol-alt (ağır başparmak payı + jest çubuğu).
const JOY_MARGIN_X := 26.0
const JOY_MARGIN_Y := 30.0
var _joy_radius: float = JOY_RADIUS
var _joy_accept: float = JOY_ACCEPT
## Düğme/joystick ölçeği için ev (başlangıç) ofsetleri: ad -> Vector4(left, top, right, bottom).
var _btn_home: Dictionary = {}
## Etkileş şu an Zıpla yuvasında mı (diyalog/Zıpla gizli).
var _interact_in_corner: bool = false
## Yüzen mod: sol-alt çeyrekte (x < %50, y > %50) herhangi bir dokunuş joystick'i oraya taşır.
var _joy_home := Vector4.ZERO
## Çoklu dokunuş: parmak indeksi -> HudTouchButton.
var _btn_touch: Dictionary = {}
var _buttons_by_name: Dictionary = {}
var _journal: CanvasLayer

var _seal_buffer: String = ""
var _seal_waiting: bool = false
var _seal_result: String = ""
const PortraitsLib := preload("res://scripts/ui/dialogue_portraits.gd")
const MedallionScript := preload("res://scripts/ui/portrait_medallion.gd")
const DIALOGUE_MARGIN_BASE := 30
const MEDALLION_POS := Vector2(22, 52)
var _medallion: Control
var _portrait_speaker: String = "~none~"
var _portrait_inset: float = 0.0
var _header_label: Label
var _header_tween: Tween
var _objective: Label
var _context_hint: Label
## Üst üste binen etkileşim nesneleri için seçici (alt orta, zemin şeridi üstünde).
var _chooser: VBoxContainer
var _chooser_targets: Array = []
const CHOOSER_MAX := 3
var _hint_tick: float = 0.0
## Masaüstünde sanal joystick/düğmeler gizli; ilk gerçek dokunuşta açılır.
var _touch_seen: bool = false
var _continue_tween: Tween
var _continue_base := Vector2.ZERO


func _ready() -> void:
	add_to_group("hud")
	_apply_fonts()
	_apply_safe_area()
	_setup_textures()
	_setup_seal_pad()
	_joy_home = Vector4(joystick_root.offset_left, joystick_root.offset_top, joystick_root.offset_right, joystick_root.offset_bottom)
	_buttons_by_name = {&"attack": btn_attack, &"dash": btn_dash, &"interact": btn_interact, &"jump": btn_jump, &"skill": btn_skill}
	for bn in _buttons_by_name:
		var b: Control = _buttons_by_name[bn]
		_btn_home[bn] = Vector4(b.offset_left, b.offset_top, b.offset_right, b.offset_bottom)
	apply_button_scale()
	safe_area.resized.connect(apply_button_scale)
	DeathManager.death_loop_helper.connect(_on_death_loop_helper)
	DeathManager.rebirth_completed.connect(_flush_toasts)
	CorpseManager.corpse_lost_to_limit.connect(_on_corpse_lost_to_limit)
	GameState.room_changed.connect(_check_puzzle_reset_notice)
	SaveManager.game_loaded.connect(_check_puzzle_reset_notice)
	GameState.journal_seen_changed.connect(_refresh_journal_badge)
	_setup_journal_badge()
	var ambient := preload("res://scripts/world/room_ambient.gd").new()
	ambient.name = "RoomAmbient"
	add_child(ambient)
	_refresh_hearts(GameState.hearts, GameState.max_hearts)
	GameState.hearts_changed.connect(_refresh_hearts)
	GameState.room_changed.connect(_refresh_objective_now)
	GameState.room_changed.connect(_on_room_header_changed)
	GameState.knowledge_changed.connect(_refresh_objective_now)
	GameState.knowledge_changed.connect(_update_control_visibility_arg)
	PuzzleManager.puzzle_solved.connect(_on_puzzle_solved_objective)
	PuzzleManager.live_changed.connect(_on_puzzle_live_changed)
	PuzzleManager.live_feedback.connect(_on_live_feedback)
	DialogueManager.page_shown.connect(_on_dialogue_page)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	DialogueManager.dialogue_cancelled.connect(_on_dialogue_closed)
	DialogueManager.typing_finished.connect(_on_typing_finished)
	DialogueManager.choices_shown.connect(_on_choices_shown)
	DialogueManager.choice_selected.connect(_refresh_choice_highlight)
	DialogueManager.choices_cleared.connect(_hide_choices)
	dialogue_panel.visible = false
	_apply_default_hint()
	btn_journal.pressed.connect(_toggle_journal)
	_journal = get_tree().get_first_node_in_group("journal_ui") as CanvasLayer
	get_tree().root.size_changed.connect(_apply_safe_area)
	UiGate.gate_changed.connect(_on_gate_changed)
	_update_control_visibility()
	_setup_guidance()
	_setup_portrait()
	_setup_room_header()
	call_deferred("_sync_dialogue_metrics")


func _apply_fonts() -> void:
	## Pixeloid hiyerarşi: hint 10 · body 12 · speaker 13 · seal 13/20
	UiTheme.apply_outlined(hint_label, UiTheme.HINT, false, Palette.PALE_LILAC)
	UiTheme.apply_outlined(dialogue_speaker, UiTheme.SPEAKER, true)
	UiTheme.apply_outlined(dialogue_text, UiTheme.BODY, false)
	dialogue_text.add_theme_constant_override("line_spacing", 2)
	if seal_digits:
		UiTheme.apply_outlined(seal_digits, UiTheme.TITLE, true)
	var seal_title := get_node_or_null("SafeArea/SealCode/Box/Title") as Label
	var seal_hint := get_node_or_null("SafeArea/SealCode/Box/Hint") as Label
	if seal_title:
		UiTheme.apply_outlined(seal_title, UiTheme.SPEAKER, true)
	if seal_hint:
		UiTheme.apply_outlined(seal_hint, UiTheme.HINT, false, Palette.PALE_LILAC)


func _setup_textures() -> void:
	joystick_base.texture = load("res://assets/hud/joystick_base.png")
	joystick_thumb.texture = load("res://assets/hud/joystick_thumb.png")
	btn_attack.texture_normal = load("res://assets/hud/attack.png")
	btn_dash.texture_normal = load("res://assets/hud/dash.png")
	btn_interact.texture_normal = load("res://assets/hud/interact.png")
	# Skill/Jump: Attack/Dash/Interact ile aynı gotik halka (prosedürel); ikon halkanın içinde.
	btn_skill.texture_normal = null
	btn_skill.ring_icon = load("res://assets/props/slash.png")
	btn_jump.texture_normal = null
	btn_journal.texture_normal = load("res://assets/hud/journal.png")
	dialogue_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_continue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_dialogue_skin("")


const DIALOGUE_DEFAULT := preload("res://assets/trr_refresh/dialogue/dialogue_default.png")
const DIALOGUE_MEMORY := preload("res://assets/trr_refresh/dialogue/dialogue_memory.png")
const DIALOGUE_WARNING := preload("res://assets/trr_refresh/dialogue/dialogue_warning.png")
const DIALOGUE_NEXT := preload("res://assets/trr_refresh/dialogue/next_arrow.png")
const DIALOGUE_LAST := preload("res://assets/trr_refresh/dialogue/last_line_diamond.png")
## Adsız anlatıcı satırları: portre ve konuşmacı etiketi yok.
const NARRATOR_NAMES := ["", "Sistem", "Kayıt"]


func _skin_for(speaker: String) -> StringName:
	var k: StringName = PortraitsLib.key_for(speaker)
	if k == &"shilda_unknown":
		return &"shilda_unknown"
	if k == &"shilda":
		return &"shilda"
	if k == &"noroi" or k == &"noroi_sad":
		return &"noroi"
	return &"default"


func _is_narrator(speaker: String) -> bool:
	return NARRATOR_NAMES.has(speaker.strip_edges())


func _apply_dialogue_skin(speaker: String) -> void:
	match _skin_for(speaker):
		&"shilda", &"shilda_unknown":
			dialogue_panel.texture = DIALOGUE_WARNING
		&"noroi":
			dialogue_panel.texture = DIALOGUE_MEMORY
		_:
			dialogue_panel.texture = DIALOGUE_DEFAULT

	var narrator := _is_narrator(speaker)
	dialogue_speaker.visible = not narrator
	var margin := $SafeArea/Dialogue/Margin as MarginContainer
	margin.add_theme_constant_override("margin_top", 38 if narrator else 28)
	margin.add_theme_constant_override("margin_bottom", 38 if narrator else 20)
	margin.add_theme_constant_override("margin_right", 44)
	dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if narrator else VERTICAL_ALIGNMENT_TOP


func _setup_seal_pad() -> void:
	for c in seal_row.get_children():
		c.queue_free()
	# Standard 3x4 KEYPAD layout (columns = 3)
	var pad := VBoxContainer.new()
	pad.add_theme_constant_override("separation", 4)
	seal_row.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	pad.add_child(grid)
	var keys: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Sil", "0", "OK"]
	for d in keys:
		var b := Button.new()
		b.text = d
		b.custom_minimum_size = Vector2(54, 32)
		GothicModalPanel.style_button(b)
		var digit: String = d
		b.pressed.connect(func(): _seal_press(digit))
		grid.add_child(b)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.custom_minimum_size = Vector2(0, 32)
	GothicModalPanel.style_button(cancel, UiTheme.HINT)
	cancel.pressed.connect(func():
		_seal_result = ""
		_seal_waiting = false)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(cancel)


func prompt_seal_code() -> String:
	if _seal_waiting:
		return ""
	_seal_buffer = ""
	_seal_result = ""
	_seal_waiting = true
	_refresh_seal_digits()
	seal_root.visible = true
	UiGate.set_seal(true)
	MobileInputManager.clear_held_inputs()
	while _seal_waiting:
		await get_tree().process_frame
	seal_root.visible = false
	UiGate.set_seal(false)
	MobileInputManager.clear_held_inputs()
	return _seal_result


func _seal_press(digit: String) -> void:
	if not _seal_waiting:
		return
	match digit:
		"Sil":
			if _seal_buffer.length() > 0:
				_seal_buffer = _seal_buffer.substr(0, _seal_buffer.length() - 1)
		"OK":
			_seal_result = _seal_buffer
			_seal_waiting = false
		_:
			if _seal_buffer.length() < 6:
				_seal_buffer += digit
	_refresh_seal_digits()


func _refresh_seal_digits() -> void:
	var shown := _seal_buffer
	while shown.length() < 3:
		shown += "_"
	seal_digits.text = shown


func _apply_safe_area() -> void:
	## DisplayServer güvenli alanı → içerik (640×360 viewport) inset'leri.
	if safe_area == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(640, 360)
	var safe: Rect2 = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	var ml := 0.0
	var mt := 0.0
	var mr := 0.0
	var mb := 0.0
	if win.x > 0 and win.y > 0 and safe.size.x > 0.0 and safe.size.y > 0.0:
		# Bantlı keep-aspect: güvenli alanı pencere oranından viewport içeriğine map et.
		var sx := float(vp_size.x) / float(win.x)
		var sy := float(vp_size.y) / float(win.y)
		ml = float(safe.position.x) * sx
		mt = float(safe.position.y) * sy
		mr = float(win.x - safe.end.x) * sx
		mb = float(win.y - safe.end.y) * sy
		# Anlamsız/boş güvenli alan → tam içerik
		if ml + mr >= vp_size.x * 0.9 or mt + mb >= vp_size.y * 0.9:
			ml = 0.0
			mt = 0.0
			mr = 0.0
			mb = 0.0
	safe_area.offset_left = clampf(ml, 0.0, 64.0)
	safe_area.offset_top = clampf(mt, 0.0, 48.0)
	safe_area.offset_right = -clampf(mr, 0.0, 64.0)
	safe_area.offset_bottom = -clampf(mb, 0.0, 48.0)
	if seal_root and seal_root.has_node("Dim"):
		var sdim := seal_root.get_node("Dim") as ColorRect
		sdim.anchor_left = 0.0
		sdim.anchor_top = 0.0
		sdim.anchor_right = 1.0
		sdim.anchor_bottom = 1.0
		sdim.offset_left = -safe_area.offset_left
		sdim.offset_top = -safe_area.offset_top
		sdim.offset_right = -safe_area.offset_right
		sdim.offset_bottom = -safe_area.offset_bottom
	call_deferred("_sync_dialogue_metrics")


## Masaüstünde tuş özeti; mobilde butonlar zaten görünür, ipucu gizli kalır.
func _apply_default_hint() -> void:
	hint_label.text = "WASD yürü · Z saldır · X atıl · E etkileş · I günlüğü aç" + (" •" if GameState.journal_any_unseen() else "")
	hint_label.visible = not (MobileInputManager.is_touch_ui() or _touch_seen)


## Yazı boyutu ayarı (Normal/Büyük): yalnız diyalog metni; sayfalama yeni boyuta göre yeniden kurulur.
func apply_text_size_setting(resync: bool = true) -> void:
	if dialogue_text == null:
		return
	UiTheme.apply_outlined(dialogue_text, int(round(float(UiTheme.BODY) * GameSettings.font_scale())), false)
	if resync:
		_sync_dialogue_metrics()


func _sync_dialogue_metrics() -> void:
	if dialogue_text == null:
		return
	var font: Font = dialogue_text.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := dialogue_text.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = UiTheme.BODY
	# Genişlik: etiketin gerçek genişliği - outline (3px x2) - pay; ölçülemezse panel sabiti.
	# Portre payı (Margin sol) metin genişliğinden düşülmüş olabilir; tam genişlik DialogueManager'a verilir.
	var w := dialogue_text.size.x + _portrait_inset - 12.0
	if w < 120.0:
		w = 436.0
	# Satır yüksekliği = font + line_spacing (outline taşması etiket kutusu dışına çizilir).
	var spacing := float(dialogue_text.get_theme_constant("line_spacing"))
	var line_h := maxf(1.0, float(font.get_height(font_size)) + spacing)
	var max_lines := 4
	if dialogue_text.size.y >= line_h * 2.0:
		max_lines = int(floor((dialogue_text.size.y - 4.0) / line_h))
	max_lines = clampi(max_lines, 2, 5)
	DialogueManager.rebuild_pages_for_metrics(w, max_lines, font_size, font)


func _toggle_journal() -> void:
	var layer := UiGate.current_layer()
	if layer != UiGate.Layer.NONE and layer != UiGate.Layer.JOURNAL:
		return
	if _journal == null:
		_journal = get_tree().get_first_node_in_group("journal_ui") as CanvasLayer
	if _journal and _journal.has_method("toggle_journal"):
		_journal.toggle_journal()


func _refresh_hearts(current: int, maximum: int) -> void:
	for c in hearts_row.get_children():
		c.queue_free()
	var full_tex: Texture2D = load("res://assets/hud/heart_full.png")
	var empty_tex: Texture2D = load("res://assets/hud/heart_empty.png")
	for i in range(maximum):
		var tr := TextureRect.new()
		tr.texture = full_tex if i < current else empty_tex
		tr.custom_minimum_size = Vector2(28, 28)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_row.add_child(tr)


func _on_dialogue_page(speaker: String, text: String, page_index: int, page_count: int) -> void:
	dialogue_panel.visible = true
	# Konuşmacı bandı: çerçeve süsüne taşmasın (clip + ellipsis).
	dialogue_speaker.clip_text = true
	dialogue_speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Label shrink-begin (min 200) olduğu için kendi size.x'i değil, VBox genişliği ölçü alınır.
	var row := dialogue_speaker.get_parent() as Control
	var max_w := maxf(dialogue_speaker.size.x, (row.size.x if row != null else 0.0) - 48.0)
	if max_w < 40.0:
		max_w = 160.0
	var font: Font = dialogue_speaker.get_theme_font("font")
	var fsize := dialogue_speaker.get_theme_font_size("font_size")
	if font == null:
		font = ThemeDB.fallback_font
	if fsize <= 0:
		fsize = UiTheme.SPEAKER
	var shown := DialogueManager.display_speaker(speaker)
	while shown.length() > 1 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w:
		shown = shown.substr(0, shown.length() - 1)
	if shown != DialogueManager.display_speaker(speaker):
		if shown.length() > 1:
			shown = shown.substr(0, shown.length() - 1) + "…"
		else:
			shown = "…"
	dialogue_speaker.text = shown
	var need_w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 8.0
	dialogue_speaker.custom_minimum_size.x = minf(maxf(need_w, 200.0), maxf(max_w, 200.0))
	dialogue_text.text = text
	_apply_dialogue_skin(speaker)
	_update_portrait(speaker)
	var more := page_index < page_count - 1 or DialogueManager.has_queued_lines() or DialogueManager.is_typing()
	_set_continue(not DialogueManager.is_typing(), more)
	_set_header_hidden_for_dialogue(true)
	hint_label.visible = false
	_update_control_visibility()


## Yazı bitince devam oku veya son satır işareti görünür.
func _set_continue(show_arrow: bool, more: bool) -> void:
	dialogue_continue.texture = DIALOGUE_NEXT if more else DIALOGUE_LAST
	dialogue_continue.visible = show_arrow
	dialogue_continue.modulate.a = 1.0 if more else 0.6
	if _continue_tween and _continue_tween.is_valid():
		_continue_tween.kill()
	if not show_arrow:
		return
	if _continue_base == Vector2.ZERO:
		_continue_base = Vector2(dialogue_continue.offset_top, dialogue_continue.offset_bottom)
	_continue_tween = create_tween().set_loops()
	_continue_tween.tween_method(_pulse_continue, -2.0, 2.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_continue_tween.tween_method(_pulse_continue, 2.0, -2.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse_continue(d: float) -> void:
	dialogue_continue.offset_top = _continue_base.x + d
	dialogue_continue.offset_bottom = _continue_base.y + d


## Diyalog sırasında üst-orta oda başlığı gizlenir (panelle üst üste binmesin).
func _set_header_hidden_for_dialogue(hidden: bool) -> void:
	var box := get_node_or_null("SafeArea/RoomHeader") as Control
	if box:
		box.visible = not hidden


func _on_typing_finished() -> void:
	if dialogue_panel.visible:
		_set_continue(true, true)


var _choice_box: VBoxContainer = null


func _on_choices_shown(options: PackedStringArray) -> void:
	_hide_choices()
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(DialogueManager.choose.bind(i))
		_choice_box.add_child(b)
	$SafeArea.add_child(_choice_box)
	_refresh_choice_highlight(DialogueManager.choice_index())
	await get_tree().process_frame
	if _choice_box == null or not is_instance_valid(_choice_box):
		return
	_place_choice_box()


## Seçim kutusu: panelin üstüne sığıyorsa üstüne, sığmıyorsa (panel üst kenara yakın) altına; sağdaki
## Etkileş düğmesine ve ekran/güvenli alan kenarına binmez.
func _place_choice_box() -> void:
	if _choice_box == null or not is_instance_valid(_choice_box):
		return
	var r := dialogue_panel.get_global_rect()
	var sa := safe_area.get_global_rect()
	_choice_box.size = Vector2(r.size.x, 0)
	var h := _choice_box.size.y
	var above_y := r.position.y - h - 6.0
	var y := above_y
	if above_y < sa.position.y + 4.0:
		y = r.end.y + 6.0
	var right := r.end.x
	if btn_interact.visible:
		var ib := btn_interact.get_global_rect()
		if y + h > ib.position.y - 2.0 and y < ib.end.y + 2.0:
			right = minf(right, ib.position.x - 6.0)
	_choice_box.size = Vector2(maxf(120.0, right - r.position.x), 0)
	_choice_box.global_position = Vector2(r.position.x, y)


func _refresh_choice_highlight(sel: int) -> void:
	if _choice_box == null or not is_instance_valid(_choice_box):
		return
	for i in _choice_box.get_child_count():
		var b := _choice_box.get_child(i) as Button
		b.text = ("> " if i == sel else "  ") + String(b.text).lstrip("> ").strip_edges()
		b.modulate = Color(1, 1, 1) if i == sel else Color(0.75, 0.75, 0.75)


func _hide_choices() -> void:
	if _choice_box != null and is_instance_valid(_choice_box):
		_choice_box.queue_free()
	_choice_box = null


func _on_dialogue_closed() -> void:
	_hide_choices()
	dialogue_panel.visible = false
	_set_continue(false, false)
	_set_header_hidden_for_dialogue(false)
	_portrait_speaker = "~none~"
	_apply_portrait_inset(0.0)
	_apply_default_hint()
	_update_control_visibility()


func _on_gate_changed(_layer: UiGate.Layer) -> void:
	_update_control_visibility()
	if UiGate.blocks_gameplay_input():
		_release_joystick()
		_release_all_buttons()


## Kapı/ölüm sonrası dışarıdan çağrılır: dokunmatik HUD'u güncel UiGate katmanına göre yeniler.
func refresh_touch_controls() -> void:
	_update_control_visibility()
	if not UiGate.blocks_gameplay_input():
		_release_joystick()
		_release_all_buttons()


func _update_control_visibility() -> void:
	var blocked := UiGate.blocks_gameplay_input()
	# Masaüstünde sanal joystick/düğmeler yok: yalnız dokunmatik modda ya da ilk dokunuştan sonra.
	var touch := _touch_seen or MobileInputManager.is_touch_ui()
	# Hikâye diyaloğunda hareket/saldırı/dash gizlenir; etkileş devam için kalır.
	joystick_root.visible = touch and not blocked
	btn_attack.visible = touch and not blocked
	btn_dash.visible = touch and not blocked
	btn_jump.visible = touch and not blocked
	btn_skill.visible = touch and not blocked and GameState.has_any_ability()
	btn_interact.visible = touch and not UiGate.blocks_dialogue_advance() and UiGate.current_layer() != UiGate.Layer.DEATH
	## Diyalogda Zıpla gizli: Etkileş başparmağın en rahat yerine (Zıpla yuvası, sağ-alt köşe) geçer.
	var corner := btn_interact.visible and not btn_jump.visible
	if corner != _interact_in_corner:
		_interact_in_corner = corner
		apply_button_scale()
	var layer := UiGate.current_layer()
	btn_journal.visible = layer == UiGate.Layer.NONE or layer == UiGate.Layer.JOURNAL
	buttons_root.modulate.a = 1.0 if btn_interact.visible or btn_attack.visible else 0.0
	## Göz açma sinematiği: kalp/hedef/düğme hiçbiri görünmez.
	## Günlük (kitap) açıkken de HUD gizli; günlük kendi kapat düğmesini taşır.
	var vis_layer := UiGate.current_layer()
	safe_area.visible = vis_layer != UiGate.Layer.CUTSCENE and vis_layer != UiGate.Layer.JOURNAL and vis_layer != UiGate.Layer.TITLE


## Görünür dokunmatik düğme + joystick tabanının ekran (viewport) dikdörtgenleri; kapı etiketi kaçınması için.
## Dokunmatik arayüz görünmüyorsa boş döner.
func get_touch_button_screen_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var ctrls: Array[Control] = [btn_attack, btn_dash, btn_interact, btn_jump, btn_skill, joystick_base]
	for c in ctrls:
		if c != null and c.is_visible_in_tree():
			out.append(c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size))
	return out


## Düğme basışı (parmak indeksiyle). Kapı (gate) mantığı eski düğme sinyalleriyle aynı.
func _press_button(btn: HudTouchButton, index: int) -> void:
	if _btn_touch.get(index) == btn:
		return
	var key := &""
	for k in _buttons_by_name:
		if _buttons_by_name[k] == btn:
			key = k
	match key:
		&"attack":
			if UiGate.blocks_combat():
				return
			MobileInputManager.press_attack()
		&"dash":
			if UiGate.blocks_combat():
				return
			MobileInputManager.press_dash()
		&"interact":
			if UiGate.blocks_dialogue_advance() or UiGate.current_layer() == UiGate.Layer.JOURNAL or UiGate.current_layer() == UiGate.Layer.ENDING:
				return
			MobileInputManager.press_interact()
		&"jump":
			if UiGate.blocks_movement():
				return
			MobileInputManager.press_jump()
		&"skill":
			if UiGate.blocks_combat():
				return
			MobileInputManager.press_skill()
		_:
			return
	_btn_touch[index] = btn
	btn.set_held(true)


func _release_button(btn: HudTouchButton) -> void:
	btn.set_held(false)
	if btn == btn_attack:
		MobileInputManager.release_attack()
	elif btn == btn_dash:
		MobileInputManager.release_dash()
	elif btn == btn_interact:
		MobileInputManager.release_interact()
	elif btn == btn_jump:
		MobileInputManager.release_jump()


## Dokunuş bitti/iptal: o parmağın tuttuğu düğme ve joystick bırakılır (gate'ten bağımsız).
func _release_touch_index(index: int) -> void:
	if _btn_touch.has(index):
		var btn: HudTouchButton = _btn_touch[index]
		_btn_touch.erase(index)
		if is_instance_valid(btn):
			_release_button(btn)
	if index == _joy_touch_index:
		_release_joystick()


func _release_all_buttons() -> void:
	for idx in _btn_touch.keys():
		var btn: HudTouchButton = _btn_touch[idx]
		if is_instance_valid(btn):
			_release_button(btn)
	_btn_touch.clear()


func _button_at(pos: Vector2) -> HudTouchButton:
	var best: HudTouchButton = null
	var best_d := INF
	for k in _buttons_by_name:
		var b: HudTouchButton = _buttons_by_name[k]
		if not b.is_visible_in_tree() or not buttons_root.visible:
			continue
		var d := b.hit_distance(pos)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = b
	return best


## HUD dışından (oynanış) çağrılır: 1.0 = bekleme başladı, 0.0 = hazır.
## Adlar: attack, dash, interact, jump, skill
func set_button_cooldown(button_name: StringName, ratio: float) -> void:
	var b: HudTouchButton = _buttons_by_name.get(StringName(String(button_name).to_lower()))
	if b:
		b.cooldown = ratio


func _input(event: InputEvent) -> void:
	# Dokunmatikte motor her dokunuşa ek bir "taklit fare" olayı üretir. Aynı dokunuş iki kez
	# işlenirse diyaloğu kapatan dokunuş joystick'i de başlatıyordu (kendi kendine koşma).
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and not _touch_seen:
		_touch_seen = true
		_update_control_visibility()
	# Bırakmalar her koşulda işlenir (kapı değişse bile takılı giriş kalmasın).
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_release_touch_index((event as InputEventScreenTouch).index)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		_release_touch_index(0)
	if _seal_waiting:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				_seal_press(str(event.keycode - KEY_0))
			elif event.keycode == KEY_BACKSPACE:
				_seal_press("Sil")
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_seal_press("OK")
			elif event.keycode == KEY_ESCAPE:
				_seal_result = ""
				_seal_waiting = false
			get_viewport().set_input_as_handled()
		return
	if UiGate.blocks_dialogue_advance():
		return
	## Seçici açıkken Tab sıradaki nesneye geçer.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB 			and _chooser != null and _chooser.visible and not DialogueManager.is_open:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("cycle_interaction"):
			pl.cycle_interaction()
			_hint_tick = 0.0
		get_viewport().set_input_as_handled()
		return
	if DialogueManager.is_open and DialogueManager.has_choices():
		## Seçim açıkken: yukarı/aşağı vurgu, panel dokunuşu yok (butonlar kendi basışını alır).
		if event.is_action_pressed("ui_up"):
			DialogueManager.move_choice(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			DialogueManager.move_choice(1)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			return
	if UiGate.current_layer() == UiGate.Layer.DEATH:
		# Ölüm sahnesi: joystick/düğme yok; yalnız yas/uyanış diyaloğu dokunuşla geçilebilir.
		if DialogueManager.is_open and _is_advance_press(event):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()
		return
	if UiGate.blocks_movement() and not DialogueManager.is_open:
		# Günlük/final: joystick yakalama yok
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			return
	if DialogueManager.is_open and event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _is_in_joystick_zone(st.position) and _button_at(st.position) == null:
			# Panel dokunuşu -> devam (joystick bölgesi hariç)
			if _is_in_dialogue_zone(st.position):
				DialogueManager.advance()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if DialogueManager.is_open and mb.pressed and not _is_in_joystick_zone(mb.position) and _button_at(mb.position) == null:
			if _is_in_dialogue_zone(mb.position):
				DialogueManager.advance()
				get_viewport().set_input_as_handled()
				return
		var fake := InputEventScreenTouch.new()
		fake.pressed = mb.pressed
		fake.position = mb.position
		fake.index = 0
		_handle_touch(fake)
	elif event is InputEventMouseMotion and _joy_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag := InputEventScreenDrag.new()
		drag.position = (event as InputEventMouseMotion).position
		drag.index = 0
		_handle_drag(drag)


func _in_float_zone(screen_pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	return screen_pos.x < vp.x * 0.5 and screen_pos.y > vp.y * 0.5


func _is_in_joystick_zone(screen_pos: Vector2) -> bool:
	if not joystick_root.visible:
		return false
	if MobileInputManager.floating_joystick:
		return _in_float_zone(screen_pos)
	var local: Vector2 = _touch_to_joystick_local(screen_pos)
	var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
	return local.distance_to(center) <= _joy_accept


func _is_in_dialogue_zone(screen_pos: Vector2) -> bool:
	if not dialogue_panel.visible:
		return false
	var r := dialogue_panel.get_global_rect()
	return r.has_point(screen_pos)


func _touch_to_joystick_local(screen_pos: Vector2) -> Vector2:
	var xform: Transform2D = joystick_base.get_parent().get_global_transform_with_canvas()
	return xform.affine_inverse() * screen_pos


## Yüzen mod: joystick tabanını dokunuş noktasına taşı (güvenli alan içinde tut).
func _recenter_joystick(screen_pos: Vector2) -> void:
	var bounds := safe_area.get_global_rect().grow(-_joy_radius)
	var target := Vector2(
		clampf(screen_pos.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x)),
		clampf(screen_pos.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y)))
	var center_local: Vector2 = joystick_base.position + joystick_base.size * 0.5
	joystick_root.global_position = target - center_local


func _restore_joystick_home() -> void:
	joystick_root.offset_left = _joy_home.x
	joystick_root.offset_top = _joy_home.y
	joystick_root.offset_right = _joy_home.z
	joystick_root.offset_bottom = _joy_home.w


func _is_advance_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	return false


func _handle_touch(event: InputEventScreenTouch) -> void:
	if not event.pressed:
		_release_touch_index(event.index)
		return
	var btn := _button_at(event.position)
	if btn != null:
		_press_button(btn, event.index)
		return
	if _chooser_hit(event.position):
		get_viewport().set_input_as_handled()
		return
	if UiGate.blocks_movement():
		return
	if _joy_active:
		return
	if MobileInputManager.floating_joystick:
		if not _in_float_zone(event.position):
			return
		_recenter_joystick(event.position)
	else:
		var l0: Vector2 = _touch_to_joystick_local(event.position)
		var c0: Vector2 = joystick_base.position + joystick_base.size * 0.5
		if l0.distance_to(c0) > _joy_accept:
			return
	_joy_active = true
	_joy_touch_index = event.index
	var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
	_update_joy(_touch_to_joystick_local(event.position), center)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _joy_active or event.index != _joy_touch_index:
		return
	if UiGate.blocks_movement():
		_release_joystick()
		return
	var local: Vector2 = _touch_to_joystick_local(event.position)
	var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
	_update_joy(local, center)


func _update_joy(local: Vector2, center: Vector2) -> void:
	var offset := (local - center).limit_length(_joy_radius)
	joystick_thumb.position = center + offset - joystick_thumb.size * 0.5
	MobileInputManager.set_move_vector(offset / _joy_radius)


func _release_joystick() -> void:
	_joy_active = false
	_joy_touch_index = -1
	MobileInputManager.set_move_vector(Vector2.ZERO)
	if joystick_base and joystick_thumb:
		var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
		joystick_thumb.position = center - joystick_thumb.size * 0.5
	if joystick_root:
		_restore_joystick_home()


## Buton boyutu ayarı (%80..%120): düğmeler sağ-alt köşeye, joystick sol-alt köşeye göre ölçeklenir;
## gerçek boyutlar değiştiği için dokunma alanı ve güvenli alan denetimi aynen çalışır.
func apply_button_scale() -> void:
	if buttons_root == null or joystick_root == null or _btn_home.is_empty():
		return
	var s := GameSettings.button_scale()
	var cw := buttons_root.offset_right - buttons_root.offset_left
	var ch := buttons_root.offset_bottom - buttons_root.offset_top
	## Küme sağ-alt köşeye göre ölçeklenir. Interact için üst sınır: üstteki diyalog panelinin alt kenarı + 2 px.
	var cap := 99.0
	if dialogue_panel != null and safe_area != null:
		var h_i: Vector4 = _btn_home[&"interact"]
		var room := safe_area.size.y + buttons_root.offset_top + ch - (dialogue_panel.offset_bottom + 2.0)
		cap = maxf(room / maxf(1.0, ch - h_i.y), 0.86)
	for bn in _buttons_by_name:
		var b: Control = _buttons_by_name[bn]
		var h: Vector4 = _btn_home[bn]
		var bs := s
		if bn == &"interact":
			if _interact_in_corner:
				h = _btn_home[&"jump"]
			else:
				bs = minf(s, cap)
				## Zıpla'nın soluna 8 birim boşlukla dizilir; bağlam ipucu yazısına (ortalı) taşmaz.
				var hj: Vector4 = _btn_home[&"jump"]
				var jump_left := cw - (cw - hj.x) * s
				var room_x := safe_area.size.x * 0.5 + buttons_root.offset_left + cw - 94.0
				bs = minf(bs, maxf((jump_left - 8.0 * s - cw + room_x) / maxf(1.0, h.z - h.x), 0.86))
				b.offset_right = minf(cw - (cw - h.z) * bs, jump_left - 8.0 * s)
				b.offset_left = b.offset_right - (h.z - h.x) * bs
				b.offset_top = ch - (ch - h.y) * bs
				b.offset_bottom = ch - (ch - h.w) * bs
				continue
		elif bn == &"dash" and safe_area != null:
			## Bağlam ipucu yazısı (ortalı, ~92 px yarıçap) ile Dash'in arasında 2 px pay bırak.
			var roomx := safe_area.size.x * 0.5 + buttons_root.offset_left + cw - 94.0
			bs = minf(s, maxf(roomx / maxf(1.0, cw - h.x), 0.86))
		b.offset_left = cw - (cw - h.x) * bs
		b.offset_right = cw - (cw - h.z) * bs
		b.offset_top = ch - (ch - h.y) * bs
		b.offset_bottom = ch - (ch - h.w) * bs
	var js := JOY_BASE_SIZE * s
	var bottom := -JOY_MARGIN_Y
	_joy_home = Vector4(JOY_MARGIN_X, bottom - js, JOY_MARGIN_X + js, bottom)
	_restore_joystick_home()
	joystick_base.offset_left = 0.0
	joystick_base.offset_top = 0.0
	joystick_base.offset_right = js
	joystick_base.offset_bottom = js
	joystick_thumb.offset_left = js * 0.25
	joystick_thumb.offset_top = js * 0.25
	joystick_thumb.offset_right = js * 0.75
	joystick_thumb.offset_bottom = js * 0.75
	_joy_radius = JOY_RADIUS * s
	_joy_accept = JOY_ACCEPT * s
	if _onboard_root != null and _onboard_root.visible:
		_place_onboarding.call_deferred()


## --- Hedef vurgusu (nabız) ---
var _obj_tween: Tween
var _obj_last_text: String = ""
var _obj_pulse_pending: bool = false
var _obj_session_pulsed: bool = false
var _obj_free_time: float = 0.0


func _can_pulse_objective() -> bool:
	return UiGate.current_layer() == UiGate.Layer.NONE and not DialogueManager.is_open and not DeathManager.is_dying


## Hedef etiketi ~1.2 sn parlar + kısa titreşim. Önceki tween öldürülür.
func pulse_objective() -> void:
	if _objective == null:
		return
	if _obj_tween != null and _obj_tween.is_valid():
		_obj_tween.kill()
	_objective.modulate = Color(1.9, 1.55, 0.95, 1.0)
	_obj_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_obj_tween.tween_property(_objective, "modulate", Color.WHITE, 1.2)
	MobileInputManager.vibrate(15)
	_obj_pulse_pending = false


## Hedef metni gerçekten değiştiyse nabız: diyalog/sahne sürerken beklemeye alınır.
func _note_objective_text(text: String) -> void:
	var changed := _obj_last_text != "" and text != _obj_last_text
	_obj_last_text = text
	if changed:
		if _can_pulse_objective():
			pulse_objective()
		else:
			_obj_pulse_pending = true


func _tick_objective_pulse(delta: float) -> void:
	if not _can_pulse_objective():
		_obj_free_time = 0.0
		return
	_obj_free_time += delta
	if _obj_pulse_pending and _obj_free_time >= 0.5:
		pulse_objective()
	elif not _obj_session_pulsed and _obj_free_time >= 2.0:
		## Oturumda kontrol ilk kez oyuncudayken (yeni oyun/uyanış dahil) hedef bir kez vurgulanır.
		_obj_session_pulsed = true
		pulse_objective()


## --- Ölüm döngüsü yardımı ---
var _helper_label: Label
var _helper_tween: Tween


func _on_death_loop_helper(room_id: StringName) -> void:
	var hint := PuzzleManager.helper_hint_for_room(room_id)
	if hint == "":
		pulse_objective() ## odaya özel ipucu yok: hedefi nabızla yeniden göster
		return
	if _helper_label == null:
		_helper_label = Label.new()
		_helper_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_helper_label.offset_left = -130.0
		_helper_label.offset_right = 130.0
		_helper_label.offset_top = -100.0
		_helper_label.offset_bottom = -58.0
		_helper_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_helper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_helper_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_helper_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.apply_outlined(_helper_label, UiTheme.HINT, false, Color(0.95, 0.9, 0.7))
		safe_area.add_child(_helper_label)
	_helper_label.text = "Takıldın mı? Küçük bir ipucu:\n" + hint
	_helper_label.modulate.a = 1.0
	_helper_label.visible = true
	if _helper_tween != null and _helper_tween.is_valid():
		_helper_tween.kill()
	_helper_tween = create_tween()
	_helper_tween.tween_interval(7.0)
	_helper_tween.tween_property(_helper_label, "modulate:a", 0.0, 0.6)
	_helper_tween.tween_callback(func(): _helper_label.visible = false)


## --- Dokunmatik ilk açılış ipucu ---
var _onboard_root: Control
var _onboard_joy: Label
var _onboard_btn: Label
var _onboard_time: float = 0.0


func _tick_onboarding(delta: float, playable: bool) -> void:
	if GameSettings.touch_onboarding_done:
		return
	var touch := _touch_seen or MobileInputManager.is_touch_ui()
	if not touch or not playable or DialogueManager.is_open:
		if _onboard_root != null:
			_onboard_root.visible = false
		return
	if _onboard_root == null:
		_build_onboarding()
	if not _onboard_root.visible:
		_onboard_root.visible = true
		_place_onboarding()
	_onboard_time += delta
	if MobileInputManager.move_vector.length() > 0.2 or not _btn_touch.is_empty() or _onboard_time >= 6.0:
		_finish_onboarding()


func _build_onboarding() -> void:
	_onboard_root = Control.new()
	_onboard_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_onboard_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_area.add_child(_onboard_root)
	_onboard_joy = _onboard_label("Sol tarafa dokunup sürükle: yürü", HORIZONTAL_ALIGNMENT_LEFT)
	_onboard_btn = _onboard_label("Sağdaki tuşlar: zıpla, saldır, atıl", HORIZONTAL_ALIGNMENT_RIGHT)


func _onboard_label(text: String, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(170, 30)
	UiTheme.apply_outlined(l, UiTheme.HINT, false, Color(0.95, 0.9, 0.7))
	_onboard_root.add_child(l)
	return l


## Etiketler joystick'in ve düğme kümesinin hemen üstüne (güvenli alan içinde) yerleşir.
func _place_onboarding() -> void:
	if _onboard_root == null:
		return
	var origin := safe_area.get_global_rect().position
	var sz := safe_area.size
	var jr := joystick_base.get_global_rect().position - origin
	_onboard_joy.position = Vector2(clampf(jr.x, 4.0, maxf(4.0, sz.x - 174.0)), maxf(4.0, jr.y - 34.0))
	var top := sz.y
	for bn in [&"attack", &"dash", &"jump", &"interact"]:
		var b: Control = _buttons_by_name[bn]
		top = minf(top, b.get_global_rect().position.y - origin.y)
	_onboard_btn.position = Vector2(maxf(4.0, sz.x - 174.0), maxf(4.0, top - 34.0))


func _finish_onboarding() -> void:
	GameSettings.touch_onboarding_done = true
	GameSettings.save_settings()
	if _onboard_root != null:
		_onboard_root.visible = false


func _refresh_objective_now(_room_id: StringName = &"") -> void:
	if _objective == null:
		return
	_objective.text = GameState.get_current_objective()
	_note_objective_text(_objective.text)
	_layout_objective_and_hint()
	_layout_objective_and_hint.call_deferred()


## Hedef 2 satira sarinca kontrol ipucunu altina iter (ust uste binmesin).
func _layout_objective_and_hint() -> void:
	if _objective == null or hint_label == null:
		return
	_fit_guidance_width()
	var lines: int = maxi(1, _objective.get_line_count())
	var h: float = float(lines * _objective.get_line_height()) + 4.0
	_objective.size = Vector2(_objective.size.x, h)
	hint_label.position.y = _objective.position.y + h + 2.0


## Hedef/ipucu yazısı her en-boy oranında güvenli alanın içinde kalır: sol >= 8, sağ günlük
## düğmesinin (76px) soluna kadar; dar ekranda genişlik daralır ve yazı sarılır.
const GUIDE_LEFT := 12.0
const GUIDE_MAX_W := 440.0
const GUIDE_RIGHT_RESERVE := 84.0


var _guide_fit_width: float = -1.0


func _fit_guidance_width() -> void:
	if _objective == null or safe_area == null:
		return
	## Yalnız güvenli alan genişliği değişince yeniden uygula (her karede değil).
	if is_equal_approx(_guide_fit_width, safe_area.size.x):
		return
	_guide_fit_width = safe_area.size.x
	var avail := safe_area.size.x - GUIDE_LEFT - GUIDE_RIGHT_RESERVE
	if avail <= 0.0:
		avail = GUIDE_MAX_W
	var w := clampf(avail, 120.0, GUIDE_MAX_W)
	if absf(_objective.size.x - w) > 0.5 or _objective.position.x != GUIDE_LEFT:
		_objective.position.x = GUIDE_LEFT
		_objective.size.x = w
	hint_label.position.x = GUIDE_LEFT
	hint_label.size.x = w
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_puzzle_solved_objective(_puzzle_id: StringName) -> void:
	_refresh_objective_now()


func _on_puzzle_live_changed(_puzzle_id: StringName, _live: bool) -> void:
	_refresh_objective_now()


var _live_hint_timer: SceneTreeTimer = null


func _on_live_feedback(_puzzle_id: StringName, live: bool) -> void:
	if not live or hint_label == null:
		return
	hint_label.text = "Bir şey açıldı."
	hint_label.visible = true
	var t := get_tree().create_timer(2.5)
	_live_hint_timer = t
	await t.timeout
	## Yalnız en yeni zamanlayıcı satırı temizler.
	if t == _live_hint_timer and is_instance_valid(hint_label):
		_live_hint_timer = null
		_apply_default_hint()


func _setup_guidance() -> void:
	_objective = Label.new()
	_objective.position = Vector2(12, 44)
	_objective.size = Vector2(440, 32)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(_objective, UiTheme.HINT, false, Color(0.95, 0.88, 0.8))
	safe_area.add_child(_objective)
	_context_hint = Label.new()
	# Alt orta: anchor ile ortali (genis ekranda da ortada).
	_context_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_context_hint.offset_left = -220.0
	_context_hint.offset_right = 220.0
	_context_hint.offset_top = -52.0
	_context_hint.offset_bottom = -16.0
	_context_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_hint.clip_text = false
	_context_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(_context_hint, UiTheme.BODY, true)
	safe_area.add_child(_context_hint)
	_chooser = VBoxContainer.new()
	_chooser.name = "InteractChooser"
	_chooser.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_chooser.offset_left = -96.0
	_chooser.offset_right = 96.0
	_chooser.offset_top = -14.0
	_chooser.offset_bottom = -14.0
	_chooser.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chooser.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chooser.add_theme_constant_override("separation", 2)
	_chooser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chooser.visible = false
	safe_area.add_child(_chooser)
	_refresh_objective_now()


func _process(delta: float) -> void:
	if _objective == null:
		return
	var playable := UiGate.current_layer() == UiGate.Layer.NONE
	_objective.visible = playable
	_context_hint.visible = playable
	if not playable:
		_hide_chooser()
	if _helper_label != null:
		_helper_label.visible = _helper_label.visible and playable
	hint_label.visible = playable and not (_touch_seen or MobileInputManager.is_touch_ui())
	_fit_guidance_width()
	_tick_objective_pulse(delta)
	_tick_onboarding(delta, playable)
	_tick_toasts(delta, playable)
	_badge_tick -= delta
	if _badge_tick <= 0.0:
		_badge_tick = 0.4
		_refresh_journal_badge()
	_hint_tick -= delta
	if _hint_tick > 0.0 or not playable:
		return
	_hint_tick = 0.15
	var obj_text := GameState.get_current_objective()
	if obj_text != _objective.text:
		_objective.text = obj_text
		_note_objective_text(obj_text)
		_layout_objective_and_hint()
	var player := get_tree().get_first_node_in_group("player")
	_context_hint.text = ""
	var touch_hint: bool = _touch_seen or MobileInputManager.is_touch_ui()
	var cands: Array = []
	var target: Node2D = null
	if player and player.has_method("get_interaction_target"):
		target = player.get_interaction_target()
		if target and player.has_method("get_interaction_candidates"):
			cands = player.get_interaction_candidates()
	if cands.size() >= 2 and cands.has(target):
		_refresh_chooser(cands, target, touch_hint)
	else:
		_hide_chooser()
		if target:
			_context_hint.text = ("El · " if touch_hint else "E · ") + _target_label(target)
	btn_interact.modulate = Color(1.3, 1.12, 1.12) if target else Color.WHITE


func _target_label(target: Node2D) -> String:
	var target_name := InteractGlowLib.label_for(target)
	if target_name == "İncele" or target.has_method("apply_push"):
		target_name = _friendly_target(String(target.name))
	return target_name


## Seçici satırlarını yeniden kur: seçili satır parlak ve "El ·" önekli, diğerleri soluk.
func _refresh_chooser(cands: Array, selected: Node2D, touch_hint: bool) -> void:
	var list: Array = cands.slice(0, CHOOSER_MAX)
	if not list.has(selected):
		list[list.size() - 1] = selected
	_chooser_targets = list
	while _chooser.get_child_count() < list.size():
		_chooser.add_child(_make_chooser_row())
	for i in _chooser.get_child_count():
		var row := _chooser.get_child(i) as PanelContainer
		if i >= list.size():
			row.visible = false
			continue
		row.visible = true
		var on: bool = list[i] == selected
		var lbl := row.get_child(0) as Label
		var key := ("El · " if touch_hint else "E · ") if on else ""
		lbl.text = ("▸ " if on else "   ") + key + _target_label(list[i])
		lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78) if on else Color(0.78, 0.74, 0.8))
		var sb := row.get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = Color(0.2, 0.08, 0.1, 0.72) if on else Color(0.04, 0.03, 0.06, 0.5)
		sb.border_color = Color(0.9, 0.55, 0.45, 0.85) if on else Color(0.5, 0.45, 0.55, 0.35)
	_chooser.visible = true


func _make_chooser_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	row.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTheme.apply_outlined(lbl, UiTheme.HINT, false)
	row.add_child(lbl)
	return row


func _hide_chooser() -> void:
	if _chooser != null and _chooser.visible:
		_chooser.visible = false
	_chooser_targets = []


## Seçici satırına dokunuş: o nesneyi seç ve kullan. Dokunuş joystick'e gitmez.
func _chooser_hit(pos: Vector2) -> bool:
	if _chooser == null or not _chooser.visible or UiGate.current_layer() != UiGate.Layer.NONE:
		return false
	for i in mini(_chooser_targets.size(), _chooser.get_child_count()):
		var row := _chooser.get_child(i) as Control
		if row.visible and row.get_global_rect().grow(2.0).has_point(pos):
			var t: Node2D = _chooser_targets[i]
			var player := get_tree().get_first_node_in_group("player")
			if is_instance_valid(t) and player and player.has_method("interact_with"):
				player.interact_with(t)
				_hint_tick = 0.0
			return true
	return false


func _friendly_target(node_name: String) -> String:
	var n := node_name.to_lower()
	if "keeper" in n or "shilda" in n:
		return GameState.keeper_speaker_name() + " ile konuş"
	if "exit" in n or "transition" in n or "portal" in n or "door" in n:
		return "Geçidi kullan"
	if "seal" in n:
		return "Mührü incele"
	if "echo" in n:
		return "Yankıyı dinle"
	if "stone" in n:
		return "Ağırlığı it"
	if "lever" in n or "reset" in n:
		return "Kolu çek"
	if "clock" in n or "watch" in n:
		return "Saati incele"
	if "flower" in n:
		return "Çiçeği incele"
	return "İncele / konuş"


func _update_control_visibility_arg(_a = null) -> void:
	_update_control_visibility()


## --- Oda başlığı ---
func _setup_room_header() -> void:
	_header_label = get_node_or_null("SafeArea/RoomHeader/RoomHeaderLabel") as Label
	if _header_label == null:
		return
	UiTheme.apply_outlined(_header_label, UiTheme.SPEAKER, true, Color(0.92, 0.86, 0.95))
	_header_label.text = RoomManager.get_room_number_and_title(StringName(String(GameState.character_current_life_knowledge.get("room", &"awakening"))))
	_fit_room_header()


## Başlık kutusu metne göre büyür: yazı genişliği + iki yan süs payı, [MIN, MAX] arası.
const HEADER_MIN_W := 220.0
const HEADER_MAX_W := 440.0
const HEADER_INSET := 28.0 ## RoomHeaderLabel yan boşluğu (hud.tscn offset_left/right ile aynı)


## Verilen metin için gereken kutu genişliği (sıkıştırılmamış). Audit de bunu kullanır.
static func header_needed_width(text: String, font: Font, font_size: int) -> float:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# +6: dış çizgi (outline 3px x2) taşması
	return ceilf(tw) + 6.0 + HEADER_INSET * 2.0


func _fit_room_header() -> void:
	if _header_label == null:
		return
	var box := _header_label.get_parent() as Control
	var font: Font = _header_label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var fsize := _header_label.get_theme_font_size("font_size")
	var w := clampf(header_needed_width(_header_label.text, font, fsize), HEADER_MIN_W, HEADER_MAX_W)
	box.offset_left = -w * 0.5
	box.offset_right = w * 0.5


func _on_room_header_changed(room_id: StringName) -> void:
	if _header_label == null:
		return
	_header_label.text = RoomManager.get_room_number_and_title(room_id)
	_fit_room_header()
	var box := _header_label.get_parent() as Control
	if _header_tween and _header_tween.is_valid():
		_header_tween.kill()
	# Giriş parıltısı: kısa süre parlak, sonra kalıcı.
	box.modulate = Color(1.7, 1.45, 1.1, 1.0)
	_header_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_header_tween.tween_property(box, "modulate", Color.WHITE, 1.4)


## --- Diyalog portresi ---
func _setup_portrait() -> void:
	if dialogue_panel == null:
		return
	_medallion = MedallionScript.new()
	_medallion.name = "PortraitMedallion"
	_medallion.position = MEDALLION_POS
	dialogue_panel.add_child(_medallion)


func _apply_portrait_inset(inset: float) -> void:
	_portrait_inset = inset
	var margin := get_node_or_null("SafeArea/Dialogue/Margin") as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", DIALOGUE_MARGIN_BASE + int(inset))


func _update_portrait(speaker: String) -> void:
	if _medallion == null:
		return
	var sad := DialogueManager.last_was_whisper or DeathManager.is_dying
	var key: StringName = PortraitsLib.key_for(speaker, sad)
	var changed := speaker != _portrait_speaker
	_portrait_speaker = speaker
	_apply_portrait_inset(PortraitsLib.TEXT_INSET if key != &"" else 0.0)
	_medallion.show_key(key, changed)


## --- Kısa bildirimler (toast): ölüm sinematiği/diyalog sürerken kuyrukta bekler ---
const TOAST_CORPSE_LOST := "En eski bedenin toprağa karıştı."
const TOAST_PUZZLE_RESET := "Bu odadaki düzenek sıfırlandı."
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_time_left: float = 0.0
var _toast_shown_log: Array[String] = [] ## test/audit: gösterilen metinler


func _on_corpse_lost_to_limit(_trace: Dictionary) -> void:
	queue_toast(TOAST_CORPSE_LOST)


func queue_toast(text: String) -> void:
	if text == "" or _toast_queue.has(text):
		return
	_toast_queue.append(text)
	_flush_toasts()


func _toast_allowed() -> bool:
	return UiGate.current_layer() == UiGate.Layer.NONE and not DeathManager.is_dying and not DialogueManager.is_open


func _flush_toasts() -> void:
	if _toast_queue.is_empty() or _toast_time_left > 0.0 or not _toast_allowed():
		return
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		## Dar tutulur: orta-alt şeritte Skill/Zıpla düğmelerine binmesin (mobile_layout_audit).
		_toast_label.offset_left = -70.0
		_toast_label.offset_right = 70.0
		_toast_label.offset_top = -170.0
		_toast_label.offset_bottom = -112.0
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.apply_outlined(_toast_label, UiTheme.HINT, false, Color(0.88, 0.84, 0.95))
		safe_area.add_child(_toast_label)
	var text: String = _toast_queue.pop_front()
	_toast_shown_log.append(text)
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	_toast_time_left = 3.6


func _tick_toasts(delta: float, playable: bool) -> void:
	if _toast_label != null and _toast_label.visible:
		_toast_label.visible = playable
	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_label != null:
			_toast_label.modulate.a = clampf(_toast_time_left / 0.6, 0.0, 1.0)
		if _toast_time_left <= 0.0 and _toast_label != null:
			_toast_label.visible = false
		return
	_flush_toasts()


## Kayıttan yükleme/odaya giriş: canlı ilerlemesi sıfırlanan bulmaca varsa tek seferlik not.
func _check_puzzle_reset_notice(_arg = null) -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	var room := RoomManager.get_active_room_id()
	if room != &"" and PuzzleManager.take_reset_notice(room):
		queue_toast(TOAST_PUZZLE_RESET)


## --- Günlük "yeni" rozeti ---
var _journal_dot: Panel
var _badge_tick: float = 0.0
var _badge_state: bool = false


func _setup_journal_badge() -> void:
	_journal_dot = Panel.new()
	_journal_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_journal_dot.offset_left = -16.0
	_journal_dot.offset_right = -4.0
	_journal_dot.offset_top = 4.0
	_journal_dot.offset_bottom = 16.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.25, 0.3)
	sb.border_color = Palette.IVORY
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	_journal_dot.add_theme_stylebox_override("panel", sb)
	_journal_dot.visible = false
	btn_journal.add_child(_journal_dot)


func _refresh_journal_badge() -> void:
	if _journal_dot == null:
		return
	var on := GameState.journal_any_unseen()
	_journal_dot.visible = on
	if on != _badge_state:
		_badge_state = on
		if hint_label.text.begins_with("WASD"):
			_apply_default_hint()
