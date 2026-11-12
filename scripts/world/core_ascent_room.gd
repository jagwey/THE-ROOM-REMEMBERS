extends "res://scripts/world/built_room.gd"
## Son Merdiven: eski kayıtlar `core_ascent` çözülü ama yeni alt bulmacalar çözülmemiş gelir;
## oyuncu kapının doğusunda doğup sunak/plakaya dönemesin diye alt bulmacalar da çözülmüş sayılır.

const SUB_PUZZLES: Array[StringName] = [&"core_ascent_seal", &"core_ascent_gap", &"core_ascent_echo"]


func _ready() -> void:
	super._ready()
	GameState.room_changed.connect(func(_r: StringName = &""): sync_legacy_solved())
	sync_legacy_solved()


func sync_legacy_solved() -> void:
	if not PuzzleManager.is_solved(&"core_ascent"):
		return
	for id in SUB_PUZZLES:
		PuzzleManager.mark_solved(id)
