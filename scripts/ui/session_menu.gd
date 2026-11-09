extends CanvasLayer
## Başlık ekranı + duraklatma menüsü (masaüstü/mobil). Mantığı UiGate ile durdurur, animasyonu değil.
## Başlık yalnız uygulama açılışında bir kez gösterilir; headless/QA koşularında atlanır.

signal title_closed

const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
const TitleScreenScript := preload("res://scripts/ui/title_screen.gd")
const RoomTransitionScript := preload("res://scripts/world/room_transition.gd")

static var _title_shown: bool = false
## Kaydet ve Çık sonrası sahne yeniden yüklenince başlık (test ortamında da) açılır.
static var _force_title: bool = false

var _panel: GothicModalPanel
var _title_screen: Control
var _menu_button: Button
var _continue_button: Button
var _settings_button: Button
var _quit_button: Button ## Kaydet ve Çık
var _main_menu_button: Button ## Ana Menüye Dön
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _joy_button: Button
var _fs_button: Button
var _haptics_button: Button
var _vol_button: Button
var _music_button: Button
var _help_label: Label
var _settings_help: Label
var _subtitle: Label
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
	_menu_button = Button.new()
	_menu_button.text = "Menü"
	# Sağ üst köşe: HUD günlük düğmesinin ALTI (üst sıra uzun oda başlığına ayrılır; anchor — geniş ekranda da köşede kalır).
	_menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu_button.offset_left = -76.0
	_menu_button.offset_right = -8.0
	_menu_button.offset_top = 82.0
	_menu_button.offset_bottom = 114.0
	_menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	GothicModalPanel.style_button(_menu_button)
	_menu_button.pressed.connect(toggle_menu)
	# Düz Control: MarginContainer çocuğu tüm alana yayıyordu → Menü düğmesi tam ekran oluyordu,
	# her dokunuş menüyü açıyordu (v1.4.3 düzeltmesi). Anchor'lar burada korunur.
	var safe_area := Control.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe_area)
	safe_area.add_child(_menu_button)
	UiGate.gate_changed.connect(_on_gate_changed)
	_panel = GothicModalPanel.new()
	## Dokunmatikte yardım metni ve tam ekran düğmesi yok — panel kısalır.
	_panel.setup("THE ROOM REMEMBERS", Vector2(420, 232 if MobileInputManager.is_touch_ui() else 292))
	add_child(_panel)
	_subtitle = _panel.add_label("Sen unutursun. Oda hatırlar.", UiTheme.HINT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label = _panel.add_label("A/D: yürü · W/Space: zıpla · E: etkileş/devam\nX: atıl · Z: saldır · Q: yankı/ruh yeteneği\nI: günlük · Esc: menü", UiTheme.HINT)
	## Duraklatma menüsü sırası: Devam Et / Ayarlar / Kaydet ve Çık / Ana Menüye Dön.
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 6)
	_panel.body.add_child(_main_box)
	_continue_button = _panel.add_button("Devam Et", close_menu, _main_box)
	_settings_button = _panel.add_button("Ayarlar", func(): _show_pause_page(true), _main_box)
	_quit_button = _panel.add_button("Kaydet ve Çık", _on_quit_button, _main_box)
	_main_menu_button = _panel.add_button("Ana Menüye Dön", request_main_menu, _main_box)
	## Ayarlar alt sayfası (var olan ses/müzik/tam ekran/joystick/titreşim düğmeleri; yeni sistem yok).
	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 6)
	_panel.body.add_child(_settings_box)
	var help_txt := ""
	if MobileInputManager.is_touch_ui():
		help_txt = "NASIL OYNANIR
Sol joystick: yürü · Sağ düğmeler: zıpla, etkileş, saldır, atıl, yankı · Sağ üst: günlük ve menü"
	else:
		help_txt = "NASIL OYNANIR
A/D: yürü · W/Space: zıpla · E: etkileş · Z: saldır · X: atıl · Q: yankı · I: günlük · Esc: menü"
	help_txt += "
Ölmek son değil: bedenin odada kalır ve bulmacaları çözmene yardım eder."
	_settings_help = Label.new()
	_settings_help.text = help_txt
	_settings_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_help.add_theme_font_size_override("font_size", 8)
	_settings_help.add_theme_color_override("font_color", Palette.PALE_LILAC)
	_settings_box.add_child(_settings_help)
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 6)
	_settings_box.add_child(audio_row)
	_vol_button = _panel.add_button("", _cycle_volume, audio_row)
	_vol_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_button = _panel.add_button("", _toggle_music, audio_row)
	_music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_settings_box.add_child(row)
	_fs_button = _panel.add_button("Tam ekran (F11)", toggle_fullscreen, row)
	_fs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fs_button.visible = not OS.has_feature("mobile")
	_joy_button = _panel.add_button("", _toggle_joystick_mode, row)
	_joy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_haptics_button = _panel.add_button("", _toggle_haptics, row)
	_haptics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_button("< Geri", func(): _show_pause_page(false), _settings_box)
	_settings_box.hide()
	_refresh_settings_buttons()
	_panel.hide()
	_build_confirm()
	_title_screen = TitleScreenScript.new()
	_title_screen.menu = self
	_title_screen.start_requested.connect(func(): _title_screen.close(close_menu))
	_title_screen.new_game_requested.connect(func(): _title_screen.close(_start_fresh))
	_title_screen.quit_requested.connect(_quit_app)
	add_child(_title_screen)
	EndingManager.epilogue_finished.connect(open_menu)
	if _should_show_title():
		_open_title()


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
	_menu_button.visible = false
	UiGate.set_title(true)
	MobileInputManager.clear_held_inputs()
	## Kayıt main._ready içinde yüklenir (bu düğümden sonra) — kartı bir kare sonra doldur.
	_title_screen.call_deferred("open", _had_save)


