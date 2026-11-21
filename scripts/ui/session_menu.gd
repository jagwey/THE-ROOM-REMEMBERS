extends CanvasLayer
## Başlık ekranı + duraklatma menüsü (masaüstü/mobil). Mantığı UiGate ile durdurur, animasyonu değil.
## Başlık yalnız uygulama açılışında bir kez gösterilir; headless/QA koşularında atlanır.

signal title_closed

const VOLUME_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
const TouchSettingsScroll := preload("res://scripts/ui/touch_settings_scroll.gd")
const TitleScreenScript := preload("res://scripts/ui/title_screen.gd")
const RoomTransitionScript := preload("res://scripts/world/room_transition.gd")

static var _title_shown: bool = false
## Kaydet ve Çık sonrası sahne yeniden yüklenince başlık (test ortamında da) açılır.
static var _force_title: bool = false

var _title_screen: Control
var _journal: CanvasLayer
var _book_menu: Control
var _menu_help: VBoxContainer
var _audio_box: VBoxContainer
var _continue_button: Button
var _settings_button: Button
var _quit_button: Button ## Kaydet ve Çık
var _main_menu_button: Button ## Ana Menüye Dön
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _joy_button: Button
var _jump_axis_button: Button
var _touch_picker: GothicModalPanel
var _layout_preview: Label
var _layout_buttons: Array[Button] = []
var _picker_jump: CheckButton
var _picker_layout: int
var _picker_confirm: Button
var _after_picker: Callable
var _fs_button: Button
var _haptics_button: Button
var _vol_button: Button
var _music_button: Button
var _music_vol_label: Label
var _sfx_vol_label: Label
var _text_speed_button: Button
var _shake_button: Button
var _font_button: Button
var _hint_button: Button
var _btn_scale_button: Button
var _settings_scroll: ScrollContainer
var _title_mode: bool = false
var _had_save: bool = false
var _confirm_panel: GothicModalPanel
var _confirm_text: Label
var _confirm_ok: Button
var _confirm_action: Callable
var _volume: float = 1.0
var _music_on: bool = true


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("session_menu")
	_had_save = SaveManager.has_save()
	_load_settings()
	_journal = get_tree().get_first_node_in_group("journal_ui") as CanvasLayer
	if _journal:
		_build_book_menu()
	_build_confirm()
	_build_touch_picker()
	_title_screen = TitleScreenScript.new()
	_title_screen.menu = self
	_title_screen.start_requested.connect(_request_start.bind(close_menu))
	_title_screen.new_game_requested.connect(_request_start.bind(_start_fresh))
	_title_screen.quit_requested.connect(_quit_app)
	add_child(_title_screen)
	if _should_show_title():
		_open_title()


