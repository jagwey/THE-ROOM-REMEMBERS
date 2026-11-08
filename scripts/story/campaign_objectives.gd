class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Saati incele, Shilda ile konuş; sağdaki geçidi bul.",
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
	"awakening_balcony": "Tesisi izle. Mor mühür Ruh Kesimi ister.",
	"awakening_crypt": "Yatakların sırrını oku; Shilda'nın defterini bul.",
	"decay_catacombs": "Karanlıkta yalnız ölülerin ışığı yol gösterir. Sembolleri gör; mührü aç.",
	"decay_shilda_wall": "Shilda atılınca son anda kenara çekil; duvara çarpsın.",
	"library_upper_stacks": "Zıpla, Arşivci'yi bul; yasak kanada tırman.",
	"library_forbidden_wing": "Ruh Kesimi'ni ve 1. mühür parçasını al.",
	"experiment_quarantine": "Kırmızı sis canlıyı yer. Bedenin sana koridor açsın.",
	"experiment_core_conduit": "Yankı Sunağı'nı kullan; üç kanalı aynı anda aç.",
	"mirrors_labyrinth": "Tavandaki aynaya bak; görünmez taşlarda yürü.",
	"core_memory_vault": "Son kaydı dinle; bütün gerçeği gör.",
	"core_bloom_garden": "Shilda'yı dinle; birlikte ilerleyin.",
	"mirrors_shrine": "Gölge Atılması'nı al; kırmızı perdeden atılarak geç; 2. mühür parçası.",
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
			return "Mor mühre Ruh Kesimi savur (Q / yıldız); mahzene in."
		return "Tesisi izle. Mor mühür şimdilik kapalı: Ruh Kesimi Yasak Kanat'ta."
	var raw := String(_BY_ROOM.get(room_id, "Kayıtları incele; sağdaki geçidi takip et."))
	var i := raw.find(" · ")
	if i > 0 and i <= 32:
		raw = raw.substr(i + 3)
	return raw


## Uyanış: kalan adımlar "Saate bak · Gölgeyle konuş · plakaya bas" biçiminde kısalır.
static func _awakening_objective() -> String:
	var k: Dictionary = GameState.player_progress_knowledge
	var steps: PackedStringArray = []
	if not bool(k.get("pocket_watch_seen", false)):
		steps.append("Saate bak")
	if not GameState.is_shilda_named():
		steps.append("Gölgeyle konuş")
	if not PuzzleManager.is_solved(&"awakening_weight"):
		steps.append("plakaya bas")
	if steps.is_empty():
		return "Kırık Geçit'ten ilerle; yarıklara dikkat et."
	var first := steps[0]
	steps[0] = first.substr(0, 1).to_upper() + first.substr(1)
	return " · ".join(steps)
