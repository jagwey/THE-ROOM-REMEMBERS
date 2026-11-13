extends Node
## Bulmaca durumu — world_memory_state.puzzles + bayrak migrasyonu.

const SealBanner := preload("res://scripts/ui/seal_banner.gd")

signal puzzle_solved(puzzle_id: StringName)
## Plaka bulmacaları: ağırlık durdukça canlı (yalnız bellekte, kaydedilmez).
signal live_changed(puzzle_id: StringName, live: bool)
## Oyuncu eyleminden doğan canlı açılış/kapanış geri bildirimi (yükleme sonrası ilk anlarda yayılmaz).
signal live_feedback(puzzle_id: StringName, live: bool)

var solved: Dictionary = {}
var _live: Dictionary = {}


func _ready() -> void:
	sync_from_world()


func _sync_legacy_flags_into_puzzles() -> void:
	var pz: Dictionary = GameState.world_memory_state.get("puzzles", {})
	if not pz is Dictionary:
		pz = {}
		GameState.world_memory_state["puzzles"] = pz
	var changed := false
	if bool(GameState.get_world_flag(&"awakening_door_opened", false)) and not bool(pz.get("awakening_weight", false)):
		pz["awakening_weight"] = true
		changed = true
	if bool(GameState.get_world_flag(&"awakening_crystal_cracked", false)) and not bool(pz.get("awakening_memory_code", false)):
		pz["awakening_memory_code"] = true
		changed = true
	## Eski kayıt: Ruh Kesimi mührü kırılmışsa balkon boşluğu aşılmış sayılır.
	if bool(pz.get("soul_seal_balcony", false)) and not bool(pz.get("awakening_balcony_crossed", false)):
		pz["awakening_balcony_crossed"] = true
		changed = true
	## Eski kayıt: geçit halkaları yoktu; mühür odası bulmacası çözülmüşse geçit zaten aşılmış sayılır.
	if (bool(pz.get("awakening_seal_weight", false)) or bool(pz.get("awakening_memory_code", false))) and not bool(pz.get("awakening_passage_rings", false)):
		pz["awakening_passage_rings"] = true
		changed = true
	if changed:
		GameState.knowledge_changed.emit(&"world")


func sync_from_world() -> void:
	_sync_legacy_flags_into_puzzles()
	solved.clear()
	var pz: Dictionary = GameState.world_memory_state.get("puzzles", {})
	if not pz is Dictionary:
		pz = {}
		GameState.world_memory_state["puzzles"] = pz
	for k in pz.keys():
		if bool(pz[k]):
			solved[String(k)] = true


func mark_solved(puzzle_id: StringName) -> void:
	var key := String(puzzle_id)
	if solved.get(key, false):
		return
	solved[key] = true
	var pz: Dictionary = GameState.world_memory_state.get("puzzles", {})
	if not pz is Dictionary:
		pz = {}
		GameState.world_memory_state["puzzles"] = pz
	pz[key] = true
	match puzzle_id:
		&"awakening_weight":
			GameState.set_world_flag(&"awakening_door_opened", true)
		&"awakening_memory_code":
			GameState.set_world_flag(&"awakening_crystal_cracked", true)
		&"decay_vine_shortcut", &"decay_vines":
			GameState.set_world_flag(&"decay_vine_open", true)
		&"decay_archive_key":
			GameState.set_world_flag(&"decay_archive_open", true)
		&"decay_weight_latch":
			GameState.set_world_flag(&"decay_weight_latched", true)
		&"core_bloom_order", &"core_vault_order", &"library_shelf_order", &"mirrors_labyrinth_crossed":
			var cm := get_node_or_null("/root/CurseManager")
			if cm and cm.has_method("clear_curse"):
				cm.clear_curse(8.0)
		_:
			pass
	puzzle_solved.emit(puzzle_id)
	_celebrate_solve()


## İlk çözümde kısa bir ödül: ses + afiş. Testler afişi beklemesin diye başlıksız kalır.
func _celebrate_solve() -> void:
	if is_inside_tree():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(&"seal_open", -8.0)
	if OS.get_environment("TORIMON_TEST") == "1":
		return
	SealBanner.show_banner("HATIRLANDI", "Bir kilit daha açıldı.")


