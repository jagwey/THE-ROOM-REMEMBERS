extends "res://scripts/world/built_room.gd"
## Son Merdiven: eski kayıtlar `core_ascent` çözülü ama yeni alt bulmacalar çözülmemiş gelir;
## oyuncu kapının doğusunda doğup sunak/plakaya dönemesin diye alt bulmacalar da çözülmüş sayılır.

const SUB_PUZZLES: Array[StringName] = [&"core_ascent_seal", &"core_ascent_gap", &"core_ascent_echo"]


func _ready() -> void:
	super._ready()
	if not GameState.room_changed.is_connected(_on_room_changed):
		GameState.room_changed.connect(_on_room_changed)
	sync_legacy_solved()


func _exit_tree() -> void:
	if GameState.room_changed.is_connected(_on_room_changed):
		GameState.room_changed.disconnect(_on_room_changed)


func _on_room_changed(_room: StringName = &"") -> void:
	sync_legacy_solved()


func sync_legacy_solved() -> void:
	if not PuzzleManager.is_solved(&"core_ascent"):
		return
	for id in SUB_PUZZLES:
		PuzzleManager.mark_solved(id)
