extends Area2D

## Bölge hikâye etkileşimi — kanıt, bulmaca, diyalog. İptal ödül vermez.



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

			DialogueManager.say("Sen", "Bir şey hatırlamaya çalışıyor.")

			await DialogueManager.dialogue_finished

	_busy = false





func _library_hall() -> void:

	DialogueManager.say("Arşivci", "Katalog… ölümde kopan hatıraları sıralar.")

	DialogueManager.say("Arşivci", "İki kayıt aynı anı anlatmıyor. Çelişiyorlar.")

	DialogueManager.say("Sen", "Hangisi doğru?")

	DialogueManager.say("Arşivci", "İkisi de bir bakıma. Soruyu açık bırak.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_catalog_conflict", "Çelişen kayıtlar", "İki tanıklık aynı anı farklı anlatıyor.", "open_question", "notlar")

	PuzzleManager.mark_solved(&"library_catalog")

	SaveManager.save_game()





func _library_witness() -> void:

	if PuzzleManager.is_solved(&"library_witnesses"):

		DialogueManager.say("Sen", "Üç tanık sustu.")

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

	DialogueManager.say("Sen", "Hücreler… güvenli örnekler.")

	DialogueManager.say("???", "Düzenek böyle çalışıyor. Canlı denek yok.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"experiment_cells_seen")

	_evidence("ev_cells_demo", "Gözlem hücreleri", "Düzenek güvenli örnekle gösterildi.", "evidence", "notlar")

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

	DialogueManager.say("Kayıt", "Yetki: Şiren. Katkı: mühür protokolü.")

	DialogueManager.say("Sen", "Ben mi… buna yardım ettim?")

	DialogueManager.say("Şilda", "Gerçeğin bir bölümünü sakladım. Hepsi değil.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_authority", "Yetki masası", "Geçmişte düzene katkıda bulunmuşum.", "evidence", "gunluk")

	PuzzleManager.mark_solved(&"experiment_authority")

	GameState.set_world_flag(&"mirrors_unlocked", true)

	SaveManager.save_game()





func _mirrors_reverse() -> void:

	DialogueManager.say("Sen", "Aynada bir kapı solda çıkıyor.")

	DialogueManager.say("Sen", "Gerçekte sağdaki işaret aynı.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"mirrors_reverse")

	SaveManager.save_game()





func _mirrors_dual() -> void:

	DialogueManager.say("Sen", "Yankı bir hatta, ben diğerinde.")

	DialogueManager.say("Sen", "İkisi birden… tamam.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"mirrors_dual")

	SaveManager.save_game()





func _mirrors_unbroken() -> void:

	DialogueManager.say("Sen", "Beni korumuyordun. Kararımı koruyordun.")

	DialogueManager.say("Şilda", "İkisini ayırmayı unuttum.")

	DialogueManager.say("Sen", "O zaman çekirdek'te seçeriz.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	GameState.player_progress_knowledge["shilda_named"] = true

	GameState.player_progress_knowledge["truth_seen"] = true

	PuzzleManager.mark_solved(&"mirrors_unbroken")

	GameState.set_world_flag(&"core_path_open", true)

	SaveManager.save_game()





func _core_threshold() -> void:

	DialogueManager.say("Sen", "Önceki yollar… burada birleşiyor.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"core_threshold")

	SaveManager.save_game()





func _core_seal_chamber() -> void:

	DialogueManager.say("Sen", "Tanıklıklar devrede.")

	DialogueManager.say("Şilda", "Hazırsan çekirdek seni bekliyor.")

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

