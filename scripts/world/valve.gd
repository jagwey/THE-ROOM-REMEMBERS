extends Area2D
## Vana: etkileşimde bağlı WaterLevel'ı `delta` kadar kaydırır.

@export var water: NodePath
@export var delta: int = 1

const COOLDOWN_MSEC := 300
var _last_use_msec: int = -COOLDOWN_MSEC


func _ready() -> void:
	add_to_group("valve")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_use_msec < COOLDOWN_MSEC:
		return
	var w := get_node_or_null(water)
	if w == null:
		push_warning("valve '%s': water node not found (%s)" % [name, water])
		return
	if w.has_method("step"):
		_last_use_msec = now
		w.step(delta)
