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
	_celebrate_solve(puzzle_id)


## Bulmaca türüne göre mevcut SFX (bağ/kilit/plaka/yankı... her çözülüş farklı duyulur).
const SOLVE_SFX := [
	["bond", &"echo_playback", -7.0],
	["seal", &"seal_key", -6.0],
	["lock", &"seal_key", -6.0],
	["latch", &"seal_key", -6.0],
	["key", &"seal_key", -6.0],
	["weight", &"plate_press", -4.0],
	["plate", &"plate_press", -4.0],
	["stand", &"plate_press", -4.0],
	["echo", &"echo_record", -6.0],
	["corpse", &"corpse_drag", -8.0],
	["dials", &"clock_tick", -4.0],
	["code", &"clock_tick", -4.0],
	["circuit", &"clock_tick", -4.0],
	["cross", &"door_open", -8.0],
	["walk", &"door_open", -8.0],
	["order", &"discovery", -8.0],
	["shelves", &"discovery", -8.0],
	["bloom", &"discovery", -8.0],
	["bellroom", &"discovery", -8.0],
	["shrine", &"discovery", -8.0],
]


static func solve_sfx_for(puzzle_id: StringName) -> Array:
	var id := String(puzzle_id)
	for e in SOLVE_SFX:
		if id.contains(String(e[0])):
			return [e[1], e[2]]
	return [&"seal_open", -8.0]


