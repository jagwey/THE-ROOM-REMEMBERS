extends Area2D
## Kan Kristali / Lanet Dikeni — bilerek dokunulursa Noroi ölür ve bedeni plakada kalır.
## İlk "ağırlık cesedi" dersi: kapıyı açık tutmak için kendi cesedini bırak.

@export var anchor_x: float = 340.0 ## ölüm anında bedenin düşeceği x (plaka merkezi)
@export var puzzle_hint: StringName = &"awakening_seal_weight"
## Odaya özgü satırlar (boşsa Uyanış plakası metni).
@export var body_line: String = "Dokunursam ölürüm ama beden plakanın üstünde kalır."
@export var solved_line: String = "Kristal sustu. Beden plakayı tutuyor."

## >= 0 ise ölüm anında beden bu y'de (zemin üstü) kalır; boşluğun üstüne köprü için.
@export var anchor_y: float = -1.0
## Açıksa beden köprü olarak sabitlenir (alınamaz) ve zaten bir köprü varsa diken yeniden ölümü vermez.
@export var hold_corpse: bool = false
@export var hold_id: StringName = &"corpse_bridge"
## > 0 ise köprü bedeni varken altında bu genişlikte kemik kalas olur (ceset 28 px; telefonda iki yarım zıplama rahat olsun).
@export var bridge_plank_width: float = 0.0
## Doluysa bu dikende bilerek ölmek bu bulmacaları doğrudan çözer (cihazda plaka fiziği
## cesedi kaçırsa bile kapı kalıcı açılır; Sera gibi "doğru dikende öl" odaları).
@export var solve_on_death: PackedStringArray = PackedStringArray()

var _armed: bool = false
var _marker: Node2D
var _marker_poll: float = 0.0
var _ellipse := PackedVector2Array()
var _plank: StaticBody2D


