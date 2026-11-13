extends Node2D
## Kadran bulmacası — her hedef için etkileşimli bir kadran (1..12). Etkileşim değeri 1→12→1 döndürür.
## Hepsi hedef değerde → puzzle_id (+ also_solve) çözülür. Çözülmüş odada kadranlar hedefte kilitlidir.

@export var puzzle_id: StringName = &"dial_puzzle"
@export var targets: PackedInt32Array = PackedInt32Array([3, 9, 6])
@export var labels: PackedStringArray = PackedStringArray()
@export var spacing: float = 200.0
@export var also_solve: PackedStringArray = []
@export var solved_line: String = "Kadranlar yerine oturdu."

var _values: PackedInt32Array = PackedInt32Array()
var _dials: Array = []
var _value_labels: Array = []
var _solved: bool = false


class Dial extends Area2D:
	var owner_puzzle: Node
	var index: int = 0

	func on_interact(_by: Node) -> void:
		owner_puzzle.call("turn", index)


func _ready() -> void:
	_solved = PuzzleManager.is_solved(puzzle_id)
	_values.resize(targets.size())
	for i in targets.size():
		_values[i] = targets[i] if _solved else 12
	var half := float(targets.size() - 1) * 0.5
	for i in targets.size():
		var d := Dial.new()
		d.owner_puzzle = self
		d.index = i
		d.name = "Dial%d" % i
		d.collision_layer = 8
		d.collision_mask = 0
		d.monitoring = false
		d.monitorable = true
		d.position = Vector2((float(i) - half) * spacing, 0)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 64)
		cs.shape = rect
		d.add_child(cs)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/props/halo.png")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.modulate = Color(0.8, 0.7, 1.0, 1.0)
		d.add_child(spr)
		var lbl := Label.new()
		lbl.position = Vector2(-60, -64)
		lbl.size = Vector2(120, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.apply_label(lbl, 16)
		d.add_child(lbl)
		add_child(d)
		_dials.append(d)
		_value_labels.append(lbl)
		_refresh(i)


func values() -> PackedInt32Array:
	return _values


func turn(index: int) -> void:
	if _solved or index < 0 or index >= _values.size():
		return
	_values[index] = 1 if _values[index] >= 12 else _values[index] + 1
	_refresh(index)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"plate_press")
	for i in targets.size():
		if _values[i] != targets[i]:
			return
	_solve()


func _solve() -> void:
	_solved = true
	PuzzleManager.mark_solved(puzzle_id)
	for id in also_solve:
		PuzzleManager.mark_solved(StringName(id))
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"seal_open")
	SaveManager.save_game()
	if solved_line != "":
		DialogueManager.say("Noroi", solved_line)
	for i in _dials.size():
		_refresh(i)


func _refresh(i: int) -> void:
	if i >= _value_labels.size():
		return
	var prefix := ""
	if i < labels.size() and labels[i] != "":
		prefix = labels[i] + " "
	(_value_labels[i] as Label).text = "%s%d" % [prefix, _values[i]]
	(_dials[i] as Node2D).modulate = Color(0.6, 0.9, 0.7, 1) if _solved else Color(1, 1, 1, 1)
