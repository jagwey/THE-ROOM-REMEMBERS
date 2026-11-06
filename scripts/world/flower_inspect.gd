extends Area2D
## Bahçe çiçeği — incele + opsiyonel EchoManager kaydı.

@export var lines: PackedStringArray = PackedStringArray(["Kırmızı bir çiçek. Yapraklar kurumuş ama sapı hâlâ dik."])
@export var register_echo_id: String = ""
@export var echo_data: Dictionary = {}
@export var memory_code_key: String = ""
@export var memory_code_value: String = ""

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func on_interact(_by: Node) -> void:
	if _busy or DialogueManager.is_open:
		return
	_busy = true
	for line in lines:
		if str(line) != "":
			DialogueManager.say("Sen", str(line))
	var ok: bool = await DialogueManager.dialogue_finished
	if ok and register_echo_id != "" and not echo_data.is_empty():
		EchoManager.register_echo(register_echo_id, echo_data)
	if ok and memory_code_key != "" and memory_code_value != "":
		var codes: Dictionary = GameState.player_progress_knowledge.get("memory_codes", {})
		codes[memory_code_key] = memory_code_value
		GameState.player_progress_knowledge["memory_codes"] = codes
	_busy = false
