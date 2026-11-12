extends StaticBody2D
## Lanetli bariyer — katman 16. Yalnız Gölge Atılması (shadow dash) içinden geçer.

@export var height: float = 120.0
## Gölge Atılması yokken söylenen ret repliği (boşsa varsayılan satır). Yeteneğin alındığı odanın adını içermeli.
@export var refusal_line: String = ""

var _t: float = 0.0
var _hint_done: bool = false


func _ready() -> void:
	add_to_group("curse_barrier")
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, height)
	cs.shape = rect
	cs.position = Vector2(0, -height * 0.5)
	add_child(cs)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(40, height)
	cs2.shape = r2
	cs2.position = Vector2(0, -height * 0.5)
	area.add_child(cs2)
	area.body_entered.connect(_touch)
	add_child(area)
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for i in 7:
		var x := sin(_t * 2.0 + float(i)) * 6.0
		var a := 0.35 + 0.25 * sin(_t * 3.0 + float(i) * 0.7)
		draw_line(Vector2(x - 8.0 + float(i) * 2.6, 0), Vector2(-x + float(i) * 2.0 - 6.0, -height), Color(0.85, 0.1, 0.25, a), 2.0)


func _touch(b: Node) -> void:
	if _hint_done or not b.is_in_group("player"):
		return
	if b.has_method("has_shadow_dash") and b.has_shadow_dash():
		return
	_hint_done = true
	DialogueManager.whisper("Noroi", refusal_line if refusal_line != "" else "Kırmızı perde bedenimi itiyor. Gölge olsaydım… geçebilirdim.")
