extends Node2D
## Sera iz gölgesi: tek gölge doğru saksıya (x620) yürür ve orada bekler. Oyuncu yaklaştıkça ilerler.
## Çözülmüşse (`decay_greenhouse_pot` veya eski `decay_greenhouse`) hiç kurulmaz. Kayda geçmez.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const PATH := [Vector2(300, 252), Vector2(460, 252), Vector2(620, 252)]


func _ready() -> void:
	if PuzzleManager.is_solved(&"decay_greenhouse_pot") or PuzzleManager.is_solved(&"decay_greenhouse"):
		return
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "PotShade"
	s.add_to_group("greenhouse_shade")
	s.set("shade_id", &"greenhouse_shade_true")
	s.set("fake", false)
	s.set("waypoints", PackedVector2Array(PATH))
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/memory_echo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.6, 0.6)
	spr.modulate = Color(0.75, 0.7, 0.95, 0.55)
	s.add_child(spr)
	s.z_index = 3
	add_child(s)
	s.global_position = PATH[0]
	s.call("start")