func is_solved(puzzle_id: StringName) -> bool:
	return bool(solved.get(String(puzzle_id), false))


## Plaka canlı durumu: ağırlık varken true. Kaydedilmez; oda değişince plakalar yeniden yazar.
func set_live(puzzle_id: StringName, live: bool) -> void:
	var key := String(puzzle_id)
	if bool(_live.get(key, false)) == live:
		return
	if live:
		_live[key] = true
	else:
		_live.erase(key)
	live_changed.emit(puzzle_id, live)


func is_live(puzzle_id: StringName) -> bool:
	return bool(_live.get(String(puzzle_id), false))


## Çoklu plaka kapısı: eski kayıt (legacy_id çözülmüş) VEYA listedeki her ID çözülmüş/canlı.
func gate_open(all_ids: PackedStringArray, legacy_id: StringName = &"") -> bool:
	if legacy_id != &"" and is_solved(legacy_id):
		return true
	if all_ids.is_empty():
		return false
	for id in all_ids:
		if not (is_solved(StringName(id)) or is_live(StringName(id))):
			return false
	return true


const HINTS: Dictionary = {
	&"decay_catacombs": {
		"goal": "Karanlıkta yol, ölülerin ışığıdır.",
		"orientation": "Çiçeği al, dikende öl. Uçurumda beden köprü olur.",
		"explicit": "Çiçeği al, dikene dokun; beden köprü ve ışık olur, geç."
	},
	&"decay_garden_bloom": {
		"goal": "Çiçeklerin açış sırası kapıyı açar.",
		"orientation": "Çiçekli bedenle yaprak sayılarını oku, sırayla dokun.",
		"explicit": "Çiçek al, dikende öl; yaprakları oku, tacı sırayla aç."
	},
	&"decay_cistern": {
		"goal": "Üç ıslak sayfa sarnıcın farklı katlarında.",
		"orientation": "Vanalarla suyu oynat; çukur dibi için tahliyeyi bedenle tut.",
		"explicit": "Sayfalar dipte, sağ rafta, sol rafta. Dibe inmek için suyu boşalt."
	},
	&"decay_catacomb_seal": {
		"goal": "Karanlıkta yol, ölülerin ışığıdır.",
		"orientation": "Çiçeği al, sonra dikende öl. Çiçekli beden ışık olur.",
		"explicit": "Girişteki çiçeği al, dikene dokun. Ceset fener olur; yola taşı."
	},
	&"awakening_weight": {
		"goal": "Kapıyı açık tutmak için bir ağırlık gerekiyor.",
		"orientation": "Taş yürür. Onu plakanın üstüne bırakırsan bir ağırlık tamam olur.",
		"explicit": "Taşı sağdaki plakaya it. Kapı ikinci bir ağırlık da istiyor."
	},
	&"awakening_corpse_plate": {
		"goal": "Kapı iki ağırlık istiyor: biri taş, biri beden.",
		"orientation": "Kırmızı kristal bedeni plakada bırakır. Taş ise öbür plakada durur.",
		"explicit": "Taşı sağdaki plakaya it, kristale iki kez dokun."
	},
	&"awakening_balcony_crossed": {
		"goal": "Kapı boşluğun karşı yakasında.",
		"orientation": "Sütunlar sana fazla uzun; basamak olacak bir şey gerek.",
		"explicit": "Kristale iki kez dokun, bedenin basamak olsun; sütunlardan geç."
	},
	&"awakening_crypt_pages": {
		"goal": "Defter sayfaları karışık duruyor.",
		"orientation": "Her sayfanın üstünde bir tarih yazıyor.",
		"explicit": "Sayfalara en eski tarihten en yeniye doğru sırayla dokun."
	},
	&"awakening_crypt_bed": {
		"goal": "Yatak boş; bir beden bekliyor.",
		"orientation": "Kırmızı kristal bedeni yatağın üstünde bırakır.",
		"explicit": "Kristale iki kez dokun; bedenin yatağa uzanınca anı açılır."
	},
	&"awakening_passage_rings": {
		"goal": "Geçidin çıkışı halkalara bağlı.",
		"orientation": "Üç halkanın çentik sayısı yankıdaki sırayla eşleşmeli.",
		"explicit": "Halkaları yankıdaki çentik sırasına çevir; çıkış açılır."
	},
	&"awakening_seal_weight": {
		"goal": "Kapı bir beden ağırlığı istiyor.",
		"orientation": "Kırmızı kristal bedeni ilk plakada bırakır.",
		"explicit": "İlk kristale iki kez dokun, beden plakada kalsın."
	},
	&"awakening_seal_second": {
		"goal": "İkinci plaka da boş kalmamalı.",
		"orientation": "Her plaka ayrı bir beden ister. Bedenler birbirini atmaz.",
		"explicit": "İkinci kristale iki kez dokun, bedenin ikinci plakada kalsın."
	},
	&"awakening_vigil_trace": {
		"goal": "Nöbet odasında gölgeler yürüyor.",
		"orientation": "Kapıyı gösteren gölge, diğerleri gibi yarıda solmaz.",
		"explicit": "Sağdaki kapıya kadar yürüyen gölgenin peşinden git."
	},
	&"awakening_memory_code": {
		"goal": "Taş mühür üç haneli bir sayı bekliyor.",
		"orientation": "Geçitteki yarıkta geçmişten kalan bir ses yankılanıyor.",
		"explicit": "Yarıktaki fısıltıyı dinle; aklına gelen üç sembolü sırayla gir."
	},
	&"decay_vines": {
		"goal": "Sarmaşık yolu kapatmış; kılıç onu çözmüyor.",
		"orientation": "Çiçek yakar. Çiçekli bir beden sarmaşığın dibinde kül bırakır.",
		"explicit": "Çiçeği al, kırık camda öl; çiçekli ceset sarmaşığı yakar."
	},
	&"decay_weight_latch": {
		"goal": "Sürgülü kapı kilitli.",
		"orientation": "Zemindeki plaka ağırlıkla tetiklenir; mekanizma sürgüyü yakalar.",
		"explicit": "Taşı plakaya it; kapı ağırlık durdukça açık kalır."
	},
	&"decay_weight_corpse": {
		"goal": "Kapı hem taşı hem bedeni bekliyor.",
		"orientation": "Taş sürgüyü tutar. Dikenli plaka ise bir beden ister.",
		"explicit": "Taşı sürgüye it; dikene dokunup bedenini plakada bırak."
	},
	&"decay_greenhouse_pot": {
		"goal": "Sera mührü yalnız doğru saksıyı tanır.",
		"orientation": "Gölge bir saksıya yürüyor. Yanlış saksı bedeni yutar, açmaz.",
		"explicit": "Gölgenin durduğu saksının dikenine dokun; bedenin orada kalsın."
	},
	&"decay_greenhouse": {
		"goal": "Sera mührü tek bir saksıya bağlı.",
		"orientation": "Duvardaki yazı çiçeği, gölge ise doğru saksıyı gösterir.",
		"explicit": "Gölgenin durduğu saksıda öl; cesedin mührü açar."
	},
	&"decay_shilda_wall_broken": {
		"goal": "Çatlak duvar kılıçla inmez.",
		"orientation": "Gözler kızarınca atılır. Son anda kenara çekil; duvara çarpsın.",
		"explicit": "İki çarpma duvarı yıkar. Üç kez öldüysen tek çarpma yeter."
	},
	&"decay_archive_key": {
		"goal": "Arşiv kapısı mühürlü; kilitte çiçek motifi var.",
		"orientation": "Bahçedeki çiçeğin ışığına bak; çiçek anısı kilidi açar.",
		"explicit": "Bahçede çiçeği aç, gölgeyle konuş; anı günlüğe işlenir."
	},
	&"library_hall_shelves": {
		"goal": "Raflardaki üç kitap sırayla çekilmeli.",
		"orientation": "Kayıt A sırayı söylüyor. Kitapları o sırayla çek.",
		"explicit": "Önce saat, sonra çiçek, en son mühür kitabını çek."
	},
	&"library_witnesses": {
		"goal": "Üç tanık aynı anda mührün yanında olmalı.",
		"orientation": "Beden plakada, yankı plakada, sen mühürde dur.",
		"explicit": "Dikene değ, sunağa dokun, plakaya bas, sonra mühre koş."
	},
	&"library_clockroom": {
		"goal": "Üç kadran var; saatler yankıda söylenmişti.",
		"orientation": "Kadranlar sırayla: 1927, 1995, bugün. Tanıkları hatırla.",
		"explicit": "Kadranları sırayla üç, dokuz ve altıya getir."
	},
	&"library_page_order": {
		"goal": "Dağılmış sayfaları oldukları sıraya diz.",
		"orientation": "Önce deney, sonra kapı, sonda mühür. Kartları böyle diz.",
		"explicit": "Deneyin başlangıcından mührün kapanışına kadar olayları sırala."
	},
	&"mirrors_reverse_crossed": {
		"goal": "Aynalı zeminde sağ sol yer değiştiriyor.",
		"orientation": "Kırmızı şeritler zeminde. Yönün ters, atlayarak geç.",
		"explicit": "Şeritlerin önünde dur, ters yöne bas ve sağ uca var."
	},
	&"mirrors_dual_echo": {
		"goal": "Yankın aynalı yürür; kolu o çeker, plakada sen dur.",
		"orientation": "Sunağa kaydet, yankı sağdan koşar. Sen plakada bekle.",
		"explicit": "Sunağı kaydet, ortaya yürü, dokun; sonra plakaya dön."
	},
	&"mirrors_dual_weight": {
		"goal": "Dikenli plakayı bir beden basık tutmalı.",
		"orientation": "Dikene değ, bedenin plakanın üstünde kalsın.",
		"explicit": "Dikene dokun; beden plakayı tutarken kapı açık kalır."
	},
	&"mirrors_gallery_plate_1": {
		"goal": "Galerinin üç plakası bedenle basılmalı.",
		"orientation": "Her plakanın yanında diken var. Sırayla üçünü de bas.",
		"explicit": "İlk dikene dokun; beden ilk plakada kalır."
	},
	&"mirrors_gallery_plate_2": {
		"goal": "Galerinin üç plakası bedenle basılmalı.",
		"orientation": "Plakalar bedeni tutar. İkincisi ortadaki.",
		"explicit": "Ortadaki dikene dokun; beden plakada kalır."
	},
	&"mirrors_gallery_plate_3": {
		"goal": "Galerinin üç plakası bedenle basılmalı.",
		"orientation": "Üçüncü plaka en sağda. Bedeni orada bırak.",
		"explicit": "Sağdaki dikene dokun; beden son plakada kalır."
	},
	&"mirrors_unbroken_mimic": {
		"goal": "Yansıma bir yol yürüyor; yankın aynı yolu izlemeli.",
		"orientation": "Yol üç nokta: yer, yüksek taş, yer. Yankıyı oradan geçir.",
		"explicit": "Sunağı kaydet; yankı alçak, yüksek, alçak noktaya sırayla uğrasın."
	},
	&"core_ascent": {
		"goal": "Son merdiven iki yetenek ve bir yankı istiyor.",
		"orientation": "Önce yankının durduğu basamak. Sonra Ruh Kesimi ve Gölge Atılması.",
		"explicit": "İkisi de açıkken son basamağa dokun; gölge mührü tutar."
	},
	&"core_seal": {
		"goal": "Çekirdeğin ana mührü kırılmalı, çıkış açılmalı.",
		"orientation": "Her iki mühür parçası birleşmeden çekirdek savunması gevşemez.",
		"explicit": "Gölgeyle çekirdeğin merkezine yaklaş, Ruh Kesimi ile mührü kır."
	},
	&"core_bloom_order": {
		"goal": "Bahçedeki üç taş uyanmadan çiçek konuşmuyor.",
		"orientation": "Taşlardaki noktaları say: önce en çok, sonra en az, sonra kalan.",
		"explicit": "Sıra dört, bir, iki. Yanlış taş zinciri başa sarar."
	},
	&"core_vault_order": {
		"goal": "Hafıza kasası karanlık. Üç sütun bir tarih sırası istiyor.",
		"orientation": "Önce kuruluşun yılı, sonra senin girdiğin yıl, en son son kayıt.",
		"explicit": "1927, sonra 1995, sonra Son. Kasa ancak o zaman açılır."
	},
	&"library_shelf_order": {
		"goal": "Yasak kanada giden tahta henüz inmedi.",
		"orientation": "Yere düşen kitaptaki notu oku, sırayı bul.",
		"explicit": "Ses, mühür, çiçek. Bu sıra tahtayı indirir."
	},
	&"soul_seal_forbidden": {
		"goal": "Yasak kanatta iki mor mühür yolu kesiyor.",
		"orientation": "Havadaki kesik Ruh Kesimi'ni verir. Mühürler o güçle açılır.",
		"explicit": "Ruh Kesimi ile önce yakındaki mührü kes."
	},
	&"soul_seal_forbidden_2": {
		"goal": "İlk mühür kesildi, ikincisi hâlâ yolda duruyor.",
		"orientation": "İkinci mühür yalnız ilk mühürden sonra tanır seni.",
		"explicit": "Ruh Kesimi ile ikinci mührü de kes."
	},
	&"library_reading_cabin": {
		"goal": "Hücrenin kabini mor mührün ardında kapalı.",
		"orientation": "Mor mührü kes, kabine gir.",
		"explicit": "Ruh Kesimi ile kabin mührünü kes."
	},
	&"library_reading_cell": {
		"goal": "Kabin açıldı, duvardaki çentikler seni bekliyor.",
		"orientation": "Duvar bir günü bile atlamadan sayılmış.",
		"explicit": "Kabinin içindeki çentik duvarını oku."
	},
	&"mirrors_labyrinth_crossed": {
		"goal": "Uçurumun karşısı tavandaki aynada görünüyor.",
		"orientation": "Mavi yansıma gerçek taş. Soluk kırmızı olan yalan.",
		"explicit": "Kırmızı basamağa atlama. Mavi taşları izleyerek karşıya geç."
	},
	&"experiment_intake": {
		"goal": "Terazinin iki kefesi de dolmalı.",
		"orientation": "Sol kefe bedeni, sağ kefe taşı tartar.",
		"explicit": "Sol kefede ölüp bedeni bırak, taşı sağ kefeye it."
	},
	&"experiment_quarantine_done": {
		"goal": "Kırmızı sis canlıyı yer. Rapor sisin ötesinde, yüksek rafta.",
		"orientation": "Ölü beden laneti emer. Cesedini sisin ortasına bırak.",
		"explicit": "Bedeni bulutun içine koy, güvenli koridordan geç, rafa zıpla."
	},
	&"experiment_conduit": {
		"goal": "Üç damar kesilmeden enerji akmaz.",
		"orientation": "Damarlar kalpten uca doğru sırayla kesilir.",
		"explicit": "Önce ortadaki, sonra soldaki, en son sağdaki damarı kes."
	},
	&"experiment_observation": {
		"goal": "Cam ardındaki yankı yürümeden not okunmaz.",
		"orientation": "Projektör plakası yalnız beden ağırlığını tanır.",
		"explicit": "Plakadaki dikende öl, bedenin plakada kalsın, yankıyı izle."
	}
}


