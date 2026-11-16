extends Node2D
## Oda güzelleştirme: ucuz, güvenli dokunuşlar (mevcut SFX, ışık titremesi, küçük parçacık). Yeni asset yok.
## Oda gizliyken Godot _process'i durdurur; ses/parlama yalnız aktif odada çalışır. Ses seviyesi AudioManager
## SFX veri yolundan (GameSettings) gelir; ani parlama GameSettings.shake_enabled() kapalıyken çalışmaz.

## Rastgele aralıklı tek atımlık SFX (damla, rüzgâr, fısıltı...). Boşsa yok.
@export var ambient_sfx: StringName = &""
@export var ambient_db: float = -24.0
@export var ambient_pitch: float = 1.0
@export var ambient_min: float = 4.0
@export var ambient_max: float = 9.0
## Bu bulmaca çözülünce ambient susar (örn. 1927 saati durunca tik sesi kesilir).
@export var stop_when_solved: StringName = &""
## Sabit aralıklı mı (tik) rastgele mi.
@export var ambient_regular: bool = false
## Ani beyaz parlama (şimşek): her ambient atımda ekranı kısa süre aydınlatır.
@export var flash: bool = false
## Işık titremesi: bu node'un modulate'i hafifçe dalgalanır (kristal, kırmızı taş).
@export var flicker_path: NodePath = NodePath("")
@export var flicker_depth: float = 0.25
## Küçük parçacık (en fazla 12): renk + alan.
@export var motes_color: Color = Color(0, 0, 0, 0)
@export var motes_area: Vector2 = Vector2(260, 60)
## Odaya girişte tek sefer SFX (örn. kasada uzun yankı).
@export var enter_sfx: StringName = &""
@export var enter_db: float = -12.0
@export var enter_pitch: float = 0.5
## Bu bulmaca ilk çözülünce tek ton (örn. bahçede yükselen ton).
@export var solve_puzzle: StringName = &""
@export var solve_sfx: StringName = &"discovery"
@export var solve_pitch: float = 1.35

var _t: float = 0.0
var _next: float = 3.0
var _fl: CanvasItem = null
var _fl_t: float = 0.0
var _flash_rect: ColorRect = null


func _ready() -> void:
	_next = randf_range(maxf(ambient_min * 0.4, 0.5), ambient_max)
	if flicker_path != NodePath(""):
		_fl = get_node_or_null(flicker_path) as CanvasItem
	if motes_color.a > 0.0:
		_build_motes()
	if enter_sfx != &"":
		RoomManager.room_changed.connect(_on_room_changed)
	if solve_puzzle != &"":
		PuzzleManager.puzzle_solved.connect(_on_puzzle_solved)


func _exit_tree() -> void:
	if RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.disconnect(_on_room_changed)
	if PuzzleManager.puzzle_solved.is_connected(_on_puzzle_solved):
		PuzzleManager.puzzle_solved.disconnect(_on_puzzle_solved)


func _sfx(id: StringName, db: float, pitch: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(id, db, pitch)


func _on_room_changed(_from_room: StringName, to_room: StringName) -> void:
	var p := get_parent()
	if p and "room_id" in p and String(p.get("room_id")) == String(to_room):
		_sfx(enter_sfx, enter_db, enter_pitch)


func _on_puzzle_solved(id: StringName) -> void:
	if id == solve_puzzle and is_visible_in_tree():
		_sfx(solve_sfx, -10.0, solve_pitch)


func _build_motes() -> void:
	var m := CPUParticles2D.new()
	m.amount = 10
	m.lifetime = 5.0
	m.preprocess = 3.0
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = motes_area * 0.5
	m.direction = Vector2(0, -1)
	m.spread = 25.0
	m.gravity = Vector2.ZERO
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 9.0
	m.scale_amount_min = 1.0
	m.scale_amount_max = 2.0
	m.color = motes_color
	m.z_index = 5
	add_child(m)


func _process(delta: float) -> void:
	if _fl != null and is_instance_valid(_fl):
		_fl_t += delta
		if _fl_t >= 0.08:
			_fl_t = 0.0
			var k := 1.0 - randf() * flicker_depth
			_fl.modulate = Color(k, k, k, _fl.modulate.a)
	if ambient_sfx == &"":
		return
	if stop_when_solved != &"" and PuzzleManager.is_solved(stop_when_solved):
		return
	_t += delta
	if _t < _next:
		return
	_t = 0.0
	_next = ambient_min if ambient_regular else randf_range(ambient_min, ambient_max)
	_sfx(ambient_sfx, ambient_db, ambient_pitch)
	if flash and GameSettings.shake_enabled():
		_do_flash()


func _do_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	var r := ColorRect.new()
	r.color = Color(0.85, 0.9, 1.0, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.16, 0.05)
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)