## İlk çözümde kısa bir ödül: ses + afiş. Testler afişi beklemesin diye başlıksız kalır.
func _celebrate_solve(puzzle_id: StringName = &"") -> void:
	if is_inside_tree():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			var pick := solve_sfx_for(puzzle_id)
			am.play_sfx(pick[0], pick[1])
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
		"orientation": "Her çiçekli ceset bir sembolü yakar: uçurum kenarları, köprü.",
		"explicit": "Çiçekle uçurumun iki kenarında öl, sonra köprüde öl; 5-8-6'yı mühre gir."
	},
	&"decay_garden_bloom": {
		"goal": "Çiçeklerin açış sırası kapıyı açar.",
		"orientation": "Yaprak sayılarını bedenin ışığında oku; sıra serada camdaydı.",
		"explicit": "Çiçek al, dikende öl; yaprakları oku, tacı sırayla aç."
	},
	&"decay_cistern": {
		"goal": "Üç ıslak sayfa sarnıcın farklı katlarında.",
		"orientation": "Vanalarla suyu oynat; çukur dibi için tahliyeyi bedenle tut.",
		"explicit": "Sayfalar dipte, sağ rafta, sol rafta. Dibe inmek için suyu boşalt."
	},
	&"decay_catacomb_seal": {
		"goal": "Karanlıkta yol, ölülerin ışığıdır.",
		"orientation": "Üç sembol, üç çiçekli ceset: iki uçurum kenarı, bir köprü.",
		"explicit": "Çiçekle uçurumun iki kenarında öl, sonra köprüde öl; 5-8-6'yı mühre gir."
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
		"orientation": "Her plaka ayrı bir beden ister. Bir beden iki plakaya yetmez.",
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
		"explicit": "Taşı plakaya it; dikene dokunup bedenini diğer plakada bırak."
	},
	&"decay_greenhouse_pot": {
		"goal": "Sera mührü yalnız doğru saksıyı tanır.",
		"orientation": "Gölge bir saksıya yürüyor. Yanlış saksı bedeni yutar, açmaz.",
		"explicit": "Gölgenin durduğu saksının dikenine dokun; bedenin orada kalsın."
	},
	&"decay_greenhouse": {
		"goal": "Sera mührü tek bir saksıya bağlı.",
		"orientation": "Gölge bir saksıya yürüyor. Camdaki yazı bahçe sırasını gösterir.",
		"explicit": "Gölgenin durduğu saksıda öl; cesedin mührü açar."
	},
	&"decay_shilda_wall_broken": {
		"goal": "Çatlak duvar kılıçla inmez. Bulutu cesedinle geç.",
		"orientation": "Cesedini buluta bırak, geç. Gözler kızarınca kenara çekil.",
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
		"explicit": "Dikene değ, sunağa dokun, plakaya bas, mühre koş: saat, çiçek, mühür."
	},
	&"library_clockroom": {
		"goal": "Üç kadran var; saatler yankıda söylenmişti.",
		"orientation": "1927, 1995, bugün: akreplerin gösterdiği saate kadranı çevir.",
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
		"explicit": "Kırmızı şeritlere basma; tuşlar ters, atlayarak sağ uca var. Kalkanlı gölgeyi kesme."
	},
	&"mirrors_dual_echo": {
		"goal": "Yankı aynada gibi tersler: sen sağa gidersen o sola gider.",
		"orientation": "Plaka ve kol solda; yankın ulaşsın diye sen sağa yürü.",
		"explicit": "Dikende öl; sunağa kaydet, sağa yürü; yankı plaka ve kolu tutar."
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
		"goal": "Galerinin ikinci plakası hâlâ boş.",
		"orientation": "Plakalar bedeni tutar. İkincisi ortadaki.",
		"explicit": "Ortadaki dikene dokun; beden plakada kalır."
	},
	&"mirrors_gallery_plate_3": {
		"goal": "Son plaka da bir beden bekliyor.",
		"orientation": "Üçüncü plaka en sağda. Bedeni orada bırak.",
		"explicit": "Sağdaki dikene dokun; beden son plakada kalır."
	},
	&"mirrors_1927_walk": {
		"goal": "Gece kendi kendine oynuyor; gölgeyi izle.",
		"orientation": "Gölge yürüyor; her noktada yakınında bekle.",
		"explicit": "Gölgenin peşinden sağ uca yürü, sonra yankıya dokun."
	},
	&"mirrors_unbroken_mimic": {
		"goal": "Yansıma bir yol yürüyor; yankın aynı yolu izlemeli.",
		"orientation": "Yol üç nokta: yer, yüksek taş, yer. Yankıyı oradan geçir.",
		"explicit": "Sunağı kaydet; yankı alçak, yüksek, alçak noktaya sırayla uğrasın."
	},
	&"core_entry_echo": {
		"goal": "Kristale giden yolu bir kapı kesiyor.",
		"orientation": "Sunak yankını kaydeder; kapı bir plakanın ağırlığına bağlı.",
		"explicit": "Sunağa dokun, plakaya yürü, yankın plakadayken kapıdan geç."
	},
	&"core_ascent": {
		"goal": "Son merdiven iki yetenek ve bir yankı istiyor.",
		"orientation": "Mührü Ruh Kesimi, perdeyi Gölge Atılması ile geç.",
		"explicit": "Mührü kes, perdeden atıl; yankın plakada, sen kapıda."
	},
	&"core_threshold_crossed": {
		"goal": "Kırmızı bulut canlıyı yer; geçit bulutun ötesinde.",
		"orientation": "Ölü beden laneti emer. Bulutun içindeki kırmızı kristallerle iki beden bırak.",
		"explicit": "Soldaki kristale iki kez dokunup öl, sonraki kristalde bunu tekrarla, geç."
	},
	&"core_seal_bond_1": {
		"goal": "Mührün üç bağı var; hepsi Ruh Kesimi ile kesilir.",
		"orientation": "Bağlar soldan sağa sırayla kesilir. Yakındakinden başla.",
		"explicit": "Ruh Kesimi ile en soldaki bağı kes."
	},
	&"core_seal_bond_2": {
		"goal": "İlk bağ kesildi, ikincisi hâlâ tutuyor.",
		"orientation": "İkinci bağ ancak birincisinden sonra gevşer.",
		"explicit": "Ruh Kesimi ile ortadaki bağı kes."
	},
	&"core_seal_bond_3": {
		"goal": "İki bağ kesildi, sonuncusu hâlâ tutuyor.",
		"orientation": "Son bağ ikincisinden sonra gevşer.",
		"explicit": "Ruh Kesimi ile en sağdaki bağı kes."
	},
	&"core_seal": {
		"goal": "Çekirdeğin ana mührü kırılmalı, çıkış açılmalı.",
		"orientation": "Her iki mühür parçası birleşmeden çekirdek savunması gevşemez.",
		"explicit": "Gölgeyle çekirdeğin merkezine yaklaş, Ruh Kesimi ile mührü kır."
	},
	&"core_defense": {
		"goal": "Çekirdek kristali dalga dalga gölge çekiyor.",
		"orientation": "Gölgeler iki uçtan kristale yürür. Kristalin başında dur, onları kes.",
		"explicit": "Kristale dokun, üç dalgayı kes. Kristal beş darbe taşır."
	},
	&"core_bloom_order": {
		"goal": "Bahçedeki üç taş uyanmadan çiçek konuşmuyor.",
		"orientation": "Taşlardaki noktaları say: önce en çok, sonra en az, sonra kalan.",
		"explicit": "Önce bedenini plakaya bırak. Sıra dört, bir, iki; yanlış taç, zinciri başa sarar."
	},
	&"core_bloom_weight": {
		"goal": "Taşlar uyanmadan önce plakada bir beden durmalı.",
		"orientation": "Dikene dokun, bedenin plakanın üstünde kalsın.",
		"explicit": "Dikene dokun; beden plakayı tutarken taşlara dokun."
	},
	&"core_vault_order": {
		"goal": "Hafıza kasası karanlık. Üç sütun bir tarih sırası istiyor.",
		"orientation": "Önce kuruluşun yılı, sonra senin girdiğin yıl, en sonda son kayıt.",
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
		"explicit": "Kırmızı basamağa atlama. Mavi taşları izleyerek son boşlukta kırmızı kristale dokun; bedenin köprü olur."
	},
	&"mirrors_shrine_trial": {
		"goal": "Tapınağın sonundaki geçit kırmızı perdelerle kapalı.",
		"orientation": "Sunaktaki Gölge Atılması perdelerden geçirir.",
		"explicit": "Sunağa dokun, üç perdeden ve boşluktan atılarak geç."
	},
	&"experiment_intake": {
		"goal": "Terazinin iki kefesi de dolmalı.",
		"orientation": "Sol kefe bedeni, sağ kefe taşı tartar.",
		"explicit": "Sol kefede ölüp bedeni bırak, taşı sağ kefeye it."
	},
	&"experiment_authority": {
		"goal": "Mührün üç hanesi başka odalardaki kayıtlarda.",
		"orientation": "Hücre A, Hücre B, Kabul Kaydı: sırayla birer hane.",
		"explicit": "Kod 418: Hücre A dört, Hücre B bir, Kabul sekiz; mühre gir."
	},
	&"experiment_circuit": {
		"goal": "Yankın plakada kalırken sen kristale koş.",
		"orientation": "Sunağa dokun, plakaya yürü, kayıt bitene dek bekle.",
		"explicit": "Plakada sekiz saniye dur, sonra kristale koş; yankı plakada kalır."
	},
	&"experiment_quarantine_done": {
		"goal": "Kırmızı sis canlıyı yer. Rapor sisin ötesinde, yüksek rafta.",
		"orientation": "Ölü beden laneti emer. Sisin içinde öl; ceset güvenli alan açar.",
		"explicit": "Bedeni bulutun içine koy, güvenli koridordan geç, rafa zıpla."
	},
	&"experiment_conduit": {
		"goal": "Üç damar kesilmeden enerji akmaz.",
		"orientation": "Damarlar kalpten uca doğru sırayla kesilir.",
		"explicit": "Önce ortadaki, sonra soldaki, en son sağdaki damarı kes."
	},
	&"awakening_bellroom_corpse": {
		"goal": "Üç plaka aynı anda tutulmalı; ilki beden ister.",
		"orientation": "Dikene dokun, bedenin plakada kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk plakayı tutsun."
	},
	&"awakening_bellroom_echo": {
		"goal": "Yankı ikinci plakayı tutmalı.",
		"orientation": "Sunağa dokun, plakaya yürü ve orada bekle.",
		"explicit": "Sunakta kaydı başlat, orta plakada sekiz saniye dur; yankı orada kalır."
	},
	&"awakening_bellroom_stand": {
		"goal": "Üçüncü plakaya sen bas.",
		"orientation": "Yankı yürürken öteki plakada dur.",
		"explicit": "Yankıyı başlat, sonra sağdaki plakada dur; üçü birlikte kapıyı açar."
	},
	&"awakening_bellroom": {
		"goal": "Çanlar defterdeki sırayla çalar.",
		"orientation": "Bir sayfa ilk ve son çanı, öteki ortadakini söyler.",
		"explicit": "Gün çanı, sonra Yas çanı, en son Gece çanı."
	},
	&"decay_rootworks_corpse": {
		"goal": "Üç ağırlık gerekir; ilki beden.",
		"orientation": "Dikene dokun; bedenin soldaki plakada kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk plakayı tutsun."
	},
	&"decay_rootworks_stone": {
		"goal": "İkinci ağırlık taş.",
		"orientation": "Taşı yürüyerek ya da etkileşimle plakaya doğru it.",
		"explicit": "Taşı sağdaki plakaya it; orada kalsın."
	},
	&"decay_rootworks_water": {
		"goal": "Üçüncü ağırlığı yukarıdaki levha verir.",
		"orientation": "Salın vanası suyu yükseltir; ikinci seviyede yan çıkıntıya atla.",
		"explicit": "Vanaya bir kez dokun, sal yükselince sağdaki çıkıntıdaki levhaya çık ve orada dur."
	},
	&"decay_rootworks": {
		"goal": "Defter üç adımın sırasını söyler.",
		"orientation": "Su verilir, sonra kök salınır, çiçek en sonda gelir.",
		"explicit": "Su, Kök, Çiçek sırasıyla dokun."
	},
	&"library_archive_vault_corpse": {
		"goal": "Kasa üç şey ister; ilki beden.",
		"orientation": "Dikene dokun; bedenin soldaki plakada kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk plakayı tutsun."
	},
	&"library_archive_vault_echo": {
		"goal": "İkinci ağırlık yankıdan gelir.",
		"orientation": "Sunağa dokun, plakaya yürü ve orada bekle.",
		"explicit": "Sunakta kaydı başlat, sağdaki plakada sekiz saniye dur; yankı orada kalır."
	},
	&"library_archive_vault_dials": {
		"goal": "Kadranlar ay numarası ister.",
		"orientation": "Defterin sayfaları Mühür, Kayıt ve Son için birer ay söyler.",
		"explicit": "Mühür 4, Kayıt 11, Son 7."
	},
	&"library_archive_vault": {
		"goal": "Raflar tarih sırasıyla açılır.",
		"orientation": "Üç ayı küçükten büyüğe diz; her ay bir raftır.",
		"explicit": "Mühür Rafı, Son Raf, Kayıt Rafı."
	},
	&"experiment_twin_lab_corpse": {
		"goal": "Tartı iki ağırlık ister; ilki beden.",
		"orientation": "Dikene dokun; bedenin soldaki kefede kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk kefeyi tutsun."
	},
	&"experiment_twin_lab_echo": {
		"goal": "İkinci ağırlık yankıdan gelir.",
		"orientation": "Sunağa dokun, kefeye yürü ve orada bekle.",
		"explicit": "Sunakta kaydı başlat, sağdaki kefede sekiz saniye dur; yankı orada kalır."
	},
	&"experiment_twin_lab_seal": {
		"goal": "Mühür yalnız bir kesimle çözülür.",
		"orientation": "Tartı açıkken mührü Ruh Kesimi'yle kır.",
		"explicit": "Beden ve yankı kefedeyken mührün önünde Ruh Kesimi'ni kullan."
	},
	&"experiment_twin_lab": {
		"goal": "İşlem föydeki sırayla yürür.",
		"orientation": "Tartı, kesim, dosya; dosya en son gelir.",
		"explicit": "Tartı, Kesim Masası, Dosya Masası."
	},
	&"mirrors_inverse_hall_mimic": {
		"goal": "Yansımanın yolu yankıyla yürünür.",
		"orientation": "Sunağa dokun; yankın sırasıyla alçak, yüksek, alçak noktalardan geçmeli.",
		"explicit": "Sunakta kaydı başlat; ters yönde sağa yürü, ortadaki platforma çık, sonra in."
	},
	&"mirrors_inverse_hall_cross": {
		"goal": "Kırmızı çizginin ötesinde bir plaka var.",
		"orientation": "Gölge Atılması kırmızı çizgiden geçer; Ayna Tapınağı'nda öğrenilir.",
		"explicit": "Çizgiye Gölge Atılması ile dal ve ötedeki plakaya bas."
	},
	&"mirrors_inverse_hall": {
		"goal": "Aynalar notlardaki sırayla yanar.",
		"orientation": "Ana Ayna, Yansıma Aynası, Gölge Aynası.",
		"explicit": "Önce Ana Ayna, sonra Yansıma, en son Gölge Aynası."
	},
	&"core_last_record_corpse": {
		"goal": "Kasa dört şey ister; ilki beden.",
		"orientation": "Dikene dokun; bedenin soldaki plakada kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk plakayı tutsun."
	},
	&"core_last_record_echo": {
		"goal": "İkinci ağırlık yankıdan gelir.",
		"orientation": "Sunağa dokun, plakaya yürü ve orada bekle.",
		"explicit": "Sunakta kaydı başlat, sağdaki plakada sekiz saniye dur."
	},
	&"core_last_record_seal": {
		"goal": "Mühür yalnız bir kesimle çözülür.",
		"orientation": "Beden ve yankı plakadayken mührü Ruh Kesimi'yle kır.",
		"explicit": "Mührün önünde Ruh Kesimi'ni kullan."
	},
	&"core_last_record_cross": {
		"goal": "Kırmızı çizginin ötesinde bir plaka var.",
		"orientation": "Gölge Atılması çizgiden geçer; Ayna Tapınağı'nda öğrenilir.",
		"explicit": "Çizgiye Gölge Atılması ile dal ve ötedeki plakaya bas."
	},
	&"core_last_record": {
		"goal": "Sayfalar kayıtların sırasıyla çevrilir.",
		"orientation": "Gözlem, kayıt, veda; veda en son gelir.",
		"explicit": "Gözlem Sayfası, Kayıt Sayfası, Veda Sayfası."
	},
	&"memory_uyanis": {
		"goal": "Nöbet odasında kırık bir anı parçalanmış.",
		"orientation": "Parçaları oku; tarihler ve neden-sonuç sırayı verir.",
		"explicit": "Önce kayıt defteri, sonra anahtar akşamı, sonra ertesi sabah."
	},
	&"memory_decay": {
		"goal": "Sarmaşığın yanında kırık bir anı dağınık duruyor.",
		"orientation": "Parçaları oku; tarihler ve neden-sonuç sırayı verir.",
		"explicit": "Mart, Nisan, Mayıs 1923 sırasıyla dokun."
	},
	&"memory_kutuphane": {
		"goal": "Saat odasında kırık bir anı dağınık duruyor.",
		"orientation": "Parçaları oku; tarihler ve neden-sonuç sırayı verir.",
		"explicit": "Eylül 1924, Şubat 1925, Haziran 1925 sırasıyla dokun."
	},
	&"memory_deney": {
		"goal": "Devre odasında kırık bir anı dağınık duruyor.",
		"orientation": "Parçaları oku; tarihler ve neden-sonuç sırayı verir.",
		"explicit": "Ocak, Ağustos, Aralık 1926 sırasıyla dokun."
	},
	&"memory_aynalar": {
		"goal": "Aynalı odada kırık bir anı dağınık duruyor.",
		"orientation": "Parçaları oku; tarihler ve neden-sonuç sırayı verir.",
		"explicit": "Mart, Mayıs, Haziran 1927 sırasıyla dokun."
	},
	&"awakening_s_room_corpse": {
		"goal": "Raf dört şey ister; ilki beden.",
		"orientation": "Dikene dokun; bedenin soldaki plakada kalsın.",
		"explicit": "Soldaki dikende öl; bedenin ilk plakayı tutsun."
	},
	&"awakening_s_room_echo": {
		"goal": "İkinci ağırlık yankıdan gelir.",
		"orientation": "Sunağa dokun, plakaya yürü ve orada bekle.",
		"explicit": "Sunakta kaydı başlat, plakada sekiz saniye dur."
	},
	&"awakening_s_room_seal": {
		"goal": "Mühür yalnız bir kesimle çözülür.",
		"orientation": "Beden ve yankı plakadayken mührü Ruh Kesimi'yle kır.",
		"explicit": "Mührün önünde Ruh Kesimi'ni kullan."
	},
	&"awakening_s_room_cross": {
		"goal": "Kırmızı çizginin ötesinde bir plaka var.",
		"orientation": "Gölge Atılması çizgiden geçer; Ayna Tapınağı'nda öğrenilir.",
		"explicit": "Çizgiye Gölge Atılması ile dal, ötedeki plakada dur."
	},
	&"awakening_s_room": {
		"goal": "Beş sayfa yıl sırasıyla çevrilir.",
		"orientation": "Duvardaki başlıklar yıllarıyla yazılı; eskiden yeniye.",
		"explicit": "İlk Gün, Sera, Yasak Raf, Yanlış Sayı, Geç Yansıma."
	},
	&"trial_awakening_bellroom": {
		"goal": "Çanlar ters çalar; çan plakası bedenle tutulu kalmalı.",
		"orientation": "Dikende ölüp bedenini plakada bırak; sonra Gece, Gün, Yas.",
		"explicit": "Dikene dokun, bedenin plakada dursun; sunağa dokun, sonra Gece, Gün, Yas çanlarına bas."
	},
	&"trial_decay_rootworks": {
		"goal": "Taş plakada kalmalı; sıra kökle başlar.",
		"orientation": "Önce taşı plakaya it, sonra Kök, Su, Çiçek diye dokun.",
		"explicit": "Taşı plakaya oturt, sunağa dokun, Kök, Su, Çiçek sırasıyla bas."
	},
	&"trial_library_archive_vault": {
		"goal": "Önce Mühür kadranı kayıtta yazan aya çevrilir; sonra raflar.",
		"orientation": "Sunak kaydı okur: Mühür kadranı Mart; sonra Kayıt, Mühür, Kayıt, Son.",
		"explicit": "Mühür kadranını Mart'a (3) çevir, sunağa dokun, Kayıt, Mühür, Kayıt, Son raflarına bas."
	},
	&"trial_experiment_twin_lab": {
		"goal": "Terazi hatayı sayar; her yanlış dokunuş süre yer.",
		"orientation": "Kesim, Tartı, Dosya; acele edersen süre erir.",
		"explicit": "Sunağa dokun, sonra Kesim, Tartı, Dosya masalarına sırayla dokun."
	},
	&"trial_mirrors_inverse_hall": {
		"goal": "İkinci adımdan sonra ayna seni sunağa geri çağırır.",
		"orientation": "Gölge, Yansıma; sonra çizgiden atılıp sunağa dön, en son Ana Ayna.",
		"explicit": "Gölge, Yansıma aynalarına bas; Gölge Atılması ile geri dön, sunağa dokun, sonra Ana Ayna."
	},
	&"trial_core_last_record": {
		"goal": "Veda sayfasından önce mühür bir kez daha kesilmeli.",
		"orientation": "Gözlem, Kayıt, Gözlem; sonra mühürde Ruh Kesimi, en son Veda.",
		"explicit": "Üç sayfadan sonra mühürde Ruh Kesimi yap, sonra Veda sayfasına dokun."
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
	"awakening_vigil": [&"awakening_vigil_trace", &"memory_uyanis"],
	"decay_vines": [&"decay_vines", &"memory_decay"],
	"decay_weight": [&"decay_weight_latch", &"decay_weight_corpse"],
	"decay_greenhouse": [&"decay_greenhouse"],
	"decay_shilda_wall": [&"decay_shilda_wall_broken"],
	"decay_garden": [&"decay_garden_bloom"],
	"decay_catacombs": [&"decay_catacomb_seal"],
	"decay_cistern": [&"decay_cistern"],
	"library_hall": [&"library_hall_shelves"],
	"library_witness": [&"library_witnesses"],
	"library_clockroom": [&"library_clockroom", &"memory_kutuphane"],
	"library_page": [&"library_page_order"],
	"library_upper_stacks": [&"library_shelf_order"],
	"library_forbidden_wing": [&"soul_seal_forbidden", &"soul_seal_forbidden_2"],
	"library_reading_cell": [&"library_reading_cabin", &"library_reading_cell"],
	"experiment_authority": [&"experiment_authority"],
	"experiment_intake": [&"experiment_intake"],
	"experiment_circuit": [&"experiment_circuit", &"memory_deney"],
	"experiment_quarantine": [&"experiment_quarantine_done"],
	"experiment_core_conduit": [&"experiment_conduit"],
	"experiment_observation": [&"experiment_observation"],
	"mirrors_reverse": [&"mirrors_reverse_crossed"],
	"mirrors_dual": [&"mirrors_dual_echo", &"mirrors_dual_weight", &"memory_aynalar"],
	"mirrors_gallery": [&"mirrors_gallery_plate_1", &"mirrors_gallery_plate_2", &"mirrors_gallery_plate_3"],
	"mirrors_unbroken": [&"mirrors_unbroken_mimic"],
	"mirrors_labyrinth": [&"mirrors_labyrinth_crossed"],
	"mirrors_shrine": [&"mirrors_shrine_trial"],
	"mirrors_1927": [&"mirrors_1927_walk"],
	"core_bloom_garden": [&"core_bloom_order"],
	"core_memory_vault": [&"core_vault_order"],
	"core_threshold": [&"core_threshold_crossed"],
	"core_ascent": [&"core_ascent"],
	"core_seal_chamber": [&"core_seal_bond_1", &"core_seal_bond_2", &"core_seal_bond_3"],
	"awakening_bellroom": [&"awakening_bellroom_corpse", &"awakening_bellroom_echo", &"awakening_bellroom_stand", &"awakening_bellroom"],
	"decay_rootworks": [&"decay_rootworks_corpse", &"decay_rootworks_stone", &"decay_rootworks_water", &"decay_rootworks"],
	"library_archive_vault": [&"library_archive_vault_corpse", &"library_archive_vault_echo", &"library_archive_vault_dials", &"library_archive_vault"],
	"experiment_twin_lab": [&"experiment_twin_lab_corpse", &"experiment_twin_lab_echo", &"experiment_twin_lab_seal", &"experiment_twin_lab"],
	"mirrors_inverse_hall": [&"mirrors_inverse_hall_mimic", &"mirrors_inverse_hall_cross", &"mirrors_inverse_hall"],
	"core_last_record": [&"core_last_record_corpse", &"core_last_record_echo", &"core_last_record_seal", &"core_last_record_cross", &"core_last_record"],
	"awakening_s_room": [&"awakening_s_room_corpse", &"awakening_s_room_echo", &"awakening_s_room_seal", &"awakening_s_room_cross", &"awakening_s_room"],
	"core": [&"core_entry_echo", &"core_seal", &"core_defense"],
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
	tier = mini(tier, GameSettings.max_hint_tier()) ## İpucu seviyesi ayarı
	match tier:
		1:
			return String(h.get("goal", ""))
		2:
			return String(h.get("orientation", ""))
		3:
			return String(h.get("explicit", ""))
		_:
			return String(h.get("goal", ""))
