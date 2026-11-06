extends Node
## Bulmaca durumu stub.

signal puzzle_solved(puzzle_id: StringName)

var solved: Dictionary = {}


func mark_solved(puzzle_id: StringName) -> void:
	solved[String(puzzle_id)] = true
	puzzle_solved.emit(puzzle_id)


func is_solved(puzzle_id: StringName) -> bool:
	return solved.get(String(puzzle_id), false)
