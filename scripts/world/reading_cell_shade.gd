extends Node2D
## Okuma Hücresi: Notches okununca bir okuyucu gölgesi (gerçek iz) kabinden kapıya doğru yürür.
## Bulmaca (library_reading_cell) Notches'ta çözülür; gölge yalnız yol gösterir. Kayda geçmez.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const SOLVE_ID := &"library_reading_cell"
const PATH := [Vector2(700, 252), Vector2(780, 252), Vector2(850, 252)]

var _spawned: bool = false


func _ready() -> void:
	add_to_group("reading_cell_shade")
	PuzzleManager.puzzle_solved.connect(_on_solved)


func _on_solved(id: StringName) -> void:
	if id == SOLVE_ID:
		_spawn()


func _spawn() -> void:
	if _spawned:
		return
	_spawned = true
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "ReaderShade"
	s.set("shade_id", &"reading_cell_reader")
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
	s.connect("reached", _on_reached.bind(s))
	s.call("start")


func _on_reached(_id: StringName, s: Node2D) -> void:
	if is_instance_valid(s):
		var tw := create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 1.2)
		tw.tween_callback(s.hide)
