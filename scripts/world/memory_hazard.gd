extends Area2D
## Visible memory fracture. Warn, allow retreat, then deal one avoidable heart of damage.

@export var hazard_id: StringName = &"awakening_rift"
@export var arm_requires_mystery: bool = true
## Geçit tehlikeleri: tek temasta yalnızca bir kalp (ölüm döngüsü yok).
@export var passage_one_heart_cap: bool = false

var _armed: bool = false
var _warned: bool = false
var _warning_open: bool = false
var _grace: float = 0.0
var _hit_cooldown: float = 0.0
var _hits_this_life: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	visible = false
	var hid: String = String(hazard_id)
	if hid.begins_with("passage_"):
		passage_one_heart_cap = true
	if DeathManager.has_signal("rebirth_completed"):
		DeathManager.rebirth_completed.connect(_on_rebirth_completed)
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		s.texture = load("res://assets/props/halo.png")
		s.modulate = Color(0.95, 0.28, 0.35, 0.8)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if not _armed:
		var mystery_ok: bool = bool(GameState.player_progress_knowledge.get("awakening_mystery_seen", false))
		## Uyanışta kırmızı yarık öğretimi plakadan sonra gelsin; erken oyunda tıkanma yok.
		var plate_teach_ok: bool = true
		if hazard_id == &"awakening_rift":
			plate_teach_ok = PuzzleManager.is_solved(&"awakening_weight") or bool(GameState.get_world_flag(&"awakening_door_opened", false))
		if (not arm_requires_mystery or mystery_ok) and plate_teach_ok:
			_armed = true
			visible = true
			GameState.set_world_flag(&"hazard_rift_seen", true)
		return
	if UiGate.pauses_world_threats() or not is_visible_in_tree() or _warning_open:
		return
	_grace = maxf(0.0, _grace - delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	for body in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		if not _warned:
			_warn(body)
			return
		if _grace <= 0.0 and _hit_cooldown <= 0.0 and body.has_method("receive_hazard_hit"):
			if passage_one_heart_cap and _hits_this_life >= 1:
				continue
			if body.receive_hazard_hit(global_position.x):
				_hit_cooldown = 2.0
				_hits_this_life += 1
				GameState.set_world_flag(&"awakening_trap_sprung", true)


func _warn(_body: Node) -> void:
	_warned = true
	_warning_open = true
	DialogueManager.say("Shilda", "Kırmızı yarıklar anılarını koparır. Geri çekil; dar yarıkları atılarak geçebilirsin (%s)." % MobileInputManager.control_name(&"dash"))
	await DialogueManager.dialogue_finished
	# Time starts after the player can actually move, never during the warning dialogue.
	_grace = 4.0
	_warning_open = false


func _on_rebirth_completed() -> void:
	_hits_this_life = 0
