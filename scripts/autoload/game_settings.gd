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

static var music_volume: float = 1.0
static var sfx_volume: float = 1.0
static var text_speed: int = 1 ## 0 Yavaş · 1 Normal · 2 Anında
static var screen_shake: bool = true
static var font_large: bool = false
static var hint_level: int = 2 ## 0 Yok (yalnız hedef) · 1 Yön · 2 Açık (hepsi)
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


static func load_settings(path: String = PATH) -> void:
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


## Yalnızca bu sınıfın anahtarlarını yazar; dosyadaki diğer anahtarlar korunur.
static func save_settings(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "text_speed", text_speed)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "font_large", font_large)
	cfg.set_value(SECTION, "hint_level", hint_level)
	cfg.save(path)


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
