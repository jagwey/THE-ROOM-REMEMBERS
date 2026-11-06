extends Area2D
## Etkileşimde weight_stone kökünü başlangıca döndürür.

@export var stone_path: NodePath


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	var n: Node = get_node_or_null(stone_path)
	if n and n.has_method("reset_to_start"):
		n.call("reset_to_start")
		DialogueManager.say("Sen", "Taş yerine kaydı.")
	elif n and n.has_method("reset_to_home"):
		n.call("reset_to_home")
		DialogueManager.say("Sen", "Taş yerine kaydı.")
	else:
		push_warning("reset_lever: invalid stone_path")
