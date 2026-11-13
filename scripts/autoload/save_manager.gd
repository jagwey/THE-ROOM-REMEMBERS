extends Node
## Kayıt — iki dosya: COMMITTED (SAVE_PATH; yalnız commit_save: mühür, Kaydet ve Çık, yeni oyun, final)
## ve RESUME (SAVE_PATH + "_resume.json"; save_game / save_resume_point; çıkışta ilerleme kaybolmasın).
## Devam Et ikisinden save_serial'ı büyük olanı yükler; lanet yeniden yüklemesi yalnız committed'ı yükler.

var SAVE_PATH: String = "user://qa/torimon_save.json" if OS.get_environment("TORIMON_TEST") == "1" else "user://torimon_save.json"
const SAVE_VERSION := 6
## Yalnız test: yazma hatasını taklit eder (Kaydet ve Çık hata diyaloğu).
var force_fail_for_test: bool = false

## Her yazımda artan sayaç; iki dosyada da "save_serial" olarak durur.
var _save_serial: int = 0
## start_new_game -> sahne yeniden yüklenince main.gd "Devam" yerine taze girişi (uzun göz, açılış diyaloğu) oynar.
var fresh_start_pending: bool = false
var _fell_back: bool = false

var _new_progress: Dictionary
var _new_world: Dictionary
var _new_life: Dictionary

func _ready() -> void:
	DeathManager.release_time_scale()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	_new_progress = GameState.player_progress_knowledge.duplicate(true)
	_new_world = GameState.world_memory_state.duplicate(true)
	_new_life = GameState.character_current_life_knowledge.duplicate(true)
	_save_serial = maxi(_serial_of(_read_with_fallback(SAVE_PATH)), _serial_of(_read_with_fallback(resume_path())))


func resume_path() -> String:
	return SAVE_PATH.get_basename() + "_resume.json"


func start_new_game() -> void:
	DeathManager.release_time_scale()
	# Explicit menu confirmation precedes this action. Eski committed kayıt, yenisi yazılana kadar
	# silinmez (BUG-030): commit_save başarısızsa eski iyi kayıt diskte kalır.
	_delete_resume_files()
	DialogueManager.clear()
	UiGate.set_story(false)
	UiGate.set_journal(false)
	UiGate.set_seal(false)
	UiGate.set_ending(false)
	MobileInputManager.clear_held_inputs()
	GameState.player_progress_knowledge = _new_progress.duplicate(true)
	GameState.world_memory_state = _new_world.duplicate(true)
	GameState.character_current_life_knowledge = _new_life.duplicate(true)
	GameState.clear_story_flags()
	GameState.reset_discovered_seals()
	GameState.possession_count = 0
	GameState.session_loaded_from_save = false
	GameState.hearts = GameState.max_hearts
	PuzzleManager.sync_from_world()
	EndingManager.reset_for_smoke()
	EchoManager.active_echo = &""
	DeathManager.reset_state()
	UiGate.set_cutscene(false)
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	if commit_save(&"new_game", GameState.DEFAULT_CHECKPOINT, &"awakening"):
		## Başarılı yeni oyun: eski oyunun .prev/.bak kopyaları yeni oyunu ezmesin.
		for suffix in [".prev", ".bak"]:
			if FileAccess.file_exists(SAVE_PATH + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	else:
		push_warning("Yeni oyun kaydı yazılamadı — eski kayıt korundu")
	fresh_start_pending = true
	get_tree().reload_current_scene()



func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(resume_path())


## Kaydet ve Çık / arka plan: oyuncunun tam konumunu "resume" olarak yazar ve kaydeder.
## Devam et bu konumdan başlar; ölüm yine yatak (checkpoint) noktasına döner. true = kayıt doğrulandı.
func save_resume_point() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var room := RoomManager.get_active_room_id()
	if player and room != &"" and not DeathManager.is_dying:
		GameState.character_current_life_knowledge["resume"] = {
			"room": String(room), "x": player.global_position.x, "y": player.global_position.y,
		}
	return save_game()


## Devam et: geçerli resume noktası (oda eşleşmeli). Tek kullanımlık — tüketilince silinir.
func take_resume_point(room_id: StringName) -> Variant:
	var r: Variant = GameState.character_current_life_knowledge.get("resume", null)
	GameState.character_current_life_knowledge.erase("resume")
	if typeof(r) != TYPE_DICTIONARY or StringName(str(r.get("room", ""))) != room_id:
		return null
	return Vector2(float(r.get("x", 0.0)), float(r.get("y", 0.0)))


## Resume noktası: mevcut tam durumu ayrı dosyaya yazar (oda girişi, hikâye, bulmaca, uygulama kapanışı).
## Committed kaydı DEĞİŞTİRMEZ; lanet geri yüklemesi o kayda döner.
func save_game() -> bool:
	return _write_atomic(resume_path(), _build_data())


## Committed kayıt: Memory Seal, Kaydet ve Çık, yeni oyun, final. Güvenli konum (mühür/yatak) saklanır,
## oyuncunun ham konumu değil. safe_room boşsa mevcut checkpoint odası kullanılır.
## Kaydet ve Çık: önce commit_save, sonra save_resume_point (resume daha yeni serial alır, tam konumdan devam).
func commit_save(reason: StringName = &"commit", safe_position: Vector2 = Vector2.INF, safe_room: StringName = &"") -> bool:
	var pos := safe_position if safe_position.is_finite() else GameState.get_checkpoint()
	var room := safe_room
	if room == &"":
		room = StringName(str(GameState.character_current_life_knowledge.get("checkpoint_room", &"awakening")))
	var data := _build_data()
	data["commit_reason"] = String(reason)
	var life: Dictionary = data["character_current_life_knowledge"]
	life.erase("resume")
	life["checkpoint"] = {"x": pos.x, "y": pos.y}
	life["checkpoint_room"] = String(room)
	life["room"] = String(room)
	life["spawn_id"] = "checkpoint"
	return _write_atomic(SAVE_PATH, data)


func _build_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_progress_knowledge": GameState.player_progress_knowledge.duplicate(true),
		"world_memory_state": _serialize_world(GameState.world_memory_state),
		"character_current_life_knowledge": _serialize_life(GameState.character_current_life_knowledge),
		"story_flags": _serialize_story_flags(GameState.story_flags),
		"discovered_seals": _serialize_seals(GameState.discovered_seals),
		"possession_count": GameState.possession_count,
		"hearts": GameState.hearts,
		"curse": CurseManager.curse if CurseManager else 0.0,
	}


