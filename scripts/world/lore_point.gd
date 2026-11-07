extends Area2D
## Genel hikâye/kanıt noktası: satırlar oynatır, günlüğe kanıt yazar, bayrak/bulmaca işaretler.
## lines: ["Konuşmacı|Metin", ...]. repeat_lines tekrar etkileşimde söylenir.

@export var lore_id: StringName = &"lore"
@export var texture_path: String = "res://assets/props/photograph.png"
@export var sprite_scale: float = 0.6
@export var lines: PackedStringArray = PackedStringArray()
@export var repeat_line: String = ""
@export var evidence_title: String = ""
@export_multiline var evidence_body: String = ""
@export var evidence_section: String = "notlar"
@export var set_flag: StringName = &""
@export var solve_puzzle: StringName = &""
@export var set_progress_key: String = "" ## player_progress_knowledge[key] = true
@export var focus_zoom: bool = false

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
		cs.position = Vector2(0, -8)
		add_child(cs)
	if texture_path != "":
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(sprite_scale, sprite_scale)
		spr.position = Vector2(0, -12)
		add_child(spr)
		if not _done():
			var tw := spr.create_tween().set_loops()
			tw.tween_property(spr, "modulate", Color(1.25, 1.1, 1.25, 1), 0.8).set_trans(Tween.TRANS_SINE)
			tw.tween_property(spr, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _done() -> bool:
	var seen: Array = GameState.player_progress_knowledge.get("lore_seen", [])
	return seen.has(String(lore_id))


func on_interact(_by: Node) -> void:
	if _busy:
		return
	if _done() and repeat_line != "":
		_say(repeat_line)
		return
	_busy = true
	if focus_zoom:
		var cam := get_tree().get_first_node_in_group("follow_camera")
		if cam and cam.has_method("zoom_to"):
			cam.zoom_to(1.22, 2.5)
	for l in lines:
		_say(l)
	var ok: bool = await DialogueManager.dialogue_finished
	_busy = false
	if not ok:
		return
	var seen: Array = GameState.player_progress_knowledge.get("lore_seen", [])
	if not seen.has(String(lore_id)):
		seen.append(String(lore_id))
	GameState.player_progress_knowledge["lore_seen"] = seen
	if evidence_title != "":
		record_evidence("ev_%s" % String(lore_id), evidence_title, evidence_body, evidence_section)
	if set_flag != &"":
		GameState.set_world_flag(set_flag, true)
	if solve_puzzle != &"":
		PuzzleManager.mark_solved(solve_puzzle)
	if set_progress_key != "":
		GameState.player_progress_knowledge[set_progress_key] = true
	SaveManager.save_game()


func _say(entry: String) -> void:
	var parts := entry.split("|", true, 1)
	if parts.size() == 2:
		DialogueManager.say(parts[0], parts[1])
	else:
		DialogueManager.say("Shiren", entry)


static func record_evidence(eid: String, title: String, body: String, section: String = "notlar", kind: String = "evidence") -> void:
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}
	var ev: Dictionary = GameState.player_progress_knowledge["evidence"]
	if ev.has(eid):
		return
	ev[eid] = {"id": eid, "discovered": true, "kind": kind, "title": title, "body": body, "section": section}
	var notes: Array = GameState.player_progress_knowledge.get("journal_notes", [])
	notes.append({"evidence_id": eid, "section": section, "title": title, "body": body, "kind": kind})
	GameState.player_progress_knowledge["journal_notes"] = notes
	GameState.player_progress_knowledge["journal_unlocked"] = true
	EchoManager.journal_updated.emit()
