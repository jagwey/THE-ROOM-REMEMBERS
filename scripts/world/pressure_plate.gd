extends Area2D
## Ceset ağırlığıyla basılan plaka — kapı/yolu açar (mobil: cesedi it).

signal pressed_changed(is_pressed: bool)

@export var puzzle_id: StringName = &"awakening_weight"
@export var required_weight: int = 1
@export var accept_player: bool = false
## Doğal oturuşta ~1 px kaçırmayı tolere et (ışınlama ile test etme).
@export var overlap_slack: float = 8.0

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
	var legacy_awakening := puzzle_id == &"awakening_weight" and bool(GameState.get_world_flag(&"awakening_door_opened", false))
	## v1.0 öncesi kayıtlar: oyuncu Çürüme bölgesine geçmişse mühür odası plakası çözülmüş sayılır.
	if puzzle_id == &"awakening_seal_weight" and not PuzzleManager.is_solved(puzzle_id):
		for r in GameState.player_progress_knowledge.get("rooms_visited", []):
			if String(r).begins_with("decay"):
				PuzzleManager.mark_solved(puzzle_id)
				break
	if PuzzleManager.is_solved(puzzle_id) or legacy_awakening:
		_set_pressed(true, false)


func _physics_process(_delta: float) -> void:
	if UiGate.pauses_world_threats():
		return
	# Area kaçırırsa mesafe toleransı ile yedek kontrol
	_recompute()


func _recompute() -> void:
	if not is_visible_in_tree():
		return
	var seen: Dictionary = {}
	var total := 0
	for b in get_overlapping_bodies():
		seen[b] = true
		total += _weight_of(b)
	if total < required_weight:
		# Slack: Area2D ~1 px kaçırırsa yakındaki cesedi de say
		for c in get_tree().get_nodes_in_group("corpse"):
			if seen.has(c) or not (c is Node2D):
				continue
			var n2 := c as Node2D
			if absf(global_position.x - n2.global_position.x) <= 30.0 + overlap_slack \
					and absf(global_position.y - n2.global_position.y) <= 24.0 + overlap_slack:
				total += _weight_of(c)
				seen[c] = true
	for c in get_tree().get_nodes_in_group("corpse"):
		if c.has_method("set_anchoring"):
			c.set_anchoring(seen.has(c) and total >= required_weight, puzzle_id)
	_set_pressed(total >= required_weight, true)


func _weight_of(b: Node) -> int:
	if b.is_in_group("corpse") and b.has_method("get_weight"):
		return int(b.get_weight())
	if b.is_in_group("weight_stone") and b.has_method("get_weight"):
		return int(b.get_weight())
	if b.is_in_group("echo_twin_body"):
		return 1
	if accept_player and b.is_in_group("player"):
		return 1
	return 0


func _set_pressed(value: bool, emit_solve: bool) -> void:
	if _pressed == value:
		return
	_pressed = value
	modulate = Color(1.2, 0.7, 0.75, 1.0) if _pressed else Color.WHITE
	pressed_changed.emit(_pressed)
	## Çözüm etkileri (mesaj, bayrak, kayıt) yalnız ilk çözümde — odaya dönüp plakaya tekrar basınca susar.
	if _pressed and emit_solve and not PuzzleManager.is_solved(puzzle_id):
		PuzzleManager.mark_solved(puzzle_id)
		if puzzle_id == &"awakening_weight":
			GameState.set_world_flag(&"awakening_door_opened", true)
			DialogueManager.say("???", "Bir şey… açıldı.")
		elif puzzle_id == &"decay_weight_latch":
			GameState.set_world_flag(&"decay_weight_latched", true)
			DialogueManager.say("???", "Mekanizmaya oturdu.")
		SaveManager.save_game()
