extends Node
## Kayıt — player + world kalıcı; character de yazılır (checkpoint için).

var SAVE_PATH: String = "user://qa/torimon_save.json" if OS.get_environment("TORIMON_TEST") == "1" else "user://torimon_save.json"
const SAVE_VERSION := 5
## Yalnız test: yazma hatasını taklit eder (Kaydet ve Çık hata diyaloğu).
var force_fail_for_test: bool = false

var _new_progress: Dictionary
var _new_world: Dictionary
var _new_life: Dictionary

func _ready() -> void:
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	_new_progress = GameState.player_progress_knowledge.duplicate(true)
	_new_world = GameState.world_memory_state.duplicate(true)
	_new_life = GameState.character_current_life_knowledge.duplicate(true)


func start_new_game() -> void:
	Engine.time_scale = 1.0
	# Explicit menu confirmation precedes this action; keep a backup.
	if has_save():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var prev_path := ProjectSettings.globalize_path(SAVE_PATH + ".prev")
	if FileAccess.file_exists(SAVE_PATH + ".prev"):
		DirAccess.remove_absolute(prev_path)
	DialogueManager.clear()
	UiGate.set_story(false)
	UiGate.set_journal(false)
	UiGate.set_seal(false)
	UiGate.set_ending(false)
	MobileInputManager.clear_held_inputs()
	GameState.player_progress_knowledge = _new_progress.duplicate(true)
	GameState.world_memory_state = _new_world.duplicate(true)
	GameState.character_current_life_knowledge = _new_life.duplicate(true)
	GameState.session_loaded_from_save = false
	GameState.hearts = GameState.max_hearts
	PuzzleManager.sync_from_world()
	EndingManager.reset_for_smoke()
	EchoManager.active_echo = &""
	DeathManager.is_dying = false
	DeathManager.phase = DeathManager.Phase.ALIVE
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	get_tree().reload_current_scene()



func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


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


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"player_progress_knowledge": GameState.player_progress_knowledge.duplicate(true),
		"world_memory_state": _serialize_world(GameState.world_memory_state),
		"character_current_life_knowledge": _serialize_life(GameState.character_current_life_knowledge),
		"hearts": GameState.hearts,
		"curse": CurseManager.curse if CurseManager else 0.0,
	}
	var temp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null or force_fail_for_test:
		push_warning("Kayıt yazılamadı: " + (str(FileAccess.get_open_error()) if f == null else "test"))
		return false
	f.store_string(JSON.stringify(data))
	f.close()

	var g_target := ProjectSettings.globalize_path(SAVE_PATH)
	var g_temp := ProjectSettings.globalize_path(temp_path)
	var g_bak := ProjectSettings.globalize_path(SAVE_PATH + ".bak")
	var g_prev := ProjectSettings.globalize_path(SAVE_PATH + ".prev")

	## Son sağlam kaydı yedekle: yazma yarıda kalırsa (pil/çökme) bir önceki yüklenir.
	if FileAccess.file_exists(SAVE_PATH) and _read_save(SAVE_PATH) != null:
		DirAccess.copy_absolute(g_target, g_prev)

	## Windows'ta hedef dosya varsa rename ERR_ALREADY_EXISTS (32) verir.
	## Bu yüzden mevcut dosyayı geçici olarak .bak'a taşıyoruz.
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_PATH + ".bak"):
			DirAccess.remove_absolute(g_bak)
		var bak_err := DirAccess.rename_absolute(g_target, g_bak)
		if bak_err != OK:
			DirAccess.copy_absolute(g_target, g_bak)
			DirAccess.remove_absolute(g_target)

	var error := DirAccess.rename_absolute(g_temp, g_target)
	if error != OK:
		push_warning("Kayıt tamamlanamadı: " + str(error))
		## Geri alma: geçici dosya taşınamadıysa .bak'ı geri yükle
		if FileAccess.file_exists(SAVE_PATH + ".bak"):
			DirAccess.rename_absolute(g_bak, g_target)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(g_temp)
		return false

	## Doğrula: yazılan dosya geri okunabiliyor mu
	var verify: Variant = _read_save(SAVE_PATH)
	if verify == null:
		push_warning("Kayıt doğrulanamadı — geri alınıyor")
		if FileAccess.file_exists(SAVE_PATH + ".bak"):
			DirAccess.remove_absolute(g_target)
			DirAccess.rename_absolute(g_bak, g_target)
		return false

	## Başarılı doğrulama sonrası geçici .bak yedeğini temizle
	if FileAccess.file_exists(SAVE_PATH + ".bak"):
		DirAccess.remove_absolute(g_bak)

	return true


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


func load_game(apply_room: bool = true) -> bool:
	var parsed: Variant = _read_save(SAVE_PATH)
	if parsed == null:
		## Ana kayıt bozuksa veya rotasyon sırasında kesildiyse .bak ya da .prev dene.
		if FileAccess.file_exists(SAVE_PATH + ".bak"):
			parsed = _read_save(SAVE_PATH + ".bak")
		if parsed == null:
			parsed = _read_save(SAVE_PATH + ".prev")
			if parsed == null:
				return false
		push_warning("Kayıt bozuk — önceki yedek yüklendi")
	var data: Dictionary = parsed
	GameState.player_progress_knowledge = data.get("player_progress_knowledge", GameState.player_progress_knowledge)
	GameState.world_memory_state = _deserialize_world(data.get("world_memory_state", {}))
	GameState.character_current_life_knowledge = _deserialize_life(data.get("character_current_life_knowledge", {}))
	GameState.session_loaded_from_save = true
	var ver := int(data.get("version", 0))
	if ver > 0 and ver < SAVE_VERSION:
		if ver < 5:
			_migrate_to_v5_puzzles()
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
