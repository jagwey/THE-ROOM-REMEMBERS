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
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	_new_progress = GameState.player_progress_knowledge.duplicate(true)
	_new_world = GameState.world_memory_state.duplicate(true)
	_new_life = GameState.character_current_life_knowledge.duplicate(true)
	_save_serial = maxi(_serial_of(_read_with_fallback(SAVE_PATH)), _serial_of(_read_with_fallback(resume_path())))


func resume_path() -> String:
	return SAVE_PATH.get_basename() + "_resume.json"


func start_new_game() -> void:
	Engine.time_scale = 1.0
	# Explicit menu confirmation precedes this action; keep a backup.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var prev_path := ProjectSettings.globalize_path(SAVE_PATH + ".prev")
	if FileAccess.file_exists(SAVE_PATH + ".prev"):
		DirAccess.remove_absolute(prev_path)
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
	GameState.session_loaded_from_save = false
	GameState.hearts = GameState.max_hearts
	PuzzleManager.sync_from_world()
	EndingManager.reset_for_smoke()
	EchoManager.active_echo = &""
	DeathManager.is_dying = false
	DeathManager.phase = DeathManager.Phase.ALIVE
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	commit_save(&"new_game", GameState.DEFAULT_CHECKPOINT, &"awakening")
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
	f.store_string(JSON.stringify(data))
	f.close()

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


func _delete_resume_files() -> void:
	var rp := resume_path()
	for suffix in ["", ".bak", ".prev", ".tmp"]:
		if FileAccess.file_exists(rp + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(rp + suffix))


func _serial_of(data: Variant) -> int:
	return int((data as Dictionary).get("save_serial", 0)) if data is Dictionary else 0


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
	GameState.player_progress_knowledge = data.get("player_progress_knowledge", GameState.player_progress_knowledge)
	GameState.world_memory_state = _deserialize_world(data.get("world_memory_state", {}))
	GameState.character_current_life_knowledge = _deserialize_life(data.get("character_current_life_knowledge", {}))
	GameState.session_loaded_from_save = true
	GameState.story_flags = _deserialize_story_flags(data.get("story_flags", {}))
	GameState.discovered_seals = _deserialize_seals(data.get("discovered_seals", null))
	var ver := int(data.get("version", 0))
	if ver > 0 and ver < SAVE_VERSION:
		if ver < 5:
			_migrate_to_v5_puzzles()
		if ver < 6:
			_migrate_to_v6_story_flags()
	elif ver > SAVE_VERSION:
		push_warning("Save version newer than game (%d > %d) — loading best-effort" % [ver, SAVE_VERSION])
	GameState.hearts = clampi(int(data.get("hearts", GameState.max_hearts)), 1, GameState.max_hearts)
	GameState.hearts_changed.emit(GameState.hearts, GameState.max_hearts)
	if data.has("curse") and CurseManager:
		CurseManager.curse = float(data.get("curse", 0.0))
		CurseManager.curse_changed.emit(CurseManager.curse)
	PuzzleManager.sync_from_world()
	if apply_room:
		CorpseManager.rebuild_world_corpses()
	GameState.knowledge_changed.emit(&"world")
	return true


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


func _serialize_world(w: Dictionary) -> Dictionary:
	return w.duplicate(true)


func _deserialize_world(raw: Variant) -> Dictionary:
	var base: Dictionary = GameState.world_memory_state.duplicate(true)
	if typeof(raw) != TYPE_DICTIONARY:
		return base
	var w: Dictionary = raw
	for k in w.keys():
		if k == "flags" and w["flags"] is Dictionary:
			var flags: Dictionary = base.get("flags", {})
			flags.merge(w["flags"], true)
			base["flags"] = flags
		elif k == "puzzles" and w["puzzles"] is Dictionary:
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
	}
	if typeof(raw) != TYPE_DICTIONARY:
		return base
	var life: Dictionary = raw
	for k in life.keys():
		base[k] = life[k]
	var cp: Variant = base.get("checkpoint", GameState.DEFAULT_CHECKPOINT)
	if cp is Dictionary:
		base["checkpoint"] = Vector2(float(cp.get("x", 120)), float(cp.get("y", 280)))
	elif not (cp is Vector2):
		base["checkpoint"] = GameState.DEFAULT_CHECKPOINT
	if life.has("curse"):
		CurseManager.curse = float(life["curse"])
	if life.has("curse_visible"):
		CurseManager.visible_meter = bool(life["curse_visible"])
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
	if bool(pk.get("first_corpse_line_seen", false)):
		_derive_flag(&"first_corpse_discovered")
	var seen: Array = pk.get("lore_seen", [])
	if seen.has("crypt_ledger"):
		_derive_flag(&"dimension_origin_discovered")
		_derive_flag(&"shilda_past_discovered")


func _derive_flag(id: StringName) -> void:
	if not GameState.story_flags.has(id):
		GameState.story_flags[id] = true
