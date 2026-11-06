class_name CampaignObjectives
extends RefCounted
## HUD hedef metinleri — `GameState.get_current_objective()` ve oda kimliğiyle eşleşir.

const _BY_ROOM: Dictionary = {
	"awakening": "Uyanış · Saati incele, Shilda ile konuş; sağdaki geçidi bul.",
	"awakening_passage": "Kırık Geçit · Kırmızı yarıklardan sakın; yankıdaki kodu alıp sağa ilerle.",
	"awakening_seal": "Mühür Odası · Taşı plakaya sürükle veya üzerinde dur; yankıdaki kodu mühre gir.",
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
	"core": "Çekirdek · Shilda ile konuş; hatırlamanın bedeline karar ver.",
}

static func get_objective(room_id: String) -> String:
	return String(_BY_ROOM.get(room_id, "Kayıtları incele; sağdaki geçidi takip et."))
