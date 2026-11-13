extends Node2D
## Kırılmayan Ayna: yansıma üç noktalı yolu yürür; Noroi'nin yankısı aynı yolu izlemelidir.
## Yol taklidi (path_mimic) çözülünce yansıma görünmez.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const START := Vector2(260, 288)
const PATH := [Vector2(340, 288), Vector2(520, 246), Vector2(700, 288)]
const MIMIC_ID := &"mirrors_unbroken_mimic"

var _shade: Node2D = null


func _ready() -> void:
	add_to_group("unbroken_reflection")
	if PuzzleManager.is_solved(MIMIC_ID) or PuzzleManager.is_solved(&"mirrors_unbroken"):
		return
	PuzzleManager.puzzle_solved.connect(_on_solved)
	_spawn()


func _on_solved(id: StringName) -> void:
	if id != MIMIC_ID and id != &"mirrors_unbroken":
		return
	if is_instance_valid(_shade):
		_shade.queue_free()
	_shade = null


func _spawn() -> void:
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "Reflection"
	s.set("shade_id", &"mirrors_unbroken_reflection")
	s.set("fake", false)
	s.set("waypoints", PackedVector2Array(PATH))
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/memory_echo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.6, 0.6)
	spr.modulate = Color(0.7, 0.85, 1.0, 0.6)
	s.add_child(spr)
	s.z_index = 3
	add_child(s)
	s.global_position = START
	_shade = s
	s.call("start")