func _refresh_mode() -> void:
	_subtitle.visible = _title_mode
	_help_label.visible = not _title_mode and not MobileInputManager.is_touch_ui() and not _settings_box.visible
	_refresh_settings_buttons()


## Duraklatma menüsü: ana düğmeler <-> ayarlar alt sayfası.
func _show_pause_page(settings: bool) -> void:
	_main_box.visible = not settings
	_settings_box.visible = settings
	_help_label.visible = not settings and not MobileInputManager.is_touch_ui()
	_subtitle.visible = _title_mode and not settings
	_focus(_vol_button if settings else _settings_button)


## Düğüm ağaçta ve görünürken odaklar (sahne yeniden yüklenirken/gizliyken grab_focus hatası vermesin).
func _focus(b: Control) -> void:
	_do_focus.call_deferred(b)


func _do_focus(b: Control) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
		b.grab_focus()


## Android geri tuşu: menü açıksa kapat, oyun sırasında menüyü aç. Başlıkta yanlışlıkla çıkmayı önler.
func handle_back() -> void:
	if is_confirm_open():
		_close_confirm()
		return
	if is_title_open():
		_title_screen.back()
		return
	if _panel.visible:
		if not _title_mode:
			close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()


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
	_confirm_panel.hide()


func is_menu_open() -> bool:
	return _panel != null and _panel.visible


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
	if _panel.visible and _continue_button:
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
		if en and is_instance_valid(en) and en.is_visible_in_tree() 				and en.global_position.distance_to(player.global_position) <= 120.0:
			return {}
	for k in get_tree().get_nodes_in_group("keeper"):
		var kn := k as Node2D
		if kn and is_instance_valid(kn) and kn.is_visible_in_tree() and int(kn.get("mode")) in [2, 5] 				and kn.global_position.distance_to(player.global_position) <= 320.0:
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
	_panel.hide()
	UiGate.set_pause_menu(false)
	DialogueManager.clear()
	UiGate.set_story(false)
	UiGate.set_journal(false)
	UiGate.set_seal(false)
	MobileInputManager.clear_held_inputs()
	EchoManager.active_echo = &""
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	get_tree().reload_current_scene()


## Yalnız başlık ekranındaki "Oyundan Çık" (onaydan sonra) uygulamayı kapatır.
func _quit_app() -> void:
	get_tree().quit()


func _toggle_joystick_mode() -> void:
	MobileInputManager.floating_joystick = not MobileInputManager.floating_joystick
	_save_settings()
	_refresh_settings_buttons()


func _toggle_haptics() -> void:
	MobileInputManager.haptics_enabled = not MobileInputManager.haptics_enabled
	_save_settings()
	_refresh_settings_buttons()


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
	_joy_button.text = _joy_text()
	if _haptics_button:
		_haptics_button.text = _haptics_text()
	_vol_button.text = _vol_text()
	_music_button.text = _music_text()


func _joy_text() -> String:
	return "Joystick: Yüzen" if MobileInputManager.floating_joystick else "Joystick: Sabit"


func _haptics_text() -> String:
	return "Titreşim: Açık" if MobileInputManager.haptics_enabled else "Titreşim: Kapalı"


func _vol_text() -> String:
	return "Ses: %%%d" % int(round(_volume * 100.0))


func _music_text() -> String:
	return "Müzik: Açık" if _music_on else "Müzik: Kapalı"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
		_music_on = bool(cfg.get_value("audio", "music", true))
		MobileInputManager.floating_joystick = bool(cfg.get_value("input", "floating_joystick", true))
		MobileInputManager.haptics_enabled = bool(cfg.get_value("input", "haptics", true))
	AudioManager.set_master_volume(_volume)
	AudioManager.set_music_enabled(_music_on)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", _volume)
	cfg.set_value("audio", "music", _music_on)
	cfg.set_value("input", "floating_joystick", MobileInputManager.floating_joystick)
	cfg.set_value("input", "haptics", MobileInputManager.haptics_enabled)
	cfg.save(SETTINGS_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if is_confirm_open():
			_close_confirm()
			get_viewport().set_input_as_handled()
			return
		if is_title_open():
			get_viewport().set_input_as_handled()
			return
		if _panel.visible:
			if _title_mode:
				return
			close_menu()
		elif UiGate.current_layer() == UiGate.Layer.NONE:
			open_menu()
		else:
			return
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if is_confirm_open():
		return
	if _panel.visible:
		close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()

## Göz açma vb. sinematikte veya modallarda Menü düğmesi gizlenir.
func _on_gate_changed(layer: int) -> void:
	_menu_button.visible = (layer == UiGate.Layer.NONE)


func open_menu() -> void:
	if DeathManager.is_dying or _panel.visible or UiGate.is_cutscene():
		return
	_title_mode = false
	_panel.dim.color.a = 0.78
	_main_box.show()
	_settings_box.hide()
	_panel.show()
	UiGate.set_pause_menu(true)
	MobileInputManager.clear_held_inputs()
	_refresh_mode()
	_focus(_continue_button)

func close_menu() -> void:
	var was_title := _title_mode
	_title_mode = false
	_panel.hide()
	UiGate.set_pause_menu(false)
	UiGate.set_title(false)
	_menu_button.visible = (UiGate.current_layer() == UiGate.Layer.NONE)
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