func _build_book_menu() -> void:
	_book_menu = Control.new()
	_book_menu.name = "MenuContent"
	_book_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal.mount_menu(_book_menu)
	_journal.closed.connect(_on_book_closed)
	var left := _book_column(0.12, 0.47, 0.16)
	var right := _book_column(0.53, 0.87, 0.40)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 6)
	left.add_child(_main_box)
	_continue_button = _book_button(_main_box, "Devam Et", close_menu)
	_settings_button = _book_button(_main_box, "Ayarlar", _show_pause_page.bind(true))
	_quit_button = _book_button(_main_box, "Kaydet ve Çık", request_save_and_exit)
	_main_menu_button = _book_button(_main_box, "Ana Menüye Dön", request_main_menu)
	_menu_help = VBoxContainer.new()
	right.add_child(_menu_help)
	_ink_label(_menu_help, "Nasıl oynanır?", UiTheme.SPEAKER)
	var help := "A/D ile yürü.\nSpace ile zıpla.\nE ile etkileş."
	if MobileInputManager.is_touch_ui():
		help = "Solda hareket.\nSağda zıplama, etkileşim ve saldırı."
	_ink_label(_menu_help, help, UiTheme.HINT)

	_settings_box = VBoxContainer.new()
	_settings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_settings_box)
	_ink_label(_settings_box, "Kontroller", UiTheme.BODY)
	_settings_scroll = TouchSettingsScroll.new()
	var controls := _settings_list(_settings_box, _settings_scroll)
	_joy_button = _book_button(controls, "", _toggle_joystick_mode)
	_jump_axis_button = _book_button(controls, "", toggle_up_to_jump)
	_btn_scale_button = _book_button(controls, "", cycle_button_scale)
	_haptics_button = _book_button(controls, "", _toggle_haptics)
	_text_speed_button = _book_button(controls, "", _cycle_text_speed)
	_font_button = _book_button(controls, "", _toggle_font_size)
	_hint_button = _book_button(controls, "", _cycle_hint_level)
	_shake_button = _book_button(controls, "", _toggle_shake)
	_fs_button = _book_button(controls, "Tam Ekran (F11)", toggle_fullscreen)
	_fs_button.visible = not MobileInputManager.is_touch_ui()
	for b in [_joy_button, _jump_axis_button, _btn_scale_button, _haptics_button]:
		b.visible = MobileInputManager.is_touch_ui()
	_book_button(_settings_box, "Geri", _show_pause_page.bind(false))

	_audio_box = VBoxContainer.new()
	_audio_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_audio_box)
	_ink_label(_audio_box, "Ses", UiTheme.BODY)
	var audio := _settings_list(_audio_box, TouchSettingsScroll.new())
	var audio_row := HBoxContainer.new()
	audio.add_child(audio_row)
	_vol_button = _book_button(audio_row, "", _cycle_volume)
	_music_button = _book_button(audio_row, "", _toggle_music)
	_music_vol_label = _add_stepper(audio, func(d: int): _step_music_volume(d))
	_sfx_vol_label = _add_stepper(audio, func(d: int): _step_sfx_volume(d))
	_show_pause_page(false)
	_refresh_settings_buttons()


