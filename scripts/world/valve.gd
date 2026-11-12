extends Area2D
## Vana: etkileşimde bağlı WaterLevel'ı `delta` kadar kaydırır.

@export var water: NodePath
@export var delta: int = 1


func _ready() -> void:
	add_to_group("valve")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	var w := get_node_or_null(water)
	if w != null and w.has_method("step"):
		w.step(delta)
