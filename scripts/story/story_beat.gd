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

		&"experiment_cell_a", &"experiment_cell_b", &"experiment_cell_c":

			await _cell_record(String(beat_id).right(1))

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
	if CurseManager.curse > 0.0:
		DialogueManager.say("Arşivci", "Lanetin hâlâ sıcak. Raflar seni tanıyor, mühürler de.")
	else:
		DialogueManager.say("Arşivci", "Yine geldin, Noroi. Bu sefer hangi rafa bakacaksın?")

	DialogueManager.say("Arşivci", "Bir kayıt kurtarıcı diyor, öteki kapıyı kilitleyen. İmza kazınmış.")

	DialogueManager.say("Noroi", "Hangisine inanayım?")

	DialogueManager.say("Arşivci", "Kayıtlar yazılı. Raflar sırayla çekilir.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_catalog_conflict", "Kazınmış imzalar", "Sayısız kişi bu yere girmiş. Hepsinin kaydında imza kazınmış. En sonda bir yıl var: 1995.", "open_question", "notlar")

	SaveManager.save_game()

func _library_witness() -> void:

	if PuzzleManager.is_solved(&"library_witnesses"):

		DialogueManager.say("Noroi", "Üç tanık sustu.")

		return

	DialogueManager.say("Noroi", "Saat, çiçek, mühür: kayıtlarını karşılaştırıyorum.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})

	if ev.has("ev_witness_clock") and ev.has("ev_witness_flower") and ev.has("ev_witness_seal"):

		DialogueManager.say("Noroi", "Felaketi mühür başlatmamış, içeride tutmuş.")
		var understood: bool = await DialogueManager.dialogue_finished
		if not understood:
			return
		SaveManager.save_game()

	else:

		DialogueManager.say("Noroi", "Önce her tanığı tek tek dinlemeliyim.")

func _library_page() -> void:

	var room := get_tree().get_first_node_in_group("library_page_puzzle")

	if room and room.has_method("open_puzzle"):

		room.open_puzzle()

	else:

		push_warning("story_beat: library_page_puzzle eksik")

func _cell_record(cell: String) -> void:

	match cell:

		"a":

			DialogueManager.say("Kayıt", "Hücre A. Denek girişi, kapı kilidi.")
			DialogueManager.say("Kayıt", "Mühür kodu üç haneli. İlk hane: dört.")
			DialogueManager.say("Noroi", "İlk hane dört. Aklımda kalsın.")

		"b":

			DialogueManager.say("Kayıt", "Hücre B. Gözlem kapısı, sessiz oda.")
			DialogueManager.say("Kayıt", "İkinci hane: bir.")
			DialogueManager.say("Shilda", "Duydun mu? Bir.")

		_:

			DialogueManager.say("Kayıt", "Hafıza koruma deneyi. Amaç: kaybedilenlerin seslerini saklamak.")
			DialogueManager.say("Kayıt", "Denek 14: Noroi. Kurucu imza: [kazınmış].")
			DialogueManager.say("Noroi", "Ben denektim, kurucu değilim.")
			DialogueManager.say("Shilda", "Kurucu başlattı. Sen içeride kaldın.")
			DialogueManager.say("Shilda", "Ben kapıda bekledim.")
			DialogueManager.say("Shilda", "Sesler bedenlerinden koptu. Oda onları sakladı.")
			DialogueManager.say("Shilda", "İleride bir devre yankını bekliyor.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	match cell:

		"a":

			_evidence("ev_cell_a", "Hücre A kaydı", "Mühür kodu üç haneli. İlk hane: dört.", "evidence", "izler")

		"b":

			_evidence("ev_cell_b", "Hücre B kaydı", "İkinci hane: bir.", "evidence", "izler")

		_:

			_evidence("ev_cells_demo", "Hafıza bağı", "İçimdeki lanet bir deneyden doğmuş. Bir patlamadan sonra bozulmuş ve gelen herkese tutunmuş.", "evidence", "notlar")

	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})

	if ev.has("ev_cell_a") and ev.has("ev_cell_b"):

		PuzzleManager.mark_solved(&"experiment_cells_seen")

	SaveManager.save_game()

