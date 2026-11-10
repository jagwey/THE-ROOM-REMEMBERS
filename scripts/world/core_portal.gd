extends Area2D
## Eski çekirdek atlama betiği — amorti edildi / kaldırıldı.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func on_interact(_by: Node = null) -> void:
	pass