func _book_column(left: float, right: float, top: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.anchor_left = left
	col.anchor_right = right
	col.anchor_top = top
	col.anchor_bottom = 0.86
	col.add_theme_constant_override("separation", 6)
	_book_menu.add_child(col)
	return col


func _book_button(parent: Control, title: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	GothicModalPanel.style_button(b, UiTheme.HINT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _ink_label(parent: Control, content: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.apply_label(label, font_size, font_size >= UiTheme.BODY)
	label.add_theme_color_override("font_color", Color("#3E1423"))
	parent.add_child(label)
	return label


func _settings_list(parent: Control, scroll: ScrollContainer) -> VBoxContainer:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list


## Başlık ayarlarında gösterilen ayrıntılı kontrol özeti.
func how_to_play_text() -> String:
	var text := "A/D ile yürü, W/Space ile zıpla. E etkileşim, Z saldırı, X atılma, Q yankı. I kitabı, Esc Menü sayfasını açar."
	if MobileInputManager.is_touch_ui():
		text = "Solda hareket. Sağda zıplama, etkileşim, saldırı, atılma ve yankı. Sağ üstteki kitap günlüğü ve menüyü açar."
	return text + "\n\nÖlmek son değil. Bedenin odada kalır ve bulmacalara yardım eder."


func _should_show_title() -> bool:
	if _force_title:
		_force_title = false
		return true
	if OS.get_environment("TORIMON_FORCE_TITLE") == "1" and not _title_shown:
		return true ## Test kancası: başlık akışını headless çalıştır (start_flow_audit).
	if _title_shown or DisplayServer.get_name() == "headless":
		return false
	for env in ["TORIMON_TEST", "TORIMON_SMOKE", "TORIMON_FRESH"]:
		if OS.get_environment(env) == "1":
			return false
	return true


func is_title_open() -> bool:
	## Açılış deferred olduğundan görünürlüğe değil moda bak (main._ready aynı karede sorar).
	return _title_mode


func _open_title() -> void:
	_title_shown = true
	_title_mode = true
	UiGate.set_title(true)
	MobileInputManager.clear_held_inputs()
	## Kayıt main._ready içinde yüklenir (bu düğümden sonra) — kartı bir kare sonra doldur.
	_title_screen.call_deferred("open", _had_save)


func _show_pause_page(settings: bool) -> void:
	_main_box.visible = not settings
	_menu_help.visible = not settings
	_settings_box.visible = settings
	_audio_box.visible = settings
	if settings:
		_settings_scroll.set_deferred("scroll_vertical", 0)
	_focus(_joy_button if settings and _joy_button.visible else (_vol_button if settings else _settings_button))


func _on_book_closed() -> void:
	_show_pause_page(false)


## Düğüm ağaçta ve görünürken odaklar (sahne yeniden yüklenirken/gizliyken grab_focus hatası vermesin).
func _focus(b: Control) -> void:
	_do_focus.call_deferred(b)


func _do_focus(b: Control) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
		b.grab_focus()


## Android geri tuşu: menü açıksa kapat, oyun sırasında menüyü aç. Başlıkta yanlışlıkla çıkmayı önler.
func handle_back() -> void:
	if _touch_picker.visible:
		_close_touch_picker()
	elif is_confirm_open():
		_close_confirm()
	elif is_title_open():
		_title_screen.back()
	elif is_menu_open():
		if _settings_box.visible:
			_show_pause_page(false)
		else:
			close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()


func _build_touch_picker() -> void:
	_touch_picker = GothicModalPanel.new()
	_touch_picker.setup("Hareket Kontrolleri", Vector2(510, 250), &"menu", 0.83)
	add_child(_touch_picker)
	_touch_picker.add_label("Sola ve sağa nasıl hareket etmek istersin?", UiTheme.BODY)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	_touch_picker.body.add_child(choices)
	var group := ButtonGroup.new()
	for layout in GameSettings.TOUCH_LAYOUT_NAMES.size():
		var b := _touch_picker.add_button(GameSettings.TOUCH_LAYOUT_NAMES[layout], _select_picker_layout.bind(layout), choices)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		_layout_buttons.append(b)
	_layout_preview = _touch_picker.add_label("", UiTheme.BODY)
	_layout_preview.custom_minimum_size.y = 32
	_picker_jump = CheckButton.new()
	_picker_jump.text = "Joystick'i yukarı itince zıpla"
	UiTheme.apply_label(_picker_jump, UiTheme.BODY, false)
	_touch_picker.body.add_child(_picker_jump)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_touch_picker.body.add_child(actions)
	_touch_picker.add_button("Geri", _close_touch_picker, actions).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_confirm = _touch_picker.add_button("Kaydet ve Başla", _accept_touch_picker, actions)
	_picker_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_touch_picker.on_close = _close_touch_picker
	_touch_picker.hide()


func _request_start(action: Callable) -> void:
	if _touch_picker.visible:
		return
	if not MobileInputManager.is_touch_ui() or GameSettings.touch_layout_chosen:
		_title_screen.close(action)
		return
	_after_picker = action
	_picker_jump.button_pressed = GameSettings.touch_up_to_jump
	_layout_buttons[GameSettings.touch_layout].set_pressed_no_signal(true)
	_select_picker_layout(GameSettings.touch_layout)
	move_child(_touch_picker, -1)
	_touch_picker.show()
	_focus(_layout_buttons[_picker_layout])


func _select_picker_layout(layout: int) -> void:
	_picker_layout = layout
	_picker_jump.disabled = layout == GameSettings.TouchLayout.ARROWS
	match layout:
		GameSettings.TouchLayout.FLOATING:
			_layout_preview.text = "Sol alana dokunduğunda joystick parmağının altında belirir."
		GameSettings.TouchLayout.FIXED:
			_layout_preview.text = "Joystick sol alt köşede sabit kalır."
		GameSettings.TouchLayout.ARROWS:
			_layout_preview.text = "Sol ve sağ oklarla yürü. Sağdaki tuşla zıpla."


func _accept_touch_picker() -> void:
	var action := _after_picker
	GameSettings.touch_up_to_jump = _picker_jump.button_pressed
	GameSettings.touch_layout_chosen = true
	_apply_touch_layout(_picker_layout)
	_close_touch_picker()
	_title_screen.close(action)


func _close_touch_picker() -> void:
	_touch_picker.hide()
	_after_picker = Callable()
	if _title_mode:
		_title_screen.focus_current_page()


func is_overlay_open() -> bool:
	return is_confirm_open() or (_touch_picker != null and _touch_picker.visible)


# --- Onay diyaloğu / Kaydet ve Çık ------------------------------------------------

func _build_confirm() -> void:
	_confirm_panel = GothicModalPanel.new()
	_confirm_panel.setup("Emin misin?", Vector2(380, 176), &"menu", 0.55)
	add_child(_confirm_panel)
	_confirm_text = _confirm_panel.add_label("", UiTheme.BODY)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_confirm_panel.body.add_child(row)
	var cancel := _confirm_panel.add_button("Vazgeç", _close_confirm, row)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_ok = _confirm_panel.add_button("", func(): _confirm_action.call(), row)
	_confirm_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_panel.on_close = _close_confirm
	_confirm_panel.hide()


func is_menu_open() -> bool:
	return _journal != null and _journal.is_menu_page()


func is_confirm_open() -> bool:
	return _confirm_panel != null and _confirm_panel.visible


func _show_confirm(title: String, text: String, ok_text: String, action: Callable) -> void:
	_confirm_panel.set_title(title)
	_confirm_text.text = text
	_confirm_ok.text = ok_text
	_confirm_action = action
	move_child(_confirm_panel, -1) ## her şeyin (başlık dahil) üstünde
	_confirm_panel.show()
	MobileInputManager.clear_held_inputs()
	_focus(_confirm_ok)


func _close_confirm() -> void:
	_confirm_panel.hide()
	if is_menu_open() and _continue_button:
		_focus(_continue_button)


func _on_quit_button() -> void:
	request_save_and_exit()


## Duraklatma menüsü: onay -> committed kayıt -> ana menü. Uygulama KAPANMAZ.
## commit_save en yeni save_serial'ı alır; Devam Et (load_game, en yüksek serial) bu committed durumu yükler.
func request_save_and_exit() -> void:
	_show_confirm("Kaydet ve Çık", "İlerlemen kaydedilecek ve ana menüye döneceksin. Emin misin?", "Kaydet ve Çık", _save_and_exit)


func _save_and_exit() -> void:
	var safe := _safe_quit_spot()
	var ok: bool
	if safe.is_empty():
		ok = SaveManager.commit_save(&"save_and_quit") ## güvenli değil: son checkpoint
	else:
		ok = SaveManager.commit_save(&"save_and_quit", safe["pos"], safe["room"])
	if not ok:
		_show_confirm("Kayıt başarısız", "Kayıt başarısız. Tekrar denemek ister misin?", "Tekrar Dene", _save_and_exit)
		return
	_confirm_panel.hide()
	return_to_title()


## Güvenliyse oyuncunun konumu + aktif oda; değilse boş (checkpoint'e düşülür). memory_seal_point ile aynı mantık.
func _safe_quit_spot() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not is_instance_valid(player) or not player.is_on_floor():
		return {}
	if DeathManager.is_dying or DialogueManager.is_open or RoomTransitionScript.is_transitioning():
		return {}
	if player.has_method("_near_hazard") and player.call("_near_hazard"):
		return {}
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en and is_instance_valid(en) and en.is_visible_in_tree() \
				and en.global_position.distance_to(player.global_position) <= 120.0:
			return {}
	for k in get_tree().get_nodes_in_group("keeper"):
		var kn := k as Node2D
		if kn and is_instance_valid(kn) and kn.is_visible_in_tree() and int(kn.get("mode")) in [2, 5] \
				and kn.global_position.distance_to(player.global_position) <= 320.0:
			return {}
	return {"pos": player.global_position, "room": RoomManager.get_active_room_id()}


## Ana Menüye Dön: kayıt YAZMAZ. Kaydedilmemiş ilerleme gider; başlıkta Devam Et son committed kaydı yükler.
func request_main_menu() -> void:
	_show_confirm("Ana Menü", "Kaydedilmemiş ilerleme kaybolacak. Ana menüye dönmek istiyor musun?", "Ana Menüye Dön", _main_menu_no_save)


## Resume dosyası uygulama-kapanış güvenliği içindi; burada silinmezse (daha yeni serial ile) Devam Et
## kaydedilmemiş ilerlemeyi geri getirirdi. Bu yüzden önce discard_resume(), sonra sahne yeniden kurulur.
func _main_menu_no_save() -> void:
	SaveManager.discard_resume()
	_confirm_panel.hide()
	return_to_title()


## Sahneyi kayıttan yeniden kurar ve başlık ekranını açar (taze açılışla aynı yol).
func return_to_title() -> void:
	_force_title = true
	_title_shown = false
	if _journal:
		_journal.close_journal()
	DialogueManager.clear()
	UiGate.set_story(false)
	UiGate.set_journal(false)
	UiGate.set_seal(false)
	MobileInputManager.clear_held_inputs()
	EchoManager.active_echo = &""
	DeathManager.reset_state()
	UiGate.set_cutscene(false)
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	get_tree().reload_current_scene()


## Yalnız başlık ekranındaki "Oyundan Çık" (onaydan sonra) uygulamayı kapatır.
func _quit_app() -> void:
	get_tree().quit()


func _toggle_joystick_mode() -> void:
	GameSettings.touch_layout_chosen = true
	_apply_touch_layout((GameSettings.touch_layout + 1) % GameSettings.TOUCH_LAYOUT_NAMES.size())


func toggle_up_to_jump() -> void:
	if GameSettings.touch_layout == GameSettings.TouchLayout.ARROWS:
		return
	GameSettings.touch_up_to_jump = not GameSettings.touch_up_to_jump
	_apply_touch_layout(GameSettings.touch_layout)


func _apply_touch_layout(layout: int) -> void:
	GameSettings.touch_layout = layout
	_save_settings()
	_refresh_settings_buttons()
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.refresh_touch_controls()


func up_to_jump_text() -> String:
	return "Yukarıyla zıpla: " + ("Açık" if GameSettings.touch_up_to_jump else "Kapalı")


func _toggle_haptics() -> void:
	GameSettings.cycle_haptics()
	_save_settings()
	_refresh_settings_buttons()
	MobileInputManager.haptic(&"ui") ## seçilen şiddeti hemen hissettir


func _add_stepper(parent: Control, on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var minus := _book_button(row, "-", on_step.bind(-1))
	var label := _ink_label(row, "", UiTheme.HINT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 4.0
	var plus := _book_button(row, "+", on_step.bind(1))
	minus.custom_minimum_size.x = 32
	plus.custom_minimum_size.x = 32
	return label


func _step_music_volume(delta: int) -> void:
	GameSettings.music_volume = snappedf(clampf(GameSettings.music_volume + float(delta) * GameSettings.VOLUME_STEP, 0.0, 1.0), GameSettings.VOLUME_STEP)
	AudioManager.set_music_volume(GameSettings.music_volume)
	_save_settings()
	_refresh_settings_buttons()


func _step_sfx_volume(delta: int) -> void:
	GameSettings.sfx_volume = snappedf(clampf(GameSettings.sfx_volume + float(delta) * GameSettings.VOLUME_STEP, 0.0, 1.0), GameSettings.VOLUME_STEP)
	AudioManager.set_sfx_volume(GameSettings.sfx_volume)
	_save_settings()
	_refresh_settings_buttons()
	AudioManager.play_sfx(&"ui_click")


func _cycle_text_speed() -> void:
	GameSettings.text_speed = (GameSettings.text_speed + 1) % GameSettings.TEXT_SPEED_NAMES.size()
	_save_settings()
	_refresh_settings_buttons()


func _toggle_shake() -> void:
	GameSettings.screen_shake = not GameSettings.screen_shake
	_save_settings()
	_refresh_settings_buttons()


func _toggle_font_size() -> void:
	GameSettings.font_large = not GameSettings.font_large
	_save_settings()
	_refresh_settings_buttons()
	_apply_font_setting()


func _cycle_hint_level() -> void:
	GameSettings.hint_level = (GameSettings.hint_level + 1) % GameSettings.HINT_LEVEL_NAMES.size()
	_save_settings()
	_refresh_settings_buttons()


## Buton boyutu: %80..%120 arası döner; HUD'a anında uygulanır.
func cycle_button_scale() -> void:
	GameSettings.button_scale_idx = (GameSettings.button_scale_idx + 1) % GameSettings.BUTTON_SCALE_PCT.size()
	_save_settings()
	_refresh_settings_buttons()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("apply_button_scale"):
			hud.apply_button_scale()


func button_scale_text() -> String:
	return "Buton boyutu: %%%d" % GameSettings.BUTTON_SCALE_PCT[GameSettings.button_scale_idx]


func _apply_font_setting() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("apply_text_size_setting"):
			hud.apply_text_size_setting()


func _cycle_volume() -> void:
	var i := 0
	for k in VOLUME_STEPS.size():
		if is_equal_approx(VOLUME_STEPS[k], _volume):
			i = k
	_volume = VOLUME_STEPS[(i + 1) % VOLUME_STEPS.size()]
	AudioManager.set_master_volume(_volume)
	_save_settings()
	_refresh_settings_buttons()


func _toggle_music() -> void:
	_music_on = not _music_on
	AudioManager.set_music_enabled(_music_on)
	_save_settings()
	_refresh_settings_buttons()


func _refresh_settings_buttons() -> void:
	if _title_screen:
		_title_screen.refresh_settings()
	if _book_menu == null:
		return
	_joy_button.text = _joy_text()
	_jump_axis_button.text = up_to_jump_text()
	_jump_axis_button.disabled = GameSettings.touch_layout == GameSettings.TouchLayout.ARROWS
	if _haptics_button:
		_haptics_button.text = _haptics_text()
	_vol_button.text = _vol_text()
	_music_button.text = _music_text()
	if _music_vol_label:
		_music_vol_label.text = "Müzik sesi: %%%d" % int(round(GameSettings.music_volume * 100.0))
		_sfx_vol_label.text = "Efekt sesi: %%%d" % int(round(GameSettings.sfx_volume * 100.0))
		_text_speed_button.text = "Metin hızı: " + GameSettings.TEXT_SPEED_NAMES[GameSettings.text_speed]
		_shake_button.text = "Ekran sarsıntısı: " + ("Açık" if GameSettings.screen_shake else "Kapalı")
		_font_button.text = "Yazı boyutu: " + ("Büyük" if GameSettings.font_large else "Normal")
		_hint_button.text = "İpucu: " + GameSettings.HINT_LEVEL_NAMES[GameSettings.hint_level]
		_btn_scale_button.text = button_scale_text()


func _joy_text() -> String:
	return GameSettings.TOUCH_LAYOUT_NAMES[GameSettings.touch_layout] + "  >"


func _haptics_text() -> String:
	GameSettings.ensure_loaded()
	return "Titreşim: " + GameSettings.HAPTIC_NAMES[clampi(GameSettings.haptics_level, 0, 3)]


func _vol_text() -> String:
	return "Ses: %%%d" % int(round(_volume * 100.0))


func _music_text() -> String:
	return "Müzik: Açık" if _music_on else "Müzik: Kapalı"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.storage_path()) == OK:
		_volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
		_music_on = bool(cfg.get_value("audio", "music", true))
	GameSettings.load_settings()
	AudioManager.set_master_volume(_volume)
	AudioManager.set_music_enabled(_music_on)
	AudioManager.set_music_volume(GameSettings.music_volume)
	AudioManager.set_sfx_volume(GameSettings.sfx_volume)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.storage_path()) ## yeni ayar anahtarları (GameSettings) korunur
	cfg.set_value("audio", "volume", _volume)
	cfg.set_value("audio", "music", _music_on)
	cfg.set_value("input", "haptics", GameSettings.haptics_level > 0) ## eski anahtar (türetilmiş)
	cfg.save(GameSettings.storage_path())
	GameSettings.save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_overlay_open() or UiGate.current_layer() == UiGate.Layer.NONE:
		handle_back()
		get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if is_overlay_open():
		return
	if is_menu_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if _journal == null or UiGate.current_layer() not in [UiGate.Layer.NONE, UiGate.Layer.JOURNAL]:
		return
	_show_pause_page(false)
	_journal.show_menu_page()
	_focus(_continue_button)


func close_menu() -> void:
	var was_title := _title_mode
	_title_mode = false
	if _journal:
		_journal.close_journal()
	UiGate.set_title(false)
	MobileInputManager.clear_held_inputs()
	if was_title:
		title_closed.emit()


## Başlıktan onaylı yeni oyun (onay title_screen'de alındı).
func _start_fresh() -> void:
	close_menu()
	SaveManager.start_new_game()


static func toggle_fullscreen() -> void:
	if OS.has_feature("mobile"):
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