func _experiment_circuit() -> void:

	if PuzzleManager.is_solved(&"experiment_circuit"):

		DialogueManager.say("Noroi", "Devre hazır.")

		return

	DialogueManager.say("Shilda", "Yankın anahtara varana dek devre sende. Sekiz saniye.")

	DialogueManager.say("Shilda", "Kaçırırsan yeniden dene. Bu oda affeder.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

func _experiment_authority() -> void:

	DialogueManager.say("Kayıt", "Protokol yetkilisi: [kazınmış]. Araştırma Yardımcısı S.")
	DialogueManager.say("Kayıt", "Acil kapatma talebi reddedildi. Mühür kodu üç hane. Haneler kayıtlara dağıtılmış.")
	DialogueManager.say("Kayıt", "Kayıt şeridinde silik bir fısıltı izi kalmış. Sözler seçilmiyor.")

	DialogueManager.say("Noroi", "Biri kimse çıkmasın diye kapıyı kilitlemiş, sesler içeride kalmış.")

	DialogueManager.say("Noroi", "Benden önce kimler vardı?")
	DialogueManager.say("Shilda", "Çok fazla insan. Çoğunun adını oda unuttu.")
	DialogueManager.say("Noroi", "Hepsini tanıyor muydun?")
	DialogueManager.say("Shilda", "Bazılarını tanıyacak kadar zamanım oldu.")
	DialogueManager.say("Shilda", "Seni unutturmak istediler. Ben hatırlamayı seçtim.")
	DialogueManager.say("Shilda", "Altmış sekiz yıl oldu. Kapı 1927'den beri kilitli.")
	DialogueManager.say("Shilda", "Sen 1995'te geldin.")
	DialogueManager.say("Noroi", "Bu kez kaçmayacağım, aynalar salonuna gidelim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	GameState.set_story_flag(&"shilda_past_discovered")

	_evidence("ev_authority_desk", "Yetki masası kaydı", "Yetki masasındaki imza kazınmış; kayıtta silik bir fısıltı izi kaldı. Düzeni kimin kurduğu okunmuyor.", "evidence", "gunluk")

	SaveManager.save_game()

func _mirrors_reverse() -> void:
	if PuzzleManager.is_solved(&"mirrors_reverse"):
		DialogueManager.say("Noroi", "Aynadaki sol, gerçekte sağ; geçit açık.")
		return
	DialogueManager.say("Noroi", "Aynada çiçek soldaki kapıda, ama yansıma yönleri ters gösteriyor.")
	DialogueManager.say("Noroi", "Gerçek kapı hangisi?")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_open_mirror_choice()

func _mirrors_dual() -> void:
	if PuzzleManager.is_solved(&"mirrors_dual"):
		DialogueManager.say("Noroi", "İki iz birleşti, yol açık.")
		return
	DialogueManager.say("Shilda", "Yankın bu anahtarı sekiz saniye tutar. Sağdaki kristale yetiş.")
	DialogueManager.say("Shilda", "Yetişemezsen yeniden dene. Bu oda affeder.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_relay_seconds = 8.0

func _mirrors_unbroken() -> void:

	DialogueManager.say("Noroi", "Neden her seferinde çiçek bırakıyorsun?")
	DialogueManager.say("Shilda", "…")
	DialogueManager.say("Shilda", "Çünkü birinin onları hatırlaması gerekiyor.")

	DialogueManager.say("Noroi", "Beni değil, bir sırrı koruyordun.")

	DialogueManager.say("Shilda", "İkisini ayırmayı unuttum.")

	DialogueManager.say("Noroi", "Döngüyü sürdürmemi de susmanı kabul etmemi de isteyemezsin.")
	DialogueManager.say("Noroi", "Ama gerçeği saklamadan yanımda durabilirsin.")
	DialogueManager.say("Shilda", "Çekirdekte son mühür var. Onu birlikte açacağız.")
	DialogueManager.say("Shilda", "Çekirdeğe gitmeden Ayna Tapınağı'na uğra.")
	DialogueManager.say("Shilda", "Gölgen orada bekliyor.")
	DialogueManager.say("Noroi", "Artık gerçeği biliyorum, sağ uçtaki geçidi açıyorum.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	GameState.player_progress_knowledge["truth_seen"] = true

	PuzzleManager.mark_solved(&"mirrors_unbroken")

	GameState.set_world_flag(&"core_path_open", true)

	var cam := get_tree().get_first_node_in_group("follow_camera")
	var door_fx: Node2D = null
	for n in get_tree().get_nodes_in_group("room_door"):
		if n is Node2D and String((n as Node).get("target_room_id") if "target_room_id" in n else "") == "core_threshold":
			door_fx = n as Node2D
			break
	if door_fx == null:
		door_fx = get_parent() as Node2D
	if cam and cam.has_method("focus_pulse") and door_fx:
		cam.focus_pulse(door_fx.global_position + Vector2(0, -40))
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"seal_open")

	SaveManager.save_game()

func _core_threshold() -> void:

	DialogueManager.say("Noroi", "Buradan birlikte çıkacağız.")
	DialogueManager.say("Shilda", "Bunu söyleyen ilk kişi değilsin.")
	DialogueManager.say("Noroi", "Biliyorum.")
	DialogueManager.say("Shilda", "Hayır. Henüz bilmiyorsun.")
	DialogueManager.say("Shilda", "Yine de kapı artık senden bir can istemiyor.")
	DialogueManager.say("Noroi", "Öğrendiklerimi yanıma aldım; son mühür odasında kayıtları birleştireceğim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"core_threshold")

	SaveManager.save_game()

func _core_seal_chamber() -> void:

	DialogueManager.say("Kayıt", "Deney başladı. Kapı kapandı. Koruma mührü devreye girdi.")
	DialogueManager.say("Noroi", "Silinen hafızalar burada kaldı, hiçbiri kayıp değil artık.")

	DialogueManager.say("Shilda", "Mührün bağları çekirdeğin başında.")
	DialogueManager.say("Shilda", "Ruh Kesimi onları kesebilir.")
	DialogueManager.say("Noroi", "Hazırım, kristale dokunduğumda bitecek.")

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
		DialogueManager.say("Noroi", "Yansımanın değil, gerçeğin yolunu seçtim; sağdaki geçit açıldı.")
	elif option == "Soldaki kapı":
		DialogueManager.say("Shilda", "Aynada sol, gerçekte sağ olur. Canın yanmadı.")
		DialogueManager.say("Shilda", "Yeniden inceleyebilirsin.")

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
	DialogueManager.say("Noroi", "Yankım geçmişi tuttu, ben yeni bir adım attım; sağdaki geçit açıldı.")

