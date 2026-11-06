extends Area2D
## Etkileşimli yankı noktası — iptal ödül vermez (EchoManager).

@export var echo_id: StringName = &"awakening_rift_echo"
@export var once_per_life: bool = false

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		if s.texture == null:
			s.texture = load("res://assets/props/memory_mote.png")
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func on_interact(_by: Node) -> void:
	if _busy or EchoManager.active_echo != &"":
		return
	if once_per_life:
		var key := "echo_point_%s" % String(echo_id)
		if bool(GameState.character_current_life_knowledge.get(key, false)):
			DialogueManager.say("Shiren", "…Yankı suskun.")
			return
	_busy = true
	await EchoManager.play_echo(echo_id)
	if once_per_life and GameState.player_progress_knowledge.get("echoes_seen", []).has(String(echo_id)):
		GameState.character_current_life_knowledge["echo_point_%s" % String(echo_id)] = true
	_busy = false
