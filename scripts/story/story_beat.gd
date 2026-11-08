extends Area2D

## Bölge hikâye etkileşimi — kanıt, bulmaca, diyalog. İptal ödül vermez.

@export var beat_id: StringName = &"library_hall"

var _busy: bool = false
var _relay_seconds := 0.0
var _relay_label: Label
var _choice_layer: CanvasLayer

func _ready() -> void:

	collision_layer = 8

	collision_mask = 0

	monitoring = false

	monitorable = true

	if has_node("Sprite2D"):

		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if $Sprite2D.texture == null:
			$Sprite2D.texture = load("res://assets/props/memory_echo.png")
			$Sprite2D.scale = Vector2(0.5, 0.5)
	if beat_id == &"mirrors_dual":
		_build_relay()

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

			DialogueManager.say("Noroi", "Bir şey hatırlamaya çalışıyor.")

			await DialogueManager.dialogue_finished

	_busy = false

func _library_hall() -> void:

	DialogueManager.say("Arşivci", "Hoş geldin. Adın listede: Noroi, 1995. Son giren.")

	DialogueManager.say("Arşivci", "Senden önce yüzlercesi geldi. Hepsinin kaydı burada, hepsinin altında aynı imza: X.")

	DialogueManager.say("Noroi", "X kim? Burayı o mu yaptı?")

	DialogueManager.say("Arşivci", "Kayıtlar çelişiyor. Sağdaki odada üç tanık var: saat, çiçek ve mühür. Hepsini dinle, sonra karşılaştır. Doğru sıra kayıp sayfayı açar.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_catalog_conflict", "X imzalı kayıtlar", "Yüzlerce kişi bu yere girmiş. Hepsinin kaydı X imzalı. Benimki en sonda: 1995.", "open_question", "notlar")

	PuzzleManager.mark_solved(&"library_catalog")

	SaveManager.save_game()

