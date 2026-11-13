extends Node2D
## 1927 Gecesi: sessiz yürüyüş. Bir iz gölgesi sahne boyunca yürür; Noroi onu sonuna dek izlerse
## `mirrors_1927_walk` çözülür ve oda gecenin tanığını/tarih tuğlasını açar. Diyalog yok.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const START := Vector2(120, 288)
const PATH := [Vector2(260, 288), Vector2(430, 250), Vector2(600, 288), Vector2(760, 288)]
const SHADE_ID := &"mirrors_1927_night"
const WALK_ID := &"mirrors_1927_walk"

var _shade: Node2D = null


func _ready() -> void:
	add_to_group("night_walk")
	if PuzzleManager.is_solved(WALK_ID) or PuzzleManager.is_solved(&"mirrors_1927"):
		return
	_spawn()


func _spawn() -> void:
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "NightShade"
	s.set("shade_id", SHADE_ID)
	s.set("fake", false)
	s.set("waypoints", PackedVector2Array(PATH))
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/memory_echo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.6, 0.6)
	spr.modulate = Color(0.85, 0.8, 1.0, 0.55)
	s.add_child(spr)
	s.z_index = 3
	s.connect("reached", _on_reached)
	add_child(s)
	s.global_position = START
	_shade = s
	s.call("start")


func _on_reached(id: StringName) -> void:
	if id != SHADE_ID:
		return
	PuzzleManager.mark_solved(WALK_ID)
	if is_instance_valid(_shade):
		var tw := _shade.create_tween()
		tw.tween_property(_shade, "modulate:a", 0.0, 1.2)
		tw.tween_callback(_shade.queue_free)
