extends "res://scripts/world/code_seal_base.gd"
## Uyanış mührü — yarık yankısındaki 314.


func _on_solved() -> void:
	GameState.set_world_flag(&"awakening_crystal_cracked", true)