func _ready() -> void:
	add_to_group("blood_thorn")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite2D"
		add_child(spr)
	spr.texture = load("res://assets/props/crystal.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = Color(1.0, 0.25, 0.32, 1.0)
	spr.scale = Vector2(0.55, 0.7)
	spr.position = Vector2(0, -18)
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "modulate", Color(1.3, 0.35, 0.4, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "modulate", Color(0.85, 0.2, 0.28, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	_build_marker()
	if hold_corpse and bridge_plank_width > 0.0:
		_build_plank()
		_update_plank.call_deferred()


## Köprü bedeninin altındaki kemik kalas: üst yüzü ceset üstüyle aynı (zemin -15), tek yönlü.
func _build_plank() -> void:
	_plank = StaticBody2D.new()
	_plank.name = "BridgePlank"
	_plank.collision_layer = 1
	_plank.collision_mask = 0
	_plank.z_index = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(bridge_plank_width, 10.0)
	cs.shape = rect
	cs.one_way_collision = true
	cs.one_way_collision_margin = 8.0
	_plank.add_child(cs)
	_plank.draw.connect(_draw_plank)
	add_child(_plank)
	var fy := anchor_y if anchor_y >= 0.0 else global_position.y
	_plank.global_position = Vector2(anchor_x, fy - 10.0)


func _draw_plank() -> void:
	var w := bridge_plank_width
	var bone := Color(0.78, 0.72, 0.62, 1.0)
	var dark := Color(0.42, 0.36, 0.3, 1.0)
	_plank.draw_rect(Rect2(-w * 0.5, -5.0, w, 6.0), bone)
	_plank.draw_rect(Rect2(-w * 0.5, 1.0, w, 2.0), dark)
	for k in [-1.0, 1.0]:
		_plank.draw_circle(Vector2(k * (w * 0.5 - 2.0), -4.0), 4.0, bone)
		_plank.draw_circle(Vector2(k * (w * 0.5 - 2.0), 0.0), 4.0, bone)
	var x := -w * 0.5 + 12.0
	while x < w * 0.5 - 10.0:
		_plank.draw_line(Vector2(x, -4.0), Vector2(x, 0.0), dark, 1.0)
		x += 14.0


func _update_plank() -> void:
	if _plank == null:
		return
	var on := _bridge_exists()
	_plank.visible = on
	var cs := _plank.get_child(0) as CollisionShape2D
	if cs:
		cs.set_deferred("disabled", not on)


## Beden düşeceği yeri (anchor_x) zeminde soluk işaretle; diken uzaktaysa ince noktalı çizgi bağla.
func _build_marker() -> void:
	for i in 16:
		var a := TAU * float(i) / 16.0
		_ellipse.append(Vector2(cos(a) * 20.0, sin(a) * 5.0))
	_marker = Node2D.new()
	_marker.name = "LandingMarker"
	_marker.z_index = -1
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	var mt := _marker.create_tween().set_loops()
	mt.tween_property(_marker, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
	mt.tween_property(_marker, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	_marker.queue_redraw()


func _draw_marker() -> void:
	var dx := anchor_x - global_position.x
	var dy := (anchor_y - global_position.y) if anchor_y >= 0.0 else 0.0
	var c := Vector2(dx, dy)
	var poly := PackedVector2Array()
	for p in _ellipse:
		poly.append(p + c)
	_marker.draw_colored_polygon(poly, Color(0.55, 0.05, 0.1, 0.22))
	poly.append(poly[0])
	_marker.draw_polyline(poly, Color(0.8, 0.12, 0.2, 0.4), 1.0)
	_marker.draw_line(c + Vector2(-7, -2), c + Vector2(7, 2), Color(0.85, 0.15, 0.22, 0.45), 1.0)
	_marker.draw_line(c + Vector2(-7, 2), c + Vector2(7, -2), Color(0.85, 0.15, 0.22, 0.45), 1.0)
	if absf(dx) > 40.0:
		var dir := signf(dx)
		var x := 14.0 * dir
		var end_x := dx - 24.0 * dir
		var col := Color(0.8, 0.12, 0.2, 0.3)
		while absf(x) < absf(end_x):
			_marker.draw_line(Vector2(x, dy), Vector2(x + 3.0 * dir, dy), col, 1.0)
			x += 9.0 * dir


func _process(delta: float) -> void:
	_marker_poll += delta
	if _marker_poll < 0.5 or _marker == null:
		return
	_marker_poll = 0.0
	_update_plank()
	var done := PuzzleManager.is_solved(puzzle_hint) or PuzzleManager.is_live(puzzle_hint)
	if not done and hold_corpse:
		done = _bridge_exists()
	_marker.visible = not done


func on_interact(by: Node) -> void:
	if DeathManager.is_dying:
		return
	if PuzzleManager.is_solved(puzzle_hint) or PuzzleManager.is_live(puzzle_hint):
		DialogueManager.say("Noroi", solved_line)
		return
	if hold_corpse and _bridge_exists():
		DialogueManager.say("Noroi", solved_line)
		return
	if not _armed:
		_armed = true
		DialogueManager.say("Noroi", "Kırmızı kristal. Dikenleri nabız gibi atıyor.")
		DialogueManager.say("Noroi", body_line)
		DialogueManager.say("Noroi", "(Yine dokunursan bilerek ölürsün.)")
		await DialogueManager.dialogue_finished
		return
	_armed = false
	var player := by as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var tw := player.create_tween()
		tw.tween_property(player, "global_position:x", anchor_x, 0.22).set_trans(Tween.TRANS_QUAD)
		await tw.finished
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.5)
	if player != null and player.has_method("note_safe_floor"):
		## Beden her zaman anchor_x'e düşsün (anchor_y yoksa son güvenli zemin yüksekliği).
		var fy := anchor_y
		if fy < 0.0:
			fy = player.get_last_safe_floor_pos().y if player.has_method("get_last_safe_floor_pos") else player.global_position.y
		player.note_safe_floor(Vector2(anchor_x, fy))
	var before := _corpse_ids()
	DeathManager.request_death(&"thorn")
	if DeathManager.is_dying:
		var changed := false
		for pid in solve_on_death:
			if not PuzzleManager.is_solved(StringName(pid)):
				PuzzleManager.mark_solved(StringName(pid))
				changed = true
		if changed:
			SaveManager.save_game()
	if hold_corpse:
		_hold_new_corpse(before)


func _bridge_exists() -> bool:
	var corpses: Array = GameState.world_memory_state.get("corpses", [])
	var room := String(GameState.character_current_life_knowledge.get("room", ""))
	for c in corpses:
		if String((c as Dictionary).get("anchor_plate", "")) == String(hold_id) and String((c as Dictionary).get("room", room)) == room:
			return true
	return false


func _corpse_ids() -> Array:
	var ids: Array = []
	for c in GameState.world_memory_state.get("corpses", []):
		ids.append(String((c as Dictionary).get("id", "")))
	return ids


## Ölümle YENİ kaydedilen bedeni köprü olarak sabitle (alınamaz; anchor_plate boş olmadığı için plaka hesapları dokunmaz).
## Ölüm reddedildiyse (yeni ceset yok) önceki hiçbir ceset sabitlenmez.
func _hold_new_corpse(ids_before: Array) -> bool:
	var corpses: Array = GameState.world_memory_state.get("corpses", [])
	for i in range(corpses.size() - 1, -1, -1):
		var c: Dictionary = corpses[i]
		if ids_before.has(String(c.get("id", ""))):
			continue
		c["anchored"] = true
		c["anchoring"] = true
		c["anchor_plate"] = String(hold_id)
		c["usable_for_puzzle"] = false
		CorpseManager.rebuild_world_corpses()
		_update_plank()
		return true
	return false
