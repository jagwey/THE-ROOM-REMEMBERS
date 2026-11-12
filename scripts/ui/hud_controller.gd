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
	hint_label.text = "WASD yürü · Z saldır · X atıl · E etkileş · I günlüğü aç"
	hint_label.visible = not (MobileInputManager.is_touch_ui() or _touch_seen)


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
	var max_w := maxf(40.0, dialogue_speaker.size.x)
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
		b.pressed.connect(DialogueManager.choose.bind(i))
		_choice_box.add_child(b)
	$SafeArea.add_child(_choice_box)
	_refresh_choice_highlight(DialogueManager.choice_index())
	await get_tree().process_frame
	if _choice_box == null or not is_instance_valid(_choice_box):
		return
	var r := dialogue_panel.get_global_rect()
	_choice_box.size = Vector2(r.size.x, 0)
	_choice_box.global_position = Vector2(r.position.x, r.position.y - _choice_box.size.y - 6.0)


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
	var layer := UiGate.current_layer()
	btn_journal.visible = layer == UiGate.Layer.NONE or layer == UiGate.Layer.JOURNAL
	buttons_root.modulate.a = 1.0 if btn_interact.visible or btn_attack.visible else 0.0
	## Göz açma sinematiği: kalp/hedef/düğme hiçbiri görünmez.
	## Günlük (kitap) açıkken de HUD gizli; günlük kendi kapat düğmesini taşır.
	var vis_layer := UiGate.current_layer()
	safe_area.visible = vis_layer != UiGate.Layer.CUTSCENE and vis_layer != UiGate.Layer.JOURNAL and vis_layer != UiGate.Layer.TITLE


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
	return local.distance_to(center) <= JOY_ACCEPT


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
	var bounds := safe_area.get_global_rect().grow(-JOY_RADIUS)
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
		if l0.distance_to(c0) > JOY_ACCEPT:
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
	var offset := (local - center).limit_length(JOY_RADIUS)
	joystick_thumb.position = center + offset - joystick_thumb.size * 0.5
	MobileInputManager.set_move_vector(offset / JOY_RADIUS)


func _release_joystick() -> void:
	_joy_active = false
	_joy_touch_index = -1
	MobileInputManager.set_move_vector(Vector2.ZERO)
	if joystick_base and joystick_thumb:
		var center: Vector2 = joystick_base.position + joystick_base.size * 0.5
		joystick_thumb.position = center - joystick_thumb.size * 0.5
	if joystick_root:
		_restore_joystick_home()


func _refresh_objective_now(_room_id: StringName = &"") -> void:
	if _objective == null:
		return
	_objective.text = GameState.get_current_objective()
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


func _fit_guidance_width() -> void:
	if _objective == null or safe_area == null:
		return
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
	hint_label.text = "Bir şey… açıldı."
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
	_objective.position = Vector2(12, 40)
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
	_refresh_objective_now()


func _process(delta: float) -> void:
	if _objective == null:
		return
	var playable := UiGate.current_layer() == UiGate.Layer.NONE
	_objective.visible = playable
	_context_hint.visible = playable
	hint_label.visible = playable and not (_touch_seen or MobileInputManager.is_touch_ui())
	_fit_guidance_width()
	_hint_tick -= delta
	if _hint_tick > 0.0 or not playable:
		return
	_hint_tick = 0.15
	var obj_text := GameState.get_current_objective()
	if obj_text != _objective.text:
		_objective.text = obj_text
		_layout_objective_and_hint()
	var player := get_tree().get_first_node_in_group("player")
	_context_hint.text = ""
	if player and player.has_method("get_interaction_target"):
		var target: Node2D = player.get_interaction_target()
		if target:
			var target_name := InteractGlowLib.label_for(target)
			if target_name == "İncele" or target.has_method("apply_push"):
				target_name = _friendly_target(String(target.name))
			var touch_hint: bool = _touch_seen or MobileInputManager.is_touch_ui()
			_context_hint.text = ("El · " if touch_hint else "E · ") + target_name
			btn_interact.modulate = Color(1.3, 1.12, 1.12)
		else:
			btn_interact.modulate = Color.WHITE


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
		return "Kolu kullan"
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
