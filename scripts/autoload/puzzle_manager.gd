extends Node
## Bulmaca durumu — world_memory_state.flags ile kalıcı.

signal puzzle_solved(puzzle_id: StringName)

var solved: Dictionary = {}


func _ready() -> void:
	# Kayıttan bayrakları yükle
	if bool(GameState.get_world_flag(&"awakening_door_opened", false)):
		solved["awakening_weight"] = true
	if bool(GameState.get_world_flag(&"awakening_crystal_cracked", false)):
		solved["awakening_memory_code"] = true


func mark_solved(puzzle_id: StringName) -> void:
	var key := String(puzzle_id)
	if solved.get(key, false):
		return
	solved[key] = true
	match puzzle_id:
		&"awakening_weight":
			GameState.set_world_flag(&"awakening_door_opened", true)
		&"awakening_memory_code":
			GameState.set_world_flag(&"awakening_crystal_cracked", true)
		_:
			pass
	puzzle_solved.emit(puzzle_id)


func is_solved(puzzle_id: StringName) -> bool:
	return bool(solved.get(String(puzzle_id), false))
