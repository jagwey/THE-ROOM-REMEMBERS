extends Node2D
## Salın fizik hareketini izler. Su hacmi haznenin iki duvarı arasında kalır.

@export_range(40.0, 1024.0, 1.0) var width: float = 160.0
## Su düğümünün yerel koordinatlarında hazne tabanı.
@export var basin_bottom_y: float = 360.0


func _ready() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	var left := -width * 0.5
	var height := basin_bottom_y - position.y - (get_parent() as Node2D).position.y
	var surface_y := 8.0
	if height <= surface_y:
		return
	var surface := Color(0.23, 0.39, 0.45, 0.61)
	var bottom := Color(0.07, 0.15, 0.19, 0.84)
	var rim := PackedVector2Array([
		Vector2(left + 15.0, -6.0), Vector2(-left - 15.0, -6.0),
		Vector2(-left, surface_y), Vector2(left, surface_y),
	])
	draw_colored_polygon(rim, Color(0.28, 0.44, 0.46, 0.64))
	draw_rect(Rect2(left + 16.0, -6.0, width - 32.0, 1.0), Color(0.58, 0.72, 0.71, 0.53))
	draw_rect(Rect2(left + 26.0, -3.0, 26.0, 1.0), Color(0.64, 0.75, 0.67, 0.47))
	draw_rect(Rect2(-left - 54.0, -2.0, 18.0, 1.0), Color(0.57, 0.71, 0.70, 0.41))
	var shape := PackedVector2Array([
		Vector2(left, surface_y), Vector2(-left, surface_y),
		Vector2(-left, height), Vector2(left, height),
	])
	draw_polygon(shape, PackedColorArray([surface, surface, bottom, bottom]))
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, surface_y), Vector2(left + 9.0, surface_y),
		Vector2(left + 4.0, height), Vector2(left, height),
	]), Color(0.11, 0.20, 0.23, 0.44))
	draw_rect(Rect2(-left - 6.0, surface_y, 6.0, height - surface_y), Color(0.08, 0.16, 0.2, 0.3))
	draw_rect(Rect2(left, surface_y, width, 1.0), Color(0.61, 0.76, 0.72, 0.64))
	draw_rect(Rect2(left, surface_y + 1.0, width, 3.0), Color(0.46, 0.66, 0.66, 0.25))
	for i in 6:
		var depth := float(4 + i * 3)
		if surface_y + depth >= height:
			break
		var x := left + fposmod(float(i * 57 + 10), width - 38.0)
		draw_rect(Rect2(x, surface_y + depth, float(10 + (i * 7) % 22), 1.0),
			Color(0.62, 0.76, 0.73, lerpf(0.33, 0.12, float(i) / 5.0)))
