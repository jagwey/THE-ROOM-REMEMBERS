extends Node2D
## Nöbet odası iz gölgeleri: 3 gölge, biri doğru. Doğru olan sağdaki kapıya kadar yürür ve
## `awakening_vigil_trace` bulmacasını çözer. Sahteler yarıda söner. Gölgeler kayda geçmez:
## iz çözüldüyse hiç kurulmaz, konuşma bittiyse (yeniden giriş) kendiliğinden başlar.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const TRACE_ID := &"awakening_vigil_trace"
const REAL_ID := &"vigil_shade_true"

var _shades: Array = []


func _ready() -> void:
	add_to_group("vigil_shades")
	if PuzzleManager.is_solved(TRACE_ID) or PuzzleManager.is_solved(&"awakening_vigil"):
		return
	_spawn(&"vigil_shade_true", false, "", PackedVector2Array([Vector2(720, 252), Vector2(900, 252), Vector2(1080, 252), Vector2(1180, 252)]))
	_spawn(&"vigil_shade_left", true, "Bu iz soğuk. Yanlış gölgenin peşine düştüm.", PackedVector2Array([Vector2(600, 252), Vector2(420, 252), Vector2(260, 252)]))
	_spawn(&"vigil_shade_near", true, "Ses vermiyor, sadece solup gitti. Bu da değil.", PackedVector2Array([Vector2(760, 252), Vector2(860, 252), Vector2(940, 252)]))
	if bool(GameState.player_progress_knowledge.get("vigil_talk_done", false)):
		start_all()


func start_all() -> void:
	for s in _shades:
		if is_instance_valid(s):
			s.start()


func _spawn(id: StringName, is_fake: bool, line: String, path: PackedVector2Array) -> void:
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = String(id)
	s.set("shade_id", id)
	s.set("fake", is_fake)
	s.set("fake_line", line)
	s.set("waypoints", path)
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/memory_echo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.6, 0.6)
	spr.modulate = Color(0.75, 0.7, 0.95, 0.55)
	s.add_child(spr)
	s.z_index = 3
	add_child(s)
	s.global_position = path[0]
	s.connect("reached", _on_reached)
	_shades.append(s)


func _on_reached(shade_id: StringName) -> void:
	if shade_id != REAL_ID or PuzzleManager.is_solved(TRACE_ID):
		return
	PuzzleManager.mark_solved(TRACE_ID)
	_clear_shades.call_deferred()


## İz çözülünce kalan gölgeler (sahteler dahil) kaldırılır; oda önbellekte kalsa da yürümeye devam etmez.
func _clear_shades() -> void:
	for s in _shades:
		if is_instance_valid(s):
			s.queue_free()
	_shades.clear()
