extends Camera2D
## Oyuncuyu takip; oda sınırlarında sıkıştır.

@export var room_rect: Rect2 = Rect2(0, 0, 640, 360)
@export var follow_smoothing: float = 8.0

var _target: Node2D


func _ready() -> void:
	make_current()
	_target = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node2D
		if _target == null:
			return
	var half := get_viewport_rect().size * 0.5 / zoom
	var desired := _target.global_position
	desired.x = clampf(desired.x, room_rect.position.x + half.x, room_rect.end.x - half.x)
	desired.y = clampf(desired.y, room_rect.position.y + half.y, room_rect.end.y - half.y)
	global_position = global_position.lerp(desired, clampf(follow_smoothing * delta, 0.0, 1.0))
