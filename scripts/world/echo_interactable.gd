extends Area2D
## Etkileşimde EchoManager.play_echo çağırır (ceset / yarık gerektirmez).

@export var echo_id: StringName = &"awakening_rift_echo"

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if _busy:
		return
	_busy = true
	_pulse_visual()
	await EchoManager.play_echo(echo_id)
	_busy = false


func _pulse_visual() -> void:
	var base_c := modulate
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate", Color(1.15, 1.05, 1.2, 1.0), 0.22)
	tw.tween_property(self, "modulate", base_c, 0.35).set_delay(0.22)
