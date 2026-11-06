extends AnimatableBody2D
## Fiziksel ceset — Echo + iterek ağırlık bulmacası (mobil: Etkileş).

@export var corpse_id: String = ""
@export var echo_id: StringName = &""
@export var weight: int = 1
@export var usable_for_puzzle: bool = true
@export var push_step: float = 36.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flower: Sprite2D = $Flower
@onready var interact: Area2D = $InteractArea

var _data: Dictionary = {}
var _echo_done: bool = false


func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	if interact:
		interact.collision_layer = 8
		interact.collision_mask = 0
		interact.monitoring = false
		interact.monitorable = true


func setup_from_data(data: Dictionary) -> void:
	_data = data
	corpse_id = String(data.get("id", ""))
	echo_id = StringName(String(data.get("echo_id", "echo_%s" % corpse_id)))
	weight = int(data.get("weight", 1))
	usable_for_puzzle = bool(data.get("usable_for_puzzle", true))
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0})
	global_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	_echo_done = seen.has(String(echo_id)) or seen.has("awakening_rift_echo")
	if sprite:
		sprite.texture = load("res://assets/props/body_echo.png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.offset = Vector2(0, -20)
	if flower:
		flower.texture = load("res://assets/props/red_flower.png")
		flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flower.visible = bool(data.get("has_flower", false))
		flower.position = Vector2(10, -8)


func on_interact(by: Node) -> void:
	if DialogueManager.is_open:
		DialogueManager.advance()
		return
	# İlk etkileşim: Echo (oyuncu bilgisi).
	if not _echo_done:
		_echo_done = true
		var eid := echo_id
		if bool(GameState.player_progress_knowledge.get("first_death_seen", false)):
			eid = &"awakening_rift_echo"
		await EchoManager.play_echo(eid)
		DialogueManager.say("Sen", "…Ağır. İtebilirim.")
		return
	# Sonraki: cesedi oyuncunun baktığı yöne it (mobil dostu).
	var dir := 1.0
	if by and by.has_method("get_facing"):
		dir = float(by.get_facing())
	elif by:
		dir = signf(by.global_position.x - global_position.x) * -1.0
		if dir == 0.0:
			dir = 1.0
	_push(dir)


func _push(dir: float) -> void:
	if not usable_for_puzzle:
		return
	global_position.x = clampf(global_position.x + dir * push_step, 40.0, 620.0)
	_persist_position()
	DialogueManager.say("Sen", "…İttim.")


func _persist_position() -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			c["position"] = {"x": global_position.x, "y": global_position.y}
			break
	# Plakayı yenile
	for p in get_tree().get_nodes_in_group("pressure_plate"):
		if p.has_method("_recompute"):
			p._recompute()
	SaveManager.save_game()


func get_weight() -> int:
	return weight if usable_for_puzzle else 0
