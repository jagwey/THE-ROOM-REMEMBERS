extends Node2D
## Gözlem Camı: ceset projektör plakasını tutarken cam arkasında Shilda yankısı yürür.
## Sona varınca "notes" seti oynar ve `experiment_observation` çözülür. Ceset kalkarsa yankı durur,
## plaka yeniden dolunca baştan başlar.

const SHADE := preload("res://scripts/world/trace_shade.gd")
const LorePointScript := preload("res://scripts/world/lore_point.gd")
const PLATE_ID := &"experiment_observation_projector"
const SOLVE_ID := &"experiment_observation"
const ROOM_ID := &"experiment_observation"
const PATH := [Vector2(440, 250), Vector2(590, 250), Vector2(740, 250)]

var _shade: Node2D = null
var _finishing: bool = false


func _ready() -> void:
	add_to_group("observation_echo")
	PuzzleManager.live_changed.connect(_on_live)
	call_deferred("_sync")


func _sync() -> void:
	if PuzzleManager.is_live(PLATE_ID):
		_spawn()


func _on_live(id: StringName, live: bool) -> void:
	if id != PLATE_ID:
		return
	if live:
		_spawn()
	else:
		_stop()


func _spawn() -> void:
	if _shade != null or _finishing or PuzzleManager.is_solved(SOLVE_ID):
		return
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "ShildaEcho"
	s.set("shade_id", &"observation_shilda")
	s.set("fake", false)
	s.set("waypoints", PackedVector2Array(PATH))
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/props/memory_echo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.6, 0.6)
	spr.modulate = Color(0.7, 0.85, 1.0, 0.6)
	s.add_child(spr)
	s.z_index = 3
	add_child(s)
	s.global_position = PATH[0]
	s.connect("reached", _on_reached)
	_shade = s
	s.call("start")


func _stop() -> void:
	if _shade != null and is_instance_valid(_shade) and not _finishing:
		_shade.queue_free()
	if not _finishing:
		_shade = null


func _on_reached(_id: StringName) -> void:
	if _finishing or PuzzleManager.is_solved(SOLVE_ID):
		return
	_finishing = true
	var lines: Array = DialogueData.get_set(ROOM_ID, &"notes")
	for line in lines:
		DialogueManager.say(String(line[0]), String(line[1]))
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		LorePointScript.record_evidence("ev_observation_notes", "Sayım Notu",
			"Gözlem camının masasında Denek 14'ün ölümleri sayılı. İmza kazınmış, yüz yok.", "izler")
		PuzzleManager.mark_solved(SOLVE_ID)
		SaveManager.save_game()
		if _shade != null and is_instance_valid(_shade):
			var tw := create_tween()
			tw.tween_property(_shade, "modulate:a", 0.0, 1.2)
			tw.tween_callback(_shade.hide)
	else:
		# diyalog yarıda kesildi: yankı baştan başlasın
		if _shade != null and is_instance_valid(_shade):
			_shade.queue_free()
		_shade = null
		_finishing = false
		if PuzzleManager.is_live(PLATE_ID):
			_spawn()
