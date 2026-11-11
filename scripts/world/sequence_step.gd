extends Area2D
## sequence_shrine çocuğu. pips > 0 ise taşın üstünde okunur noktalar çizer.

@export var step_id: String = "a"
@export var label: String = "Taş"
@export var texture_path: String = "res://assets/props/red_flower.png"
@export var sprite_scale: float = 0.55
@export var tint: Color = Color.WHITE
@export var pips: int = 0

var _sprite: Sprite2D
var _lit: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 48)
		cs.shape = rect
		cs.position = Vector2(0, -16)
		add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.position = Vector2(0, -18)
	_sprite.modulate = tint
	add_child(_sprite)
	queue_redraw()


func get_interact_label() -> String:
	return label


func get_glow_kind() -> StringName:
	return &"memory"


func set_lit(on: bool) -> void:
	_lit = on
	if _sprite:
		_sprite.modulate = Color(1.35, 1.15, 1.05) if on else tint
	queue_redraw()


func on_interact(_by: Node) -> void:
	var shrine := get_parent()
	if shrine and shrine.has_method("press"):
		shrine.press(step_id, self)


func _draw() -> void:
	if pips <= 0:
		return
	var col := Color(1.0, 0.86, 0.55, 1.0) if _lit else Color(0.95, 0.32, 0.38, 0.95)
	var span := float(pips - 1) * 6.0
	for i in pips:
		draw_circle(Vector2(-span * 0.5 + float(i) * 6.0, -40.0), 2.4, col)