## Oda -> sırayla bakılacak çözülmemiş bulmaca. Günlük ipucu bunu kullanır.
const ROOM_PUZZLES: Dictionary = {
	"awakening": [&"awakening_weight", &"awakening_corpse_plate"],
	"awakening_balcony": [&"awakening_balcony_crossed"],
	"awakening_crypt": [&"awakening_crypt_pages", &"awakening_crypt_bed"],
	"awakening_passage": [&"awakening_passage_rings", &"awakening_memory_code"],
	"awakening_seal": [&"awakening_seal_weight", &"awakening_seal_second", &"awakening_memory_code"],
	"awakening_vigil": [&"awakening_vigil_trace"],
	"decay_vines": [&"decay_vines"],
	"decay_weight": [&"decay_weight_latch", &"decay_weight_corpse"],
	"decay_greenhouse": [&"decay_greenhouse"],
	"decay_shilda_wall": [&"decay_shilda_wall_broken"],
	"decay_garden": [&"decay_garden_bloom"],
	"decay_catacombs": [&"decay_catacomb_seal"],
	"decay_cistern": [&"decay_cistern"],
	"library_hall": [&"library_hall_shelves"],
	"library_witness": [&"library_witnesses"],
	"library_clockroom": [&"library_clockroom"],
	"library_page": [&"library_page_order"],
	"library_upper_stacks": [&"library_shelf_order"],
	"library_forbidden_wing": [&"soul_seal_forbidden", &"soul_seal_forbidden_2"],
	"library_reading_cell": [&"library_reading_cabin", &"library_reading_cell"],
	"experiment_intake": [&"experiment_intake"],
	"experiment_circuit": [&"experiment_circuit"],
	"experiment_quarantine": [&"experiment_quarantine_done"],
	"experiment_core_conduit": [&"experiment_conduit"],
	"experiment_observation": [&"experiment_observation"],
	"mirrors_reverse": [&"mirrors_reverse_crossed"],
	"mirrors_dual": [&"mirrors_dual_echo", &"mirrors_dual_weight"],
	"mirrors_gallery": [&"mirrors_gallery_plate_1", &"mirrors_gallery_plate_2", &"mirrors_gallery_plate_3"],
	"mirrors_unbroken": [&"mirrors_unbroken_mimic"],
	"mirrors_labyrinth": [&"mirrors_labyrinth_crossed"],
	"core_bloom_garden": [&"core_bloom_order"],
	"core_memory_vault": [&"core_vault_order"],
	"core_ascent": [&"core_ascent"],
	"core": [&"core_seal"],
}


