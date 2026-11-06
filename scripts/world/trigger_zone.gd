extends Area2D
## Yasak / çıkış / lanet yakını tetikleyici — Bekçi'ye iletir, öldürmez.

signal triggered(zone_id: StringName, body: Node)

@export var zone_id: StringName = &"forbidden"
@export var one_shot: bool = false

var _fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## player
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if one_shot and _fired:
		return
	_fired = true
	triggered.emit(zone_id, body)
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper and keeper.has_method("on_trigger_zone"):
		keeper.on_trigger_zone(zone_id, body)


func reset_shot() -> void:
	_fired = false
