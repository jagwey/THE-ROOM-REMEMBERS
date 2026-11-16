extends "res://scripts/world/lore_point.gd"
## Geri dönüş köşesi kaydı: bir yetenek kapısının ardında (record) ya da aynı odadaki ikinci parça (fragment).
## Kayıt yalnız kapı açıksa VE parça okunduysa alınır. Alınca "nooks" bayrağı kalıcıdır; günlük "Kayıtlar N/8" sayar.

const TOTAL := 8

@export var nook_id: String = ""
## "fragment" (açık parça) ya da "record" (kapının ardındaki kayıt).
@export var role: String = "record"
## "soul" (Ruh Kesimi) ya da "dash" (Gölge Atılması).
@export var ability: String = "soul"
@export var gate_puzzle: StringName = &""
@export var frag_id: String = ""
@export var refusal_line: String = ""
@export var gate_hint: String = ""
@export var need_line: String = ""


static func nook_flags() -> Dictionary:
	var d: Variant = GameState.player_progress_knowledge.get("nooks", {})
	return d if d is Dictionary else {}


static func count() -> int:
	var n := 0
	for k in nook_flags():
		if bool(nook_flags()[k]):
			n += 1
	return mini(n, TOTAL)


static func has_nook(id: String) -> bool:
	return bool(nook_flags().get(id, false))


func _has_ability() -> bool:
	var key := "ability_soul_slash" if ability == "soul" else "ability_shadow_dash"
	return bool(GameState.player_progress_knowledge.get(key, false))


func _frag_seen() -> bool:
	if frag_id == "":
		return true
	var seen: Array = GameState.player_progress_knowledge.get("lore_seen", [])
	return seen.has(frag_id)


func _default_hint() -> String:
	if ability == "soul":
		return "Damarı ruhumla kesmeliyim; Ruh Kesimi dalgası tam üstüne değmeli."
	return "Çizgiyi yürüyerek geçemem; Gölge Atılması ile içinden atılmalıyım."


func _default_refusal() -> String:
	if ability == "soul":
		return "Damar mühürlü; Ruh Kesimi'ni Yasak Kanat'ta bulmadan açamam."
	return "Çizgi beni geri itiyor; Gölge Atılması'nı Ayna Tapınağı'nda bulmalıyım."


func _refuse(line: String) -> void:
	_busy = true
	DialogueManager.say("Noroi", line)
	await DialogueManager.dialogue_finished
	_busy = false


func on_interact(by: Node) -> void:
	if _busy:
		return
	if role == "record":
		if gate_puzzle != &"" and not PuzzleManager.is_solved(gate_puzzle):
			if not _has_ability():
				await _refuse(refusal_line if refusal_line != "" else _default_refusal())
			else:
				await _refuse(gate_hint if gate_hint != "" else _default_hint())
			return
		if not _frag_seen():
			await _refuse(need_line)
			return
	await super.on_interact(by)
	if role == "record" and _done() and nook_id != "" and not has_nook(nook_id):
		var d := nook_flags()
		d[nook_id] = true
		GameState.player_progress_knowledge["nooks"] = d
		SaveManager.save_game()
