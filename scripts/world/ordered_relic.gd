extends Area2D

const LorePointScript := preload("res://scripts/world/lore_point.gd")
## Sıralı iz: needs anahtarı yoksa kilitli satır, varsa diyalog seti ve isteğe bağlı bulmaca.

@export var relic_id: String = ""
@export var needs: String = ""
@export var dialogue_room: StringName = &""
@export var dialogue_set: StringName = &""
@export var solve_puzzle: StringName = &""
## Doluysa: bu bulmaca çözülmeden iz tamamen sessizdir (diyalog yok, kayıt yok).
@export var requires_puzzle: StringName = &""
@export var locked_line: String = "Önce öteki iz."
@export var count_line: bool = false
@export var need_soul: bool = false
@export var need_dash: bool = false
## Boşsa varsayılan satır. Yeteneğin alındığı odanın adını içerebilir.
@export var soul_refusal_line: String = ""
@export var dash_refusal_line: String = ""
@export var evidence_title: String = ""
@export_multiline var evidence_body: String = ""

var _busy: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 48)
		cs.shape = rect
		add_child(cs)


func on_interact(_by: Node) -> void:
	if _busy:
		return
	if requires_puzzle != &"" and not PuzzleManager.is_solved(requires_puzzle):
		return
	_busy = true
	if need_soul and not bool(GameState.player_progress_knowledge.get("ability_soul_slash", false)):
		DialogueManager.say("Noroi", soul_refusal_line if soul_refusal_line != "" else "Son basamak Ruh Kesimi istiyor.")
		await DialogueManager.dialogue_finished
		_busy = false
		return
	if need_dash and not bool(GameState.player_progress_knowledge.get("ability_shadow_dash", false)):
		DialogueManager.say("Noroi", dash_refusal_line if dash_refusal_line != "" else "Aralık Gölge Atılması istiyor.")
		await DialogueManager.dialogue_finished
		_busy = false
		return
	var seen: Dictionary = GameState.player_progress_knowledge.get("relics", {})
	if needs != "" and not bool(seen.get(needs, false)):
		DialogueManager.say("Noroi", locked_line)
		await DialogueManager.dialogue_finished
		_busy = false
		return
	seen[relic_id] = true
	GameState.player_progress_knowledge["relics"] = seen
	if dialogue_set != &"":
		var lines: Array = DialogueData.get_set(dialogue_room, dialogue_set)
		for line in lines:
			DialogueManager.say(String(line[0]), String(line[1]))
	if count_line:
		DialogueManager.say("Noroi", "Duvar üç beden sayıyor. Üçü de benim.")
	var ok: bool = await DialogueManager.dialogue_finished
	if ok:
		if evidence_title != "":
			LorePointScript.record_evidence("ev_%s" % relic_id, evidence_title, evidence_body, "izler")
		if solve_puzzle != &"":
			PuzzleManager.mark_solved(solve_puzzle)
		SaveManager.save_game()
	_busy = false
