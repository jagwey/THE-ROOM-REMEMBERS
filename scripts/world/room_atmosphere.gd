extends Node2D
## Oda paleti + hafif parallax modülasyon (Awakening / Core).

@export var room_id: StringName = &"awakening"


func _ready() -> void:
	_tint_layers()


func _tint_layers() -> void:
	var far := get_node_or_null("ParallaxFar") as CanvasItem
	var mid := get_node_or_null("ParallaxMid") as CanvasItem
	var front := get_node_or_null("ParallaxFront") as CanvasItem
	if far:
		far.modulate = Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 1.0).lerp(Color.WHITE, 0.55)
	if mid:
		mid.modulate = Color(1.0, 0.96, 0.98, 1.0)
	if front:
		front.modulate = Color.WHITE
	if room_id == &"core":
		if far:
			far.modulate = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 1.0).lerp(Color.WHITE, 0.7)
		if mid:
			mid.modulate = Color(1.0, 0.92, 0.94, 1.0)
