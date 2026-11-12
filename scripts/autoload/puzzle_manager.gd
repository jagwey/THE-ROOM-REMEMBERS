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
		&"decay_vine_shortcut":
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


const HINTS: Dictionary = {
	&"decay_catacombs": {
		"goal": "Karanlıkta yol, ölülerin ışığıdır.",
		"orientation": "Çiçeği al, sonra dikende öl. Çiçekli beden ışık olur.",
		"explicit": "Girişteki çiçeği al, dikene dokun. Cesedin fener gibi yanar; onu yola taşı."
	},
	&"decay_catacomb_seal": {
		"goal": "Karanlıkta yol, ölülerin ışığıdır.",
		"orientation": "Çiçeği al, sonra dikende öl. Çiçekli beden ışık olur.",
		"explicit": "Girişteki çiçeği al, dikene dokun. Cesedin fener gibi yanar; onu yola taşı."
	},
	&"awakening_weight": {
		"goal": "Kapıyı açık tutmak için bir ağırlık gerekiyor.",
		"orientation": "Taş yürür. Onu plakanın üstüne bırakırsan kapı açık kalır.",
		"explicit": "Taş ya da hareketsiz bir beden plakada durursa kapı kapanmaz."
	},
	&"awakening_memory_code": {
		"goal": "Taş mühür üç haneli bir bellek rezonansı bekliyor.",
		"orientation": "Geçitteki yarıkta geçmişten kalan bir ses yankılanıyor.",
		"explicit": "Yarıktaki fısıltıyı dinle; zihninde canlanan üç sembolü sırayla gir."
	},
	&"decay_weight_latch": {
		"goal": "Çürüme bahçesine giden sürgülü kapı kilitli.",
		"orientation": "Zemindeki plaka ağırlıkla tetiklenir; karşıdaki mekanizma sürgüyü yakalar.",
		"explicit": "Ağır taşı plakada bırak. Kapı ağırlık durdukça açık; geçtiğinde hatırlar."
	},
	&"decay_greenhouse": {
		"goal": "Sera mührü iki el istiyor.",
		"orientation": "Camın ötesindeki gölge bir yanı tutuyor. Senin basman gereken bir plaka var.",
		"explicit": "Ortadaki plakaya bas. Uzaktaki el mührü bırakmaz."
	},
	&"decay_shilda_wall_broken": {
		"goal": "Çatlak duvar kılıçla inmez.",
		"orientation": "Gözler kızarınca atılır. Son anda kenara çekil; duvara çarpsın.",
		"explicit": "İki çarpma duvarı yıkar. Kovalamacada üç kez öldüysen tek çarpma yeter."
	},
	&"decay_archive_key": {
		"goal": "Arşiv kapısı mühürlü; kilitte bir çiçek motifi yer alıyor.",
		"orientation": "Bahçedeki kırmızı yaprakları incele ve Bekçi'nin güvenini kazan.",
		"explicit": "Bekçi ile barış içinde konuşup çiçeğin anısını günlüğüne kaydet; kilit açılır."
	},
	&"library_clockroom": {
		"goal": "İki saat iki geceyi tutuyor.",
		"orientation": "Önce 1927, sonra 1995. Cep saatin aynı geceyi bilir.",
		"explicit": "Soldaki saati dinle, sonra sağdakini. Sayfa kapısı açılır."
	},
	&"library_page_order": {
		"goal": "Dağılmış arşiv sayfaları doğru kronolojiye dizilmeli.",
		"orientation": "Tanıkları hatırla: önce deney, sonra kapı, en son mühür.",
		"explicit": "İlk deney başlangıcından mühürlerin kapandığı felaket gününe kadar olayları sırala."
	},
	&"mirrors_gallery": {
		"goal": "Camlar ölü bedenlerini tutuyor.",
		"orientation": "Duvar, hatırladığından fazla ceset sayar.",
		"explicit": "Ortadaki duvarı dinle. Sayıyı kabul edince kırılmayan ayna açılır."
	},
	&"mirrors_dual": {
		"goal": "İkiz aynaların arkasındaki geçit eşzamanlı rezonans istiyor.",
		"orientation": "Aynadaki yansıma seninle zıt yönde hareket eder; iki kristali aynı anda tetikle.",
		"explicit": "Gölge Atılması ile mesafeyi hızla kapatıp iki tarafın enerjisini dengele."
	},
	&"core_ascent": {
		"goal": "Son merdiven iki yetenek ve bir yankı istiyor.",
		"orientation": "Önce yankının durduğu basamak. Sonra Ruh Kesimi ve Gölge Atılması.",
		"explicit": "İkisi de açıkken son basamağa dokun. Gölge mührü tutar. Gidelim."
	},
	&"core_seal": {
		"goal": "Çekirdeğin ana mührü kırılmalı ve boyut kapısı aralanmalı.",
		"orientation": "Her iki mühür parçası birleşmeden çekirdek savunması gevşemez.",
		"explicit": "Bekçi ile birlikte çekirdeğin merkezine yaklaş ve Ruh Kesimi ile bağı kopar."
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
		"goal": "Yasak kanada giden tahta inmiş değil.",
		"orientation": "Arşivci üç kitabın adını sırayla söyledi.",
		"explicit": "Ses, mühür, çiçek. Bu sıra tahtayı indirir."
	},
	&"mirrors_labyrinth_crossed": {
		"goal": "Uçurumun karşısı tavandaki aynada görünüyor.",
		"orientation": "Mavi yansıma gerçek taş. Soluk kırmızı olan yalan.",
		"explicit": "Kırmızı basamağa atlama. Mavi taşları izleyerek karşıya geç."
	},
	&"experiment_intake": {
		"goal": "Kabul masası 1995'i tutuyor.",
		"orientation": "Önce dosya, sonra askıdaki palto.",
		"explicit": "Denek 14'ün eşyası senin saatin. Paltoyu okuyunca devre açılır."
	},
	&"experiment_quarantine_done": {
		"goal": "Kırmızı sis canlıyı yer. Rapor sisin ötesinde, yüksek rafta.",
		"orientation": "Ölü beden laneti emer. Cesedini sisin ortasına bırak.",
		"explicit": "Bedeni bulutun içine koy, güvenli koridordan geç, rafa zıpla."
	}
}


