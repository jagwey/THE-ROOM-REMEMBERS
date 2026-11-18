extends Node2D
## Yol taklidi: kontrol noktaları sırayla (yalnız yankı gövdesiyle) geçilirse bulmaca çözülür.
## Sıra dışı geçiş ilerlemeyi sıfırlar; kilitlemez.

@export var puzzle_id: StringName = &"path_mimic"
## Oda koordinatı (düğümün yerel uzayında).
@export var checkpoints: PackedVector2Array = PackedVector2Array()
@export var radius: float = 40.0
## true: yalnız katman 64 yankı gövdesi sayılır.
@export var echo_only: bool = true
@export var also_solve: PackedStringArray = PackedStringArray()
@export var reset_line: String = ""

var _progress: int = 0
var _inside: Array = []


func _ready() -> void:
	add_to_group("path_mimic")
	_inside.resize(checkpoints.size())
	_inside.fill(false)
	if PuzzleManager.is_solved(puzzle_id):
		_progress = checkpoints.size()
	z_index = -1
	queue_redraw()


## Soluk halkalar: yankının geçeceği noktalar (geçilenler daha soluk, sıradaki biraz parlak).
func _draw() -> void:
	if PuzzleManager.is_solved(puzzle_id):
		return
	for i in checkpoints.size():
		var a := 0.12 if i < _progress else (0.34 if i == _progress else 0.2)
		var col := Color(0.78, 0.8, 0.95, a)
		draw_arc(checkpoints[i], radius * 0.7, 0.0, TAU, 28, col, 1.5, true)
		draw_circle(checkpoints[i], 2.0, col)


func progress() -> int:
	return _progress


func _candidates() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("echo_twin_body"):
		if n is Node2D:
			out.append(n)
	if not echo_only:
		var p := get_tree().get_first_node_in_group("player")
		if p is Node2D:
			out.append(p)
	return out


func _physics_process(_delta: float) -> void:
	if checkpoints.is_empty() or PuzzleManager.is_solved(puzzle_id):
		return
	var cands := _candidates()
	for i in checkpoints.size():
		var wp := to_global(checkpoints[i])
		var hit := false
		for c in cands:
			if (c as Node2D).global_position.distance_to(wp) <= radius:
				hit = true
				break
		if hit and not bool(_inside[i]):
			_enter(i)
		_inside[i] = hit


func _enter(i: int) -> void:
	if i == _progress:
		_progress += 1
		queue_redraw()
		if _progress >= checkpoints.size():
			PuzzleManager.mark_solved(puzzle_id)
			for extra in also_solve:
				PuzzleManager.mark_solved(StringName(extra))
			SaveManager.save_game()
		return
	if _progress > 0 or i != 0:
		var had := _progress > 0
		_progress = 1 if i == 0 else 0
		queue_redraw()
		if had and reset_line != "" and not DialogueManager.is_open:
			DialogueManager.say("Noroi", reset_line)
