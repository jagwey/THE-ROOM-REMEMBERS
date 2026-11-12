extends Node
## Yalnız-ceset tahliye plakasını su seviyesine bağlar: plaka basılıyken drain açık.

@export var plate: NodePath
@export var water: NodePath


func _ready() -> void:
	var p := get_node_or_null(plate)
	var w := get_node_or_null(water)
	if p == null or w == null:
		push_warning("drain_link '%s': plate/water missing" % name)
		return
	p.pressed_changed.connect(func(on: bool): w.set_drain(on))
	if bool(p.get("_pressed")):
		w.set_drain(true)
