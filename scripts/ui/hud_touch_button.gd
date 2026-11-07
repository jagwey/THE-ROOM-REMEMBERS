class_name HudTouchButton
extends TextureButton
## Mobil HUD düğmesi: basış geri bildirimi (scale + glow) ve prosedürel cooldown halkası.
## Dokunuşları HUD denetleyicisi (çoklu dokunuş) yönetir; bu düğme fare/GUI girişini yutmaz.

## "jump" ise ikonun üstüne yukarı ok çizilir (hazır ikon yok).
@export var glyph: StringName = &""
## true: ikon dokusu yerine prosedürel gotik halka (koyu disk + lila/altın çift halka) çizilir; Attack/Dash/Interact ile aynı dil.
@export var gothic_ring: bool = false
## gothic_ring açıkken halkanın içine çizilen ikon (opsiyonel).
var ring_icon: Texture2D = null
## 1.0 = az önce kullanıldı (tam bekleme), 0.0 = hazır.
var cooldown: float = 0.0:
	set(v):
		var nv := clampf(v, 0.0, 1.0)
		if absf(nv - cooldown) < 0.004 and nv != 0.0 and cooldown != 0.0:
			return
		cooldown = nv
		queue_redraw()

var held: bool = false
var _glow: float = 0.0:
	set(v):
		_glow = v
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_update_pivot)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


## Dokunuş koordinatı (viewport/canvas) bu düğmenin dairesinde mi? Parmak payı +6.
func hit_distance(pos: Vector2) -> float:
	var c := get_global_rect().get_center()
	var r := maxf(size.x, size.y) * 0.5 + 6.0
	var d := c.distance_to(pos)
	return d if d <= r else -1.0


func set_held(v: bool) -> void:
	if held == v:
		return
	held = v
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(0.88, 0.88) if v else Vector2.ONE, 0.07 if v else 0.12)
	_tween.tween_property(self, "self_modulate", Color(1.35, 1.2, 1.2, 1.0) if v else Color.WHITE, 0.07 if v else 0.14)
	_tween.tween_property(self, "_glow", 1.0 if v else 0.0, 0.07 if v else 0.2)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if gothic_ring:
		draw_circle(c, r - 1.0, Color(Palette.VOID, 0.78))
		draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(Palette.PALE_LILAC, 0.9), 2.0, true)
		draw_arc(c, r - 5.0, 0.0, TAU, 48, Color(0.78, 0.62, 0.3, 0.75), 1.0, true)
		if ring_icon != null:
			var s := r * 1.1
			draw_texture_rect(ring_icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if _glow > 0.01:
		draw_circle(c, r, Color(Palette.CRIMSON, 0.30 * _glow))
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(Palette.IVORY, 0.65 * _glow), 3.0, true)
	if glyph == &"jump":
		var w := r * 0.42
		var col := Palette.IVORY
		draw_polyline(PackedVector2Array([c + Vector2(-w, w * 0.45), c + Vector2(0, -w * 0.45), c + Vector2(w, w * 0.45)]), col, 4.0)
		draw_polyline(PackedVector2Array([c + Vector2(-w, w * 1.15), c + Vector2(0, w * 0.25), c + Vector2(w, w * 1.15)]), Color(col, 0.55), 4.0)
	if cooldown > 0.001:
		var start := -PI * 0.5
		var end := start + TAU * cooldown
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(48.0 * cooldown))
		for i in steps + 1:
			var a := start + (end - start) * float(i) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
		draw_colored_polygon(pts, Color(Palette.VOID, 0.62))
		draw_arc(c, r - 2.0, start, end, 48, Color(Palette.PALE_LILAC, 0.95), 3.0, true)
