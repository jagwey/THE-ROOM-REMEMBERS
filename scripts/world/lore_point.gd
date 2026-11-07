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
		var base_mod := Color.WHITE
		if texture_path.ends_with("photograph.png"):
			## Beyaz kutu yerine koyu, yaşlanmış parşömen çerçeve.
			base_mod = Color(0.74, 0.62, 0.5, 1.0)
			_add_parchment_frame(spr)
		spr.modulate = base_mod
		add_child(spr)
		if not _done():
			var peak := Color(minf(base_mod.r * 1.08, 1.0), minf(base_mod.g * 1.06, 1.0), minf(base_mod.b * 1.08, 1.0), 1.0)
			var tw := spr.create_tween().set_loops()
			tw.tween_property(spr, "modulate", peak, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(spr, "modulate", base_mod, 0.9).set_trans(Tween.TRANS_SINE)


## Fotoğrafın arkasına koyu kahve kenar + soluk parşömen iç dolgu (sprite'ın altında).
func _add_parchment_frame(spr: Sprite2D) -> void:
	var tex := spr.texture
	if tex == null:
		return
	var half := Vector2(tex.get_width(), tex.get_height()) * spr.scale * 0.5 + Vector2(2.0, 2.0)
	var c := spr.position
	var outer := Polygon2D.new()
	outer.name = "ParchmentEdge"
	outer.color = Color(0.1, 0.07, 0.05, 0.95)
	outer.polygon = PackedVector2Array([c + Vector2(-half.x - 1.5, -half.y - 1.5), c + Vector2(half.x + 1.5, -half.y - 1.5), c + Vector2(half.x + 1.5, half.y + 1.5), c + Vector2(-half.x - 1.5, half.y + 1.5)])
	add_child(outer)
	var inner := Polygon2D.new()
	inner.name = "ParchmentBody"
	inner.color = Color(0.3, 0.22, 0.15, 0.95)
	inner.polygon = PackedVector2Array([c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + Vector2(half.x, half.y), c + Vector2(-half.x, half.y)])
	add_child(inner)


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


## Shilda adı verildi mi? Bayrak yoksa isim beat'inin bıraktığı bilgiden türetip bayrağa yazar
## (shilda_name_beat.gd başka ajanın; bayrağı burada kalıcılaştırıyoruz).
static func shilda_is_named() -> bool:
	if bool(GameState.get_world_flag(&"shilda_named", false)):
		return true
	if bool(GameState.player_progress_knowledge.get("shilda_named_partial", false)):
		GameState.set_world_flag(&"shilda_named", true)
		return true
	return false


func _say(entry: String) -> void:
	var parts := entry.split("|", true, 1)
	if parts.size() == 2:
		var who: String = parts[0]
		if who == "???" and shilda_is_named():
			who = "Shilda"
		DialogueManager.say(who, parts[1])
	else:
		DialogueManager.say("Noroi", entry)


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