func _library_witness() -> void:

	if PuzzleManager.is_solved(&"library_witnesses"):

		DialogueManager.say("Noroi", "Üç tanık sustu.")

		return

	DialogueManager.say("Noroi", "Saat, çiçek, mühür. Kayıtlarını karşılaştırıyorum.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})

	if ev.has("ev_witness_clock") and ev.has("ev_witness_flower") and ev.has("ev_witness_seal"):

		DialogueManager.say("Noroi", "Önce deney başladı. Sonra patlama oldu. Mühür en son kapandı. Mühür felaketi başlatmamış; yalnızca içeride tutmuş.")
		var understood: bool = await DialogueManager.dialogue_finished
		if not understood:
			return
		PuzzleManager.mark_solved(&"library_witnesses")

		SaveManager.save_game()

	else:

		DialogueManager.say("Noroi", "Önce her tanığı tek tek dinlemeliyim.")

func _library_page() -> void:

	var room := get_tree().get_first_node_in_group("library_page_puzzle")

	if room and room.has_method("open_puzzle"):

		room.open_puzzle()

	else:

		push_warning("story_beat: library_page_puzzle eksik")

func _experiment_cells() -> void:

	DialogueManager.say("Kayıt", "Deney 1: Hatıra bağı. Amaç: hatırayı bedenden ayırıp bu boyuta bağlamak. İmza: X.")

	DialogueManager.say("Noroi", "İçimdeki lanet… bu deney mi?")
	DialogueManager.say("Shilda", "Evet. X onu yıllarca burada denedi. Ben de yardım ettim. Sonra patlama oldu; lanet bozuldu ve gelen herkese tutundu.")
	DialogueManager.say("Shilda", "Bu sefer kimseyi feda etmeyeceğiz. Sağdaki devrede yankın bir anahtarı tutacak, sen de öbürünü açacaksın.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"experiment_cells_seen")

	_evidence("ev_cells_demo", "Hatıra bağı", "İçimdeki lanet X'in deneyi. Bir patlamadan sonra bozulmuş ve gelen herkese tutunmuş.", "evidence", "notlar")

	SaveManager.save_game()

func _experiment_circuit() -> void:

	if PuzzleManager.is_solved(&"experiment_circuit"):

		DialogueManager.say("Noroi", "Devre hazır.")

		return

	DialogueManager.say("Shilda", "Üstteki Yankıyı başlat düğmesine bas. Silüet anahtara ulaşınca sekiz saniyen olacak; o sürede Devremi aç düğmesine bas. Yetişemezsen ceza yok, yeniden dene.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

func _experiment_authority() -> void:

	DialogueManager.say("Kayıt", "Yetkili: X. Yardımcı ve denek: Shilda. Patlama sonrası tahliye talebi reddedildi. Mühürler açık kalacak.")

	DialogueManager.say("Noroi", "Denek mi? Shilda… sen de mi bu deneyin içindeydin?")

	DialogueManager.say("Shilda", "Eskiden senin boyundaydım. Bu biçim onun işi. Yine de kazaydı, biliyorum. O bize kötülük istemezdi.")
	DialogueManager.say("Noroi", "Kaza mıydı, değil miydi… Aynalar salonunda öğreneceğiz.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_authority", "Yetki masası", "Shilda, X'in yardımcısı ve deneklerinden biriymiş. Patlamadan sonra kimsenin çıkmasına izin verilmemiş.", "evidence", "gunluk")

	PuzzleManager.mark_solved(&"experiment_authority")

	GameState.set_world_flag(&"mirrors_unlocked", true)

	SaveManager.save_game()

func _mirrors_reverse() -> void:
	if PuzzleManager.is_solved(&"mirrors_reverse"):
		DialogueManager.say("Noroi", "Aynadaki sol, gerçekte sağ. Geçit açık.")
		return
	DialogueManager.say("Noroi", "Aynada çiçek soldaki kapının önünde. Ama yansıma yönleri ters gösterir. Gerçek kapı hangisi?")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_open_mirror_choice()

func _mirrors_dual() -> void:
	if PuzzleManager.is_solved(&"mirrors_dual"):
		DialogueManager.say("Noroi", "İki iz birleşti. Yol açık.")
		return
	DialogueManager.say("Shilda", "Yankın bu anahtarı altı saniye tutabilir. Konuşma bitince sağdaki kristale yürü ve dokun. Süre biterse buradan yeniden başla; ceza yok.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_relay_seconds = 6.0

func _mirrors_unbroken() -> void:

	DialogueManager.say("Noroi", "Kaç kişi geldi, Shilda?")

	DialogueManager.say("Shilda", "1927'den beri her günü saydım. Yirmi dört bin sekiz yüz otuz yedi gün. Yüzlerce kişi geldi; hepsini lanet yuttu. Hiçbirini kurtaramadım.")

	DialogueManager.say("Noroi", "Bu yüzden mi başta benden uzak durdun?")
	DialogueManager.say("Shilda", "Bağlanırsam seni de kaybederim sandım. Ama sen geri dönüyorsun. Sen sonuncusun, Noroi. Belki de ilk çıkan olursun.")
	DialogueManager.say("Noroi", "O zaman birlikte çıkalım. Sağdaki geçidi aç.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	GameState.set_shilda_named(true)

	GameState.player_progress_knowledge["truth_seen"] = true

	PuzzleManager.mark_solved(&"mirrors_unbroken")

	GameState.set_world_flag(&"core_path_open", true)

	SaveManager.save_game()

func _core_threshold() -> void:

	DialogueManager.say("Shilda", "Saat sırayı, çiçek kaybı, anahtar izni, mühür de sorumluluğu gösterdi. Artık kapı senden can istemiyor.")
	DialogueManager.say("Noroi", "Öğrendiklerimi yanıma aldım. Mühür odasında X'in mührünü çözeceğim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"core_threshold")

	SaveManager.save_game()

func _core_seal_chamber() -> void:

	DialogueManager.say("Noroi", "X deneyi başlattı. Patlama oldu, mühür kapandı. Yüzlerce kişi burada kaldı. Ben kalmayacağım.")

	DialogueManager.say("Shilda", "Seçim senin. Mührü birlikte kırarsak ikimiz de çıkarız. Bağı koparırsan bütün anıların geri döner.")
	DialogueManager.say("Noroi", "Son kapının ardında solda bağı koparmak, sağda mührü birlikte kırmak var. Önce okuyacağım, sonra karar vereceğim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"core_seal")
	GameState.player_progress_knowledge["trusted_keeper"] = true

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
	GameState.player_progress_knowledge["journal_unlocked"] = true

	EchoManager.journal_updated.emit()

func _open_mirror_choice() -> void:
	_choice_layer = CanvasLayer.new()
	_choice_layer.layer = 26
	get_tree().current_scene.add_child(_choice_layer)
	var modal := GothicModalPanel.new()
	modal.setup("Aynalar", Vector2(500, 190))
	_choice_layer.add_child(modal)
	modal.on_close = _answer_mirror.bind("Geri dön")
	modal.add_label("Aynada çiçek solda. Gerçek kapı hangisi?", UiTheme.BODY)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	modal.body.add_child(row)
	for option in ["Soldaki kapı", "Sağdaki kapı", "Geri dön"]:
		var button := modal.add_button(option, _answer_mirror.bind(option), row)
		button.custom_minimum_size = Vector2(120, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiGate.set_story(true)

func _answer_mirror(option: String) -> void:
	if not is_instance_valid(_choice_layer):
		return
	_choice_layer.queue_free()
	_choice_layer = null
	UiGate.set_story(false)
	if option == "Sağdaki kapı":
		PuzzleManager.mark_solved(&"mirrors_reverse")
		SaveManager.save_game()
		DialogueManager.say("Noroi", "Yansımanın değil, gerçeğin yolunu seçtim. Sağdaki geçit açıldı.")
	elif option == "Soldaki kapı":
		DialogueManager.say("Shilda", "Aynada sol, gerçekte sağ olur. Canın yanmadı. Yeniden inceleyebilirsin.")

func _build_relay() -> void:
	var relay := Area2D.new()
	relay.name = "SecondRelay"
	relay.set_script(load("res://scripts/world/mirror_relay.gd"))
	relay.set("source", self)
	relay.position = Vector2(190, 0)
	add_child(relay)
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38, 48)
	collider.shape = rect
	relay.add_child(collider)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/props/crystal.png")
	sprite.scale = Vector2(0.6, 0.6)
	relay.add_child(sprite)
	_relay_label = Label.new()
	_relay_label.position = Vector2(-70, -66)
	_relay_label.text = "İkinci anahtar"
	UiTheme.apply_outlined(_relay_label, UiTheme.HINT)
	relay.add_child(_relay_label)

func _process(delta: float) -> void:
	if beat_id != &"mirrors_dual" or _relay_seconds <= 0:
		return
	if RoomManager.get_active_room_id() != &"mirrors_dual":
		_relay_seconds = 0
		return
	if UiGate.pauses_world_threats():
		return
	_relay_seconds = maxf(0, _relay_seconds - delta)
	_relay_label.text = "%s: birleştir · %.1f" % [MobileInputManager.control_name(&"interact"), _relay_seconds]
	if _relay_seconds == 0:
		_relay_label.text = "Süre doldu. Sola dön."

func finish_relay() -> void:
	if PuzzleManager.is_solved(&"mirrors_dual"):
		return
	if _relay_seconds <= 0:
		DialogueManager.say("Noroi", "Önce soldaki mühürde yankıyı başlatmalıyım.")
		return
	_relay_seconds = 0
	_relay_label.text = "İki iz birleşti"
	PuzzleManager.mark_solved(&"mirrors_dual")
	SaveManager.save_game()
	DialogueManager.say("Noroi", "Yankım geçmişi tuttu; ben yeni bir adım attım. Sağdaki geçit açıldı.")