## Oda -> sırayla bakılacak çözülmemiş bulmaca. Günlük ipucu bunu kullanır.
const ROOM_PUZZLES: Dictionary = {
	"awakening": [&"awakening_weight"],
	"awakening_passage": [&"awakening_memory_code"],
	"awakening_seal": [&"awakening_memory_code"],
	"decay_weight": [&"decay_weight_latch"],
	"decay_greenhouse": [&"decay_greenhouse"],
	"decay_shilda_wall": [&"decay_shilda_wall_broken"],
	"decay_garden": [&"decay_archive_key"],
	"library_clockroom": [&"library_clockroom"],
	"library_page": [&"library_page_order"],
	"library_upper_stacks": [&"library_shelf_order"],
	"experiment_intake": [&"experiment_intake"],
	"experiment_circuit": [&"experiment_circuit"],
	"experiment_quarantine": [&"experiment_quarantine_done"],
	"mirrors_dual": [&"mirrors_dual"],
	"mirrors_gallery": [&"mirrors_gallery"],
	"mirrors_labyrinth": [&"mirrors_labyrinth_crossed"],
	"core_bloom_garden": [&"core_bloom_order"],
	"core_memory_vault": [&"core_vault_order"],
	"core_ascent": [&"core_ascent"],
	"core": [&"core_seal"],
}


## Günlük açılınca kademe artar: 1 hedef, 2 yön, 3 açık cevap. Üçten sonra artmaz.
func journal_hint_for_active_room() -> Dictionary:
	var room := String(RoomManager.get_active_room_id())
	var list: Array = ROOM_PUZZLES.get(room, [])
	var pid := &""
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
