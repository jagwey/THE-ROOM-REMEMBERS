extends Area2D
var source: Node

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true

func on_interact(_by: Node) -> void:
	if is_instance_valid(source):
		source.finish_relay()
