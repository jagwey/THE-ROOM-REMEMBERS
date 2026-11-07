extends CanvasLayer
## Başlık ekranı + duraklatma menüsü (masaüstü/mobil). Mantığı UiGate ile durdurur, animasyonu değil.
## Başlık yalnız uygulama açılışında bir kez gösterilir; headless/QA koşularında atlanır.

signal title_closed

const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

static var _title_shown: bool = false

var _panel: GothicModalPanel
var _menu_button: Button
var _confirm: bool = false
var _new_button: Button
var _continue_button: Button
var _quit_button: Button
var _joy_button: Button
var _fs_button: Button
var _vol_button: Button
var _music_button: Button
var _help_label: Label
var _subtitle: Label
var _title_mode: bool = false
var _had_save: bool = false
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
	# Sağ üst köşe: HUD günlük düğmesinin solu (anchor — geniş ekranda da köşede kalır).
	_menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu_button.offset_left = -150.0
	_menu_button.offset_right = -84.0
	_menu_button.offset_top = 10.0
	_menu_button.offset_bottom = 42.0
	_menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	GothicModalPanel.style_button(_menu_button)
	_menu_button.pressed.connect(toggle_menu)
	add_child(_menu_button)
	_panel = GothicModalPanel.new()
	## Dokunmatikte yardım metni ve tam ekran düğmesi yok — panel kısalır.
	_panel.setup("THE ROOM REMEMBERS", Vector2(420, 284 if MobileInputManager.is_touch_ui() else 336))
	add_child(_panel)
	_subtitle = _panel.add_label("Sen unutursun. Oda hatırlar.", UiTheme.HINT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label = _panel.add_label("A/D: yürü · W/Space: zıpla · E: etkileş/devam\nX: atıl · Z: saldır · Q: yankı/ruh yeteneği\nI: günlük · Esc: menü", UiTheme.HINT)
	_continue_button = _panel.add_button("Devam et", close_menu)
	_new_button = _panel.add_button("Yeni oyun", _new_game)
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 6)
	_panel.body.add_child(audio_row)
	_vol_button = _panel.add_button("", _cycle_volume, audio_row)
	_vol_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_button = _panel.add_button("", _toggle_music, audio_row)
	_music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_panel.body.add_child(row)
	_fs_button = _panel.add_button("Tam ekran (F11)", toggle_fullscreen, row)
	_fs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fs_button.visible = not OS.has_feature("mobile")
	_joy_button = _panel.add_button("", _toggle_joystick_mode, row)
	_joy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quit_button = _panel.add_button("Kaydet ve çık", _quit)
	_refresh_settings_buttons()
	_panel.hide()
	EndingManager.epilogue_finished.connect(open_menu)
	if _should_show_title():
		_open_title()


func _should_show_title() -> bool:
	if _title_shown or DisplayServer.get_name() == "headless":
		return false
	for env in ["TORIMON_TEST", "TORIMON_SMOKE", "TORIMON_FRESH"]:
		if OS.get_environment(env) == "1":
			return false
	return true


func is_title_open() -> bool:
	return _title_mode and _panel.visible


func _open_title() -> void:
	_title_shown = true
	_title_mode = true
	_menu_button.visible = false
	_panel.dim.color.a = 0.97
	_panel.show()
	UiGate.set_journal(true)
	MobileInputManager.clear_held_inputs()
	_refresh_mode()


func _refresh_mode() -> void:
	_subtitle.visible = _title_mode
	_help_label.visible = not _title_mode and not MobileInputManager.is_touch_ui()
	_continue_button.text = ("Devam et" if _had_save else "Başla") if _title_mode else "Devam et"
	_new_button.visible = _had_save or not _title_mode
	_new_button.text = "Yeni oyun"
	_quit_button.text = "Çıkış" if _title_mode else "Kaydet ve çık"
	_confirm = false
	_refresh_settings_buttons()


## Android geri tuşu: menü açıksa kapat, oyun sırasında menüyü aç. Başlıkta yanlışlıkla çıkmayı önler.
func handle_back() -> void:
	if _panel.visible:
		if not _title_mode:
			close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()


func _quit() -> void:
	if not _title_mode:
		SaveManager.save_game()
	get_tree().quit()


func _toggle_joystick_mode() -> void:
	MobileInputManager.floating_joystick = not MobileInputManager.floating_joystick
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
	_joy_button.text = "Joystick: Yüzen" if MobileInputManager.floating_joystick else "Joystick: Sabit"
	_vol_button.text = "Ses: %%%d" % int(round(_volume * 100.0))
	_music_button.text = "Müzik: Açık" if _music_on else "Müzik: Kapalı"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
		_music_on = bool(cfg.get_value("audio", "music", true))
		MobileInputManager.floating_joystick = bool(cfg.get_value("input", "floating_joystick", true))
	AudioManager.set_master_volume(_volume)
	AudioManager.set_music_enabled(_music_on)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", _volume)
	cfg.set_value("audio", "music", _music_on)
	cfg.set_value("input", "floating_joystick", MobileInputManager.floating_joystick)
	cfg.save(SETTINGS_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
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
	if _panel.visible:
		close_menu()
	elif UiGate.current_layer() == UiGate.Layer.NONE:
		open_menu()

func open_menu() -> void:
	if DeathManager.is_dying or _panel.visible:
		return
	_title_mode = false
	_panel.dim.color.a = 0.78
	_panel.show()
	UiGate.set_journal(true)
	MobileInputManager.clear_held_inputs()
	_refresh_mode()

func close_menu() -> void:
	var was_title := _title_mode
	_title_mode = false
	_menu_button.visible = true
	_panel.hide()
	UiGate.set_journal(false)
	MobileInputManager.clear_held_inputs()
	if was_title:
		title_closed.emit()

func _new_game() -> void:
	if not _confirm:
		_confirm = true
		_new_button.text = "Sıfırdan başlamak için tekrar bas"
		return
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
