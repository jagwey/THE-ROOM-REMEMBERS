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
@export var story_flag_ids: PackedStringArray = PackedStringArray() ## okununca GameState.set_story_flag

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
		var _ur := spr.texture.get_image().get_used_rect() if spr.texture else Rect2i()
		if _ur.size.y > 0 and not texture_path.ends_with("photograph.png"):
			spr.position = Vector2(0, -(float(_ur.end.y) - spr.texture.get_height() * 0.5) * sprite_scale)
		elif _ur.size.y > 0:
			spr.position = Vector2(0, -22)
		var base_mod := Color.WHITE
		if texture_path.ends_with("photograph.png"):
			## Beyaz kutu yerine koyu, yaşlanmış parşömen çerçeve.
			base_mod = Color(0.74, 0.62, 0.5, 1.0)
			_add_parchment_frame(spr)
		spr.modulate = base_mod
		if texture_path.ends_with("memory_echo.png"):
			## Karanlık odalarda okunur olsun: toplamsal yumuşak hale.
			var halo := Sprite2D.new()
			halo.texture = spr.texture
			halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			halo.position = spr.position
			halo.scale = spr.scale * 1.7
			halo.modulate = Color(0.8, 0.65, 1.0, 1.0)
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			halo.material = mat
			add_child(halo)
			var htw := halo.create_tween().set_loops()
			htw.tween_property(halo, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
			htw.tween_property(halo, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		add_child(spr)
		if not _done():
			var peak := Color(minf(base_mod.r * 1.08, 1.0), minf(base_mod.g * 1.06, 1.0), minf(base_mod.b * 1.08, 1.0), 1.0)
			var tw := spr.create_tween().set_loops()
			tw.tween_property(spr, "modulate", peak, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(spr, "modulate", base_mod, 0.9).set_trans(Tween.TRANS_SINE)


## Fotografin arkasina ince, parlayan anı çerçevesi (sprite'ın altında).
func _add_parchment_frame(spr: Sprite2D) -> void:
	if spr.texture == null:
		return
	var fr := Sprite2D.new()
	fr.name = "MemoryFrame"
	fr.texture = load("res://assets/props/memory_frame.png")
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fr.position = spr.position
	fr.scale = Vector2.ONE * (spr.texture.get_width() * spr.scale.x / 56.0 * 1.1)
	add_child(fr)
	var tw := fr.create_tween().set_loops()
	tw.tween_property(fr, "modulate:a", 0.7, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fr, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


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
	for sf in story_flag_ids:
		GameState.set_story_flag(StringName(sf), true)
	if String(RoomManager.get_active_room_id()).begins_with("library"):
		GameState.set_story_flag(&"first_archive_record_read", true)
	if solve_puzzle != &"":
		PuzzleManager.mark_solved(solve_puzzle)
	if set_progress_key != "":
		GameState.player_progress_knowledge[set_progress_key] = true
	SaveManager.save_game()


## Shilda adı verildi mi? Tek kaynak: GameState.is_shilda_named().
static func shilda_is_named() -> bool:
	return GameState.is_shilda_named()


func _say(entry: String) -> void:
	var parts := entry.split("|", true, 1)
	if parts.size() == 2:
		DialogueManager.say(parts[0], parts[1]) ## "Shilda"/"???" kartı DialogueManager çözer
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
