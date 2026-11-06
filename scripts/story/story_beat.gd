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
			$Sprite2D.texture = load("res://assets/props/cassette.png")
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

			DialogueManager.say("Shiren", "Bir şey hatırlamaya çalışıyor.")

			await DialogueManager.dialogue_finished

	_busy = false

func _library_hall() -> void:

	DialogueManager.say("Arşivci", "Hoş geldin Shiren. Her dönüşünde kendin için başka bir raf arıyorsun.")

	DialogueManager.say("Arşivci", "Bir kayıtta kurtarıcısın, diğerinde kapıyı kilitleyen kişi. İkisi de aynı imzayı taşıyor.")

	DialogueManager.say("Shiren", "Hangisi doğru?")

	DialogueManager.say("Arşivci", "Sağdaki odada saat, çiçek ve mühür var. Üçünü de dinle; ortadaki kayıtta tanıkları karşılaştır. Sıra, kayıp sayfayı açacak.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_catalog_conflict", "Çelişen kayıtlar", "İki tanıklık aynı anı farklı anlatıyor.", "open_question", "notlar")

	PuzzleManager.mark_solved(&"library_catalog")

	SaveManager.save_game()

func _library_witness() -> void:

	if PuzzleManager.is_solved(&"library_witnesses"):

		DialogueManager.say("Shiren", "Üç tanık sustu.")

		return

	DialogueManager.say("Shiren", "Saat, çiçek, mühür. Kayıtlarını karşılaştırıyorum.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})

	if ev.has("ev_witness_clock") and ev.has("ev_witness_flower") and ev.has("ev_witness_seal"):

		DialogueManager.say("Shiren", "Deney önce başladı. Kapı sonra kapandı. Koruma mührü en son çalıştı. Mühür felaketi başlatmamış, içeride tutmuş.")
		var understood: bool = await DialogueManager.dialogue_finished
		if not understood:
			return
		PuzzleManager.mark_solved(&"library_witnesses")

		SaveManager.save_game()

	else:

		DialogueManager.say("Shiren", "Önce her tanığı tek tek dinlemeliyim.")

func _library_page() -> void:

	var room := get_tree().get_first_node_in_group("library_page_puzzle")

	if room and room.has_method("open_puzzle"):

		room.open_puzzle()

	else:

		push_warning("story_beat: library_page_puzzle eksik")

func _experiment_cells() -> void:

	DialogueManager.say("Kayıt", "Hatıra koruma deneyi. Amaç: kaybedilen kişilerin seslerini muhafaza etmek.")

	DialogueManager.say("Shiren", "Birini unutmak istememişim. Bu yüzden mi burayı kurdum?")
	DialogueManager.say("Shilda", "Önce tek bir sesi saklamak istedin. Sonra hiçbir kaybın son olmamasını. Hatıralar bedenlerden ayrılıp odada birikti.")
	DialogueManager.say("Shilda", "Şimdi kimseyi feda etmeyeceğiz. Sağdaki devrede eski yankı bir anahtarı tutacak. Shiren diğerini açacak.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"experiment_cells_seen")

	_evidence("ev_cells_demo", "Gözlem hücreleri", "Düzenek güvenli örnekle gösterildi.", "evidence", "notlar")

	SaveManager.save_game()

func _experiment_circuit() -> void:

	if PuzzleManager.is_solved(&"experiment_circuit"):

		DialogueManager.say("Shiren", "Devre hazır.")

		return

	DialogueManager.say("Shilda", "Üstte Yankıyı başlat düğmesine bas. Silüet anahtara ulaşınca sekiz saniyen var: Devremi aç düğmesine bas. Başaramazsan ceza yok; yeniden dene.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

func _experiment_authority() -> void:

	DialogueManager.say("Kayıt", "Protokol yetkilisi: Shiren. Güvenlik görevlisi: Shilda. Acil kapatma talebi reddedildi.")

	DialogueManager.say("Shiren", "Dışarı çıkmasın diye kapıyı ben kilitledim. İçeridekilerin sesleri burada kaldı.")

	DialogueManager.say("Shilda", "Bunu taşıyamadığında benden seni unutturmamı istedin. Her dönüşünde aynı karar seni bekledi.")
	DialogueManager.say("Shiren", "Bu kez kendimden kaçmayacağım. Aynalar salonuna gidelim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	_evidence("ev_authority", "Yetki masası", "Geçmişte düzene katkıda bulunmuşum.", "evidence", "gunluk")

	PuzzleManager.mark_solved(&"experiment_authority")

	GameState.set_world_flag(&"mirrors_unlocked", true)

	SaveManager.save_game()

func _mirrors_reverse() -> void:
	if PuzzleManager.is_solved(&"mirrors_reverse"):
		DialogueManager.say("Shiren", "Aynadaki sol, gerçekte sağ. Geçit açık.")
		return
	DialogueManager.say("Shiren", "Aynada çiçek soldaki kapıda. Karşımdaki yansıma yönleri ters gösteriyor. Gerçek kapı hangisi?")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_open_mirror_choice()

func _mirrors_dual() -> void:
	if PuzzleManager.is_solved(&"mirrors_dual"):
		DialogueManager.say("Shiren", "İki iz birleşti. Yol açık.")
		return
	DialogueManager.say("Shilda", "Yankın bu anahtarı altı saniye tutabilir. Konuşma bitince sağdaki kristale yürü ve etkileş. Süre biterse burada yeniden başlat; ceza yok.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	_relay_seconds = 6.0

func _mirrors_unbroken() -> void:

	DialogueManager.say("Shiren", "Beni korumuyordun. Kararımı koruyordun.")

	DialogueManager.say("Shilda", "İkisini ayırmayı unuttum.")

	DialogueManager.say("Shiren", "Döngüyü sürdürmemi de, seni affetmemi de isteyemezsin. Ama gerçeği saklamadan yanımda durabilirsin.")
	DialogueManager.say("Shilda", "Çekirdekte iki yol var. Sesleri birlikte mühürler, bekçiliği paylaşırız. Ya da bağı koparır, hatıraları serbest bırakırız.")
	DialogueManager.say("Shiren", "İkisini de anlayarak seçeceğim. Sağdaki geçidi aç.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	GameState.player_progress_knowledge["shilda_named"] = true

	GameState.player_progress_knowledge["truth_seen"] = true

	PuzzleManager.mark_solved(&"mirrors_unbroken")

	GameState.set_world_flag(&"core_path_open", true)

	SaveManager.save_game()

func _core_threshold() -> void:

	DialogueManager.say("Shilda", "Saat sıralamayı, çiçek kaybı, anahtar izni, mühür sorumluluğu gösterdi. Artık kapı senden bir can istemiyor.")
	DialogueManager.say("Shiren", "Öğrendiklerimi yanıma aldım. Son mühür odasında kayıtları birleştireceğim.")

	var ok: bool = await DialogueManager.dialogue_finished

	if not ok:

		return

	PuzzleManager.mark_solved(&"core_threshold")

	SaveManager.save_game()

func _core_seal_chamber() -> void:

	DialogueManager.say("Shiren", "Deney başladı. Kapıyı kapattım. Koruma mührü devreye girdi. Sonra unutmak istedim. Artık hiçbiri kayıp değil.")

	DialogueManager.say("Shilda", "Senin adına seçim yapmayacağım. Birlikte mühürlemek sesleri burada korur; bağı koparmak onları serbest bırakır.")
	DialogueManager.say("Shiren", "Son kapının ardında solda bağı koparma, sağda birlikte mühürleme var. Önce sonucu okuyacağım, sonra onaylayacağım.")

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
	var panel := PanelContainer.new()
	panel.position = Vector2(100, 125)
	panel.size = Vector2(440, 110)
	_choice_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.text = "Aynada çiçek solda. Gerçek kapı hangisi?"
	box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for option in ["Soldaki kapı", "Sağdaki kapı", "Geri dön"]:
		var button := Button.new()
		button.text = option
		button.custom_minimum_size = Vector2(130, 36)
		row.add_child(button)
		button.pressed.connect(_answer_mirror.bind(option))
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
		DialogueManager.say("Shiren", "Yansımanın değil, gerçeğin yolunu seçtim. Sağdaki geçit açıldı.")
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
	_relay_label.add_theme_font_size_override("font_size", 10)
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
	_relay_label.text = "E: birleştir · %.1f" % _relay_seconds
	if _relay_seconds == 0:
		_relay_label.text = "Süre doldu. Sola dön."

func finish_relay() -> void:
	if PuzzleManager.is_solved(&"mirrors_dual"):
		return
	if _relay_seconds <= 0:
		DialogueManager.say("Shiren", "Önce soldaki mühürde yankıyı başlatmalıyım.")
		return
	_relay_seconds = 0
	_relay_label.text = "İki iz birleşti"
	PuzzleManager.mark_solved(&"mirrors_dual")
	SaveManager.save_game()
	DialogueManager.say("Shiren", "Yankım geçmişi tuttu; ben yeni bir adım attım. Sağdaki geçit açıldı.")

