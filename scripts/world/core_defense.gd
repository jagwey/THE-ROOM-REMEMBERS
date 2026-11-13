extends Node2D
## Çekirdek savunması — 3 dalga gölge kristale yürür; kristalin canı biterse dalgalar sıfırlanır.
## Oyuncu ölmez, ceset oluşmaz. Odadan çıkınca aktif dalga iptal edilir.

signal wave_started(i: int)
signal defended

const SHADE_SCENE := "res://scenes/world/memory_shade_walking.tscn"

@export var puzzle_id: StringName = &"core_defense"
@export var waves: PackedInt32Array = PackedInt32Array([2, 3, 4])
@export var spawn_points: PackedVector2Array = PackedVector2Array([Vector2(120, 288), Vector2(840, 288)])
@export var crystal_hp: int = 5
@export var fail_line: String = "Kristal titriyor. Dalgalar yeniden geliyor."

var _active: bool = false
var _wave: int = 0
var _hp: int = 0
var _gen: int = 0
var _shades: Array = []
var _label: Label = null


func _ready() -> void:
	add_to_group("core_defense")
	if not RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.connect(_on_room_changed)
	_label = Label.new()
	_label.position = Vector2(400, 168)
	_label.size = Vector2(160, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.visible = false
	add_child(_label)


func _exit_tree() -> void:
	if RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.disconnect(_on_room_changed)
	_active = false
	_gen += 1
	_cancel()


func is_active() -> bool:
	return _active


func wave_index() -> int:
	return _wave


func hp() -> int:
	return _hp


func shade_count() -> int:
	return _shades.size()


func crystal_x() -> float:
	var c := get_tree().get_first_node_in_group("core_crystal") as Node2D
	return c.global_position.x if c != null else 480.0


func start() -> void:
	if _active or PuzzleManager.is_solved(puzzle_id):
		return
	_active = true
	_hp = crystal_hp
	_wave = 0
	_gen += 1
	_begin_wave()


func _begin_wave() -> void:
	if not _active:
		return
	_update_label()
	wave_started.emit(_wave)
	var scn := load(SHADE_SCENE) as PackedScene
	if scn == null or _wave >= waves.size():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cx := crystal_x()
	var n: int = waves[_wave]
	for k in n:
		var sp: Vector2 = spawn_points[k % spawn_points.size()]
		# Oyuncunun üstüne doğma: yakınsa en uzaktaki noktayı seç.
		if player != null and absf(player.global_position.x - sp.x) < 80.0:
			for cand in spawn_points:
				if absf(player.global_position.x - cand.x) > absf(player.global_position.x - sp.x):
					sp = cand
		sp.x += signf(cx - sp.x) * 34.0 * float(k / maxi(spawn_points.size(), 1))
		var shade := scn.instantiate() as CharacterBody2D
		shade.set_meta("defense", self)
		shade.position = sp
		add_child(shade)
		shade.tree_exited.connect(_on_shade_gone.bind(shade))
		_shades.append(shade)


## Gölge kristale değdi: can düşer, gölge söner.
func shade_reached(shade: Node) -> void:
	if not _active or not _shades.has(shade):
		return
	_forget(shade)
	if is_instance_valid(shade):
		shade.queue_free()
	if _hit_crystal():
		return  # kayip: dalgalar zaten sifirlandi
	if _active and _hp > 0 and _shades.is_empty():
		_wave_done()


## Test ve savunma içi: kristale doğrudan 1 hasar.
func hit_crystal() -> void:
	if _active:
		_hit_crystal()


## Dönüş: kristal çöktü ve dalgalar sıfırlandıysa true.
func _hit_crystal() -> bool:
	_hp = maxi(_hp - 1, 0)
	_update_label()
	var c := get_tree().get_first_node_in_group("core_crystal") as CanvasItem
	if c != null:
		c.modulate = Color(1.0, 0.45, 0.45)
		c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.3)
	if _hp <= 0:
		_fail()
		return true
	return false


func _fail() -> void:
	_cancel()
	DialogueManager.say("", fail_line)
	_active = true
	_hp = crystal_hp
	_wave = 0
	_gen += 1
	_after(1.5 if OS.get_environment("TORIMON_TEST") != "1" else 0.0, _begin_wave)


func _after(sec: float, cb: Callable) -> void:
	var g := _gen
	if sec <= 0.0:
		cb.call_deferred()
		return
	if not is_inside_tree():
		return
	get_tree().create_timer(sec).timeout.connect(func() -> void:
		if g == _gen and _active:
			cb.call())


func _forget(shade: Node) -> void:
	_shades.erase(shade)
	if is_instance_valid(shade) and shade.tree_exited.is_connected(_on_shade_gone.bind(shade)):
		shade.tree_exited.disconnect(_on_shade_gone.bind(shade))


func _on_shade_gone(shade: Node) -> void:
	if not _active or not _shades.has(shade):
		return
	_shades.erase(shade)
	if _shades.is_empty() and _hp > 0:
		_wave_done()


func _wave_done() -> void:
	_wave += 1
	if _wave >= waves.size():
		_finish()
		return
	_gen += 1
	_after(1.2 if OS.get_environment("TORIMON_TEST") != "1" else 0.0, _begin_wave)


func _finish() -> void:
	_active = false
	_label.visible = false
	PuzzleManager.mark_solved(puzzle_id)
	SaveManager.save_game()
	defended.emit()


## Aktif dalgayı iptal eder: gölgeler silinir, sinyal bağları kopar, savunma pasif.
func _cancel() -> void:
	_active = false
	_gen += 1
	for s in _shades.duplicate():
		_forget(s)
		if is_instance_valid(s):
			s.queue_free()
	_shades.clear()
	_wave = 0
	if _label != null:
		_label.visible = false


func _on_room_changed(_from: StringName, to: StringName) -> void:
	if to != &"core":
		_cancel()


func _update_label() -> void:
	if _label != null:
		_label.text = "Kristal %d/%d · Dalga %d/%d" % [_hp, crystal_hp, _wave + 1, waves.size()]
		_label.visible = _active


## Yalnız TORIMON_TEST: mevcut dalgayı anında bitirir.
func debug_clear_wave() -> void:
	if OS.get_environment("TORIMON_TEST") != "1" or not _active:
		return
	for s in _shades.duplicate():
		_forget(s)
		if is_instance_valid(s):
			s.queue_free()
	_shades.clear()
	_wave_done()
