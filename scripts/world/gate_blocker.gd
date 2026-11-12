extends StaticBody2D
## Basınç plakası / bayrak ile açılan engel.

@export var open_flag: StringName = &"awakening_door_opened"
## Hangi bulmaca çözülünce açılır (boşsa sadece bayrak).
@export var puzzle_listen: StringName = &"awakening_weight"
## Boş değilse puzzle_listen yerine kullanılır: listedeki HER id çözülmüş/canlı olunca açılır.
@export var puzzle_listen_all: PackedStringArray = []
## Eski kayıt: bu id çözülmüşse yeni çoklu şart aranmadan açık.
@export var legacy_puzzle: StringName = &""
## true ise yalnızca puzzle ile açılır (bayrak/legacy tek başına yetmez).
@export var ignore_world_flag: bool = false
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
## Geçiş kilidi: gate canlı plaka yüzünden açıkken oyuncu karşı tarafa geçerse bulmaca kalıcı çözülür.
var _entry_side: int = 0
var _last_player_x: float = NAN
## Tek karede bu kadar kayma = teleport/spawn; taraf yeniden öğrenilir.
const TELEPORT_DX := 160.0
## Oda aktif olduktan / kayıt yüklendikten sonra bu süre canlı değişim geri bildirimi (sfx/HUD) susar.
const FEEDBACK_GRACE_MS := 600
var _grace_until_ms: int = 0
## Test için: yayılan geri bildirim sayısı.
var feedback_count: int = 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	GameState.world_flag_changed.connect(_on_flag)
	PuzzleManager.puzzle_solved.connect(_on_puzzle)
	PuzzleManager.live_changed.connect(_on_live)
	GameState.room_changed.connect(_on_room_changed)
	var par := get_parent() as CanvasItem
	if par != null:
		par.visibility_changed.connect(_reset_side)
	_grace_until_ms = Time.get_ticks_msec() + FEEDBACK_GRACE_MS
	_apply(_is_open())


func _reset_side() -> void:
	_grace_until_ms = Time.get_ticks_msec() + FEEDBACK_GRACE_MS
	_entry_side = 0
	_last_player_x = NAN


func _on_room_changed(_room_id: StringName = &"") -> void:
	_reset_side()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENABLED or what == NOTIFICATION_DISABLED:
		_reset_side()


func _listen_ids() -> PackedStringArray:
	if not puzzle_listen_all.is_empty():
		return puzzle_listen_all
	if puzzle_listen != &"":
		return PackedStringArray([String(puzzle_listen)])
	return PackedStringArray()


func _all_solved(ids: PackedStringArray) -> bool:
	for id in ids:
		if not PuzzleManager.is_solved(StringName(id)):
			return false
	return true


func _is_open() -> bool:
	if PuzzleManager.gate_open(_listen_ids(), legacy_puzzle):
		return true
	if ignore_world_flag:
		return false
	if open_flag != &"" and bool(GameState.get_world_flag(open_flag, false)):
		return true
	return false


func _on_flag(f: StringName, value: Variant) -> void:
	if f == open_flag:
		if bool(value):
			_pulse_open()
		_apply(bool(value))


func _on_puzzle(puzzle_id: StringName) -> void:
	if _listen_ids().has(String(puzzle_id)):
		_pulse_open()
		_apply(_is_open())


func _on_live(puzzle_id: StringName, live: bool) -> void:
	if not _listen_ids().has(String(puzzle_id)) or not is_inside_tree():
		return
	var parent_vis := get_parent() as CanvasItem
	var audible := (parent_vis == null or parent_vis.is_visible_in_tree()) and Time.get_ticks_msec() >= _grace_until_ms
	if live:
		_pulse_open()
	if audible:
		feedback_count += 1
		PuzzleManager.live_feedback.emit(puzzle_id, live)
		var am := get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_sfx"):
			am.play_sfx(&"door_open" if live else &"plate_press", -4.0)
	_apply(_is_open())


func _physics_process(_delta: float) -> void:
	var ids := _listen_ids()
	if ids.is_empty() or _all_solved(ids) or not PuzzleManager.gate_open(ids):
		_entry_side = 0
		_last_player_x = NAN
		return
	## Gate açıkken kendi görünürlüğü kapalıdır; oda görünürlüğüne bak.
	var par := get_parent() as CanvasItem
	if par != null and not par.is_visible_in_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var px := player.global_position.x
	if not is_nan(_last_player_x) and absf(px - _last_player_x) > TELEPORT_DX:
		_entry_side = 0
	_last_player_x = px
	var side := 1 if px > global_position.x else -1
	if _entry_side == 0:
		_entry_side = side
	elif side != _entry_side:
		_entry_side = 0
		for id in ids:
			PuzzleManager.mark_solved(StringName(id))
		SaveManager.save_game()


func _apply(open: bool) -> void:
	collision_layer = 0 if open else 1
	if has_meta("room_saved_layer"):
		set_meta("room_saved_layer", 0 if open else 1)
	if shape:
		shape.set_deferred("disabled", open)
	visible = not open
	if sprite:
		sprite.modulate = Color(1, 1, 1, 0.0) if open else Color(1, 1, 1, 1)


func _pulse_open() -> void:
	if not is_visible_in_tree():
		return
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("focus_pulse"):
		cam.focus_pulse(global_position + Vector2(0, -50))
