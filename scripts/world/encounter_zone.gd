extends Area2D
## Shilda karşılaşması tetikleyicisi. Oyuncu girince (çözülmemişse) kısa konuşma + keeper.start_encounter.
## Bağlı CrackedWall yıkılınca karşılaşma biter, bulmaca çözülür ve güven artar.

@export var encounter_id: StringName = &"shilda_wall"
@export var puzzle_id: StringName = &"decay_shilda_wall_broken"
@export var wall_path: NodePath
@export var zone_size: Vector2 = Vector2(80, 120)

var _running: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = zone_size
	cs.shape = rect
	cs.position = Vector2(0, -zone_size.y * 0.5)
	add_child(cs)
	body_entered.connect(_on_enter)
	var wall := get_node_or_null(wall_path)
	if wall and wall.has_signal("broken"):
		wall.broken.connect(_on_wall_broken)
	DeathManager.death_started.connect(_on_chase_death)
	RoomManager.room_changed.connect(_on_room_changed)


func _on_chase_death(_reason: StringName) -> void:
	_running = false
	if RoomManager.get_active_room_id() != &"decay_shilda_wall" or PuzzleManager.is_solved(puzzle_id):
		return
	var n := int(GameState.player_progress_knowledge.get("wall_chase_deaths", 0)) + 1
	GameState.player_progress_knowledge["wall_chase_deaths"] = n


func _on_room_changed(_from_room: StringName, new_room: StringName) -> void:
	if new_room != &"decay_shilda_wall" and _running:
		_running = false
		var keeper := get_tree().get_first_node_in_group("keeper")
		if keeper and keeper.has_method("end_encounter"):
			keeper.end_encounter(false)


func _on_enter(body: Node) -> void:
	if _running or not body.is_in_group("player") or PuzzleManager.is_solved(puzzle_id):
		return
	if UiGate.pauses_world_threats() or DeathManager.is_dying:
		return
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper == null or not keeper.has_method("start_encounter"):
		return
	_running = true
	var first := not bool(GameState.player_progress_knowledge.get("encounter_%s_seen" % String(encounter_id), false))
	GameState.player_progress_knowledge["encounter_%s_seen" % String(encounter_id)] = true
	var fails := int(GameState.player_progress_knowledge.get("wall_chase_deaths", 0))
	if first:
		DialogueManager.say("Shilda", "Dur. Bu duvarın ardında… unutmaman gereken bir şey var.")
		DialogueManager.say("Shilda", "Ama önce göster bana: benden kaçabilir misin?")
		DialogueManager.say("Shilda", "Gözlerim kızarınca atıl. Duvarın önünde kal; son adımda kenara çekil.")
	else:
		DialogueManager.say("Shilda", "Yine mi. Atıl.")
	if fails >= 3:
		DialogueManager.say("Shilda", "Duvar yoruldu. Bir çarpma yeter. Kenara çekil.")
	elif fails == 2:
		DialogueManager.say("Shilda", "Boş yana atıl. İkinci çarpma taşı indirir.")
	elif fails == 1:
		DialogueManager.say("Shilda", "Gözler kızarınca son adımda kenara çekil.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok or DeathManager.is_dying:
		_running = false
		return
	keeper.start_encounter(encounter_id)


func _on_wall_broken(_id: StringName) -> void:
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper and keeper.has_method("end_encounter"):
		keeper.end_encounter(true)
	_running = false
	PuzzleManager.mark_solved(puzzle_id)
	GameState.player_progress_knowledge["shilda_wall_trust"] = true
	DialogueManager.say("Shilda", "…Affet. Seni incitmek istemedim.")
	DialogueManager.say("Shilda", "Bazen gerçeğe giden tek yol, bir duvarı kırmaktır.")
	SaveManager.save_game()
