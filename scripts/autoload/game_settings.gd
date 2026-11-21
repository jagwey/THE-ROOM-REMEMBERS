class_name GameSettings
extends RefCounted
## Oyuncu ayarları (statik, autoload değil). user://settings.cfg içinde ses/giriş anahtarlarıyla yan yana durur;
## kaydederken dosya önce okunur, böylece başka anahtarlar silinmez. Varsayılanlar eski davranışla aynıdır.

const PATH := "user://settings.cfg"
const SECTION := "game"

const TEXT_SPEED_NAMES: Array[String] = ["Yavaş", "Normal", "Anında"]
const TEXT_SPEED_CPS: Array[float] = [24.0, 48.0, 0.0] ## 0 = anında
const HINT_LEVEL_NAMES: Array[String] = ["Yok", "Yön", "Açık"]
const FONT_SCALE_LARGE := 1.25
const VOLUME_STEP := 0.1
const BUTTON_SCALE_PCT: Array[int] = [80, 90, 100, 110, 120]
const BACK_HINT_MAX := 2
const HAPTIC_NAMES: Array[String] = ["Kapalı", "Hafif", "Normal", "Güçlü"]
enum TouchLayout { FLOATING, FIXED, ARROWS }
const TOUCH_LAYOUT_NAMES: Array[String] = ["Yüzen joystick", "Sabit joystick", "Yön tuşları"]

const HAPTIC_MULT: Array[float] = [0.0, 0.5, 1.0, 1.6]

static var music_volume: float = 1.0
static var sfx_volume: float = 1.0
static var text_speed: int = 1 ## 0 Yavaş · 1 Normal · 2 Anında
static var screen_shake: bool = true
static var font_large: bool = false
static var hint_level: int = 2 ## 0 Yok (yalnız hedef) · 1 Yön · 2 Açık (hepsi)
static var button_scale_idx: int = 2 ## BUTTON_SCALE_PCT indeksi (varsayılan %100)
static var touch_layout: int = TouchLayout.FLOATING
static var touch_up_to_jump: bool = false
static var touch_layout_chosen: bool = false
static var back_hint_count: int = 0 ## "geri" ipucu kaç kez gösterildi (2'den sonra susar)
static var haptics_level: int = 2 ## 0 Kapalı · 1 Hafif · 2 Normal · 3 Güçlü
static var fast_travel_hint_shown: bool = false ## hızlı seyahat ipucu bir kez gösterildi
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func reset_defaults() -> void:
	music_volume = 1.0
	sfx_volume = 1.0
	text_speed = 1
	screen_shake = true
	font_large = false
	hint_level = 2
	button_scale_idx = 2
	touch_layout = TouchLayout.FLOATING
	touch_up_to_jump = false
	touch_layout_chosen = false
	back_hint_count = 0
	haptics_level = 2
	fast_travel_hint_shown = false


static func storage_path() -> String:
	return "user://qa/settings.cfg" if OS.get_environment("TORIMON_TEST") == "1" else PATH


static func load_settings(path: String = "") -> void:
	path = storage_path() if path.is_empty() else path
	reset_defaults()
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	music_volume = snappedf(clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0), VOLUME_STEP)
	sfx_volume = snappedf(clampf(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0), VOLUME_STEP)
	text_speed = clampi(int(cfg.get_value(SECTION, "text_speed", 1)), 0, 2)
	screen_shake = bool(cfg.get_value(SECTION, "screen_shake", true))
	font_large = bool(cfg.get_value(SECTION, "font_large", false))
	hint_level = clampi(int(cfg.get_value(SECTION, "hint_level", 2)), 0, 2)
	button_scale_idx = clampi(int(cfg.get_value(SECTION, "button_scale_idx", 2)), 0, BUTTON_SCALE_PCT.size() - 1)
	var legacy_layout := TouchLayout.FLOATING if bool(cfg.get_value("input", "floating_joystick", true)) else TouchLayout.FIXED
	touch_layout = clampi(int(cfg.get_value("input", "touch_layout", legacy_layout)), 0, TOUCH_LAYOUT_NAMES.size() - 1)
	touch_up_to_jump = bool(cfg.get_value("input", "touch_up_to_jump", false))
	touch_layout_chosen = bool(cfg.get_value("input", "touch_layout_chosen", false))
	back_hint_count = clampi(int(cfg.get_value(SECTION, "back_hint_count", 0)), 0, 99)
	fast_travel_hint_shown = bool(cfg.get_value(SECTION, "fast_travel_hint_shown", false))
	if cfg.has_section_key(SECTION, "haptics_level"):
		haptics_level = clampi(int(cfg.get_value(SECTION, "haptics_level", 2)), 0, 3)
	else: ## eski ayar: input/haptics false -> 0, true -> 2
		haptics_level = 2 if bool(cfg.get_value("input", "haptics", true)) else 0


## Yalnızca bu sınıfın anahtarlarını yazar; dosyadaki diğer anahtarlar korunur.
static func save_settings(path: String = "") -> void:
	path = storage_path() if path.is_empty() else path
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "text_speed", text_speed)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "font_large", font_large)
	cfg.set_value(SECTION, "hint_level", hint_level)
	cfg.set_value(SECTION, "button_scale_idx", button_scale_idx)
	cfg.set_value("input", "touch_layout", touch_layout)
	cfg.set_value("input", "touch_up_to_jump", touch_up_to_jump)
	cfg.set_value("input", "touch_layout_chosen", touch_layout_chosen)
	cfg.set_value(SECTION, "back_hint_count", back_hint_count)
	cfg.set_value(SECTION, "haptics_level", haptics_level)
	cfg.set_value(SECTION, "fast_travel_hint_shown", fast_travel_hint_shown)
	cfg.save(path)


static func haptics_on() -> bool:
	ensure_loaded()
	return haptics_level > 0


## Titreşim süresini seviyeye göre ölçekler (5..200 ms).
static func scale_haptic_ms(ms: int) -> int:
	ensure_loaded()
	var m: float = HAPTIC_MULT[clampi(haptics_level, 0, 3)]
	return clampi(int(round(float(ms) * m)), 5, 200)


static func cycle_haptics() -> void:
	ensure_loaded()
	haptics_level = (haptics_level + 1) % HAPTIC_NAMES.size()


static func text_cps() -> float:
	ensure_loaded()
	return TEXT_SPEED_CPS[clampi(text_speed, 0, 2)]


static func shake_enabled() -> bool:
	ensure_loaded()
	return screen_shake


static func font_scale() -> float:
	ensure_loaded()
	return FONT_SCALE_LARGE if font_large else 1.0


## En yüksek izin verilen ipucu kademesi (1 hedef, 2 yön, 3 açık).
static func max_hint_tier() -> int:
	ensure_loaded()
	return clampi(hint_level, 0, 2) + 1


## Dokunmatik düğme/joystick ölçeği (0.8 .. 1.2).
static func button_scale() -> float:
	ensure_loaded()
	return float(BUTTON_SCALE_PCT[clampi(button_scale_idx, 0, BUTTON_SCALE_PCT.size() - 1)]) / 100.0
