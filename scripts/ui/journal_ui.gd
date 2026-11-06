extends CanvasLayer
## Yıpranmış sayfa günlük — Günlük / Notlar / İzler. Oyuncu meta bilgisi.

signal closed

@onready var panel: TextureRect = $Panel
@onready var title: Label = $Panel/Title
@onready var body: RichTextLabel = $Panel/Body
@onready var tab_gunluk: Button = $Panel/Tabs/Gunluk
@onready var tab_notlar: Button = $Panel/Tabs/Notlar
@onready var tab_izler: Button = $Panel/Tabs/Izler
@onready var btn_close: Button = $Panel/Close

var _section: String = "gunluk"


func _ready() -> void:
	add_to_group("journal_ui")
	visible = false
	layer = 20
	panel.texture = load("res://assets/panels/journal.png")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tab_gunluk.pressed.connect(func(): _show_section("gunluk"))
	tab_notlar.pressed.connect(func(): _show_section("notlar"))
	tab_izler.pressed.connect(func(): _show_section("izler"))
	btn_close.pressed.connect(close_journal)
	EchoManager.journal_updated.connect(func(): if visible: _show_section(_section))
	# Klavye J
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle_journal()
		get_viewport().set_input_as_handled()


func open_journal() -> void:
	GameState.player_progress_knowledge["journal_unlocked"] = true
	visible = true
	_show_section(_section)


func close_journal() -> void:
	visible = false
	closed.emit()


func toggle_journal() -> void:
	if visible:
		close_journal()
	else:
		open_journal()


func _show_section(section: String) -> void:
	_section = section
	var label := "Günlük"
	match section:
		"notlar":
			label = "Notlar"
		"izler":
			label = "İzler"
		_:
			label = "Günlük"
	title.text = label
	var notes: Array = EchoManager.get_notes_for_section(section)
	# Dünya bayraklarından iz satırları
	if section == "izler":
		notes = notes.duplicate()
		_append_world_traces(notes)
	if notes.is_empty():
		body.text = "[i]Sayfa boş… henüz bir yankı yok.[/i]"
		return
	var text := ""
	for n in notes:
		if n is Dictionary:
			text += "[b]%s[/b]\n%s\n\n" % [String(n.get("title", "")), String(n.get("body", ""))]
	body.text = text.strip_edges()


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
