extends Node2D
## Ana sahne — World / Player / Keeper / Camera / UI / Audio iskeleti.


func _ready() -> void:
	GameState.mark_room_visited(&"awakening")
	DialogueManager.say("???", "Gözlerin açılıyor.")
	DialogueManager.say("???", "Oda seni hatırlıyor.")
