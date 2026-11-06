extends Area2D
## Bellek kodu — oyuncu yankıdan hatırlar; karakter bilmez.

@export var code_key: String = "awakening"
@export var puzzle_id: StringName = &"awakening_memory_code"


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
	if PuzzleManager.is_solved(puzzle_id):
		DialogueManager.say("Sen", "Mühür zaten açık.")
		return
	var codes: Dictionary = GameState.player_progress_knowledge.get("memory_codes", {})
	var code := String(codes.get(code_key, ""))
	if code == "":
		# Karakter bilmiyor.
		DialogueManager.say("Sen", "…Üzerinde çizikler. Bir kod mu?")
		DialogueManager.say("Sen", "Hatırlamıyorum.")
		return
	# Oyuncu meta bilgisi — karakter diyaloğu gibi görünse de bilgi player katmanından.
	DialogueManager.say("Sen", "(İçimden: %s… evet.)" % _spaced(code))
	DialogueManager.say("Sen", "Mühür… gevşedi.")
	await DialogueManager.dialogue_closed
	PuzzleManager.mark_solved(puzzle_id)
	GameState.set_world_flag(&"awakening_crystal_cracked", true)
	modulate = Color(0.6, 0.9, 0.7, 1)
	SaveManager.save_game()


func _spaced(code: String) -> String:
	var parts: PackedStringArray = []
	for i in code.length():
		parts.append(code.substr(i, 1))
	return " ".join(parts)
