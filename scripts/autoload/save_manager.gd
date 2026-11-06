extends Node
## Kayıt — player + world kalıcı; character de yazılır (checkpoint için).

var SAVE_PATH: String = "user://qa/torimon_save.json" if OS.get_environment("TORIMON_TEST") == "1" else "user://torimon_save.json"
const SAVE_VERSION := 5

var _new_progress: Dictionary
var _new_world: Dictionary
var _new_life: Dictionary

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	_new_progress = GameState.player_progress_knowledge.duplicate(true)
	_new_world = GameState.world_memory_state.duplicate(true)
	_new_life = GameState.character_current_life_knowledge.duplicate(true)


func start_new_game() -> void:
	# Explicit menu confirmation precedes this action; keep a backup.
	if has_save():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
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
	CurseManager.reset_for_new_life()
	RoomManager.reset_registry()
	get_tree().reload_current_scene()



func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"player_progress_knowledge": GameState.player_progress_knowledge.duplicate(true),
		"world_memory_state": _serialize_world(GameState.world_memory_state),
		"character_current_life_knowledge": _serialize_life(GameState.character_current_life_knowledge),
		"hearts": GameState.hearts,
	}
	var temp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_warning("Kayıt yazılamadı: " + str(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		push_warning("Kayıt tamamlanamadı: " + str(error))


func load_game(apply_room: bool = true) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
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
