class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Durmuş saate bak. Gölge konuşursa dinle. Sağdaki geçit seni çağırıyor.",
	"awakening_passage": "Kırmızı yarık anını koparır. Taş bir sayı fısıldıyor; onu sağdaki eşiğe götür.",
	"awakening_seal": "Plaka canlıyı tanımaz. Kristal bir beden ister. Yankının sayısı mühürde bekler.",
	"decay_vines": "Sarmaşık yolu yutmuş. Kolu bul; düğüm çözülünce geçit nefes alır.",
	"decay_weight": "Taş ağır. Onu plakanın üstüne bırak. Şaşırırsan kol taşı geri çağırır.",
	"decay_garden": "Çiçeğe bak. Shilda'yı dinle. Arşivin mührü ancak o zaman uyanır.",
	"library_hall": "Arşivci seni tanıyor. Tanıklıklar rafların arasında.",
	"library_witness": "Üç tanık var: saat, çiçek, mühür. Hepsini dinle.",
	"library_page": "Sayfalar dağılmış. Olayları oldukları sıraya koy.",
	"experiment_cells": "Gözlem kaydı hâlâ sıcak. Güvenli geçit onun ardında.",
	"experiment_circuit": "Yankın bir anahtarı tutsun. Sen ötekini aç. Devre ikinizi birden ister.",
	"experiment_authority": "İmza kazınmış. Yine de kimin başlattığını satırlardan oku.",
	"mirrors_reverse": "Ayna yönleri ters çevirir. Doğru kapı, sandığın yönün tersinde.",
	"mirrors_dual": "İki kristal aynı nefeste uyanmalı. Yankın birini tutsun.",
	"mirrors_unbroken": "Kırılmayan ayna yalan söylemez. Shilda ile yüzleş.",
	"core_threshold": "İzler sende. Çekirdek artık uzak değil.",
	"core_seal_chamber": "Tanıklıklar birleşince son kapı nefes alır.",
	"core": "Aşağı in. Mührü Shilda ile birlikte kır.",
	"awakening_balcony": "Camın ardı boşluk. Kopuk taşın üstünden geç. Mor mühür henüz uyumuyor.",
	"awakening_crypt": "Yataklar boş değil. Sır duvarda, defterde.",
	"decay_catacombs": "Karanlıkta yol, ölülerin ışığıdır. Sembolleri gör; mühür uyanır.",
	"decay_shilda_wall": "Gözleri kızarınca son adımda kenara çekil. Duvar onun çarpmasıyla iner.",
	"library_upper_stacks": "Raflar bir sıra biliyor: ses, mühür, çiçek. Sıra doğruysa tahta iner; inince yukarı tırman.",
	"library_forbidden_wing": "Burada bir kesik asılı. Onu al; mührün ilk yarısı da burada.",
	"experiment_quarantine": "Sis canlıyı yer, ölüyü emer. Rapor, sisin ötesinde, yüksek rafta.",
	"experiment_core_conduit": "Üç kanal aynı anda açık kalmalı. Yankın bir kolu tutsun.",
	"mirrors_labyrinth": "Yol tavandaki aynada. Mavi taş gerçektir; soluk kırmızı yalan söyler.",
	"core_memory_vault": "Sütunlar bir yıl sırası tutuyor. 1927, 1995, sonra Son.",
	"core_bloom_garden": "Taçları say: dört, bir, iki. Sonra Shilda konuşur.",
	"mirrors_shrine": "Gölgeyi içine çek. Kırmızı perde bedeni iter. Mührün öteki yarısı orada.",
	"awakening_vigil": "Gölge burada yüzünü gösteriyor. Onu dinle; sağdaki kapı o zaman açılır.",
	"decay_greenhouse": "Camın ötesinde bir el mührü tutuyor. Plaka senin.",
	"library_clockroom": "İki saat, iki gece. Önce 1927, sonra 1995.",
	"library_reading_cell": "Duvar gün gün çentilmiş. İnsan günleri burada bitmiş.",
	"experiment_intake": "Önce kabul dosyası. Sonra askıdaki palto. İkisi de 1995'i biliyor.",
	"mirrors_gallery": "Duvar, unuttuğun bedenleri sayıyor. Sonra kırılmayan aynaya geç.",
	"mirrors_1927": "1927 gecesi kendi kendine oynuyor. Dokunma. Sonra geri dön.",
	"decay_cistern": "Suyun üstündeki sayfalar bir ömür tutuyor. Oku, göğsüne koy.",
	"experiment_observation": "Camın bu yanındaki masada bir sayım notu var. İmza kazınmış. Yine de al.",
	"core_ascent": "Yankıyı dinle. İki güç de sende olunca son basamak seni çağırır.",
}

static func _has_soul_slash() -> bool:
	return bool(GameState.player_progress_knowledge.get("ability_soul_slash", false))


static func get_objective(room_id: String) -> String:
	return objective_for_room(room_id)


## Yalnız hedef metni (oda adı öneki yok — oda adı HUD başlığında).
static func objective_for_room(room_id: String) -> String:
	if room_id == "awakening":
		return _awakening_objective()
	## Mor mühür Ruh Kesimi ister; yetenek yoksa oyuncuyu nereye gideceğine yönlendir.
	if room_id == "awakening_balcony":
		if PuzzleManager.is_solved(&"soul_seal_balcony"):
			return "Mühür sustu. Balkon ile mahzen artık aynı nefesi paylaşıyor."
		if _has_soul_slash():
			return "Kopuk taşın üstünden geç. Mor mühre ruhunu savur; mahzen aşağıda."
		return "Camın ardı boşluk. Kopuk taşın üstünden geç. Mor mühür henüz uyumuyor."
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


## Uyanış: kalan adımlar "Saate bak · Gölgeyle konuş · plakaya bas" biçiminde kısalır.
static func _awakening_objective() -> String:
	var k: Dictionary = GameState.player_progress_knowledge
	var steps: PackedStringArray = []
	if not bool(k.get("pocket_watch_seen", false)):
		steps.append("Saate bak")
	if GameState.has_story_flag(&"first_death_completed") and not GameState.is_shilda_named():
		steps.append("Gölgeyle konuş")
	if not PuzzleManager.is_solved(&"awakening_weight"):
		steps.append("plakaya bas")
	if steps.is_empty():
		return "Kırık Geçit açık. Kırmızı yarıklara basma."
	var first := steps[0]
	steps[0] = first.substr(0, 1).to_upper() + first.substr(1)
	return " · ".join(steps)
