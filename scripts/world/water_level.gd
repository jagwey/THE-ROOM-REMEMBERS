extends Node2D
## Su seviyesi bulmaca parçası (0..3). Seviye 0 yalnız tahliye açıkken (drain_open) izinli.
## Raft (AnimatableBody2D) level_y[level]'e tween'lenir; durum world flag "<puzzle_key>_level".

signal level_changed(level: int)

@export var level_y: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
@export var start_level: int = 1
@export var puzzle_key: StringName = &""

var level: int = 1
var drain_open: bool = false
var _raft: AnimatableBody2D
var _tween: Tween


func _flag() -> StringName:
	return StringName(String(puzzle_key) + "_level")


func _ready() -> void:
	_raft = get_node_or_null("Raft") as AnimatableBody2D
	if _raft == null:
		_raft = AnimatableBody2D.new()
		_raft.name = "Raft"
		add_child(_raft)
	_raft.sync_to_physics = true
	level = clampi(int(GameState.get_world_flag(_flag(), start_level)), 0, 3)
	if level_y.size() > level:
		_raft.position.y = level_y[level]


func step(delta: int) -> void:
	_set_level(level + delta)


func set_drain(open: bool) -> void:
	drain_open = open
	if not open and level == 0:
		_set_level(1)


func _set_level(target: int) -> void:
	var lo := 0 if drain_open else 1
	var new_level := clampi(target, lo, 3)
	if new_level == level:
		return
	level = new_level
	GameState.set_world_flag(_flag(), level)
	if _raft != null and level_y.size() > level:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_raft, "position:y", level_y[level], 0.5)
	level_changed.emit(level)
