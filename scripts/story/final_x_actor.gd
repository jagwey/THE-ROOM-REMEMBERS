class_name FinalXActor
extends Node2D
## X (Kurucu): uzun, koyu siluet + soğuk beyaz ışık. YER TUTUCU görsel (X için sprite yok):
## Node2D._draw ile çizilir; gerçek sprite gelince bu düğüm sprite ile değiştirilebilir.
## Ayak noktası (0,0). Yüz başlangıçta görünmez: yalnız siluet + ışık halesi.

const HEIGHT := 86.0
var glow: float = 0.0: ## 0..1 soğuk ışık şiddeti
	set(v):
		glow = v
		queue_redraw()


func _init() -> void:
	name = "XActor"
	z_index = 5


func _draw() -> void:
	var coat := Color(0.05, 0.06, 0.09, 1.0)
	var rim := Color(0.82, 0.92, 1.0, 0.85 * glow)
	## Soğuk beyaz hale (arkadan aydınlatma)
	for i in 6:
		var r := 70.0 - float(i) * 9.0
		draw_circle(Vector2(0, -HEIGHT * 0.55), r, Color(0.78, 0.9, 1.0, 0.045 * glow))
	## Uzun palto: omuzdan yere kadar yamuk
	var body := PackedVector2Array([
		Vector2(-11, -HEIGHT + 16), Vector2(11, -HEIGHT + 16),
		Vector2(17, -4), Vector2(14, 0), Vector2(-14, 0), Vector2(-17, -4),
	])
	draw_colored_polygon(body, coat)
	draw_polyline(PackedVector2Array([body[0], body[5], body[4]]), rim, 1.5)
	draw_polyline(PackedVector2Array([body[1], body[2], body[3]]), rim, 1.5)
	## Omuzlar ve baş (yüz yok)
	draw_rect(Rect2(-13, -HEIGHT + 14, 26, 6), coat)
	draw_circle(Vector2(0, -HEIGHT + 6), 8.0, coat)
	draw_arc(Vector2(0, -HEIGHT + 6), 8.0, deg_to_rad(200), deg_to_rad(340), 12, rim, 1.5)
