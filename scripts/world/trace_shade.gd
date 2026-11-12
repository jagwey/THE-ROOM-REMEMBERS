extends Node2D
## İz gölgesi: savaşsız, hasarsız. Waypoint'ler boyunca yürür; oyuncu wait_radius dışındaysa bir
## sonraki waypoint'te bekler. Son waypoint'te: gerçekse `reached`, sahteyse fısıldar ve söner.

signal reached(shade_id: StringName)

@export var waypoints: PackedVector2Array = PackedVector2Array()
@export var wait_radius: float = 96.0
@export var speed: float = 70.0
@export var fake: bool = false
@export var fake_line: String = ""
@export var shade_id: StringName = &""

var _idx: int = 0
var _running: bool = false
var _done: bool = false


func start() -> void:
	_idx = 0
	_done = false
	_running = true


func _physics_process(delta: float) -> void:
	if not _running or _done or waypoints.is_empty():
		return
	if UiGate.pauses_world_threats():
		return
	var target := waypoints[_idx]
	var to_target := target - global_position
	var step := speed * delta
	if to_target.length() > step:
		global_position += to_target.normalized() * step
		return
	global_position = target
	if _idx >= waypoints.size() - 1:
		_finish()
		return
	if _player_near():
		_idx += 1


func _player_near() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D and (p as Node2D).global_position.distance_to(global_position) <= wait_radius:
			return true
	return false


func _finish() -> void:
	_done = true
	_running = false
	if fake:
		if fake_line != "":
			DialogueManager.whisper("Noroi", fake_line)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 1.2)
		tw.tween_callback(hide)
	else:
		reached.emit(shade_id)
