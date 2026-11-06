extends CanvasLayer
## Unutulmuş sayfa — sıra: experiment_started → door_closed → seal_engaged

const ORDER: Array[String] = ["experiment_started", "door_closed", "seal_engaged"]

var _labels: Array[Label] = []
var _slots: Array[String] = ["seal_engaged", "experiment_started", "door_closed"]
var _selected: int = 0
var _verifying: bool = false


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not has_node("Panel"):
		_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210.0
	panel.offset_top = -130.0
	panel.offset_right = 210.0
	panel.offset_bottom = 130.0
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "Unutulmuş sayfa — sırayı kur"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var clue := Label.new()
	clue.text = "Saat: deney önce. Çiçek: kapı sonra. Mühür: koruma en son."
	clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue.custom_minimum_size.x = 380
	v.add_child(clue)
	for i in 3:
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
		_labels.append(lab)
	var row := HBoxContainer.new()
	v.add_child(row)
	var b_prev := Button.new()
	b_prev.text = "← önceki kart"
	b_prev.pressed.connect(_select_prev)
	row.add_child(b_prev)
	var b_next := Button.new()
	b_next.text = "sonraki kart →"
	b_next.pressed.connect(_select_next)
	row.add_child(b_next)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var b_up := Button.new()
	b_up.text = "Yukarı al"
	b_up.pressed.connect(_swap_up)
	row2.add_child(b_up)
	var b_down := Button.new()
	b_down.text = "Aşağı al"
	b_down.pressed.connect(_swap_down)
	row2.add_child(b_down)
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	var b_try := Button.new()
	b_try.text = "Doğrula"
	b_try.pressed.connect(_on_verify)
	row3.add_child(b_try)
	var b_close := Button.new()
	b_close.text = "Kapat"
	b_close.pressed.connect(_hide_puzzle)
	row3.add_child(b_close)
	_sync_labels()


func open_puzzle() -> void:
	if PuzzleManager.is_solved(&"library_page_order"):
		DialogueManager.say("Shiren", "Sayfa yerinde.")
		return
	if not has_node("Panel"):
		_build_ui()
	if not PuzzleManager.is_solved(&"library_witnesses"):
		DialogueManager.say("Shiren", "Sayfayı kurmadan önce saat, çiçek ve mührü dinlemeliyim. Sonra ortadaki kaydı karşılaştırmalıyım.")
		return
	visible = true
	UiGate.set_story(true)
	_sync_labels()


func _hide_puzzle() -> void:
	visible = false
	UiGate.set_story(false)


func _label_for(id: String) -> String:
	match id:
		"experiment_started":
			return "Deney başlatıldı"
		"door_closed":
			return "Kapı kapatıldı"
		"seal_engaged":
			return "Mühür devreye girdi"
		_:
			return id


func _sync_labels() -> void:
	for i in mini(_labels.size(), _slots.size()):
		_labels[i].text = _label_for(_slots[i])
		_labels[i].modulate = Color.WHITE if i == _selected else Color(0.75, 0.72, 0.8)


func _select_prev() -> void:
	_selected = (_selected + 2) % 3
	_sync_labels()


func _select_next() -> void:
	_selected = (_selected + 1) % 3
	_sync_labels()


func _swap_up() -> void:
	if _selected <= 0:
		return
	var t: String = _slots[_selected - 1]
	_slots[_selected - 1] = _slots[_selected]
	_slots[_selected] = t
	_selected -= 1
	_sync_labels()


func _swap_down() -> void:
	if _selected >= 2:
		return
	var t: String = _slots[_selected + 1]
	_slots[_selected + 1] = _slots[_selected]
	_slots[_selected] = t
	_selected += 1
	_sync_labels()


func _on_verify() -> void:
	if _verifying:
		return
	_verifying = true
	var ok := true
	for i in ORDER.size():
		if _slots[i] != ORDER[i]:
			ok = false
			break
	if not ok:
		visible = false
		DialogueManager.say("???", "Sıra tutmuyor.")
		await DialogueManager.dialogue_finished
		_verifying = false
		visible = true
		UiGate.set_story(true)
		return
	await _success_flow()
	_verifying = false


func _success_flow() -> void:
	visible = false
	UiGate.set_story(false)
	DialogueManager.say("Shiren", "Kaydı sen mi sildin?")
	DialogueManager.say("Shilda", "Hayır. Silmemi sen istedin.")
	DialogueManager.say("Shiren", "O zaman neden sakladın?")
	DialogueManager.say("Shilda", "Bir gün bunu yeniden sorarsın diye. Deneyin yetki kaydı sağdaki kapının ardında.")
	var heard: bool = await DialogueManager.dialogue_finished
	if heard:
		PuzzleManager.mark_solved(&"library_page_order")
		GameState.set_world_flag(&"experiment_unlocked", true)
		_evidence_own_seal()
		SaveManager.save_game()
	_hide_puzzle()


func _evidence_own_seal() -> void:
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	var eid := "ev_own_seal"
	if ev.has(eid):
		return
	ev[eid] = {
		"id": eid,
		"discovered": true,
		"kind": "inference",
		"title": "Kendi mührüm",
		"body": "Kaydı silmemi istemişim. Shilda saklamış.",
		"section": "gunluk",
	}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({
		"evidence_id": eid,
		"section": "gunluk",
		"title": "Kendi mührüm",
		"body": "Kaydı silmemi istemişim. Shilda saklamış.",
		"kind": "inference",
	})
	GameState.player_progress_knowledge["journal_notes"] = notes
	EchoManager.journal_updated.emit()