## Eski kayıt: bu id çözülmüşse oda zaten geçilmiş sayılır, yeni bulmaca ipucu gösterilmez.
const LEGACY_ROOM_DONE: Dictionary = {
	"decay_vines": [&"decay_vine_shortcut"],
	"decay_weight": [&"decay_weight_latch"],
	"decay_greenhouse": [&"decay_greenhouse"],
	"decay_garden": [&"decay_archive_key"],
	"decay_cistern": [&"decay_cistern"],
	"decay_catacombs": [&"decay_catacomb_seal"],
	"awakening_passage": [&"awakening_memory_code"],
	"awakening_seal": [&"awakening_memory_code"],
}


## Günlük açılınca kademe artar: 1 hedef, 2 yön, 3 açık cevap. Üçten sonra artmaz.
func journal_hint_for_active_room() -> Dictionary:
	var room := String(RoomManager.get_active_room_id())
	var list: Array = ROOM_PUZZLES.get(room, [])
	var pid := &""
	for legacy in LEGACY_ROOM_DONE.get(room, []):
		if is_solved(StringName(String(legacy))):
			return {}
	for candidate in list:
		var id := StringName(String(candidate))
		if not is_solved(id):
			pid = id
			break
	if pid == &"":
		return {}
	var visits: Dictionary = GameState.player_progress_knowledge.get("hint_visits", {})
	var n := mini(int(visits.get(room, 0)) + 1, 3)
	visits[room] = n
	GameState.player_progress_knowledge["hint_visits"] = visits
	return {"title": "Bu oda", "body": get_current_hint(pid, n)}


func get_hints(puzzle_id: StringName) -> Dictionary:
	return HINTS.get(puzzle_id, {
		"goal": "Odadaki izleri ve mekanizmaları incele.",
		"orientation": "Çevredeki yankılar ve nesneler yol gösterir.",
		"explicit": "Bulmacanın parçalarını sırayla birleştir."
	})


func get_current_hint(puzzle_id: StringName, tier: int = 1) -> String:
	var h := get_hints(puzzle_id)
	match tier:
		1:
			return String(h.get("goal", ""))
		2:
			return String(h.get("orientation", ""))
		3:
			return String(h.get("explicit", ""))
		_:
			return String(h.get("goal", ""))
