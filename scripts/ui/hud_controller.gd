extends CanvasLayer
## Kalpler + mobil kontroller + hikâye diyaloğu (atlas çerçeve) + mühür girişi.

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
@onready var dialogue_continue: Label = $SafeArea/Dialogue/Continue
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

## Panel PNG ana çerçeve (alpha bileşen); alttaki süs hariç.
## Kaynak: docs/.../panel_olcumleri.json → dialogue [62,3,257,115)
const DIALOGUE_ATLAS := Rect2(61, 2, 197, 114)
## Sigil süsü (atlas bölgesi içinde): sütun aralığı, satır sayısı, yedek düz kenar şeridi.
const SIGIL_X0 := 76
const SIGIL_X1 := 135
const SIGIL_ROWS := 46
const SIGIL_SRC_X := 44
const SIGIL_SRC_W := 32

var _seal_buffer: String = ""
var _seal_waiting: bool = false
var _seal_result: String = ""
var _objective: Label
var _context_hint: Label
var _hint_tick: float = 0.0


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
	GameState.knowledge_changed.connect(_refresh_objective_now)
	PuzzleManager.puzzle_solved.connect(_on_puzzle_solved_objective)
	DialogueManager.page_shown.connect(_on_dialogue_page)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	DialogueManager.dialogue_cancelled.connect(_on_dialogue_closed)
	DialogueManager.typing_finished.connect(_on_typing_finished)
	dialogue_panel.visible = false
	_apply_default_hint()
	btn_journal.pressed.connect(_toggle_journal)
	_journal = get_tree().get_first_node_in_group("journal_ui") as CanvasLayer
	get_tree().root.size_changed.connect(_apply_safe_area)
	UiGate.gate_changed.connect(_on_gate_changed)
	_update_control_visibility()
	_setup_guidance()
	call_deferred("_sync_dialogue_metrics")


func _apply_fonts() -> void:
	## Pixeloid hiyerarşi: hint 10 · body 12 · speaker 13 · continue 10 · seal 13/20
	UiTheme.apply_outlined(hint_label, UiTheme.HINT, false, Palette.PALE_LILAC)
	UiTheme.apply_outlined(dialogue_speaker, UiTheme.SPEAKER, true)
	UiTheme.apply_outlined(dialogue_text, UiTheme.BODY, false)
	dialogue_text.add_theme_constant_override("line_spacing", 2)
	UiTheme.apply_outlined(dialogue_continue, UiTheme.HINT, false, Palette.PALE_LILAC)
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
	btn_skill.texture_normal = load("res://assets/hud/speech.png")
	btn_jump.texture_normal = load("res://assets/hud/joystick_thumb.png")
	btn_journal.texture_normal = load("res://assets/hud/journal.png")
	if dialogue_panel:
		_build_dialogue_frame()
		dialogue_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## dialogue.png üst orta "sigil" süsü yatayda gerilince bozulur: sigil sütunları düz kenarla
## değiştirilir ve süs ayrı (gerilmeyen) bir TextureRect olarak üstte çizilir.
func _build_dialogue_frame() -> void:
	var src: Texture2D = load("res://assets/panels/dialogue.png")
	var region := Rect2i(int(DIALOGUE_ATLAS.position.x), int(DIALOGUE_ATLAS.position.y), int(DIALOGUE_ATLAS.size.x), int(DIALOGUE_ATLAS.size.y))
	var img: Image = src.get_image() if src else null
	if img == null or img.is_empty() or img.is_compressed():
		var atlas := AtlasTexture.new()
		atlas.atlas = src
		atlas.region = DIALOGUE_ATLAS
		dialogue_panel.texture = atlas
		return
	var base: Image = img.get_region(region)
	var patched: Image = base.duplicate()
	for y in range(0, SIGIL_ROWS):
		for x in range(SIGIL_X0, SIGIL_X1):
			patched.set_pixel(x, y, base.get_pixel(SIGIL_SRC_X + (x - SIGIL_X0) % SIGIL_SRC_W, y))
	dialogue_panel.texture = ImageTexture.create_from_image(patched)
	var sigil := TextureRect.new()
	sigil.name = "Sigil"
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = Rect2(region.position.x + SIGIL_X0, region.position.y, SIGIL_X1 - SIGIL_X0, SIGIL_ROWS)
	sigil.texture = at
	sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.stretch_mode = TextureRect.STRETCH_SCALE
	sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sigil.anchor_left = 0.5
	sigil.anchor_right = 0.5
	sigil.offset_left = -float(SIGIL_X1 - SIGIL_X0) * 0.5
	sigil.offset_right = float(SIGIL_X1 - SIGIL_X0) * 0.5
	sigil.offset_top = 0.0
	sigil.offset_bottom = float(SIGIL_ROWS)
	dialogue_panel.add_child(sigil)


