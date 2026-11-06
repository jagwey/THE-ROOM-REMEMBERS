extends CanvasLayer
## İki sayfa günlük: sol liste, sağ ayrıntı. Tree pause YOK — UiGate ile oynanış durur.

signal closed

@onready var book_art: TextureRect = $BookRoot/BookArt
@onready var tab_gunluk: Button = $BookRoot/LeftPage/Tabs/Gunluk
@onready var tab_notlar: Button = $BookRoot/LeftPage/Tabs/Notlar
@onready var tab_izler: Button = $BookRoot/LeftPage/Tabs/Izler
@onready var list_title: Label = $BookRoot/LeftPage/ListTitle
@onready var entry_list: ItemList = $BookRoot/LeftPage/Scroll/EntryList
@onready var detail_title: Label = $BookRoot/RightPage/DetailTitle
@onready var scroll: ScrollContainer = $BookRoot/RightPage/Scroll
@onready var detail_body: RichTextLabel = $BookRoot/RightPage/Scroll/DetailBody
@onready var empty_label: Label = $BookRoot/RightPage/EmptyLabel
@onready var btn_close: Button = $BookRoot/RightPage/Close

var _section: String = "gunluk"
var _entries: Array = []

const JOURNAL_ATLAS := Rect2(63, 2, 193, 128)


func _ready() -> void:
	add_to_group("journal_ui")
	visible = false
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/panels/journal.png")
	atlas.region = JOURNAL_ATLAS
	book_art.texture = atlas
	book_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	list_title.add_theme_color_override("font_color", Color(0.2, 0.14, 0.18, 1.0))
	detail_title.add_theme_color_override("font_color", Color(0.2, 0.14, 0.18, 1.0))
	detail_body.add_theme_color_override("default_color", Color(0.18, 0.12, 0.16, 1.0))
	empty_label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.32, 1.0))
	UiTheme.apply_label(list_title, 11, true)
	UiTheme.apply_label(detail_title, 12, true)
	UiTheme.apply_label(detail_body, 10, false)
	UiTheme.apply_label(empty_label, 10, false)
	for tab in [tab_gunluk, tab_notlar, tab_izler, btn_close]:
		if tab:
			UiTheme.apply_label(tab, 10, false)
	tab_gunluk.pressed.connect(func(): _show_section("gunluk"))
	tab_notlar.pressed.connect(func(): _show_section("notlar"))
	tab_izler.pressed.connect(func(): _show_section("izler"))
	btn_close.pressed.connect(close_journal)
	entry_list.item_selected.connect(_on_entry_selected)
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
	if UiGate.current_layer() == UiGate.Layer.ENDING:
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
	entry_list.clear()
	for n in _entries:
		if n is Dictionary:
			var t := String(n.get("title", "Kayıt"))
			if t.length() > 22:
				t = t.substr(0, 21) + "…"
			entry_list.add_item(t)
	if _entries.is_empty():
		detail_title.text = ""
		detail_body.text = ""
		empty_label.visible = true
		empty_label.text = "Sayfa boş…\nhenüz bir yankı yok."
		return
	empty_label.visible = false
	entry_list.select(0)
	_on_entry_selected(0)


func _on_entry_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var n: Variant = _entries[index]
	if not (n is Dictionary):
		return
	detail_title.text = String(n.get("title", ""))
	detail_body.text = String(n.get("body", ""))
	detail_body.scroll_to_line(0)


func _highlight_tabs() -> void:
	for pair in [[tab_gunluk, "gunluk"], [tab_notlar, "notlar"], [tab_izler, "izler"]]:
		var btn: Button = pair[0]
		var id: String = pair[1]
		if id == _section:
			btn.modulate = Color(1.25, 1.1, 1.0, 1.0)
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
