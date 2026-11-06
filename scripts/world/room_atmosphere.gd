extends Node2D
## Oda paleti + hafif parallax modülasyon (Awakening / Core).

@export var room_id: StringName = &"awakening"


func _ready() -> void:
	_tint_layers()


func _tint_layers() -> void:
	var far := get_node_or_null("ParallaxFar") as CanvasItem
	var mid := get_node_or_null("ParallaxMid") as CanvasItem
	var front := get_node_or_null("ParallaxFront") as CanvasItem
	var rid := String(room_id)
	if rid == "core":
		if far:
			far.modulate = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 1.0).lerp(Color.WHITE, 0.7)
		if mid:
			mid.modulate = Color(1.0, 0.92, 0.94, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("awakening"):
		if far:
			far.modulate = Color(Palette.DEEP_STONE.r, Palette.DEEP_STONE.g, Palette.DEEP_STONE.b, 1.0).lerp(Color.WHITE, 0.5)
		if mid:
			mid.modulate = Color(0.92, 0.88, 0.9, 1.0)
		if front:
			front.modulate = Color(0.96, 0.93, 0.95, 1.0)
	elif rid.begins_with("decay"):
		if far:
			far.modulate = Color(0.42, 0.5, 0.38, 1.0).lerp(Color.WHITE, 0.45)
		if mid:
			mid.modulate = Color(0.88, 0.82, 0.78, 1.0)
		if front:
			front.modulate = Color(0.94, 0.9, 0.86, 1.0)
	elif rid.begins_with("library"):
		if far:
			far.modulate = Color(0.5, 0.48, 0.62, 1.0).lerp(Color.WHITE, 0.5)
		if mid:
			mid.modulate = Color(0.9, 0.88, 0.94, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("experiment"):
		if far:
			far.modulate = Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(0.9, 0.86, 0.92, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("mirrors"):
		if far:
			far.modulate = Color(0.62, 0.58, 0.72, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(0.88, 0.84, 0.92, 1.0)
		if front:
			front.modulate = Color.WHITE
	else:
		if far:
			far.modulate = Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(1.0, 0.96, 0.98, 1.0)
		if front:
			front.modulate = Color.WHITE
