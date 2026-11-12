class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Durmuş saate bak. Gölge konuşursa dinle. Sağdaki geçide yürü.",
	"awakening_passage": "Taşı dinle, sayıyı ezberle. Kırmızı yarığa basma, mühre git.",
	"awakening_seal": "Kristale dokun, bedenin plakada kalsın; sonra sayıyı mühre yaz.",
	"decay_vines": "Sarmaşık yolu kapatmış. Kolu çek, düğüm çözülsün, geçide geç.",
	"decay_weight": "Taşı plakaya bırak. Şaşırırsan kolu çek, taş geri gelir.",
	"decay_garden": "Çiçeklere bak, Shilda'yı dinle, arşiv mührünü aç.",
	"library_hall": "Arşivciyi dinle, sağdaki odada tanıkları bul.",
	"library_witness": "Üç tanık var: saat, çiçek, mühür. Hepsini dinle.",
	"library_page": "Sayfalar dağılmış. Olayları oldukları sıraya koy.",
	"experiment_cells": "Gözlem kaydını oku, ardındaki güvenli geçide yürü.",
	"experiment_circuit": "Yankın bir anahtarı tutsun, sen ötekini aç.",
	"experiment_authority": "Yetki masasındaki kaydı oku, mühür kodunu bul.",
	"mirrors_reverse": "Ayna yönü ters çevirir; gördüğünün tersindeki kapıyı seç.",
	"mirrors_dual": "İki kristali aynı anda uyandır; yankın birini tutsun.",
	"mirrors_unbroken": "Kırılmayan ayna yalan söylemez. Shilda ile yüzleş.",
	"core_threshold": "İzler sende. Shilda ile konuş, sonra mühür odasına geç.",
	"core_seal_chamber": "Tanıklıklar birleşince son kapı nefes alır.",
	"core": "Aşağı in. Mührü Shilda ile birlikte kır.",
	"awakening_balcony": "Sütunlara bedenini basamak yap, karşıya geç.",
	"awakening_crypt": "Sayfaları tarih sırasına diz; bedenini yatağa bırak.",
	"decay_catacombs": "Çiçekli bedenin ışığıyla yürü. Sembolleri oku, mührü aç.",
	"decay_shilda_wall": "Gözleri kızarınca son adımda kenara çekil. Duvarı o yıkar.",
	"library_upper_stacks": "Ses, mühür, çiçek sırasıyla seç; tahta inince tırman.",
	"library_forbidden_wing": "Havadaki kesiği al, mührün ilk yarısını da bul.",
	"experiment_quarantine": "Cesedini sise bırak, güvenli koridordan rafa zıpla.",
	"experiment_core_conduit": "Plakada dur, yankın bir kolu tutsun, ötekini sen çek.",
	"mirrors_labyrinth": "Yol tavandaki aynada. Mavi taş gerçektir; soluk kırmızı yalan söyler.",
	"core_memory_vault": "Sütunlara sırayla dokun: 1927, 1995, sonra Son.",
	"core_bloom_garden": "Taçları say: dört, bir, iki. Sonra Shilda konuşur.",
	"mirrors_shrine": "Gölgeyi içine çek, perdeyi geç ve mührün öteki yarısını al.",
	"awakening_vigil": "Gölgeyle konuş. Sağdaki kapı ancak o zaman açılır.",
	"decay_greenhouse": "Camın ötesindeki el mührü tutuyor. Plakaya bas.",
	"library_clockroom": "Önce 1927 saatini, sonra 1995 saatini dinle.",
	"library_reading_cell": "Duvardaki çentiklere bak, kaç gün sayıldığını gör.",
	"experiment_intake": "Önce kabul dosyasını, sonra askıdaki paltoyu oku.",
	"mirrors_gallery": "Duvar, unuttuğun bedenleri sayıyor. Sonra kırılmayan aynaya geç.",
	"mirrors_1927": "1927 gecesi kendi kendine oynuyor. Dokunma. Sonra geri dön.",
	"decay_cistern": "Sayfalar suyun üstünde yüzüyor. Oku, göğsüne koy.",
	"experiment_observation": "Cam önündeki masadan sayım notunu al.",
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
