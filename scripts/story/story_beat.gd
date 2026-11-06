extends Area2D
## BÃ¶lge hikÃ¢ye etkileÅŸimi â€” kanÄ±t, bulmaca, diyalog. Ä°ptal Ã¶dÃ¼l vermez.

@export var beat_id: StringName = &"library_hall"

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if has_node("Sprite2D"):
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func on_interact(_by: Node) -> void:
	if _busy:
		return
	_busy = true
	match beat_id:
		&"library_hall":
			await _library_hall()
		&"library_witness":
			await _library_witness()
		&"library_page":
			await _library_page()
		&"experiment_cells":
			await _experiment_cells()
		&"experiment_circuit":
			await _experiment_circuit()
		&"experiment_authority":
			await _experiment_authority()
		&"mirrors_reverse":
			await _mirrors_reverse()
		&"mirrors_dual":
			await _mirrors_dual()
		&"mirrors_unbroken":
			await _mirrors_unbroken()
		&"core_threshold":
			await _core_threshold()
		&"core_seal_chamber":
			await _core_seal_chamber()
		_:
			DialogueManager.say("Sen", "â€¦Bir ÅŸey hatÄ±rlamaya Ã§alÄ±ÅŸÄ±yor.")
			await DialogueManager.dialogue_finished
	_busy = false


func _library_hall() -> void:
	DialogueManager.say("ArÅŸivci", "Katalogâ€¦ Ã¶lÃ¼mde kopan hatÄ±ralarÄ± sÄ±ralar.")
	DialogueManager.say("ArÅŸivci", "Ä°ki kayÄ±t aynÄ± anÄ± anlatmÄ±yor. Ã‡eliÅŸiyorlar.")
	DialogueManager.say("Sen", "Hangisi doÄŸru?")
	DialogueManager.say("ArÅŸivci", "Ikisi deâ€¦ bir bakÄ±ma. Soruyu aÃ§Ä±k bÄ±rak.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_evidence("ev_catalog_conflict", "Ã‡eliÅŸen kayÄ±tlar", "Ä°ki tanÄ±klÄ±k aynÄ± anÄ± farklÄ± anlatÄ±yor.", "open_question", "notlar")
	PuzzleManager.mark_solved(&"library_catalog")
	SaveManager.save_game()


func _library_witness() -> void:
	if PuzzleManager.is_solved(&"library_witnesses"):
		DialogueManager.say("Sen", "Üç tanık… sustu.")
		return
	DialogueManager.say("Sen", "Saat, çiçek, mühür. Hepsi birbirini düzeltiyor.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})
	if ev.has("ev_witness_clock") and ev.has("ev_witness_flower") and ev.has("ev_witness_seal"):
		PuzzleManager.mark_solved(&"library_witnesses")
		SaveManager.save_game()
	else:
		DialogueManager.say("Sen", "Önce her tanığı tek tek dinlemeliyim.")


func _library_page() -> void:
	var room := get_tree().get_first_node_in_group("library_page_puzzle")
	if room and room.has_method("open_puzzle"):
		room.open_puzzle()
	else:
		push_warning("story_beat: library_page_puzzle eksik")


func _experiment_cells() -> void:
	DialogueManager.say("Sen", "HÃ¼crelerâ€¦ gÃ¼venli Ã¶rnekler.")
	DialogueManager.say("???", "DÃ¼zenek bÃ¶yle Ã§alÄ±ÅŸÄ±yor. CanlÄ± denek yok.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"experiment_cells_seen")
	_evidence("ev_cells_demo", "GÃ¶zlem hÃ¼creleri", "DÃ¼zenek gÃ¼venli Ã¶rnekle gÃ¶sterildi.", "evidence", "notlar")
	SaveManager.save_game()


func _experiment_circuit() -> void:
	if PuzzleManager.is_solved(&"experiment_circuit"):
		DialogueManager.say("Sen", "Devre hazır.")
		return
	DialogueManager.say("Sen", "Kayıtlı rota — oyuncu kaydı değil. Üstteki düğmelerle akış.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return


func _experiment_authority() -> void:
	DialogueManager.say("KayÄ±t", "Yetki: Shiren. KatkÄ±: mÃ¼hÃ¼r protokolÃ¼.")
	DialogueManager.say("Sen", "Ben miâ€¦ buna yardÄ±m ettim?")
	DialogueManager.say("Shilda", "GerÃ§eÄŸin bir bÃ¶lÃ¼mÃ¼nÃ¼ sakladÄ±m. Hepsi deÄŸil.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_evidence("ev_authority", "Yetki masasÄ±", "GeÃ§miÅŸte dÃ¼zene katkÄ±da bulunmuÅŸum.", "evidence", "gunluk")
	PuzzleManager.mark_solved(&"experiment_authority")
	GameState.set_world_flag(&"mirrors_unlocked", true)
	SaveManager.save_game()


func _mirrors_reverse() -> void:
	DialogueManager.say("Sen", "Aynada bir kapÄ±â€¦ solda Ä±ÅŸÄ±k.")
	DialogueManager.say("Sen", "GerÃ§ekte saÄŸdaki iÅŸaret aynÄ±.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"mirrors_reverse")
	SaveManager.save_game()


func _mirrors_dual() -> void:
	DialogueManager.say("Sen", "YankÄ± bir hatta, ben diÄŸerinde.")
	DialogueManager.say("Sen", "Ä°kisi birdenâ€¦ tamam.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"mirrors_dual")
	SaveManager.save_game()


func _mirrors_unbroken() -> void:
	DialogueManager.say("Sen", "Beni korumuyordun. KararÄ±mÄ± koruyordun.")
	DialogueManager.say("Shilda", "Ä°kisini ayÄ±rmayÄ± unuttum.")
	DialogueManager.say("Sen", "â€¦O zaman Ã‡ekirdek'te seÃ§eriz.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	GameState.player_progress_knowledge["shilda_named"] = true
	GameState.player_progress_knowledge["truth_seen"] = true
	PuzzleManager.mark_solved(&"mirrors_unbroken")
	GameState.set_world_flag(&"core_path_open", true)
	SaveManager.save_game()


func _core_threshold() -> void:
	DialogueManager.say("Sen", "Ã–nceki yollarâ€¦ burada birleÅŸiyor.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"core_threshold")
	SaveManager.save_game()


func _core_seal_chamber() -> void:
	DialogueManager.say("Sen", "TanÄ±klÄ±klarâ€¦ devrede.")
	DialogueManager.say("Shilda", "HazÄ±rsan Ã‡ekirdek seni bekliyor.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"core_seal")
	SaveManager.save_game()


func _evidence(eid: String, title: String, body: String, kind: String, section: String) -> void:
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	if ev.has(eid):
		return
	ev[eid] = {"id": eid, "discovered": true, "kind": kind, "title": title, "body": body, "section": section}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({
		"evidence_id": eid,
		"section": section,
		"title": title,
		"body": body,
		"kind": kind,
	})
	GameState.player_progress_knowledge["journal_notes"] = notes
	EchoManager.journal_updated.emit()

