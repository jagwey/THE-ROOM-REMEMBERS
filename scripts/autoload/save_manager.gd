extends Node
## Kayıt stub — world + player katmanları.

const SAVE_PATH := "user://torimon_save.json"


func save_game() -> void:
	var data := {
		"player_progress_knowledge": GameState.player_progress_knowledge,
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
	GameState.world_memory_state = data.get("world_memory_state", GameState.world_memory_state)
	GameState.character_current_life_knowledge = data.get("character_current_life_knowledge", GameState.character_current_life_knowledge)
	GameState.hearts = int(data.get("hearts", GameState.max_hearts))
	GameState.hearts_changed.emit(GameState.hearts, GameState.max_hearts)
	return true


func _serialize_world(w: Dictionary) -> Dictionary:
	return w.duplicate(true)


func _serialize_life(life: Dictionary) -> Dictionary:
	var out := life.duplicate(true)
	var cp: Variant = out.get("checkpoint", Vector2.ZERO)
	if cp is Vector2:
		out["checkpoint"] = {"x": cp.x, "y": cp.y}
	return out