func _setup_seal_pad() -> void:
	for c in seal_row.get_children():
		c.queue_free()
	# HBox yerine 4 sütunluk ızgara
	var pad := VBoxContainer.new()
	pad.add_theme_constant_override("separation", 4)
	seal_row.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	pad.add_child(grid)
	var keys: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "⌫", "OK"]
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
		"⌫":
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
	call_deferred("_sync_dialogue_metrics")


## Masaüstünde tuş özeti; mobilde butonlar zaten görünür, ipucu gizli kalır.
func _apply_default_hint() -> void:
	hint_label.text = "WASD · Z saldır · X dash · E etkileş · I günlük"
	hint_label.visible = not MobileInputManager.is_touch_ui()


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
	var w := dialogue_text.size.x - 12.0
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
	if UiGate.current_layer() == UiGate.Layer.ENDING:
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
	var shown := speaker
	while shown.length() > 1 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w:
		shown = shown.substr(0, shown.length() - 1)
	if shown != speaker:
		if shown.length() > 1:
			shown = shown.substr(0, shown.length() - 1) + "…"
		else:
			shown = "…"
	dialogue_speaker.text = shown
	dialogue_text.text = text
	var more := page_index < page_count - 1 or DialogueManager.has_queued_lines() or DialogueManager.is_typing()
	dialogue_continue.text = "…" if DialogueManager.is_typing() else ("▼" if more else "■")
	hint_label.visible = false
	_update_control_visibility()


func _on_typing_finished() -> void:
	if dialogue_panel.visible:
		dialogue_continue.text = "▼"


func _on_dialogue_closed() -> void:
	dialogue_panel.visible = false
	_apply_default_hint()
	_update_control_visibility()


func _on_gate_changed(_layer: UiGate.Layer) -> void:
	_update_control_visibility()
	if UiGate.blocks_gameplay_input():
		_release_joystick()
		_release_all_buttons()


func _update_control_visibility() -> void:
	var blocked := UiGate.blocks_gameplay_input()
	# Hikâye diyaloğunda hareket/saldırı/dash gizlenir; etkileş devam için kalır.
	joystick_root.visible = not blocked
	btn_attack.visible = not blocked
	btn_dash.visible = not blocked
	btn_jump.visible = not blocked
	btn_skill.visible = not blocked
	btn_interact.visible = not UiGate.blocks_dialogue_advance() and UiGate.current_layer() != UiGate.Layer.DEATH
	btn_journal.visible = UiGate.current_layer() != UiGate.Layer.ENDING
	buttons_root.modulate.a = 1.0 if btn_interact.visible or btn_attack.visible else 0.0


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
				_seal_press("⌫")
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_seal_press("OK")
			elif event.keycode == KEY_ESCAPE:
				_seal_result = ""
				_seal_waiting = false
			get_viewport().set_input_as_handled()
		return
	if UiGate.blocks_dialogue_advance() or UiGate.current_layer() == UiGate.Layer.DEATH:
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


func _on_puzzle_solved_objective(_puzzle_id: StringName) -> void:
	_refresh_objective_now()


func _setup_guidance() -> void:
	_objective = Label.new()
	_objective.position = Vector2(12, 68)
	_objective.size = Vector2(440, 44)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(_objective, UiTheme.HINT, false, Color(0.95, 0.88, 0.8))
	safe_area.add_child(_objective)
	_context_hint = Label.new()
	# Alt orta: anchor ile ortali (genis ekranda da ortada).
	_context_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_context_hint.offset_left = -140.0
	_context_hint.offset_right = 140.0
	_context_hint.offset_top = -44.0
	_context_hint.offset_bottom = -14.0
	_context_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_hint_tick -= delta
	if _hint_tick > 0.0 or not playable:
		return
	_hint_tick = 0.15
	_objective.text = GameState.get_current_objective()
	var player := get_tree().get_first_node_in_group("player")
	_context_hint.text = ""
	if player and player.has_method("get_interaction_target"):
		var target: Node2D = player.get_interaction_target()
		if target:
			var target_name := _friendly_target(String(target.name))
			_context_hint.text = "E / el · " + target_name
			btn_interact.modulate = Color(1.3, 1.12, 1.12)
		else:
			btn_interact.modulate = Color.WHITE


func _friendly_target(node_name: String) -> String:
	var n := node_name.to_lower()
	if "keeper" in n or "shilda" in n:
		return "Shilda ile konuş"
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