func _write_atomic(path: String, data: Dictionary) -> bool:
	_save_serial += 1
	data["save_serial"] = _save_serial
	var temp_path := path + ".tmp"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null or force_fail_for_test:
		push_warning("Kayıt yazılamadı: " + (str(FileAccess.get_open_error()) if f == null else "test"))
		return false
	var stored: Variant = f.store_string(JSON.stringify(data))
	var write_err := f.get_error()
	f.close()
	## Yazma sonucu denetlenir (disk dolu / G-Ç hatası): geçici dosya doğrulanmadan hedefe dokunulmaz.
	if (stored is bool and not stored) or write_err != OK or not _temp_matches(temp_path, int(data["save_serial"])):
		push_warning("Kayıt geçici dosyaya yazılamadı/doğrulanamadı — eski kayıt korundu")
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false

	var g_target := ProjectSettings.globalize_path(path)
	var g_temp := ProjectSettings.globalize_path(temp_path)
	var g_bak := ProjectSettings.globalize_path(path + ".bak")
	var g_prev := ProjectSettings.globalize_path(path + ".prev")

	## Son sağlam kaydı yedekle: yazma yarıda kalırsa (pil/çökme) bir önceki yüklenir.
	if FileAccess.file_exists(path) and _read_save(path) != null:
		DirAccess.copy_absolute(g_target, g_prev)

	## Windows'ta hedef dosya varsa rename ERR_ALREADY_EXISTS (32) verir.
	## Bu yüzden mevcut dosyayı geçici olarak .bak'a taşıyoruz.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(g_bak)
		var bak_err := DirAccess.rename_absolute(g_target, g_bak)
		if bak_err != OK:
			DirAccess.copy_absolute(g_target, g_bak)
			DirAccess.remove_absolute(g_target)

	var error := DirAccess.rename_absolute(g_temp, g_target)
	if error != OK:
		push_warning("Kayıt tamamlanamadı: " + str(error))
		## Geri alma: geçici dosya taşınamadıysa .bak'ı geri yükle
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(g_bak, g_target)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(g_temp)
		return false

	## Doğrula: yazılan dosya geri okunabiliyor mu
	var verify: Variant = _read_save(path)
	if verify == null:
		push_warning("Kayıt doğrulanamadı — geri alınıyor")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(g_target)
			DirAccess.rename_absolute(g_bak, g_target)
		return false

	## Başarılı doğrulama sonrası geçici .bak yedeğini temizle
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(g_bak)

	return true


