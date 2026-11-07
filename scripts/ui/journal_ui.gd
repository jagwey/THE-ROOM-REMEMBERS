extends CanvasLayer
## İki sayfa günlük: sol liste, sağ ayrıntı. Tree pause YOK — UiGate ile oynanış durur.

signal closed

@onready var book_art: TextureRect = $BookRoot/BookArt
@onready var tab_gunluk: Button = $BookRoot/Tabs/Gunluk
@onready var tab_notlar: Button = $BookRoot/Tabs/Notlar
@onready var tab_izler: Button = $BookRoot/Tabs/Izler
@onready var tab_harita: Button = $BookRoot/Tabs/Harita
@onready var left_page: Control = $BookRoot/LeftPage
@onready var right_page: Control = $BookRoot/RightPage
@onready var map_view: JournalMap = $BookRoot/MapView
@onready var list_title: Label = $BookRoot/LeftPage/ListTitle
@onready var entry_list: VBoxContainer = $BookRoot/LeftPage/Scroll/EntryList
@onready var detail_title: Label = $BookRoot/RightPage/DetailTitle
@onready var scroll: ScrollContainer = $BookRoot/RightPage/Scroll
@onready var detail_body: RichTextLabel = $BookRoot/RightPage/Scroll/DetailBody
@onready var empty_label: Label = $BookRoot/RightPage/EmptyLabel
@onready var btn_close: Button = $BookRoot/Close

var _section: String = "gunluk"
var _entries: Array = []
var _selected_index: int = -1

const JOURNAL_ATLAS := Rect2(63, 2, 193, 128)
const INK := Color(0.239, 0.071, 0.125)
const INK_SOFT := Color(0.36, 0.17, 0.22)


func _ready() -> void:
	add_to_group("journal_ui")
	visible = false
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/panels/journal.png")
	atlas.region = JOURNAL_ATLAS
	book_art.texture = atlas
	book_art.stretch_mode = TextureRect.STRETCH_SCALE
	book_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Parşömen üstü koyu bordo mürekkep (yüksek kontrast).
	list_title.add_theme_color_override("font_color", INK)
	detail_title.add_theme_color_override("font_color", INK)
	detail_body.add_theme_color_override("default_color", INK)
	detail_body.add_theme_constant_override("line_separation", 4)
	empty_label.add_theme_color_override("font_color", INK_SOFT)
	UiTheme.apply_label(list_title, UiTheme.SPEAKER, true)
	UiTheme.apply_label(detail_title, UiTheme.SPEAKER, true)
	UiTheme.apply_label(detail_body, UiTheme.BODY, false)
	detail_body.add_theme_constant_override("line_separation", 4)
	detail_body.add_theme_color_override("default_color", INK)
	UiTheme.apply_label(empty_label, UiTheme.BODY, false)
	for tab in [tab_gunluk, tab_notlar, tab_izler, tab_harita, btn_close]:
		if tab:
			GothicModalPanel.style_button(tab, UiTheme.HINT)
			tab.custom_minimum_size.y = 24.0
	for tab in [tab_gunluk, tab_notlar, tab_izler, tab_harita]:
		var on := StyleBoxFlat.new()
		on.bg_color = Palette.DARK_RED
		on.border_color = Palette.IVORY
		on.set_border_width_all(2)
		tab.add_theme_stylebox_override("disabled", on)
		tab.add_theme_color_override("font_disabled_color", Palette.IVORY)
	map_view.visible = false
	tab_gunluk.pressed.connect(func(): _show_section("gunluk"))
	tab_notlar.pressed.connect(func(): _show_section("notlar"))
	tab_izler.pressed.connect(func(): _show_section("izler"))
	tab_harita.pressed.connect(func(): _show_section("harita"))
	btn_close.pressed.connect(close_journal)
	EchoManager.journal_updated.connect(func(): if visible: _show_section(_section))
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle_journal()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_journal()
		get_viewport().set_input_as_handled()


func open_journal() -> void:
	if UiGate.current_layer() == UiGate.Layer.ENDING or UiGate.current_layer() == UiGate.Layer.CUTSCENE:
		return
	GameState.player_progress_knowledge["journal_unlocked"] = true
	visible = true
	UiGate.set_journal(true)
	_show_section(_section)
	btn_close.grab_focus()


