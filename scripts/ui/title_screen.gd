extends Control
## Tam ekran ana menü: atmosferik arka plan, kayıt özeti kartı, ayarlar / nasıl oynanır alt sayfaları.
## SessionMenu oluşturur; ayar durumu (ses, müzik, joystick) SessionMenu'de kalır.

signal start_requested
signal new_game_requested
signal quit_requested

const RoomTransitionScript := preload("res://scripts/world/room_transition.gd")
const BG_DIR := "res://assets/backgrounds/awakening/"
const DRIFT := 18.0

var menu: Node ## SessionMenu — ayar metinleri ve değiştiricileri
var _layers: Array[TextureRect] = []
var _title: Label
var _pages: Dictionary = {} ## StringName -> VBoxContainer
var _page: StringName = &"main"
var _start_button: Button
var _new_button: Button
var _vol_button: Button
var _music_button: Button
var _joy_button: Button
var _fs_button: Button
var _card_box: VBoxContainer
var _t: float = 0.0
var _closing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_layout()
	hide()


func open(has_save: bool) -> void:
	_closing = false
	_start_button.text = "Devam et" if has_save else "Başla"
	_new_button.visible = has_save
	_refresh_card()
	_refresh_settings()
	_show_page(&"main")
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## Kapanış: kısa karartma, sonra geri çağrı (oyuna geçiş).
func close(then: Callable) -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		hide()
		then.call())


## Android geri / Esc: alt sayfadaysa ana sayfaya döner. true = olay tüketildi.
func back() -> bool:
	if _page != &"main":
		_click()
		_show_page(&"main")
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and back():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	## Katmanlar farklı hızda salınır — derinlik hissi.
	for i in _layers.size():
		var k := float(i + 1) / float(_layers.size())
		_layers[i].position.x = -DRIFT + sin(_t * 0.12 + i) * DRIFT * k
	## Başlık mum ışığı gibi titrer.
	var flick := 0.9 + 0.06 * sin(_t * 2.3) + 0.04 * sin(_t * 7.1)
	_title.modulate = Color(1.0, flick, flick, 1.0)


# --- Kurulum -----------------------------------------------------------------

func _build_background() -> void:
	var base := ColorRect.new()
	base.color = Palette.VOID
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	for layer_name in ["far", "mid", "front"]:
		var tex := load(BG_DIR + layer_name + ".png") as Texture2D
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = -DRIFT
		tr.offset_right = DRIFT
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_layers.append(tr)
	## Sol tarafı koyulaştır: menü okunur, sahne sağda görünür kalır.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(Palette.VOID, 0.92))
	grad.set_color(1, Color(Palette.VOID, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var motes := _Motes.new()
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(motes)


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	_title = Label.new()
	_title.text = "THE ROOM REMEMBERS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(_title, 30, true)
	root.add_child(_title)
	var sub := Label.new()
	sub.text = "Sen unutursun. Oda hatırlar."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(sub, UiTheme.HINT, false, Palette.PALE_LILAC)
	root.add_child(sub)
	var line_box := CenterContainer.new()
	var line := ColorRect.new()
	line.color = Palette.CRIMSON
	line.custom_minimum_size = Vector2(220, 2)
	line_box.add_child(line)
	root.add_child(line_box)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	root.add_child(spacer)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 230
	row.add_child(column)
	_build_main_page(column)
	_build_settings_page(column)
	_build_help_page(column)
	_build_confirm_page(column)

	row.add_child(_build_card())

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var hint := Label.new()
	hint.text = "" if MobileInputManager.is_touch_ui() else "Yön tuşları: seç · Enter: onayla · Esc: geri"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.apply_outlined(hint, 12, false, Palette.PALE_LILAC)
	footer.add_child(hint)
	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	UiTheme.apply_outlined(ver, 12, false, Palette.PALE_LILAC)
	footer.add_child(ver)


func _new_page(parent: Control, id: StringName) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.hide()
	parent.add_child(page)
	_pages[id] = page
	return page


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	GothicModalPanel.style_button(b)
	b.custom_minimum_size.y = 34.0 if MobileInputManager.is_touch_ui() else 30.0
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		_click()
		cb.call())
	## Fare ile klavye aynı vurguyu paylaşsın.
	b.mouse_entered.connect(func():
		if not MobileInputManager.is_touch_ui():
			b.grab_focus())
	parent.add_child(b)
	return b


func _page_label(parent: Control, text: String, size: int = UiTheme.HINT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.apply_outlined(l, size, bold)
	parent.add_child(l)
	return l


func _build_main_page(parent: Control) -> void:
	var p := _new_page(parent, &"main")
	_start_button = _button(p, "Başla", func(): start_requested.emit())
	_new_button = _button(p, "Yeni oyun", func(): _show_page(&"confirm"))
	_button(p, "Ayarlar", func(): _show_page(&"settings"))
	_button(p, "Nasıl oynanır", func(): _show_page(&"help"))
	_button(p, "Çıkış", func(): quit_requested.emit())


func _build_settings_page(parent: Control) -> void:
	var p := _new_page(parent, &"settings")
	_page_label(p, "AYARLAR", UiTheme.BODY, true)
	_vol_button = _button(p, "", func():
		menu._cycle_volume()
		_refresh_settings())
	_music_button = _button(p, "", func():
		menu._toggle_music()
		_refresh_settings())
	_joy_button = _button(p, "", func():
		menu._toggle_joystick_mode()
		_refresh_settings())
	_fs_button = _button(p, "Tam ekran (F11)", func(): menu.toggle_fullscreen())
	_fs_button.visible = not OS.has_feature("mobile")
	_button(p, "< Geri", func(): _show_page(&"main"))


func _build_help_page(parent: Control) -> void:
	var p := _new_page(parent, &"help")
	_page_label(p, "NASIL OYNANIR", UiTheme.BODY, true)
	var controls := ""
	if MobileInputManager.is_touch_ui():
		controls = "Sol joystick: yürü\nSağ düğmeler: zıpla · etkileş · saldır · atıl · yankı\nSağ üst: günlük ve menü"
	else:
		controls = "A/D: yürü · W/Space: zıpla\nE: etkileş · Z: saldır · X: atıl\nQ: yankı · I: günlük · Esc: menü"
	_page_label(p, controls, 13)
	_page_label(p, "Ölmek son değil: bedenin odada kalır ve bulmacaları çözmene yardım eder.", 12).add_theme_color_override("font_color", Palette.PALE_LILAC)
	_button(p, "< Geri", func(): _show_page(&"main"))


func _build_confirm_page(parent: Control) -> void:
	var p := _new_page(parent, &"confirm")
	_page_label(p, "YENİ OYUN", UiTheme.BODY, true)
	_page_label(p, "Tüm ilerleme silinecek. Oda yine de hatırlayabilir…", 13)
	_button(p, "Evet, sıfırdan başla", func(): new_game_requested.emit())
	_button(p, "Vazgeç", func(): _show_page(&"main"))


func _build_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.VOID, 0.82)
	sb.border_color = Palette.STONE
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 5)
	card.add_child(_card_box)
	return card


