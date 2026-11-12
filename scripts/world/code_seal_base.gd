extends Area2D
## Ortak bellek-kodu mührü. Tuş takımı HER ZAMAN açılır; doğru kodda üç tepki:
## aynı yaşamda öğrenildi / önceki yaşamda öğrenildi (beden hatırlar) / hiç görülmedi (oyuncu hatırlar).
## 3x4 KEYPAD layout & notch-covering fullscreen dim (anchor_right = 1.0, columns = 3, set_anchors_preset).

@export var code_key: String = "awakening"
@export var puzzle_id: StringName = &"awakening_memory_code"
@export var story_code: String = "314"
@export var intro_line: String = "…Üzerinde çizikler. Bir kod mu?"
@export var solved_line: String = "Mühür… gevşedi."
@export var wrong_line: String = "…Yanlış. Mühür kımıldamadı."

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
		DialogueManager.say("Noroi", "Mühür zaten açık.")
		return
	_busy = true
	_session += 1
	var session := _session
	var reaction := GameState.memory_code_reaction(code_key)
	if reaction == &"unknown":
		DialogueManager.say("Noroi", intro_line)
	else:
		DialogueManager.say("Noroi", "…Bir sayı geliyor aklıma. Denemeliyim.")
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
	if session != _session:
		_busy = false
		return
	if entered == "":
		DialogueManager.say("Noroi", "…Vazgeçtim.")
		await DialogueManager.dialogue_finished
		_busy = false
		return

	if entered == story_code:
		_camera_focus()
		match reaction:
			&"same_life":
				DialogueManager.say("Noroi", "Yankıdaki sayı buydu… %s." % _spaced(entered))
			&"past_life":
				DialogueManager.say("Noroi", "Bu sembollerin anlamını bilmiyorum…")
				DialogueManager.say("Noroi", "Ellerim bu şifreyi nereden bildi?!")
			_:
				DialogueManager.say("Noroi", "…Ben bunu hiç görmedim.")
				DialogueManager.say("Noroi", "Zihnimin içinde başka biri var, parmaklarımı kim yönetiyor?!")
		DialogueManager.say("Noroi", solved_line)
		var confirm_ok: bool = await DialogueManager.dialogue_finished
		if session != _session or not confirm_ok:
			_busy = false
			return
		if reaction == &"unknown":
			GameState.player_progress_knowledge["foreign_memory_used"] = true
		GameState.learn_memory_code(code_key, story_code)
		PuzzleManager.mark_solved(puzzle_id)
		_on_solved()
		modulate = Color(0.6, 0.9, 0.7, 1)
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"seal_open")
		SaveManager.save_game()
	else:
		DialogueManager.say("Noroi", wrong_line)
		if reaction == &"unknown":
			DialogueManager.say("Noroi", "Bir yerde… bir yankı bunu söylemiş olmalı.")
		await DialogueManager.dialogue_finished
	_busy = false


## Alt sınıflar dünya bayrağı vb. için override eder.
func _on_solved() -> void:
	pass


func _camera_focus() -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("zoom_to"):
		cam.zoom_to(1.22, 1.6)


func _spaced(code: String) -> String:
	var parts: PackedStringArray = []
	for i in code.length():
		parts.append(code.substr(i, 1))
	return " ".join(parts)
