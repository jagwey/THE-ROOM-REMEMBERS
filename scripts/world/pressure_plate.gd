extends Area2D
## Ceset ağırlığıyla basılan plaka — kapı/yolu açar (mobil: cesedi it).

signal pressed_changed(is_pressed: bool)

@export var puzzle_id: StringName = &"awakening_weight"
@export var required_weight: int = 1
@export var accept_player: bool = false
## Doğal oturuşta ~1 px kaçırmayı tolere et (ışınlama ile test etme).
@export var overlap_slack: float = 8.0
## Eski davranış: basınca kalıcı çözülür (yalnız oyuncunun kendi basması gereken plakalar; Faz 2'de saksı tasarımına geçer).
@export var latch_on_press: bool = false
## false ise weight_stone gövdesi ağırlık saymaz (yalnız ceset; accept_player kuralı aynen).
@export var accept_stone: bool = true

var _pressed: bool = false


func _ready() -> void:
	add_to_group("pressure_plate")
	collision_layer = 0
	collision_mask = 1 | 64 ## corpses on world layer + echo twin
	if accept_player:
		collision_mask = 1 | 2 | 64
	monitoring = true
	body_entered.connect(func(_b): _recompute())
	body_exited.connect(func(_b): _recompute())
	if has_node("Sprite2D"):
		$Sprite2D.texture = load("res://assets/props/pressure_plate.png")
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Algı alanını biraz büyüt — doğal itişte tetiklensin
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var rect := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = Vector2(maxf(rect.size.x, 48.0), maxf(rect.size.y, 28.0))
		cs.shape = rect
	## v1.0 öncesi kayıtlar: oyuncu Çürüme bölgesine geçmişse mühür odası plakası çözülmüş sayılır.
	if puzzle_id == &"awakening_seal_weight" and not PuzzleManager.is_solved(puzzle_id):
		for r in GameState.player_progress_knowledge.get("rooms_visited", []):
			if String(r).begins_with("decay"):
				PuzzleManager.mark_solved(puzzle_id)
				break
	call_deferred("_recompute")


func _exit_tree() -> void:
	if _pressed:
		_pressed = false
		PuzzleManager.set_live(puzzle_id, false)


func _physics_process(_delta: float) -> void:
	if UiGate.pauses_world_threats():
		return
	# Area kaçırırsa mesafe toleransı ile yedek kontrol
	_recompute()


func _recompute() -> void:
	if not is_visible_in_tree():
		_set_pressed(false)
		return
	var seen: Dictionary = {}
	var total := 0
	for b in get_overlapping_bodies():
		if not b.is_visible_in_tree() or b.is_queued_for_deletion():
			continue
		seen[b] = true
		total += _weight_of(b)
	if total < required_weight:
		# Slack: Area2D ~1 px kaçırırsa yakındaki cesedi de say
		var near: Array = get_tree().get_nodes_in_group("corpse") + get_tree().get_nodes_in_group("weight_stone")
		for c in near:
			if seen.has(c) or not (c is Node2D):
				continue
			var n2 := c as Node2D
			if not n2.is_visible_in_tree() or n2.is_queued_for_deletion():
				continue
			if absf(global_position.x - n2.global_position.x) <= 30.0 + overlap_slack \
					and absf(global_position.y - n2.global_position.y) <= 24.0 + overlap_slack:
				total += _weight_of(c)
				seen[c] = true
	for c in get_tree().get_nodes_in_group("corpse"):
		if c.is_queued_for_deletion():
			continue
		var on_plate: bool = seen.has(c) and total >= required_weight
		if c.has_method("set_anchoring"):
			c.set_anchoring(on_plate, puzzle_id)
		elif c.has_method("set_anchored"):
			c.set_anchored(on_plate)
		elif "corpse_id" in c and String(c.corpse_id) != "":
			CorpseManager.set_corpse_anchored(String(c.corpse_id), on_plate)
	_set_pressed(total >= required_weight)


func _weight_of(b: Node) -> int:
	if b.is_in_group("corpse") and b.has_method("get_weight"):
		return int(b.get_weight())
	if accept_stone and b.is_in_group("weight_stone") and b.has_method("get_weight"):
		return int(b.get_weight())
	if b.is_in_group("echo_twin_body"):
		return 1
	if accept_player and b.is_in_group("player"):
		return 1
	return 0


func is_pressed() -> bool:
	return _pressed


func _set_pressed(value: bool) -> void:
	if _pressed == value:
		return
	_pressed = value
	modulate = Color(1.2, 0.7, 0.75, 1.0) if _pressed else Color.WHITE
	if _pressed:
		var cam := get_tree().get_first_node_in_group("follow_camera") if is_inside_tree() else null
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.14)
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(&"plate_press", -6.0)
	pressed_changed.emit(_pressed)
	## Canlı kural: ağırlık durdukça açık. Kalıcı çözüm geçişte gate_blocker'da yazılır.
	PuzzleManager.set_live(puzzle_id, _pressed)
	if _pressed and latch_on_press and not PuzzleManager.is_solved(puzzle_id):
		PuzzleManager.mark_solved(puzzle_id)
		SaveManager.save_game()