# --- Durum -------------------------------------------------------------------

func _show_page(id: StringName) -> void:
	_page = id
	for k in _pages.keys():
		(_pages[k] as Control).visible = k == id
	_focus_first.call_deferred(_pages[id])


func _focus_first(page: Control) -> void:
	for c in page.get_children():
		if c is Button and (c as Button).visible:
			(c as Button).grab_focus()
			return


func _refresh_settings() -> void:
	if menu == null:
		return
	_vol_button.text = menu._vol_text()
	_music_button.text = menu._music_text()
	_joy_button.text = menu._joy_text()


func _refresh_card() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	var gs := GameState
	var visited: Array = gs.player_progress_knowledge.get("rooms_visited", [])
	if not SaveManager.has_save() or visited.size() <= 1 and int(gs.player_progress_knowledge.get("deaths", 0)) == 0:
		_card_line("YENİ UYANIŞ", UiTheme.BODY, true, Palette.IVORY)
		_card_line("Hiçbir şey hatırlamıyorsun.\nOda ise her şeyi hatırlıyor.", 13, false, Palette.IVORY)
		_card_line("Saatine bak, plakaya bas, ilerle.", 12, false, Palette.PALE_LILAC)
		return
	var rid := String(gs.character_current_life_knowledge.get("room", &"awakening"))
	var titles: Dictionary = RoomTransitionScript.ROOM_TITLES
	_card_line("SON HAFIZA", UiTheme.BODY, true, Palette.IVORY)
	_card_line(String(titles.get(rid, rid.capitalize())), 15, true, Color(1.0, 0.82, 0.5))
	_card_line("Keşif: %d / %d oda" % [visited.size(), titles.size()], 13, false, Palette.IVORY)
	_card_line("Ölüm: %d · Can: %d/%d" % [int(gs.player_progress_knowledge.get("deaths", 0)), gs.hearts, gs.max_hearts], 13, false, Palette.IVORY)
	var endings: Array = gs.player_progress_knowledge.get("endings_seen", [])
	if not endings.is_empty():
		_card_line("Görülen son: %d" % endings.size(), 13, false, Palette.IVORY)
	var obj := gs.get_current_objective()
	if not obj.is_empty():
		_card_line("Hedef: " + obj, 12, false, Palette.PALE_LILAC)


func _card_line(text: String, size: int, bold: bool, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 196
	UiTheme.apply_outlined(l, size, bold, color)
	_card_box.add_child(l)


func _click() -> void:
	AudioManager.play_sfx(&"ui_click", -6.0)


## Yavaşça yükselen kor / toz zerreleri.
class _Motes extends Control:
	const COUNT := 34
	var _p: Array = []

	func _ready() -> void:
		for i in COUNT:
			_p.append(_spawn(true))

	func _spawn(anywhere: bool) -> Dictionary:
		var s := get_viewport_rect().size if is_inside_tree() else Vector2(640, 360)
		return {
			"pos": Vector2(randf() * s.x, (randf() * s.y) if anywhere else s.y + 4.0),
			"v": randf_range(6.0, 18.0),
			"r": randf_range(0.6, 1.6),
			"ph": randf() * TAU,
			"warm": randf() < 0.6,
		}

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		for i in _p.size():
			var m: Dictionary = _p[i]
			m["ph"] = float(m["ph"]) + delta
			m["pos"] = (m["pos"] as Vector2) + Vector2(sin(float(m["ph"]) * 0.8) * 6.0 * delta, -float(m["v"]) * delta)
			if (m["pos"] as Vector2).y < -4.0:
				_p[i] = _spawn(false)
		queue_redraw()

	func _draw() -> void:
		for m in _p:
			var a := 0.35 + 0.35 * sin(float(m["ph"]) * 2.0)
			var c := Color(1.0, 0.72, 0.45, a) if m["warm"] else Color(0.75, 0.65, 0.85, a * 0.8)
			draw_circle(m["pos"], float(m["r"]), c)
