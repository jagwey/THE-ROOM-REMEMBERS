extends Node
## Oda diyalogları: res://data/dialogue/<room_id>.json
## Tüketiciler yalnız get_set görür; dosya biçimini bilmez.

const DIR := "res://data/dialogue/"


func get_set(room_id: StringName, set_id: StringName) -> Array:
	var path := DIR + "%s.json" % String(room_id)
	if not FileAccess.file_exists(path):
		push_error("DialogueData: dosya yok %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueData: JSON okunamadı %s" % path)
		return []
	var sets: Variant = (parsed as Dictionary).get("sets", {})
	if typeof(sets) != TYPE_DICTIONARY or not (sets as Dictionary).has(String(set_id)):
		push_error("DialogueData: set yok %s / %s" % [room_id, set_id])
		return []
	var raw: Variant = (sets as Dictionary)[String(set_id)]
	if typeof(raw) != TYPE_ARRAY:
		push_error("DialogueData: set dizi değil %s / %s" % [room_id, set_id])
		return []
	var out: Array = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var chosen: Dictionary = entry
		if (entry as Dictionary).has("variants"):
			chosen = _pick_variant((entry as Dictionary)["variants"])
			if chosen.is_empty():
				continue
		out.append([_speaker(String(chosen.get("s", ""))), String(chosen.get("t", ""))])
	return out


func _speaker(speaker: String) -> String:
	if speaker == "@shilda":
		return GameState.keeper_speaker_name()
	return speaker


func _pick_variant(variants: Variant) -> Dictionary:
	if typeof(variants) != TYPE_ARRAY:
		return {}
	for item in variants:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var when: Variant = (item as Dictionary).get("when", {})
		if typeof(when) != TYPE_DICTIONARY:
			when = {}
		if _when_matches(when):
			return item
	return {}


func _when_matches(when: Dictionary) -> bool:
	for key in when.keys():
		var name := String(key)
		var value: Variant = when[key]
		match name:
			"min_deaths":
				if int(GameState.player_progress_knowledge.get("deaths", 0)) < int(value):
					return false
			"flag":
				if not GameState.has_story_flag(StringName(String(value))):
					return false
			"not_flag":
				if GameState.has_story_flag(StringName(String(value))):
					return false
			"named":
				if GameState.is_shilda_named() != bool(value):
					return false
			"solved":
				if not PuzzleManager.is_solved(StringName(String(value))):
					return false
			_:
				return false
	return true
