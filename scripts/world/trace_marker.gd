extends Area2D
## Çiçek / leke / silüet izi — Echo etkileşimi.

var kind: String = "stain"
var echo_id: StringName = &"default"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func setup(trace: Dictionary) -> void:
	kind = String(trace.get("kind", "stain"))
	echo_id = StringName("trace_%s" % kind)
	var pos: Dictionary = trace.get("position", {"x": 0, "y": 0})
	global_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	match kind:
		"flower":
			spr.texture = load("res://assets/props/red_flower.png")
		"silhouette":
			spr.texture = load("res://assets/props/body_echo.png")
			spr.modulate = Color(0.4, 0.35, 0.45, 0.55)
		_:
			spr.texture = load("res://assets/props/curse.png")
			spr.modulate = Color(0.5, 0.2, 0.25, 0.4)
			spr.scale = Vector2(0.5, 0.5)
	add_child(spr)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	add_child(shape)


func on_interact(_by: Node) -> void:
	await EchoManager.play_echo(echo_id)