func close_journal() -> void:
	if not visible:
		return
	visible = false
	UiGate.set_journal(false)
	MobileInputManager.clear_held_inputs()
	closed.emit()


func toggle_journal() -> void:
	if visible:
		close_journal()
	else:
		open_journal()


func _show_section(section: String) -> void:
	_section = section
	_highlight_tabs()
	var is_map := section == "harita"
	map_view.visible = is_map
	left_page.visible = not is_map
	right_page.visible = not is_map
	if is_map:
		map_view.refresh()
		return
	var label := "Günlük"
	match section:
		"notlar":
			label = "Notlar"
		"izler":
			label = "İzler"
		_:
			label = "Günlük"
	list_title.text = label
	_entries = EchoManager.get_notes_for_section(section)
	if section == "izler":
		_entries = _entries.duplicate()
		_append_world_traces(_entries)
	_rebuild_list()
	if _entries.is_empty():
		detail_title.text = ""
		detail_body.text = ""
		empty_label.visible = true
		empty_label.text = "Sayfa boş…\nhenüz bir yankı yok."
		return
	empty_label.visible = false
	_on_entry_selected(0)


## Girdiler sarmalı (autowrap) düğmeler: uzun başlıklar kesilmez, liste kaydırılır.
func _rebuild_list() -> void:
	for c in entry_list.get_children():
		entry_list.remove_child(c)
		c.queue_free()
	for i in _entries.size():
		var n: Variant = _entries[i]
		if not (n is Dictionary):
			continue
		var b := Button.new()
		b.text = String(n.get("title", "Kayıt"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		b.custom_minimum_size = Vector2(190, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		UiTheme.apply_label(b, UiTheme.BODY, false)
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(col, INK)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _entry_box(0.10))
		b.add_theme_stylebox_override("pressed", _entry_box(0.28))
		b.add_theme_stylebox_override("focus", _entry_box(0.16))
		b.pressed.connect(_on_entry_selected.bind(i))
		entry_list.add_child(b)


func _on_entry_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var n: Variant = _entries[index]
	if not (n is Dictionary):
		return
	_selected_index = index
	for i in entry_list.get_child_count():
		var b := entry_list.get_child(i) as Button
		if b:
			b.add_theme_stylebox_override("normal", _entry_box(0.22) if i == index else StyleBoxEmpty.new())
	detail_title.text = String(n.get("title", ""))
	detail_body.text = String(n.get("body", ""))
	detail_body.scroll_to_line(0)


func _highlight_tabs() -> void:
	for pair in [[tab_gunluk, "gunluk"], [tab_notlar, "notlar"], [tab_izler, "izler"], [tab_harita, "harita"]]:
		var btn: Button = pair[0]
		var id: String = pair[1]
		if id == _section:
			btn.modulate = Color.WHITE
			btn.disabled = true
		else:
			btn.modulate = Color(1, 1, 1, 1)
			btn.disabled = false


func _append_world_traces(notes: Array) -> void:
	var flags: Dictionary = GameState.world_memory_state.get("flags", {})
	if bool(flags.get("awakening_trap_sprung", false)):
		notes.append({"title": "Yarık", "body": "Zemin yalan söyledi. Dünya bunu hatırlıyor."})
	if bool(flags.get("awakening_door_opened", false)):
		notes.append({"title": "Ağırlık", "body": "Bir beden plakaya yetti. Yol açıldı."})
	if bool(flags.get("awakening_crystal_cracked", false)):
		notes.append({"title": "314", "body": "Mühür, hatırladığım sayıya boyun eğdi."})
	for t in GameState.world_memory_state.get("traces", []):
		if t is Dictionary:
			notes.append({
				"title": "İz: %s" % String(t.get("kind", "?")),
				"body": "Fazla cesetten kalan iz. Oda unutmaz.",
			})


func _entry_box(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.12, 0.2, alpha)
	sb.border_color = Color(INK, 0.8)
	sb.set_border_width_all(1)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb
