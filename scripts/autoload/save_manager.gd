extends Node
## Kayıt — player + world kalıcı; character de yazılır (checkpoint için).

const SAVE_PATH := "user://torimon_save.json"
const SAVE_VERSION := 4


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"player_progress_knowledge": GameState.player_progress_knowledge.duplicate(true),
		"world_memory_state": _serialize_world(GameState.world_memory_state),
		"character_current_life_knowledge": _serialize_life(GameState.character_current_life_knowledge),
		"hearts": GameState.hearts,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
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
	GameState.hearts = int(data.get("hearts", GameState.max_hearts))
	GameState.hearts_changed.emit(GameState.hearts, GameState.max_hearts)
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
		else:
			base[k] = w[k]
	if not base.has("traces"):
		base["traces"] = []
	if not base.has("flags"):
		base["flags"] = {}
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
