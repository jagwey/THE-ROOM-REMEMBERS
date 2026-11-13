class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Durmuş saate bak. Gölge konuşursa dinle. Sağdaki geçide yürü.",
	"awakening_passage": "Halkalara yankıdaki sırayla dokun, kristalle basamak kur.",
	"awakening_seal": "İki kristal, iki beden, iki plaka. Kapı açılınca sayıyı mühre yaz.",
	"decay_vines": "Çiçeği al, kırık camda öl; çiçekli cesedin sarmaşığı yakar.",
	"decay_weight": "Taşı sürgüye it, dikenli plakaya bedenini bırak. Şaşırırsan kolu çek.",
	"decay_garden": "Çiçek sırasını oku, tacı sırayla aç, arşiv kapısına git.",
	"library_hall": "Kayıt A'yı oku, raf kitaplarını sırayla çek.",
	"library_witness": "Yankıları dinle. Ceset, yankı ve sen mührü açın.",
	"library_page": "Sayfalar dağılmış. Olayları oldukları sıraya koy.",
	"experiment_cells": "Hücre A ve B kayıtlarını oku, kapıları ceset plakasıyla aç.",
	"experiment_circuit": "Yankın bir anahtarı sekiz saniye tutsun, sen ötekini aç.",
	"experiment_authority": "Hücre ve kabul kayıtlarındaki haneleri bul, mührü aç.",
	"mirrors_reverse": "Aynalı zeminde yön ters; kırmızı şeritlere basmadan sağ uca var.",
	"mirrors_dual": "Yankın ters yürür; kolu o çeksin. Plakayı bedenle bastır.",
	"mirrors_unbroken": "Yansıma bir yol yürür; yankınla izle, sonra Shilda ile yüzleş.",
	"core_threshold": "İzler sende. Shilda ile konuş, sonra mühür odasına geç.",
	"core_seal_chamber": "Tanıklıklar birleşince son kapı nefes alır.",
	"core": "Aşağı in. Mührü Shilda ile birlikte kır.",
	"awakening_balcony": "Sütunlara bedenini basamak yap, karşıya geç.",
	"awakening_crypt": "Sayfaları tarih sırasına diz; bedenini yatağa bırak.",
	"decay_catacombs": "Çiçekli beden ışık ve köprü olur. Sembolleri oku, mührü aç.",
	"decay_shilda_wall": "Lanet bulutuna cesedini bırak, kalkanının içinden yürü.",
	"library_upper_stacks": "Ses, mühür, çiçek sırasıyla seç; tahta inince tırman.",
	"library_forbidden_wing": "Havadaki kesiği al, iki mührü sırayla kes.",
	"experiment_quarantine": "Cesedini sise bırak, güvenli koridordan rafa zıpla.",
	"experiment_core_conduit": "Kayıttaki sırayla üç damarı ruhla kes.",
	"mirrors_labyrinth": "Mavi taş gerçek. Son boşlukta kırmızı kristale dokun, köprü ol.",
	"core_memory_vault": "Sütunlara sırayla dokun: 1927, 1995, sonra Son.",
	"core_bloom_garden": "Taçları say: dört, bir, iki. Sonra Shilda konuşur.",
	"mirrors_shrine": "Sunaktan Gölge Atılması'nı al, üç perdeyi ve boşluğu atılarak geç.",
	"awakening_vigil": "Gölgeyle konuş, sonra kapıya yürüyen izin peşinden git.",
	"decay_greenhouse": "Duvardaki yazıyı oku, gölgenin gittiği saksıda öl; cesedin mührü açar.",
	"library_clockroom": "Saatleri dinle, kadranları tanıkların saatine getir.",
	"library_reading_cell": "Kabini ruhla kes, duvardaki çentiklere bak.",
	"experiment_intake": "Kabul kaydını oku, teraziyi ceset ve taşla doldur.",
	"mirrors_gallery": "Üç plakayı üç bedenle bas; duvar bedenleri sayıyor.",
	"mirrors_1927": "Gece kendi kendine oynuyor. Gölgenin peşinden git, yankıyı dinle.",
	"decay_cistern": "Suyu vanalarla oynat, üç ıslak sayfayı topla.",
	"experiment_observation": "Cesedini projektör plakasına bırak, cam ardındaki yankıyı izle.",
	"core_ascent": "Sunağa dokun, plakaya yürü ve bekle; yankın tutarken kapıdan geç.",
}

static func get_objective(room_id: String) -> String:
	return objective_for_room(room_id)


## Yalnız hedef metni (oda adı öneki yok — oda adı HUD başlığında).
static func objective_for_room(room_id: String) -> String:
	if room_id == "awakening":
		return _awakening_objective()
	if room_id == "awakening_balcony":
		if PuzzleManager.is_solved(&"awakening_balcony_crossed"):
			return "Karşıya geçtin. Kapı açık, mahzene in."
		return "Sütunlara bedenini basamak yap, karşıya geç."
	if room_id == "awakening_crypt":
		var pages := PuzzleManager.is_solved(&"awakening_crypt_pages")
		var bed := PuzzleManager.is_solved(&"awakening_crypt_bed")
		if pages and bed:
			return "Halkanın hanelerini topladın. Defteri oku."
		if pages:
			return "Bedenini yatağa bırak, anıyı aç."
		if bed:
			return "Defter sayfalarını tarih sırasına diz."
		return "Sayfaları tarih sırasına diz; bedenini yatağa bırak."
	var raw := String(_BY_ROOM.get(room_id, "Kayıtları incele; sağdaki geçidi takip et."))
	var i := raw.find(" · ")
	if i > 0 and i <= 32:
		raw = raw.substr(i + 3)
	if not GameState.is_shilda_named():
		raw = raw.replace("Shilda'yı", "gölgeyi") \
			.replace("Shilda'nın", "gölgenin") \
			.replace("Shilda'ya", "gölgeye") \
			.replace("Shilda ile", "gölge ile") \
			.replace("Shilda", "Gölge")
	return raw


## Uyanış: kalan adımlar "Saate bak · Gölgeyle konuş · taşı plakaya it · ceset plakası" biçiminde kısalır.
static func _awakening_objective() -> String:
	var k: Dictionary = GameState.player_progress_knowledge
	var steps: PackedStringArray = []
	if not bool(k.get("pocket_watch_seen", false)):
		steps.append("Saate bak")
	if GameState.has_story_flag(&"first_death_completed") and not GameState.is_shilda_named():
		steps.append("Gölgeyle konuş")
	if not (PuzzleManager.is_solved(&"awakening_weight") or PuzzleManager.is_live(&"awakening_weight")):
		steps.append("taşı plakaya it")
	## Eski kayıt: taş plakası çözülmüşse kapı zaten açık, ceset adımı gerekmez.
	var legacy_open := PuzzleManager.is_solved(&"awakening_weight")
	if not legacy_open and not (PuzzleManager.is_solved(&"awakening_corpse_plate") or PuzzleManager.is_live(&"awakening_corpse_plate")):
		steps.append("bedenini plakaya bırak")
	if steps.is_empty():
		return "Kırık Geçit açık. Kırmızı yarıklara basma."
	var first := steps[0]
	steps[0] = first.substr(0, 1).to_upper() + first.substr(1)
	return " · ".join(steps)
