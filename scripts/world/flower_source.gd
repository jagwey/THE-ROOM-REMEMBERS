extends Area2D
## Katakomb çiçek kaynağı: çiçeği ele alır (hayat başına). Ölünce ceset çiçeği taşır ve fener gibi yanar.
## Kaynak tükenmez; çiçeksiz ölümden sonra yeniden alınabilir.

const PICK_LINE := "Solgun bir çiçek. Elimde ışık gibi duruyor."
const HELD_LINE := "Çiçek zaten elimde."


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if DialogueManager.is_open:
		return
	var life: Dictionary = GameState.character_current_life_knowledge
	if bool(life.get("flower_in_hand", false)):
		DialogueManager.say("Noroi", HELD_LINE)
		return
	life["flower_in_hand"] = true
	DialogueManager.say("Noroi", PICK_LINE)
