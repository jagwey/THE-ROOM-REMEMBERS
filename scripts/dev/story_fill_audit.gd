extends SceneTree
## Hikaye diyalog dolgusu: oda başına satır sayısı, tekrar, uzunluk, cümle sınırı, toplam alt sınır.
## Çalıştır: godot --headless --path . -s res://scripts/dev/story_fill_audit.gd
const MIN_TOTAL := 650
const MAX_CHARS := 120
const MAX_SENTENCES := 2
const MECHANIC_KEYS := ["body_line", "solved_line", "locked_line", "locked_lines", "refusal_line"]
const SCENE_KEYS := ["lines", "locked_lines", "untrusted_lines", "body_line", "solved_line", "repeat_line", "locked_line", "refusal_line", "dialogue_sets"]
const PHASES := {
	"Mesafeli": ["awakening", "awakening_balcony", "awakening_crypt", "awakening_passage", "awakening_seal", "awakening_vigil"],
	"Merak": ["decay_cistern", "decay_garden", "decay_vines", "decay_weight", "decay_catacombs", "decay_shilda_wall"],
	"Güven": ["decay_greenhouse", "library_clockroom", "library_reading_cell", "library_forbidden_wing", "library_upper_stacks", "library_witness", "experiment_intake", "experiment_cells"],
	"Acı": ["experiment_observation", "experiment_quarantine", "experiment_circuit", "experiment_authority", "mirrors_1927", "mirrors_gallery", "mirrors_unbroken", "mirrors_dual", "mirrors_labyrinth", "mirrors_shrine"],
	"Ortak amaç": ["core_threshold", "core_ascent", "core_bloom_garden", "core_memory_vault", "core"],
}

var failures := 0
var per_room := {}
var all_lines: Array = [] ## [room, text]


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("SF ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _add(room: String, text: String, checked := true) -> void:
	per_room[room] = int(per_room.get(room, 0)) + 1
	if checked:
		all_lines.append([room, text])


func _strip_speaker(s: String) -> String:
	var i := s.find("|")
	if i > 0 and i <= 16:
		return s.substr(i + 1)
	return s


func _quoted(src: String) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for m in rx.search_all(src):
		out.append(m.get_string(1).replace("\\\"", "\"").replace("\\n", "\n"))
	return out


func _scan_json() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var room := String((parsed as Dictionary).get("room", f.get_basename()))
		var sets: Variant = (parsed as Dictionary).get("sets", {})
		if typeof(sets) != TYPE_DICTIONARY:
			continue
		for set_id in (sets as Dictionary).keys():
			for entry in (sets as Dictionary)[set_id]:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var first := true
				var variants: Array = (entry as Dictionary).get("variants", [entry])
				for v in variants:
					var t := String((v as Dictionary).get("t", ""))
					if first:
						_add(room, t)
						first = false
					else:
						all_lines.append([room, t])


func _scan_scenes() -> void:
	var dir := DirAccess.open("res://scenes/rooms")
	if dir == null:
		return
	var rx := RegEx.new()
	rx.compile("(?m)^(" + "|".join(SCENE_KEYS) + ")\\s*=\\s*(.*)$")
	for f in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		var room := f.get_basename()
		var txt := FileAccess.get_file_as_string("res://scenes/rooms/" + f).replace("\r", "")
		for m in rx.search_all(txt):
			var key := m.get_string(1)
			for q in _quoted(m.get_string(2)):
				if key == "dialogue_sets":
					for part in String(q).split(";;"):
						_add(room, _strip_speaker(String(part)))
				else:
					_add(room, _strip_speaker(String(q)), not MECHANIC_KEYS.has(key))


func _scan_scripts(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for d in dir.get_directories():
		if d == "dev":
			continue
		_scan_scripts(path.path_join(d))
	var rx := RegEx.new()
	rx.compile("say(?:_with)?\\(\\s*\"[^\"]*\"\\s*,\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string(path.path_join(f))
		for m in rx.search_all(txt):
			_add("script:" + f.get_basename(), m.get_string(1), f == "story_beat.gd")


func _sentences(t: String) -> int:
	var s := t.replace("S.", "S").replace("{deaths}", "0")
	var rx := RegEx.new()
	rx.compile("[.!?…]+[»\"]?(?:\\s|$)")
	return rx.search_all(s).size()


func _phase_total(rooms: Array) -> int:
	var n := 0
	for r in rooms:
		n += int(per_room.get(r, 0))
	return n


func _run() -> void:
	_scan_json()
	_scan_scenes()
	_scan_scripts("res://scripts")
	var total := all_lines.size()
	var counted := 0
	for k in per_room.keys():
		counted += int(per_room[k])
	print("SF total (incl. variants) ", total, " slots ", counted)
	for ph in PHASES.keys():
		print("SF phase ", ph, " = ", _phase_total(PHASES[ph]))
	var rooms: Array = per_room.keys()
	rooms.sort()
	for r in rooms:
		print("SF room ", r, " = ", per_room[r])
	check(counted >= MIN_TOTAL, "total dialogue lines >= %d (is %d)" % [MIN_TOTAL, counted])
	var seen := {}
	var dups := 0
	var too_long := 0
	var too_many := 0
	for pair in all_lines:
		var t := String(pair[1]).strip_edges()
		if t.length() > 12:
			if seen.has(t):
				dups += 1
				print("SF dup: ", pair[0], " / ", seen[t], " | ", t)
			seen[t] = pair[0]
		if t.length() > MAX_CHARS:
			too_long += 1
			print("SF long (", t.length(), "): ", pair[0], " | ", t)
		if _sentences(t) > MAX_SENTENCES:
			too_many += 1
			print("SF sentences: ", pair[0], " | ", t)
	check(dups == 0, "no exact duplicate lines")
	check(too_long == 0, "all lines <= %d chars" % MAX_CHARS)
	check(too_many == 0, "all lines <= %d sentences" % MAX_SENTENCES)
	print("SF RESULT ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
