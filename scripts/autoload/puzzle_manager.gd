extends Node
## Bulmaca durumu — world_memory_state.puzzles + bayrak migrasyonu.

signal puzzle_solved(puzzle_id: StringName)

var solved: Dictionary = {}


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
		_:
			pass
	puzzle_solved.emit(puzzle_id)


func is_solved(puzzle_id: StringName) -> bool:
	return bool(solved.get(String(puzzle_id), false))
