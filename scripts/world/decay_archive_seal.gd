extends Area2D
## Arşiv mührü — bahçe çiçeğinden hatırlanan kod (memory_codes["decay_archive"]).

@export var code_key: String = "decay_archive"
@export var puzzle_id: StringName = &"decay_archive_key"
@export var story_code: String = "729"

var _busy: bool = false
var _session: int = 0


func _ready() -> void:
	add_to_group("memory_seal")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if has_node("Sprite2D"):
		$Sprite2D.texture = load("res://assets/props/seal.png")
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if PuzzleManager.is_solved(puzzle_id):
		modulate = Color(0.6, 0.9, 0.7, 1)


func on_interact(_by: Node) -> void:
	if _busy:
		return
	if PuzzleManager.is_solved(puzzle_id):
		DialogueManager.say("Shiren", "Mühür zaten açık.")
		return
	_busy = true
	_session += 1
	var session := _session
	var expected := story_code
	var codes: Dictionary = GameState.player_progress_knowledge.get("memory_codes", {})
	var known := String(codes.get(code_key, ""))
	if known == "":
		DialogueManager.say("Shiren", "…Semboller var. Bir anahtar gibi.")
		DialogueManager.say("Shiren", "Bahçede bir şey hatırlatsa…")
		var done_empty: bool = await DialogueManager.dialogue_finished
		if session != _session or not done_empty:
			_busy = false
			return
		_busy = false
		return

	DialogueManager.say("Shiren", "…Sayılar geliyor. Deneyeyim.")
	var intro_ok: bool = await DialogueManager.dialogue_finished
	if session != _session or not intro_ok:
		_busy = false
		return

	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = get_tree().root.find_child("HUD", true, false)
	var entered := ""
	if hud and hud.has_method("prompt_seal_code"):
		entered = await hud.prompt_seal_code()
	else:
		entered = ""

	if session != _session:
		_busy = false
		return

	if entered == "":
		DialogueManager.say("Shiren", "…Vazgeçtim.")
		await DialogueManager.dialogue_finished
		_busy = false
		return

	if entered == expected:
		DialogueManager.say("Shiren", "(İçimden: %s… evet.)" % _spaced(entered))
		DialogueManager.say("Shiren", "Arşiv kapısı… gevşedi.")
		var confirm_ok: bool = await DialogueManager.dialogue_finished
		if session != _session or not confirm_ok:
			_busy = false
			return
		PuzzleManager.mark_solved(puzzle_id)
		modulate = Color(0.6, 0.9, 0.7, 1)
		SaveManager.save_game()
	else:
		DialogueManager.say("Shiren", "…Yanlış. Mühür sert.")
		await DialogueManager.dialogue_finished
	_busy = false


func _spaced(code: String) -> String:
	var parts: PackedStringArray = []
	for i in code.length():
		parts.append(code.substr(i, 1))
	return " ".join(parts)
