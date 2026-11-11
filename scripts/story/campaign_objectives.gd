class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Saati incele, gölgeyle konuş; sağdaki geçidi bul.",
	"awakening_passage": "Kırmızı yarıklardan sakın; yankıdaki kodu alıp sağa ilerle.",
	"awakening_seal": "Plaka canlıyı tutmaz. Kan kristali… bedenin plakada kalsın; yankıdaki kodu mühre gir.",
	"decay_vines": "Sarmaşık kolunu bul ve kısayolu aç.",
	"decay_weight": "Taşı plakaya it; gerekirse sıfırlama kolunu kullan.",
	"decay_garden": "Çiçeği incele, Shilda'yı dinle; arşiv mührünü aç.",
	"library_hall": "Arşivciyle konuş, tanıklıkları araştır.",
	"library_witness": "Saat, çiçek ve mühür kayıtlarını oku.",
	"library_page": "Tanıklıkları olay sırasına koy.",
	"experiment_cells": "Gözlem kaydını incele; güvenli geçidi bul.",
	"experiment_circuit": "Yankıyı etkinleştir, pencerede devreni aç.",
	"experiment_authority": "Deneyi kimin başlattığını öğren; imzayı incele.",
	"mirrors_reverse": "Yansımanın terslediği yönü çöz; doğru kapıyı seç.",
	"mirrors_dual": "Mührü başlat, süre içinde kristali birleştir.",
	"mirrors_unbroken": "Gerçeği dinle; Shilda ile yüzleş.",
	"core_threshold": "Topladığın izlerle Çekirdek'e yaklaş.",
	"core_seal_chamber": "Tanıklıkları birleştir; son kapıyı aç.",
	"core": "Çekirdeğe in; mührü Shilda ile birlikte kır.",
	"awakening_balcony": "Boşluğa bak, kopuk zemini atla. Mor mühür Ruh Kesimi ister.",
	"awakening_crypt": "Yatakların sırrını oku; defteri bul.",
	"decay_catacombs": "Karanlıkta yalnız ölülerin ışığı yol gösterir. Sembolleri gör; mührü aç.",
	"decay_shilda_wall": "Shilda atılınca son anda kenara çekil; duvara çarpsın.",
	"library_upper_stacks": "Kitaplar: ses, mühür, çiçek. Tahta inince yasak kanada tırman.",
	"library_forbidden_wing": "Ruh Kesimi'ni ve 1. mühür parçasını al.",
	"experiment_quarantine": "Sisin ortasına bir beden bırak. Rapor yüksek rafta.",
	"experiment_core_conduit": "Yankı Sunağı'nı kullan; üç kanalı aynı anda aç.",
	"mirrors_labyrinth": "Tavana bak. Mavi taş gerçek, soluk kırmızı yalan.",
	"core_memory_vault": "Sütunlar: 1927, 1995, sonra Son. Kasa o zaman konuşur.",
	"core_bloom_garden": "Taşlar: dört, bir, iki. Sonra Shilda'yı dinle.",
	"mirrors_shrine": "Gölge Atılması'nı al; kırmızı perdeden atılarak geç; 2. mühür parçası.",
	"awakening_vigil": "Gölgeyle konuş. Yolu gösterince sağdaki kapı açılır.",
	"decay_greenhouse": "Gölge uzaktan mührü tutuyor. Plakaya bas.",
	"decay_cistern": "Sarnıca bak. Geldiğin kapıdan ağırlık salonuna dön.",
	"library_clockroom": "Duran saatlerin arasından geç.",
	"library_reading_cell": "Hücredeki çentikleri gör. Tanık odasına dön.",
	"experiment_intake": "Kabul kaydının önünden geç.",
	"experiment_observation": "Camın ardına bak. Yankı devresine dön.",
	"mirrors_gallery": "Yansımaların arasından geç.",
	"mirrors_1927": "Kırık geceyi izle. İki yankıya dön.",
	"core_ascent": "Son merdiveni çık. Mühür odasına in.",
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
			return "Mor mühür çözüldü. Mahzen ile balkon arası artık açık."
		if _has_soul_slash():
			return "Kopuk zemini atla. Mor mühre Ruh Kesimi savur; mahzene in."
		return "Boşluğa bak, kopuk zemini atla. Mor mühür Yasak Kanat'ta açılır."
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
		return "Kırık Geçit'ten ilerle; yarıklara dikkat et."
	var first := steps[0]
	steps[0] = first.substr(0, 1).to_upper() + first.substr(1)
	return " · ".join(steps)
