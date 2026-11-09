class_name CreditsScroll
extends ScrollContainer
## Kayan jenerik metni (içerik CreditsData'da). Başlık ekranı "Jenerik" sayfası ve final sonrası jenerik
## aynı bileşeni kullanır: `play(süre)` metni alttan üste kaydırır, bitince `finished` yayar.

signal finished

var _tween: Tween
var _box: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


func _build() -> void:
	if _box != null:
		return
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	var lead := Control.new() ## metin alttan girsin
	lead.custom_minimum_size.y = 150
	_box.add_child(lead)
	var t := Label.new()
	t.text = CreditsData.TITLE
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(t, 22, true)
	_box.add_child(t)
	_line(CreditsData.TAGLINE, UiTheme.HINT, false, Palette.PALE_LILAC)
	for s in CreditsData.SECTIONS:
		_line("", 8, false, Palette.IVORY)
		if String(s["head"]) != "":
			_line(String(s["head"]).to_upper(), UiTheme.HINT, true, Palette.CRIMSON.lightened(0.35))
		for l in s["lines"]:
			_line(String(l), UiTheme.BODY, false, Palette.IVORY)
	var tail := Control.new()
	tail.custom_minimum_size.y = 90
	_box.add_child(tail)


func _line(text: String, size: int, bold: bool, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.apply_outlined(l, size, bold, color)
	_box.add_child(l)


## Metni baştan alttan üste kaydırır. seconds: toplam kayma süresi.
func play(seconds: float, lead_in: float = 0.8) -> void:
	stop()
	scroll_vertical = 0
	_tween = create_tween()
	_tween.tween_interval(lead_in)
	_tween.tween_method(func(v: float):
		var bar := get_v_scroll_bar()
		scroll_vertical = int(v * maxf(0.0, bar.max_value - bar.page)), 0.0, 1.0, seconds)
	_tween.tween_callback(func(): finished.emit())


func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
