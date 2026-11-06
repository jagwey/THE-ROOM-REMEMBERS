extends Area2D
## İlk anlamlı ölüm tuzağı — gizem/uyarı sonrası. Bekçi öldürmez; bu öğretir.

@export var hazard_id: StringName = &"awakening_rift"
@export var arm_requires_mystery: bool = true

var _armed: bool = false
var _warned: bool = false
var _killing: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	visible = false
	body_entered.connect(_on_body_entered)
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		s.texture = load("res://assets/props/halo.png")
		s.modulate = Color(0.7, 0.2, 0.28, 0.55)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if _armed:
		return
	if not arm_requires_mystery:
		_arm()
		return
	if bool(GameState.player_progress_knowledge.get("awakening_mystery_seen", false)):
		_arm()


func _arm() -> void:
	_armed = true
	GameState.set_world_flag(&"hazard_rift_seen", true)
	visible = true


func _player_inside() -> bool:
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false


func _on_body_entered(body: Node) -> void:
	if not _armed or _killing:
		return
	if not body.is_in_group("player"):
		return
	var life_warned := bool(GameState.character_current_life_knowledge.get("warned_hazard", false))
	if not life_warned and not _warned:
		_warned = true
		GameState.character_current_life_knowledge["warned_hazard"] = true
		DialogueManager.say("???", "Zemin… yanlış.")
		DialogueManager.say("???", "Dokunma.")
		await DialogueManager.dialogue_closed
		# Uyarıdan sonra hâlâ riftteyse — öğretici ölüm (Bekçi değil).
		if _player_inside() and not DeathManager.is_dying:
			await _kill_player()
		return
	# Bu hayatta zaten uyarıldıysa ikinci temas öldürür.
	await _kill_player()


func _kill_player() -> void:
	if _killing or DeathManager.is_dying:
		return
	_killing = true
	GameState.set_world_flag(&"awakening_trap_sprung", true)
	DialogueManager.clear()
	DialogueManager.say("Sen", "—!")
	await get_tree().create_timer(0.2).timeout
	DeathManager.request_death(hazard_id)
	await DeathManager.rebirth_completed
	_killing = false
	_warned = false