## Geçici dosya geri okunur ve beklenen save_serial'ı taşıyorsa true.
func _temp_matches(temp_path: String, serial: int) -> bool:
	var parsed: Variant = _read_save(temp_path)
	return parsed is Dictionary and _serial_of(parsed) == serial


## Test/temizlik: committed + resume ve hepsinin .prev/.bak/.tmp dosyaları.
func delete_all_save_files() -> void:
	for base in [SAVE_PATH, resume_path()]:
		for suffix in ["", ".bak", ".prev", ".tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))


func consume_fresh_start() -> bool:
	var v := fresh_start_pending
	fresh_start_pending = false
	return v


## Ana Menüye Dön: kaydedilmemiş ilerleme (resume) atılır; Devam Et committed kaydı yükler.
func discard_resume() -> void:
	_delete_resume_files()
	GameState.character_current_life_knowledge.erase("resume")


func _delete_resume_files() -> void:
	var rp := resume_path()
	for suffix in ["", ".bak", ".prev", ".tmp"]:
		if FileAccess.file_exists(rp + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(rp + suffix))


func _serial_of(data: Variant) -> int:
	return _int_of((data as Dictionary).get("save_serial", 0)) if data is Dictionary else 0


## Elle düzenlenmiş/bozuk kayıtta beklenmeyen tip (dizi, sözlük, null) çökme yerine varsayılana düşer.
func _int_of(v: Variant, fallback: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_BOOL:
			return int(v)
		TYPE_FLOAT:
			return int(v) if is_finite(v) else fallback
		TYPE_STRING:
			return int(float(v)) if (v as String).is_valid_float() else fallback
	return fallback


func _float_of(v: Variant, fallback: float = 0.0) -> float:
	match typeof(v):
		TYPE_INT, TYPE_BOOL:
			return float(v)
		TYPE_FLOAT:
			return v if is_finite(v) else fallback
		TYPE_STRING:
			return float(v) if (v as String).is_valid_float() else fallback
	return fallback


## d[key] varsa ve beklenen kapsayıcı tipinde değilse boş kapsayıcıyla değiştirir.
func _coerce_container(d: Dictionary, key: String, want_array: bool) -> void:
	if not d.has(key):
		return
	if want_array and not d[key] is Array:
		d[key] = []
	elif not want_array and not d[key] is Dictionary:
		d[key] = {}


## Ana dosya bozuksa .bak, sonra .prev denenir. Hiçbiri yoksa null.
func _read_with_fallback(path: String) -> Variant:
	var parsed: Variant = _read_save(path)
	if parsed != null:
		return parsed
	if not (FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".prev")):
		return null
	parsed = _read_save(path + ".bak")
	if parsed == null:
		parsed = _read_save(path + ".prev")
	if parsed != null:
		_fell_back = true
	return parsed


## Okunamayan/bozuk dosyada null döner.
func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("player_progress_knowledge"):
		return null
	return parsed


## Devam Et: committed ve resume'dan save_serial'ı büyük olan (eşitse committed).
func load_game(apply_room: bool = true) -> bool:
	_fell_back = false
	var committed: Variant = _read_with_fallback(SAVE_PATH)
	var resume: Variant = _read_with_fallback(resume_path())
	var parsed: Variant = committed
	if resume != null and (committed == null or _serial_of(resume) > _serial_of(committed)):
		parsed = resume
	if parsed == null:
		return false
	_warn_if_fell_back()
	return _apply_data(parsed, apply_room)


## Lanet geri yüklemesi: yalnız committed kaydı yükler; resume dosyası silinir (Devam Et eski durumu diriltmesin).
func load_committed(apply_room: bool = true) -> bool:
	_fell_back = false
	var parsed: Variant = _read_with_fallback(SAVE_PATH)
	if parsed == null:
		return false
	_warn_if_fell_back()
	_delete_resume_files()
	return _apply_data(parsed, apply_room)


func _warn_if_fell_back() -> void:
	if _fell_back:
		push_warning("Kayıt bozuk — önceki yedek yüklendi")
		_fell_back = false


func _apply_data(data: Dictionary, apply_room: bool) -> bool:
	GameState.player_progress_knowledge = _deserialize_progress(data.get("player_progress_knowledge", null))
	GameState.world_memory_state = _deserialize_world(data.get("world_memory_state", {}))
	GameState.character_current_life_knowledge = _deserialize_life(data.get("character_current_life_knowledge", {}))
	GameState.session_loaded_from_save = true
	GameState.story_flags = _deserialize_story_flags(data.get("story_flags", {}))
	GameState.discovered_seals = _deserialize_seals(data.get("discovered_seals", null))
	## Sayaç yalnız artar: load_committed (lanet geri yüklemesi) eski dosyadaki düşük değerle sıfırlamasın.
	GameState.possession_count = maxi(GameState.possession_count, _int_of(data.get("possession_count", 0)))
	var ver := _int_of(data.get("version", 0))
	if ver > 0 and ver < SAVE_VERSION:
		if ver < 5:
			_migrate_to_v5_puzzles()
		if ver < 6:
			_migrate_to_v6_story_flags()
	elif ver > SAVE_VERSION:
		push_warning("Save version newer than game (%d > %d) — loading best-effort" % [ver, SAVE_VERSION])
	GameState.hearts = clampi(_int_of(data.get("hearts", GameState.max_hearts), GameState.max_hearts), 1, GameState.max_hearts)
	GameState.hearts_changed.emit(GameState.hearts, GameState.max_hearts)
	if data.has("curse") and CurseManager:
		CurseManager.restore_curse(_float_of(data.get("curse", 0.0)))
	_migrate_soul_slash_for_late_rooms()
	_migrate_shelf_order_for_late_rooms()
	_migrate_side_room_puzzles_for_late_rooms()
	PuzzleManager.sync_from_world()
	if apply_room:
		CorpseManager.rebuild_world_corpses()
	GameState.knowledge_changed.emit(&"world")
	return true


## Faz 3 göçü: Ruh Kesimi artık deney hücrelerinden önce verilir. Eski kayıt library_forbidden_wing'den
## sonraki bir odadaysa ve yetenek yoksa ver (yoksa kilitlenirdi).
func _migrate_soul_slash_for_late_rooms() -> void:
	if bool(GameState.player_progress_knowledge.get("ability_soul_slash", false)):
		return
	var life := GameState.character_current_life_knowledge
	var room_id := str(life.get("room", life.get("checkpoint_room", "")))
	var order: PackedStringArray = RoomManager.ROOM_ORDER
	var idx := order.find(room_id)
	if idx > order.find("library_forbidden_wing"):
		GameState.player_progress_knowledge["ability_soul_slash"] = true


## Faz 3 göçü: Yasak Kanat kapısı artık library_shelf_order ister (eskiden library_page_order). Eski kayıt
## üst raflardan sonraki bir odadaysa ve raf sırası kayıtlı değilse çözülmüş say (yoksa geri dönüşte kapı kilitli kalırdı).
func _migrate_shelf_order_for_late_rooms() -> void:
	var puzzles: Variant = GameState.world_memory_state.get("puzzles", null)
	if not (puzzles is Dictionary) or bool((puzzles as Dictionary).get("library_shelf_order", false)):
		return
	var life := GameState.character_current_life_knowledge
	var room_id := str(life.get("room", life.get("checkpoint_room", "")))
	var idx := RoomManager.ROOM_ORDER.find(room_id)
	if idx > RoomManager.ROOM_ORDER.find("library_upper_stacks"):
		(puzzles as Dictionary)["library_shelf_order"] = true


## Faz 3 göçü (v1.16 kayıtları): Yasak Kanat, Okuma Hücresi, Karantina, Ruh Damarları ve Gözlem Camı
## eskiden çıkmaz yan odaydı; artık ana yolda ve ileri kapıları kilitli. Kayıt bu odaların ilerisindeyse
## kapı bulmacalarını çözülmüş say (geri dönüşte kapı kilitli kalmasın). Yalnız eksikleri ekler (idempotent).
const _LATE_ROOM_SOLVED: Array = [
	["library_forbidden_wing", ["soul_seal_forbidden", "soul_seal_forbidden_2"]],
	["library_reading_cell", ["library_reading_cabin", "library_reading_cell"]],
	["experiment_cells", ["experiment_cell_a", "experiment_cell_b", "experiment_cell_c"]],
	["experiment_quarantine", ["experiment_quarantine_done"]],
	["experiment_core_conduit", ["experiment_vein_1", "experiment_vein_2", "experiment_vein_3", "experiment_conduit"]],
	["experiment_observation", ["experiment_observation_projector", "experiment_observation"]],
]


func _migrate_side_room_puzzles_for_late_rooms() -> void:
	var puzzles: Variant = GameState.world_memory_state.get("puzzles", null)
	if not (puzzles is Dictionary):
		return
	var life := GameState.character_current_life_knowledge
	var room_id := str(life.get("room", life.get("checkpoint_room", "")))
	var here := RoomManager.ROOM_ORDER.find(room_id)
	if here < 0:
		return
	for entry in _LATE_ROOM_SOLVED:
		if here > RoomManager.ROOM_ORDER.find(String(entry[0])):
			for id in entry[1]:
				(puzzles as Dictionary)[String(id)] = true


func _serialize_seals(seals: Array[StringName]) -> Array:
	var out: Array = []
	for id in seals:
		out.append(String(id))
	return out


## Eksik/bozuk alan: yalnız Uyanış mührü açık. Uyanış mührü her zaman listede.
func _deserialize_seals(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = [&"awakening"]
	if raw is Array:
		for v in raw:
			var id := StringName(String(v))
			if id != &"" and not out.has(id):
				out.append(id)
	return out


func _serialize_story_flags(flags: Dictionary) -> Dictionary:
	var out := {}
	for k in flags.keys():
		out[String(k)] = bool(flags[k])
	return out


func _deserialize_story_flags(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in (raw as Dictionary).keys():
		out[StringName(str(k))] = bool(raw[k])
	return out


## Varsayılan ilerleme + dosyadaki değerler; bozuk tipli kapsayıcılar boşaltılır (BUG-011).
func _deserialize_progress(raw: Variant) -> Dictionary:
	var base: Dictionary = _new_progress.duplicate(true)
	if typeof(raw) == TYPE_DICTIONARY:
		for k in (raw as Dictionary).keys():
			base[k] = raw[k]
	for key in ["rooms_visited", "journal_notes", "echoes_seen", "endings_seen", "lore_seen"]:
		_coerce_container(base, key, true)
	for key in ["memory_codes", "memory_code_life", "shilda_trust"]:
		_coerce_container(base, key, false)
	return base


func _serialize_world(w: Dictionary) -> Dictionary:
	return w.duplicate(true)


func _deserialize_world(raw: Variant) -> Dictionary:
	var base: Dictionary = GameState.world_memory_state.duplicate(true)
	if typeof(raw) != TYPE_DICTIONARY:
		return base
	var w: Dictionary = raw
	for k in w.keys():
		if k == "flags":
			if w["flags"] is Dictionary:
				var flags: Dictionary = base.get("flags", {})
				flags.merge(w["flags"], true)
				base["flags"] = flags
		elif k == "puzzles":
			if w["puzzles"] is Dictionary:
				var pz: Dictionary = base.get("puzzles", {})
				if not pz is Dictionary:
					pz = {}
				for pk in w["puzzles"].keys():
					pz[String(pk)] = w["puzzles"][pk]
				base["puzzles"] = pz
		else:
			base[k] = w[k]
	if not base.has("traces"):
		base["traces"] = []
	if not base.has("flags"):
		base["flags"] = {}
	if not base.has("puzzles"):
		base["puzzles"] = {}
	## Tip korumaları (BUG-012): bozuk alanlar çökme yerine güvenli varsayılana düşer.
	for key in ["corpses", "traces", "echo_sites", "forbidden_touched"]:
		_coerce_container(base, key, true)
	_coerce_container(base, "flags", false)
	_coerce_container(base, "puzzles", false)
	var clean_corpses: Array = []
	for c in base["corpses"]:
		if c is Dictionary:
			clean_corpses.append(c)
	base["corpses"] = clean_corpses
	base["flowers_left"] = _int_of(base.get("flowers_left", 0))
	return base


func _serialize_life(life: Dictionary) -> Dictionary:
	var out := life.duplicate(true)
	var cp: Variant = out.get("checkpoint", GameState.DEFAULT_CHECKPOINT)
	if cp is Vector2:
		out["checkpoint"] = {"x": cp.x, "y": cp.y}
	out["curse"] = CurseManager.curse
	out["curse_visible"] = CurseManager.visible_meter
	return out


func _deserialize_life(raw: Variant) -> Dictionary:
	var base: Dictionary = {
		"room": &"awakening",
		"checkpoint": GameState.DEFAULT_CHECKPOINT,
		"checkpoint_room": &"awakening",
		"spawn_id": &"default",
		"interacted": [],
		"dialogue_flags": {},
		"warned_hazard": false,
		"flower_in_hand": false,
	}
	if typeof(raw) != TYPE_DICTIONARY:
		return base
	var life: Dictionary = raw
	for k in life.keys():
		base[k] = life[k]
	_coerce_container(base, "interacted", true)
	_coerce_container(base, "dialogue_flags", false)
	var cp: Variant = base.get("checkpoint", GameState.DEFAULT_CHECKPOINT)
	if cp is Dictionary:
		base["checkpoint"] = Vector2(_float_of(cp.get("x", 120), 120.0), _float_of(cp.get("y", 280), 280.0))
	elif not (cp is Vector2):
		base["checkpoint"] = GameState.DEFAULT_CHECKPOINT
	if life.has("curse"):
		CurseManager.curse = _float_of(life["curse"])
	if life.has("curse_visible"):
		CurseManager.visible_meter = life["curse_visible"] is bool and life["curse_visible"]
	return base


func _migrate_to_v5_puzzles() -> void:
	var pz: Dictionary = GameState.world_memory_state.get("puzzles", {})
	if not pz is Dictionary:
		pz = {}
		GameState.world_memory_state["puzzles"] = pz
	if bool(GameState.get_world_flag(&"awakening_door_opened", false)):
		pz["awakening_weight"] = true
	if bool(GameState.get_world_flag(&"awakening_crystal_cracked", false)):
		pz["awakening_memory_code"] = true


## v6: hikâye bayrakları eski durumdan en iyi çabayla türetilir; kaynak yoksa bayrak kurulmaz.
func _migrate_to_v6_story_flags() -> void:
	var pk: Dictionary = GameState.player_progress_knowledge
	var visited: Array = pk.get("rooms_visited", [])
	var corpses: Variant = GameState.world_memory_state.get("corpses", [])
	if GameState.is_shilda_named():
		_derive_flag(&"shilda_name_known")
	if int(pk.get("deaths", 0)) > 0 or (corpses is Array and not (corpses as Array).is_empty()):
		_derive_flag(&"first_death_completed")
	if visited.has("core_threshold"):
		_derive_flag(&"core_access_granted")
	var pz: Variant = GameState.world_memory_state.get("puzzles", {})
	if pz is Dictionary and (bool(pz.get("awakening_weight", false)) or bool(pz.get("awakening_memory_code", false))):
		_derive_flag(&"intro_completed")
	## Uyanış ve Kırık Geçit'in ötesine geçmiş eski kayıt: giriş + gölge/uyarı sahneleri yaşanmış sayılır.
	var past_start := false
	for rid in visited:
		if String(rid) != "awakening" and String(rid) != "awakening_passage":
			past_start = true
	if past_start or bool(pk.get("awakening_mystery_seen", false)) or bool(pk.get("pocket_watch_seen", false)):
		_derive_flag(&"intro_completed")
	if past_start:
		_derive_flag(&"first_shadow_seen")
		_derive_flag(&"first_warning_heard")
	if bool(pk.get("first_corpse_line_seen", false)):
		_derive_flag(&"first_corpse_discovered")
	var seen: Array = pk.get("lore_seen", [])
	if seen.has("crypt_ledger"):
		_derive_flag(&"dimension_origin_discovered")
	## Shilda'nın "hatırlamayı seçtim" itirafı experiment_authority sahnesinde yaşanır (crypt_ledger tek başına yetmez).
	if pz is Dictionary and bool(pz.get("experiment_authority", false)):
		_derive_flag(&"shilda_past_discovered")


func _derive_flag(id: StringName) -> void:
	if not GameState.story_flags.has(id):
		GameState.story_flags[id] = true
