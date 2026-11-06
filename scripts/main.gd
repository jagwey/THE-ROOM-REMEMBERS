extends Node2D
## Ana sahne — World / Player / Keeper / Camera / UI / Audio.


func _ready() -> void:
	GameState.mark_room_visited(&"awakening")
	# Kısa oda girişi; gizem fısıltıları Keeper mystery beat'te gelir.
	DialogueManager.say("???", "Gözlerin açılıyor.")
	DialogueManager.say("???", "Oda seni hatırlıyor.")
