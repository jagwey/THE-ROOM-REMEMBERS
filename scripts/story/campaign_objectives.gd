class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Uyanış · Saati incele, Shilda ile konuş; sağdaki geçidi bul.",
	"awakening_passage": "Kırık Geçit · Kırmızı yarıklardan sakın; yankıdaki kodu alıp sağa ilerle.",
	"awakening_seal": "Mühür Odası · Plaka canlıyı tutmaz. Kan kristali… bedenin plakada kalsın; yankıdaki kodu mühre gir.",
	"decay_vines": "Çürüme · Sarmaşık kolunu bul ve kısayolu aç.",
	"decay_weight": "Ağırlık Odası · Taşı plakaya it; gerekirse sıfırlama kolunu kullan.",
	"decay_garden": "Solmuş Bahçe · Çiçeği incele, Shilda'yı dinle; arşiv mührünü aç.",
	"library_hall": "Hafıza Kütüphanesi · Arşivciyle konuş, tanıklıkları araştır.",
	"library_witness": "Üç Tanık · Saat, çiçek ve mühür kayıtlarını oku.",
	"library_page": "Unutulan Sayfa · Tanıklıkları olay sırasına koy.",
	"experiment_cells": "Deney Hücreleri · Gözlem kaydını incele; güvenli geçidi bul.",
	"experiment_circuit": "Hafıza Devresi · Yankıyı etkinleştir, pencerede devreni aç.",
	"experiment_authority": "Yetki Masası · Kendi imzanı bul; deneyi kimin başlattığını öğren.",
	"mirrors_reverse": "Aynalar · Yansımanın terslediği yönü çöz; doğru kapıyı seç.",
	"mirrors_dual": "İki Yankı · Mührü başlat, süre içinde kristali birleştir.",
	"mirrors_unbroken": "Kırılmayan Ayna · Gerçeği dinle; Shilda ile yüzleş.",
	"core_threshold": "Son Eşik · Topladığın izlerle Çekirdek'e yaklaş.",
	"core_seal_chamber": "Mühür Dairesi · Tanıklıkları birleştir; son kapıyı aç.",
	"core": "Çekirdek · İki mühür parçasıyla Shilda'nın yanına git; hatırlamanın bedeline karar ver.",
	"awakening_balcony": "Gözlem Balkonu · Tesisi izle. Mor mühür Ruh Kesimi ister.",
	"awakening_crypt": "İlk Bedenler Mahzeni · Yatakların sırrını oku; Shilda'nın defterini bul.",
	"decay_catacombs": "Kemik Mahzeni · Karanlıkta yalnız ölülerin ışığı yol gösterir. Sembolleri gör; mührü aç.",
	"decay_shilda_wall": "Çatlak Duvar · Shilda atılınca son anda kenara çekil; duvara çarpsın.",
	"library_upper_stacks": "Üst Raflar · Zıpla, Arşivci'yi bul; yasak kanada tırman.",
	"library_forbidden_wing": "Yasak Kanat · Ruh Kesimi'ni ve 1. mühür parçasını al.",
	"experiment_quarantine": "Karantina · Kırmızı sis canlıyı yer. Bedenin sana koridor açsın.",
	"experiment_core_conduit": "Enerji Kanalı · Yankı Sunağı'nı kullan; üç kanalı aynı anda aç.",
	"mirrors_labyrinth": "Yansıma Labirenti · Tavandaki aynaya bak; görünmez taşlarda yürü.",
	"core_memory_vault": "Hafıza Kasası · Son kaydı dinle; bütün gerçeği gör.",
	"core_bloom_garden": "Çiçek Bahçesi · Shilda ile barış; güveni onar.",
	"mirrors_shrine": "Ayna Tapınağı · Gölge Atılması'nı al; kırmızı perdeden atılarak geç; 2. mühür parçası.",
}

static func get_objective(room_id: String) -> String:
	return objective_for_room(room_id)


## Yalnız hedef metni (oda adı öneki yok — oda adı HUD başlığında).
static func objective_for_room(room_id: String) -> String:
	if room_id == "awakening":
		return _awakening_objective()
	var raw := String(_BY_ROOM.get(room_id, "Kayıtları incele; sağdaki geçidi takip et."))
	var i := raw.find(" · ")
	if i > 0 and i <= 32:
		raw = raw.substr(i + 3)
	return raw


## Uyanış: kalan adımlar "Saate bak · Shilda ile konuş · plakaya bas" biçiminde kısalır.
static func _awakening_objective() -> String:
	var k: Dictionary = GameState.player_progress_knowledge
	var steps: PackedStringArray = []
	if not bool(k.get("pocket_watch_seen", false)):
		steps.append("Saate bak")
	if not bool(k.get("shilda_named_partial", false)) and not bool(k.get("shilda_named", false)):
		steps.append("Shilda ile konuş")
	if not PuzzleManager.is_solved(&"awakening_weight"):
		steps.append("plakaya bas")
	if steps.is_empty():
		return "Kırık Geçit'ten ilerle; yarıklara dikkat et."
	var first := steps[0]
	steps[0] = first.substr(0, 1).to_upper() + first.substr(1)
	return " · ".join(steps)
