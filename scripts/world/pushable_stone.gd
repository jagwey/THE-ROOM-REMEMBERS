extends "res://scripts/world/weight_stone.gd"
## Oyuncunun itebildiği taş ağırlık — WeightStone ile aynı güvenilir itiş (omuz + Etkileş adımı).

@export var weight_value: int = 1
@export var push_speed: float = 70.0

var _home: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	min_x = -100000.0 ## sınırları duvar/uçurum ışınları belirler
	max_x = 100000.0
	add_to_group("corpse") ## pressure_plate weight_of corpse path
	add_to_group("pushable_stone")
	_home = global_position
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		if s.texture == null:
			s.texture = load("res://assets/layers/rubble.png")
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func get_weight() -> int:
	return weight_value


func reset_to_home() -> void:
	reset_to_start()
	global_position = _home
