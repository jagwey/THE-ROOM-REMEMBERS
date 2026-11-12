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
	var panel := GothicModalPanel.new()
	panel.name = "Panel"
	panel.setup("Unutulmuş sayfa — sırayı kur", Vector2(470, 330))
	add_child(panel)
	panel.add_label("Tanıkları hatırla: önce deney, sonra kapı, en son mühür.", UiTheme.HINT)
	for i in 3:
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.apply_outlined(lab, UiTheme.BODY, true)
		panel.body.add_child(lab)
		_labels.append(lab)
	var row := _row(panel)
	_btn(panel, row, "← önceki kart", _select_prev)
	_btn(panel, row, "sonraki kart →", _select_next)
	var row2 := _row(panel)
	_btn(panel, row2, "Yukarı al", _swap_up)
	_btn(panel, row2, "Aşağı al", _swap_down)
	var row3 := _row(panel)
	_btn(panel, row3, "Doğrula", _on_verify)
	_btn(panel, row3, "Kapat", _hide_puzzle)
	_sync_labels()


func _row(panel: GothicModalPanel) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	panel.body.add_child(r)
	return r


func _btn(panel: GothicModalPanel, row: HBoxContainer, text: String, cb: Callable) -> void:
	var b := panel.add_button(text, cb, row)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func open_puzzle() -> void:
	if PuzzleManager.is_solved(&"library_page_order"):
		DialogueManager.say("Noroi", "Sayfa yerinde.")
		return
	if not has_node("Panel"):
		_build_ui()
	if not PuzzleManager.is_solved(&"library_witnesses"):
		DialogueManager.say("Noroi", "Önce saat, çiçek ve mührü dinlemeliyim. Sonra ortadaki kaydı karşılaştıracağım.")
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
		DialogueManager.say("", "Sıra tutmuyor.")
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
	DialogueManager.say("Noroi", "Kaydı sen mi sildin?")
	DialogueManager.say("Shilda", "Hayır. Sayfayı kazıyan ben değilim. Ben bir kopyasını sakladım.")
	DialogueManager.say("Noroi", "O zaman neden sakladın?")
	DialogueManager.say("Shilda", "Biri gelip bunu soracak diye. Deneyin yetki kaydı sağdaki kapının ardında.")
	var heard: bool = await DialogueManager.dialogue_finished
	if heard:
		PuzzleManager.mark_solved(&"library_page_order")
		GameState.set_world_flag(&"experiment_unlocked", true)
		_evidence_own_seal()
		SaveManager.save_game()
		var cam := get_tree().get_first_node_in_group("follow_camera")
		var door: Node2D = null
		var idx := RoomManager.ROOM_ORDER.find("library_page")
		if idx >= 0 and idx + 1 < RoomManager.ROOM_ORDER.size():
			var next_room: String = RoomManager.ROOM_ORDER[idx + 1]
			for n in get_tree().get_nodes_in_group("room_door"):
				if n is Node2D and "target_room_id" in n and String(n.get("target_room_id")) == next_room:
					door = n as Node2D
					break
		if cam and cam.has_method("focus_pulse") and door:
			cam.focus_pulse(door.global_position + Vector2(0, -40))
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"seal_open")
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
		"title": "Silinmiş sayfa",
		"body": "Sayfayı biri kazımış. Shilda bir kopyasını saklamış.",
		"section": "gunluk",
	}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({
		"evidence_id": eid,
		"section": "gunluk",
		"title": "Silinmiş sayfa",
		"body": "Sayfayı biri kazımış. Shilda bir kopyasını saklamış.",
		"kind": "inference",
	})
	GameState.player_progress_knowledge["journal_notes"] = notes
	EchoManager.journal_updated.emit()
